import 'package:get/get.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../data/services/pocketbase_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/models/models.dart';
import '../../utils/constants.dart';

class UseCalculatorController extends GetxController {
  Calculator? calculator;

  InAppWebViewController? webViewController;

  final isLoading = true.obs;
  final hasError = false.obs;
  final isWebViewReady = false.obs;

  String? htmlContent;
  String? errorMessage;

  DateTime? sessionStartTime;
  String? currentUsageLogId;

  @override
  void onInit() {
    calculator = Get.arguments as Calculator?;

    if (calculator != null) {
      _startUsageTracking();
      loadCalculatorFile();
    } else {
      hasError.value = true;
      errorMessage = 'No calculator data provided';
      isLoading.value = false;
    }

    super.onInit();
  }

  /// ================================
  /// LOAD FILE (FIXED VERSION)
  /// ================================
  Future<void> loadCalculatorFile() async {
    print('📁 Loading calculator: ${calculator?.name}');
    print('📄 appFile from DB: ${calculator?.appFile}');
    print('📄 recordId: ${calculator?.id}');

    if (calculator?.appFile == null || calculator!.appFile.isEmpty) {
      hasError.value = true;
      errorMessage = 'Calculator file not found';
      isLoading.value = false;
      return;
    }

    try {
      isLoading.value = true;
      hasError.value = false;

      final directory = await getApplicationDocumentsDirectory();
      final localFile = File(
        '${directory.path}/calculator_${calculator!.id}.html',
      );

      /// ================================
      /// 1. CHECK CACHE
      /// ================================
      if (await localFile.exists()) {
        final cached = await localFile.readAsString();

        if (cached.trim().startsWith('<')) {
          htmlContent = cached;
          print('✅ Loaded from cache');
          _loadIntoWebViewIfReady();
          isLoading.value = false;
          return;
        } else {
          await localFile.delete();
        }
      }

      /// ================================
      /// 2. BUILD FILE URL (FIXED)
      /// ================================
      const collectionName = 'calculators';

      final downloadUrl = PocketBaseService.to.getFileUrl(
        collectionName: collectionName,
        recordId: calculator!.id,
        filename: calculator!.appFile,
      );

      print('🔗 FINAL URL: $downloadUrl');

      /// ================================
      /// 3. DOWNLOAD FILE
      /// ================================
      final response = await http.get(Uri.parse(downloadUrl));

      print('📡 HTTP STATUS: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('Failed to download file: ${response.statusCode}');
      }

      final body = response.body;

      if (!body.trim().startsWith('<')) {
        throw Exception('Invalid HTML received from server');
      }

      /// ================================
      /// 4. CACHE + STORE
      /// ================================
      await localFile.writeAsString(body);

      htmlContent = body;

      print('✅ Download + cache success');

      _loadIntoWebViewIfReady();
    } catch (e) {
      hasError.value = true;
      errorMessage = 'Failed to load calculator: $e';
      print('❌ ERROR: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// ================================
  /// WEBVIEW HANDLING
  /// ================================
  void onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;
    _loadIntoWebViewIfReady();
  }

  Future<void> _loadIntoWebViewIfReady() async {
    if (webViewController == null || htmlContent == null) return;

    await webViewController!.loadData(
      data: htmlContent!,
      baseUrl: WebUri(pocketbaseUrl),
    );

    print('🌐 HTML loaded into WebView');
  }

  void refreshWebView() {
    webViewController?.reload();
  }

  /// ================================
  /// USAGE TRACKING
  /// ================================
  Future<void> _startUsageTracking() async {
    try {
      final user = AuthService.to.currentUser.value;
      if (user == null || calculator == null) return;

      sessionStartTime = DateTime.now();

      final usageLogData = CalculatorUsageLog.forCreate(
        userId: user.id,
        calculatorId: calculator!.id,
        sessionStart: sessionStartTime!,
        calculatorType: calculator!.type,
      );

      final record = await PocketBaseService.to.createRecord(
        collectionName: CalculatorUsageLog.collection,
        data: usageLogData,
      );

      currentUsageLogId = record.id;
    } catch (e) {
      print('⚠️ Usage tracking failed: $e');
    }
  }

  Future<void> _endUsageTracking() async {
    try {
      if (currentUsageLogId == null || sessionStartTime == null) return;

      final end = DateTime.now();
      final duration = end.difference(sessionStartTime!);

      if (duration.inSeconds < 5) return;

      await PocketBaseService.to.updateRecord(
        collectionName: CalculatorUsageLog.collection,
        recordId: currentUsageLogId!,
        data: CalculatorUsageLog.forSessionEnd(sessionEnd: end),
      );
    } catch (e) {
      print('⚠️ End tracking failed: $e');
    }
  }

  @override
  void onClose() {
    _endUsageTracking();
    webViewController = null;
    super.onClose();
  }

  // ==========================================================
  // ✅ COMPATIBILITY LAYER (FIXES YOUR UI ERRORS)
  // ==========================================================

  String? get fileUrl => htmlContent;

  void retry() {
    if (calculator != null) {
      loadCalculatorFile();
    }
  }

  void onLoadStart(InAppWebViewController controller, WebUri? url) {
    isWebViewReady.value = false;
    print('🌐 WebView start: $url');
  }

  void onLoadStop(InAppWebViewController controller, WebUri? url) {
    isWebViewReady.value = true;
    print('🌐 WebView stop: $url');
  }

  void onLoadError(
    InAppWebViewController controller,
    WebUri? url,
    int code,
    String message,
  ) {
    hasError.value = true;
    errorMessage = message;
    print('❌ WebView error [$code]: $message');
  }
}
