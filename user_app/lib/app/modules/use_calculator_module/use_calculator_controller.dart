import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../data/services/backend_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/models/models.dart';
import '../../data/models/backend_record.dart';
import '../../utils/constants.dart';

class UseCalculatorController extends GetxController {
  static const String _bundledSampleAssetRoot =
      'lib/app/modules/tools_module/assets/samples';
  static const String _appPackageName = 'user_app';

  void _log(String message) => debugPrint(message);

  // Calculator data
  Calculator? calculator;

  // WebView controller
  InAppWebViewController? webViewController;

  // Reactive variables
  final isLoading = true.obs;
  final hasError = false.obs;
  final isWebViewReady = false.obs;

  String? fileUrl;
  String? errorMessage;

  // Usage tracking variables
  DateTime? sessionStartTime;
  String? currentUsageLogId;

  @override
  void onInit() {
    // Get calculator data from arguments
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

  /// Load HTML content (check local cache first, then download)
  Future<void> loadCalculatorFile() async {
    _log('📁 [Calculator] loadCalculatorFile started for ${calculator?.name}');
    _log('   📄 App file: ${calculator?.appFile}');

    if (calculator?.appFile == null || calculator!.appFile.isEmpty) {
      _log('   ❌ [Calculator] No app file specified');
      hasError.value = true;
      errorMessage = 'Calculator file not found';
      isLoading.value = false;
      return;
    }

    try {
      _log('   ⏳ [Calculator] Starting load process');
      isLoading.value = true;
      hasError.value = false;
      errorMessage = null;

      // Check if file exists locally first
      final directory = await getApplicationDocumentsDirectory();
      final localFile = File(
        '${directory.path}/calculator_${calculator!.id}.html',
      );
      _log('   📂 [Calculator] Cache directory: ${directory.path}');
      _log('   📄 [Calculator] Local file path: ${localFile.path}');

      // Ensure cache directory exists
      if (!await directory.exists()) {
        _log('   📁 [Calculator] Creating cache directory');
        await directory.create(recursive: true);
      }

      final fileExists = await localFile.exists();
      _log('   🔍 [Calculator] Local file exists: $fileExists');

      if (fileExists) {
        _log('   📦 [Calculator] Loading from local cache');
        final cachedContent = await localFile.readAsString();
        _log(
          '   📏 [Calculator] Cached content length: ${cachedContent.length} chars',
        );

        // Validate cached content is not empty and looks like HTML
        if (cachedContent.isNotEmpty && cachedContent.trim().startsWith('<')) {
          fileUrl = cachedContent;
          _log('   ✅ [Calculator] Valid HTML content loaded from cache');
        } else {
          _log('   ⚠️  [Calculator] Cached file exists but content is invalid');
          _log('   🗑️  [Calculator] Removing invalid cache file');
          await localFile.delete(); // Remove invalid cache
          fileUrl = null; // Mark as not loaded to trigger download
        }
      } else {
        _log('   ❌ [Calculator] No cached file found');
      }

      if (fileUrl == null || fileUrl!.isEmpty) {
        final bundledContent = await _loadBundledSampleContent(
          calculator!.appFile,
        );
        if (bundledContent != null && bundledContent.trim().startsWith('<')) {
          _log('   📦 [Calculator] Loading bundled sample asset');
          fileUrl = bundledContent;
          await localFile.writeAsString(bundledContent);
        } else if (_isBundledSampleReference(calculator!.appFile)) {
          throw Exception(
            'Bundled sample asset not found for ${calculator!.appFile}. '
            'Rebuild the app so Flutter repackages module assets.',
          );
        }
      }

      // Download if not cached, bundled, or cache was invalid
      if (fileUrl == null || fileUrl!.isEmpty) {
        _log('   🌐 [Calculator] Need to download - no valid cache');
        final downloadUrl = BackendService.to.getFileUrl(
          collectionName: Calculator.collection,
          recordId: calculator!.id,
          filename: calculator!.appFile,
        );
        _log('   🔗 [Calculator] Download URL: $downloadUrl');

        if (downloadUrl.isEmpty) {
          throw Exception('Unable to generate file URL');
        }

        _log('   ⬇️  [Calculator] Starting HTTP download');
        final response = await http.get(Uri.parse(downloadUrl));
        _log('   📡 [Calculator] HTTP response code: ${response.statusCode}');

        if (response.statusCode != 200) {
          throw Exception('Failed to download file: ${response.statusCode}');
        }

        _log(
          '   📏 [Calculator] Downloaded content length: ${response.body.length} chars',
        );

        // Validate downloaded content
        if (response.body.isEmpty || !response.body.trim().startsWith('<')) {
          _log('   ❌ [Calculator] Downloaded content is not valid HTML');
          throw Exception('Downloaded file is not valid HTML content');
        }

        _log('   💾 [Calculator] Saving to cache and setting fileUrl');
        // Save to cache and use for WebView
        await localFile.writeAsString(response.body);
        fileUrl = response.body;
        _log('   ✅ [Calculator] Download and cache complete');
      } else {
        _log('   ✅ [Calculator] Using existing cached content');
      }
    } catch (e) {
      hasError.value = true;
      errorMessage = 'Failed to load calculator: ${e.toString()}';
      _log('Error loading calculator: $e');
    } finally {
      isLoading.value = false;

      // If WebView is already created, load the content
      if (webViewController != null && fileUrl != null && fileUrl!.isNotEmpty) {
        _log('Loading HTML content into existing WebView');
        _loadHtmlIntoWebView();
      }
    }
  }

  Future<String?> _loadBundledSampleContent(String appFile) async {
    for (final assetPath in _candidateBundledAssetPaths(appFile)) {
      try {
        _log('   🔎 [Calculator] Trying bundled asset: $assetPath');
        return await rootBundle.loadString(assetPath);
      } catch (e) {
        _log('   ⚠️  [Calculator] Bundled asset miss: $assetPath -> $e');
        continue;
      }
    }
    return null;
  }

  List<String> _candidateBundledAssetPaths(String appFile) {
    final normalized = appFile.trim().replaceAll('\\', '/');
    if (normalized.isEmpty) {
      return const <String>[];
    }

    final basename = normalized.split('/').last;
    final candidates = <String>{
      if (normalized.startsWith('assets/')) normalized,
      if (normalized.startsWith('lib/')) normalized,
      if (normalized.startsWith('samples/')) normalized,
      if (normalized.startsWith('samples/'))
        '$_bundledSampleAssetRoot/${normalized.split('/').last}',
      'packages/$_appPackageName/$_bundledSampleAssetRoot/$basename',
      '$_bundledSampleAssetRoot/$basename',
    };

    return candidates.toList(growable: false);
  }

  bool _isBundledSampleReference(String appFile) {
    final normalized = appFile.trim().replaceAll('\\', '/');
    if (normalized.isEmpty) {
      return false;
    }
    return normalized.startsWith('samples/') ||
        normalized.startsWith(_bundledSampleAssetRoot) ||
        normalized.startsWith('lib/app/modules/tools_module/assets/samples/');
  }

  /// Retry loading the calculator
  void retry() {
    if (calculator != null) {
      loadCalculatorFile();
    }
  }

  /// Refresh the WebView
  void refreshWebView() {
    webViewController?.reload();
  }

  /// Handle WebView creation
  void onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;
    _log('🌐 [WebView] WebView created and controller set');

    // Load HTML content if available
    if (fileUrl != null && fileUrl!.isNotEmpty) {
      _log('📄 [WebView] HTML content available, loading into WebView');
      _loadHtmlIntoWebView();
    } else {
      _log('⚠️  [WebView] No HTML content available yet');
    }
  }

  /// Load HTML content into WebView
  Future<void> _loadHtmlIntoWebView() async {
    _log('🔄 [WebView] _loadHtmlIntoWebView called');
    if (webViewController != null && fileUrl != null && fileUrl!.isNotEmpty) {
      _log('   📏 [WebView] Content length: ${fileUrl!.length} chars');
      // Add a small delay to ensure WebView is fully ready
      await Future.delayed(const Duration(milliseconds: 100));

      _log('   📤 [WebView] Calling loadData()');
      await webViewController!.loadData(
        data: fileUrl!,
        baseUrl: WebUri(backendBaseUrl),
      );
      _log('   ✅ [WebView] loadData() completed');
    } else {
      _log('   ❌ [WebView] Cannot load - missing controller or content');
      _log('   🔍 [WebView] WebView controller: ${webViewController != null}');
      _log(
        '   🔍 [WebView] FileUrl available: ${fileUrl != null && fileUrl!.isNotEmpty}',
      );
    }
  }

  /// Handle page load start
  void onLoadStart(InAppWebViewController controller, WebUri? url) {
    isWebViewReady.value = false;
    _log('WebView loading URL: ${url?.toString()}');
  }

  /// Handle page load completion
  void onLoadStop(InAppWebViewController controller, WebUri? url) {
    isWebViewReady.value = true;
    _log('WebView finished loading URL: ${url?.toString()}');
  }

  /// Handle page load errors
  void onLoadError(
    InAppWebViewController controller,
    WebUri? url,
    int code,
    String message,
  ) {
    hasError.value = true;
    errorMessage = 'Failed to load: $message';
  }

  @override
  void onClose() {
    _endUsageTracking();
    webViewController = null;
    super.onClose();
  }

  // ==================== USAGE TRACKING METHODS ====================

  /// Start tracking calculator usage session
  Future<void> _startUsageTracking() async {
    try {
      if (calculator == null) return;

      final user = AuthService.to.currentUser.value;
      if (user == null) return;

      sessionStartTime = DateTime.now();

      // Create usage log record with session_start
      final usageLogData = CalculatorUsageLog.forCreate(
        userId: user.id,
        calculatorId: calculator!.id,
        sessionStart: sessionStartTime!,
        calculatorType: calculator!.type,
      );

      final record = await BackendService.to.createRecord(
        collectionName: CalculatorUsageLog.collection,
        data: usageLogData,
      );

      currentUsageLogId = record.id;
      _log('📊 [Usage] Started tracking session: $currentUsageLogId');
    } catch (e) {
      if (e is ClientException && BackendService.to.isAuthenticationError(e)) {
        _log(
          '⚠️  [Usage] Skipping tracking because the session is no longer valid',
        );
        return;
      }
      _log('⚠️  [Usage] Failed to start tracking: $e');
      // Don't show error to user - tracking failure shouldn't interrupt app flow
    }
  }

  /// End tracking calculator usage session
  Future<void> _endUsageTracking() async {
    try {
      if (currentUsageLogId == null || sessionStartTime == null) return;

      final sessionEnd = DateTime.now();
      final duration = sessionEnd.difference(sessionStartTime!);

      // Only track sessions longer than 5 seconds to avoid accidental opens
      if (duration.inSeconds < 5) {
        _log(
          '📊 [Usage] Session too short (${duration.inSeconds}s), not recording',
        );
        return;
      }

      // Update usage log record with session_end
      await BackendService.to.updateRecord(
        collectionName: CalculatorUsageLog.collection,
        recordId: currentUsageLogId!,
        data: CalculatorUsageLog.forSessionEnd(sessionEnd: sessionEnd),
      );

      // Increment calculator usage count
      await _incrementCalculatorUsageCount();

      _log(
        '📊 [Usage] Ended session: ${duration.inMinutes}m ${duration.inSeconds % 60}s',
      );
    } catch (e) {
      if (e is ClientException && BackendService.to.isAuthenticationError(e)) {
        _log(
          '⚠️  [Usage] Skipping usage completion because the session is no longer valid',
        );
      } else {
        _log('⚠️  [Usage] Failed to end tracking: $e');
      }
      // Don't show error to user - tracking failure shouldn't interrupt app flow
    } finally {
      // Reset tracking variables
      currentUsageLogId = null;
      sessionStartTime = null;
    }
  }

  /// Increment the calculator's usage count
  Future<void> _incrementCalculatorUsageCount() async {
    try {
      if (calculator == null) return;

      final currentCount = calculator!.usageCount;
      final newCount = currentCount + 1;

      await BackendService.to.updateRecord(
        collectionName: Calculator.collection,
        recordId: calculator!.id,
        data: {'usageCount': newCount},
      );

      // Update local calculator object
      calculator!.data['usageCount'] = newCount;

      _log('📊 [Usage] Incremented calculator usage count to: $newCount');
    } catch (e) {
      _log('⚠️  [Usage] Failed to increment usage count: $e');
    }
  }
}
