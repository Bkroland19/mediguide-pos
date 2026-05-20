import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../models/backend_record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_app/app/utils/constants.dart';

import '../models/user.dart';

typedef BackendErrorInterceptor = Future<void> Function(ClientException error);

/// Backend compatibility service.
///
/// Provides a backend-first data API for the mobile app.
class BackendService extends GetxService {
  static BackendService get to => Get.find();

  static const Set<String> _bestEffortWriteCollections = {
    'reading_progress',
    'calculator_usage_logs',
    'guideline_usage_logs',
    'drug_usage_logs',
    'abbreviation_usage_logs',
    'consultant_usage_logs',
    'facility_usage_logs',
    'ai_usage_logs',
  };

  final Map<String, Timer> _pollers = {};
  String? _token;
  String? _refreshToken;
  BackendErrorInterceptor? _errorInterceptor;
  bool _isHandlingAuthFailure = false;

  Future<BackendService> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(SharedPreferencesKeys.userToken);
    _refreshToken = prefs.getString(SharedPreferencesKeys.refreshToken);
    return this;
  }

  bool get isAuthenticated => (_token ?? '').isNotEmpty;

  void setErrorInterceptor(BackendErrorInterceptor interceptor) {
    _errorInterceptor = interceptor;
  }

  bool supportsCollectionWrite(String collectionName, {bool files = false}) {
    if (files) {
      return false;
    }
    switch (collectionName) {
      case User.collection:
      case 'support_tickets':
      case 'support_ticket_replies':
      case 'conversations':
      case 'messages':
      case 'reading_progress':
      case 'calculator_usage_logs':
      case 'guideline_usage_logs':
      case 'drug_usage_logs':
      case 'abbreviation_usage_logs':
      case 'consultant_usage_logs':
      case 'facility_usage_logs':
      case 'ai_usage_logs':
        return true;
      default:
        return false;
    }
  }

  bool get supportsMessaging =>
      supportsCollectionWrite('conversations') &&
      supportsCollectionWrite('messages');

  bool get supportsSupportTickets =>
      supportsCollectionWrite('support_tickets') &&
      supportsCollectionWrite('support_ticket_replies');

  bool get supportsProfileEditing => supportsCollectionWrite(User.collection);

  bool isBestEffortCollectionWrite(String collectionName) {
    return _bestEffortWriteCollections.contains(collectionName);
  }

  String unsupportedCollectionWriteMessage(
    String collectionName, {
    bool files = false,
  }) {
    if (files && collectionName == User.collection) {
      return 'Profile photo uploads are not exposed by the backend yet.';
    }

    switch (collectionName) {
      case User.collection:
        return 'Profile editing is not exposed by the backend yet.';
      case 'support_tickets':
      case 'support_ticket_replies':
        return 'Support ticket creation is not exposed by the backend yet.';
      case 'conversations':
      case 'messages':
        return 'Messaging is not exposed by the backend yet.';
      case 'calculators':
        return 'Calculator management is not exposed by the backend yet.';
      case 'drugs':
        return 'Drug management is not exposed by the backend yet.';
      case 'medical_guidelines':
        return 'Guideline management is not exposed by the backend yet.';
      default:
        return 'This action is not exposed by the backend yet.';
    }
  }

  Future<RecordModel> register({
    required String email,
    required String password,
    required String passwordConfirm,
    Map<String, dynamic>? additionalData,
  }) async {
    final payload = _normalizeUserWritePayload({
      ...?additionalData,
      'email': email,
      'password': password,
      'passwordConfirm': passwordConfirm,
    });

    final response = await _requestJson(
      'POST',
      '/api/v2/auth/register',
      body: payload,
      authRequired: false,
    );

    final user = _extractDataMap(response);
    final createdUser = RecordModel.fromJson(
      _normalizeIncomingRecord(User.collection, user),
    );

    try {
      final loggedInUser = await login(email: email, password: password);
      return loggedInUser;
    } catch (_) {
      return createdUser;
    }
  }

  Future<RecordModel> login({
    required String email,
    required String password,
    String? expand,
  }) async {
    final response = await _requestJson(
      'POST',
      '/api/v2/auth/login',
      body: {'email': email, 'password': password},
      authRequired: false,
    );

    final data = _extractDataMap(response);
    _token = (data['token'] ?? '').toString();
    _refreshToken = (data['refresh_token'] ?? '').toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPreferencesKeys.userToken, _token ?? '');
    await prefs.setString(
      SharedPreferencesKeys.refreshToken,
      _refreshToken ?? '',
    );

    final user = Map<String, dynamic>.from(data['user'] as Map? ?? const {});
    return RecordModel.fromJson(
      _normalizeIncomingRecord(User.collection, user),
    );
  }

  Future<AuthMethodsList> getAuthMethods() async {
    return AuthMethodsList();
  }

  Future<void> requestPasswordReset(String email) async {
    throw UnimplementedError(
      'Password reset is not exposed by the backend yet.',
    );
  }

  Future<void> confirmPasswordReset({
    required String token,
    required String password,
    required String passwordConfirm,
  }) async {
    throw UnimplementedError(
      'Password reset confirmation is not exposed by the backend yet.',
    );
  }

  Future<void> confirmEmailVerification(String token) async {
    throw UnimplementedError(
      'Email verification is not exposed by the backend yet.',
    );
  }

  Future<void> refreshAuth() async {
    if ((_refreshToken ?? '').isNotEmpty) {
      await refreshSession();
      return;
    }
    if (!isAuthenticated) return;
    final response = await _requestJson('GET', '/api/v2/me');
    final data = _extractDataMap(response);
    if (data.isEmpty) {
      await logout();
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    throw UnsupportedError(
      'Password change is not exposed by the backend yet.',
    );
  }

  Future<void> logout() async {
    if (isAuthenticated) {
      try {
        await _requestJson('POST', '/api/v2/auth/logout', body: const {});
      } catch (_) {}
    }
    _token = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SharedPreferencesKeys.userToken);
    await prefs.remove(SharedPreferencesKeys.refreshToken);
    await prefs.remove(SharedPreferencesKeys.currentUser);
  }

  Future<void> refreshSession() async {
    final refreshToken = (_refreshToken ?? '').trim();
    if (refreshToken.isEmpty) {
      throw ClientException(
        response: const {'error': 'refresh token missing'},
        originalError: 'Refresh token missing',
      );
    }

    final response = await _requestJson(
      'POST',
      '/api/v2/auth/refresh',
      body: {'refresh_token': refreshToken},
      authRequired: false,
    );
    final data = _extractDataMap(response);
    _token = (data['token'] ?? '').toString();
    _refreshToken = (data['refresh_token'] ?? '').toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPreferencesKeys.userToken, _token ?? '');
    await prefs.setString(
      SharedPreferencesKeys.refreshToken,
      _refreshToken ?? '',
    );
  }

  Future<RecordModel> createRecord({
    required String collectionName,
    required Map<String, dynamic> data,
    List<http.MultipartFile>? files,
  }) async {
    if (files != null && files.isNotEmpty) {
      throw UnsupportedError(
        unsupportedCollectionWriteMessage(collectionName, files: true),
      );
    }

    if (!supportsCollectionWrite(collectionName) &&
        !isBestEffortCollectionWrite(collectionName)) {
      throw UnsupportedError(unsupportedCollectionWriteMessage(collectionName));
    }

    try {
      final response = await _requestJson(
        'POST',
        '/api/v1/$collectionName',
        body: _normalizeOutgoingRecord(collectionName, data),
      );
      final item = _extractItemMap(response);
      return RecordModel.fromJson(
        _normalizeIncomingRecord(collectionName, item),
      );
    } catch (e) {
      if (supportsCollectionWrite(collectionName)) {
        rethrow;
      }
      if (!isBestEffortCollectionWrite(collectionName)) {
        throw UnsupportedError(
          unsupportedCollectionWriteMessage(collectionName),
        );
      }

      // Fallback to optimistic local record for flows that the backend
      // does not yet expose as write endpoints but are safe as best-effort
      // local/session state.
      final now = DateTime.now().toIso8601String();
      return RecordModel.fromJson(
        _normalizeIncomingRecord(collectionName, {
          'id': data['id'] ?? 'local-${DateTime.now().microsecondsSinceEpoch}',
          'created_at': now,
          'updated_at': now,
          ..._normalizeOutgoingRecord(collectionName, data),
        }),
      );
    }
  }

  Future<ResultList<RecordModel>> getRecordList({
    required String collectionName,
    int page = 1,
    int perPage = 30,
    String? filter,
    String? sort,
    String? expand,
    bool forceRefresh = false,
  }) async {
    final fetched = await _fetchCollectionItems(
      collectionName: collectionName,
      search: null,
    );

    final filtered = _applyFilter(
      fetched
          .map((item) => _normalizeIncomingRecord(collectionName, item))
          .toList(),
      filter,
    );
    final sorted = _applySort(filtered, sort);
    final totalItems = sorted.length;
    final totalPages = totalItems == 0 ? 0 : ((totalItems - 1) ~/ perPage) + 1;
    final start = ((page - 1) * perPage).clamp(0, totalItems);
    final end = (start + perPage).clamp(0, totalItems);
    final items = sorted
        .sublist(start, end)
        .map(RecordModel.fromJson)
        .toList(growable: false);

    return ResultList<RecordModel>(
      page: page,
      perPage: perPage,
      totalItems: totalItems,
      totalPages: totalPages,
      items: items,
    );
  }

  Future<List<RecordModel>> getFullList({
    required String collectionName,
    int batch = 100,
    String? filter,
    String? sort,
    String? expand,
  }) async {
    final result = await getRecordList(
      collectionName: collectionName,
      page: 1,
      perPage: batch,
      filter: filter,
      sort: sort,
      expand: expand,
    );
    return result.items;
  }

  Future<RecordModel?> getRecord({
    required String collectionName,
    required String recordId,
    String? expand,
    bool forceRefresh = false,
  }) async {
    try {
      final response = await _requestJson(
        'GET',
        '/api/v1/$collectionName/$recordId',
      );
      final item = _extractItemMap(response);
      return RecordModel.fromJson(
        _normalizeIncomingRecord(collectionName, item),
      );
    } catch (_) {
      return null;
    }
  }

  Future<RecordModel> getFirstListItem({
    required String collectionName,
    required String filter,
    String? expand,
  }) async {
    final result = await getRecordList(
      collectionName: collectionName,
      page: 1,
      perPage: 1,
      filter: filter,
      expand: expand,
    );
    if (result.items.isEmpty) {
      throw Exception('No matching record found');
    }
    return result.items.first;
  }

  Future<RecordModel> updateRecord({
    required String collectionName,
    required String recordId,
    required Map<String, dynamic> data,
    List<http.MultipartFile>? files,
  }) async {
    if (files != null && files.isNotEmpty) {
      throw UnsupportedError(
        unsupportedCollectionWriteMessage(collectionName, files: true),
      );
    }

    if (!supportsCollectionWrite(collectionName) &&
        !isBestEffortCollectionWrite(collectionName)) {
      throw UnsupportedError(unsupportedCollectionWriteMessage(collectionName));
    }

    try {
      final response = await _requestJson(
        'PATCH',
        '/api/v1/$collectionName/$recordId',
        body: _normalizeOutgoingRecord(collectionName, data),
      );
      final item = _extractItemMap(response);
      return RecordModel.fromJson(
        _normalizeIncomingRecord(collectionName, item),
      );
    } catch (e) {
      if (supportsCollectionWrite(collectionName)) {
        rethrow;
      }
      if (!isBestEffortCollectionWrite(collectionName)) {
        throw UnsupportedError(
          unsupportedCollectionWriteMessage(collectionName),
        );
      }

      final existing = await getRecord(
        collectionName: collectionName,
        recordId: recordId,
      );
      final merged = {
        ...?existing?.data,
        ..._normalizeOutgoingRecord(collectionName, data),
        'id': recordId,
        'updated_at': DateTime.now().toIso8601String(),
      };
      return RecordModel.fromJson(
        _normalizeIncomingRecord(collectionName, merged),
      );
    }
  }

  Future<void> deleteRecord({
    required String collectionName,
    required String recordId,
  }) async {
    if (!supportsCollectionWrite(collectionName)) {
      throw UnsupportedError(unsupportedCollectionWriteMessage(collectionName));
    }
    await _requestJson('DELETE', '/api/v1/$collectionName/$recordId');
  }

  Future<RecordModel> upsertRecord({
    required String collectionName,
    required Map<String, dynamic> data,
    String idField = 'id',
    List<http.MultipartFile>? files,
  }) async {
    final recordId = data[idField]?.toString();
    if (recordId == null || recordId.isEmpty) {
      return createRecord(
        collectionName: collectionName,
        data: data,
        files: files,
      );
    }
    return updateRecord(
      collectionName: collectionName,
      recordId: recordId,
      data: data,
      files: files,
    );
  }

  Future<List<dynamic>> batchOperation(
    List<Map<String, dynamic>> operations,
  ) async {
    final results = <dynamic>[];
    for (final operation in operations) {
      final type = operation['type']?.toString();
      final collection = operation['collection']?.toString() ?? '';
      final data = Map<String, dynamic>.from(
        operation['data'] as Map? ?? const {},
      );
      switch (type) {
        case 'create':
          results.add(
            await createRecord(collectionName: collection, data: data),
          );
        case 'update':
          results.add(
            await updateRecord(
              collectionName: collection,
              recordId: operation['id'].toString(),
              data: data,
            ),
          );
        case 'delete':
          await deleteRecord(
            collectionName: collection,
            recordId: operation['id'].toString(),
          );
          results.add(true);
        case 'upsert':
          results.add(
            await upsertRecord(collectionName: collection, data: data),
          );
        default:
          throw Exception('Unknown operation type: $type');
      }
    }
    return results;
  }

  void subscribeToCollection(
    String collectionName,
    Function(RecordSubscriptionEvent) callback, {
    String recordId = '*',
    String? filter,
  }) {
    final subscriptionId = '$collectionName/$recordId';
    _pollers[subscriptionId]?.cancel();
    _pollers[subscriptionId] = Timer.periodic(const Duration(seconds: 20), (
      _,
    ) async {
      // Compatibility no-op poller: keep the API surface but avoid breaking controllers.
      // The app already reloads most views on entry and user actions.
    });
  }

  void unsubscribeFromCollection({
    required String collectionName,
    String recordId = '*',
  }) {
    final subscriptionId = '$collectionName/$recordId';
    _pollers.remove(subscriptionId)?.cancel();
  }

  void subscribeToCustomEvent({
    required String eventName,
    required Function(dynamic) callback,
  }) {}

  void unsubscribeFromCustomEvent(String eventName) {}

  Future<Map<String, dynamic>> callCustomEndpoint({
    required String path,
    required String method,
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool forceRefresh = false,
    Duration? timeout,
  }) async {
    return _requestJson(
      method.toUpperCase(),
      _normalizeCustomPath(path),
      body: body,
      query: query,
      headers: headers,
      timeout: timeout,
    );
  }

  Future<Map<String, dynamic>> getCustomEndpoint({
    required String path,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool forceRefresh = false,
    Duration? timeout,
  }) async {
    return callCustomEndpoint(
      path: path,
      method: 'GET',
      query: query,
      headers: headers,
      forceRefresh: forceRefresh,
      timeout: timeout,
    );
  }

  Future<Map<String, dynamic>> postCustomEndpoint({
    required String path,
    required Map<String, dynamic> body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return callCustomEndpoint(
      path: path,
      method: 'POST',
      body: body,
      query: query,
      headers: headers,
      timeout: timeout,
    );
  }

  void unsubscribeFromAll() {
    for (final poller in _pollers.values) {
      poller.cancel();
    }
    _pollers.clear();
  }

  void onDisconnect(Function(List<String>) callback) {}

  String getFileUrl({
    RecordModel? record,
    String? collectionName,
    String? recordId,
    required String filename,
    String? thumb,
  }) {
    if (filename.isEmpty) return '';
    if (filename.startsWith('http://') || filename.startsWith('https://')) {
      return filename;
    }
    if (filename.startsWith('/')) {
      return '$backendBaseUrl$filename';
    }
    return '$backendBaseUrl/$filename';
  }

  Future<String> getFileToken() async => '';

  String createFilter(String filterTemplate, Map<String, dynamic> params) {
    var result = filterTemplate;
    params.forEach((key, value) {
      final replacement = value is num || value is bool ? '$value' : '"$value"';
      result = result.replaceAll('{$key}', replacement);
    });
    return result;
  }

  Future<bool> checkConnection() async {
    try {
      final response = await _requestJson(
        'GET',
        '/api/healthz',
        authRequired: false,
      );
      return response['ok'] == true || response['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> incrementUsageCount(
    String collectionName,
    String recordId,
  ) async {
    // Usage tracking is now represented by dedicated usage log collections.
  }

  String _normalizeCustomPath(String path) {
    final trimmed = path.trim();
    if (!trimmed.startsWith('/api/')) {
      return trimmed;
    }
    if (trimmed.startsWith('/api/v1/') || trimmed.startsWith('/api/v2/')) {
      return trimmed;
    }
    return trimmed.replaceFirst('/api/', '/api/v1/');
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool authRequired = true,
    Duration? timeout,
    bool attemptedRefresh = false,
  }) async {
    final uri = _buildUri(path, query: query);
    if (authRequired && !isAuthenticated) {
      final exception = ClientException(
        url: uri,
        statusCode: 401,
        response: const {'error': 'authentication required'},
        originalError: 'Authentication required',
      );
      await _handleClientException(exception);
      throw exception;
    }

    final mergedHeaders = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (authRequired && isAuthenticated) 'Authorization': 'Bearer $_token',
      ...?headers,
    };

    try {
      late final Future<http.Response> request;
      switch (method.toUpperCase()) {
        case 'GET':
          request = http.get(uri, headers: mergedHeaders);
        case 'POST':
          request = http.post(
            uri,
            headers: mergedHeaders,
            body: jsonEncode(body ?? const {}),
          );
        case 'PATCH':
          request = http.patch(
            uri,
            headers: mergedHeaders,
            body: jsonEncode(body ?? const {}),
          );
        case 'PUT':
          request = http.put(
            uri,
            headers: mergedHeaders,
            body: jsonEncode(body ?? const {}),
          );
        case 'DELETE':
          request = http.delete(uri, headers: mergedHeaders);
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      final response = timeout == null
          ? await request
          : await request.timeout(timeout);

      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      if (response.statusCode == 401 &&
          authRequired &&
          !attemptedRefresh &&
          (_refreshToken ?? '').trim().isNotEmpty) {
        try {
          await refreshSession();
          return _requestJson(
            method,
            path,
            body: body,
            query: query,
            headers: headers,
            authRequired: authRequired,
            timeout: timeout,
            attemptedRefresh: true,
          );
        } catch (_) {}
      }

      final exception = ClientException(
        url: uri,
        statusCode: response.statusCode,
        response: decoded,
        originalError:
            decoded['error']?.toString() ??
            decoded['message']?.toString() ??
            'Request failed with status ${response.statusCode}',
      );
      await _handleClientException(exception);
      throw exception;
    } on TimeoutException {
      final seconds = timeout?.inSeconds ?? 0;
      final exception = ClientException(
        url: uri,
        isAbort: true,
        response: const {'error': 'request timed out'},
        originalError: seconds > 0
            ? 'Request timed out after $seconds seconds'
            : 'Request timed out',
      );
      await _handleClientException(exception);
      throw exception;
    }
  }

  bool isAuthenticationError(ClientException error) {
    final message =
        error.originalError?.toString().toLowerCase() ??
        error.response['error']?.toString().toLowerCase() ??
        error.response['message']?.toString().toLowerCase() ??
        '';
    return error.statusCode == 401 ||
        message.contains('invalid token') ||
        message.contains('authentication required') ||
        message.contains('unauthorized');
  }

  Future<void> _handleClientException(ClientException error) async {
    if (isAuthenticationError(error) && !_isHandlingAuthFailure) {
      _isHandlingAuthFailure = true;
      try {
        await logout();
      } finally {
        _isHandlingAuthFailure = false;
      }
    }

    final interceptor = _errorInterceptor;
    if (interceptor != null) {
      await interceptor(error);
    }
  }

  Uri _buildUri(String path, {Map<String, dynamic>? query}) {
    final base = backendBaseUrl.endsWith('/')
        ? backendBaseUrl.substring(0, backendBaseUrl.length - 1)
        : backendBaseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$base$normalizedPath');
    final queryParameters = <String, String>{};
    query?.forEach((key, value) {
      if (value != null) queryParameters[key] = value.toString();
    });
    return uri.replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchCollectionItems({
    required String collectionName,
    String? search,
  }) async {
    if (_collectionNeedsAuth(collectionName) && !isAuthenticated) {
      return const <Map<String, dynamic>>[];
    }

    final items = <Map<String, dynamic>>[];
    var page = 1;
    const perPage = 100;
    var totalItems = 0;

    do {
      final response = await _requestJson(
        'GET',
        '/api/v1/$collectionName',
        authRequired: _collectionNeedsAuth(collectionName),
        query: {
          'page': page,
          'per_page': perPage,
          if (search != null && search.isNotEmpty) 'q': search,
        },
      );

      final pageItems = (response['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      items.addAll(pageItems);
      totalItems = (response['total_items'] as num?)?.toInt() ?? items.length;
      page++;
    } while (items.length < totalItems);

    return items;
  }

  bool _collectionNeedsAuth(String collectionName) {
    const authCollections = {
      'notifications',
      'support_tickets',
      'support_ticket_replies',
      'conversations',
      'messages',
      'reading_progress',
      'calculator_usage_logs',
      'guideline_usage_logs',
      'drug_usage_logs',
      'abbreviation_usage_logs',
      'consultant_usage_logs',
      'facility_usage_logs',
      'ai_usage_logs',
      'users',
    };
    return authCollections.contains(collectionName);
  }

  Map<String, dynamic> _extractDataMap(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Map<String, dynamic> _extractItemMap(Map<String, dynamic> response) {
    if (response['item'] is Map<String, dynamic>) {
      return response['item'] as Map<String, dynamic>;
    }
    if (response['item'] is Map) {
      return Map<String, dynamic>.from(response['item'] as Map);
    }
    final data = response['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Map<String, dynamic> _normalizeOutgoingRecord(
    String collectionName,
    Map<String, dynamic> data,
  ) {
    final normalized = Map<String, dynamic>.from(data);
    switch (collectionName) {
      case User.collection:
        return _normalizeUserWritePayload(normalized);
      case 'reading_progress':
        _rename(normalized, 'guideline_id', 'guideline_document_id');
        normalized.remove('total_sections');
        normalized.remove('is_completed');
        return normalized;
      case 'guideline_usage_logs':
        _rename(normalized, 'guideline_id', 'guideline_document_id');
        return normalized;
      case 'conversations':
        _rename(normalized, 'participant1', 'participant1_user_id');
        _rename(normalized, 'participant2', 'participant2_user_id');
        normalized.remove('last_message');
        return normalized;
      case 'messages':
        _rename(normalized, 'conversation', 'conversation_id');
        _rename(normalized, 'sender', 'sender_user_id');
        _rename(normalized, 'reply_to', 'reply_to_id');
        _rename(normalized, 'attachments', 'attachments_json');
        _rename(normalized, 'read_by', 'read_by_json');
        _rename(normalized, 'reactions', 'reactions_json');
        return normalized;
      case 'calculators':
        _rename(normalized, 'backgroundColor', 'background_color');
        _rename(normalized, 'appFile', 'app_file_json');
        _rename(normalized, 'addedBy', 'added_by_user_id');
        _rename(normalized, 'usageCount', 'usage_count');
        return normalized;
      case 'consultants':
        _rename(normalized, 'user', 'user_id');
        _rename(normalized, 'alternativePhone', 'alternative_phone');
        _rename(normalized, 'licenseNumber', 'license_number');
        _rename(normalized, 'yearsOfExperience', 'years_of_experience');
        _rename(normalized, 'postalCode', 'postal_code');
        _rename(normalized, 'preferredLanguage', 'preferred_language');
        _rename(normalized, 'consultationTypes', 'consultation_types');
        _rename(normalized, 'isVerified', 'is_verified');
        _rename(normalized, 'totalConsultations', 'total_consultations');
        _rename(normalized, 'availability', 'availability_json');
        return normalized;
      default:
        return normalized;
    }
  }

  Map<String, dynamic> _normalizeUserWritePayload(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);
    _rename(normalized, 'passwordConfirm', 'password_confirm');
    _rename(normalized, 'alternativePhone', 'alternative_phone');
    _rename(normalized, 'facilityId', 'facility_id');
    _rename(normalized, 'postalCode', 'postal_code');
    _rename(normalized, 'licenseNumber', 'license_number');
    _rename(normalized, 'jobTitle', 'job_title');
    _rename(normalized, 'preferredLanguage', 'preferred_language');
    if (normalized['specialization'] is String) {
      final value = normalized['specialization'].toString().trim();
      normalized['specialization'] = value.isEmpty
          ? <String>[]
          : <String>[value];
    }
    normalized.remove('role');
    normalized.remove('emailVisibility');
    return normalized;
  }

  Map<String, dynamic> _normalizeIncomingRecord(
    String collectionName,
    Map<String, dynamic> raw,
  ) {
    final normalized = Map<String, dynamic>.from(raw);
    normalized['collectionName'] = collectionName;
    normalized['collectionId'] = collectionName;
    normalized['created'] =
        normalized['created'] ?? normalized['created_at'] ?? '';
    normalized['updated'] =
        normalized['updated'] ?? normalized['updated_at'] ?? '';

    switch (collectionName) {
      case User.collection:
        normalized['alternativePhone'] =
            normalized['alternativePhone'] ??
            normalized['alternative_phone'] ??
            '';
        normalized['facilityId'] =
            normalized['facilityId'] ?? normalized['facility_id'] ?? '';
        normalized['postalCode'] =
            normalized['postalCode'] ?? normalized['postal_code'] ?? '';
        normalized['licenseNumber'] =
            normalized['licenseNumber'] ?? normalized['license_number'] ?? '';
        normalized['jobTitle'] =
            normalized['jobTitle'] ?? normalized['job_title'] ?? '';
        normalized['preferredLanguage'] =
            normalized['preferredLanguage'] ??
            normalized['preferred_language'] ??
            '';
        final specialization = normalized['specialization'];
        if (specialization is List && specialization.isNotEmpty) {
          normalized['specialization'] = specialization.first.toString();
        } else {
          normalized['specialization'] =
              normalized['specialization']?.toString() ?? '';
        }
        final roles = normalized['roles'];
        if (normalized['role'] == null && roles is List && roles.isNotEmpty) {
          final firstRole = Map<String, dynamic>.from(
            (roles.first as Map?) ?? const {},
          );
          normalized['role'] =
              firstRole['role_key']?.toString() ??
              firstRole['name']?.toString() ??
              'healthcareProvider';
        }
        normalized['emailVisibility'] = normalized['emailVisibility'] ?? false;
        break;
      case 'calculators':
        normalized['backgroundColor'] =
            normalized['backgroundColor'] ??
            normalized['background_color'] ??
            '';
        normalized['appFile'] =
            normalized['appFile'] ??
            _extractFileValue(normalized['app_file_json']);
        normalized['addedBy'] =
            normalized['addedBy'] ?? normalized['added_by_user_id'] ?? '';
        normalized['usageCount'] =
            normalized['usageCount'] ?? normalized['usage_count'] ?? 0;
        break;
      case 'consultants':
        normalized['user'] = normalized['user'] ?? normalized['user_id'] ?? '';
        normalized['alternativePhone'] =
            normalized['alternativePhone'] ??
            normalized['alternative_phone'] ??
            '';
        normalized['licenseNumber'] =
            normalized['licenseNumber'] ?? normalized['license_number'] ?? '';
        normalized['yearsOfExperience'] =
            normalized['yearsOfExperience'] ??
            normalized['years_of_experience'] ??
            0;
        normalized['postalCode'] =
            normalized['postalCode'] ?? normalized['postal_code'] ?? '';
        normalized['preferredLanguage'] =
            normalized['preferredLanguage'] ??
            normalized['preferred_language'] ??
            '';
        normalized['consultationTypes'] =
            normalized['consultationTypes'] ??
            normalized['consultation_types'] ??
            <dynamic>[];
        normalized['isVerified'] =
            normalized['isVerified'] ?? normalized['is_verified'] ?? false;
        normalized['totalConsultations'] =
            normalized['totalConsultations'] ??
            normalized['total_consultations'] ??
            0;
        normalized['availability'] =
            normalized['availability'] ??
            normalized['availability_json'] ??
            <String, dynamic>{};
        _setRelatedUserExpand(normalized, fieldName: 'user', prefix: 'user');
        break;
      case 'health_facilities':
        normalized['facility_level_name'] =
            normalized['facility_level_name'] ?? '';
        normalized['authority_name'] = normalized['authority_name'] ?? '';
        normalized['ownership_type_name'] =
            normalized['ownership_type_name'] ?? '';
        normalized['district_name'] = normalized['district_name'] ?? '';
        normalized['county_name'] = normalized['county_name'] ?? '';
        normalized['subcounty_name'] = normalized['subcounty_name'] ?? '';
        normalized['parish_name'] = normalized['parish_name'] ?? '';
        normalized['region_name'] = normalized['region_name'] ?? '';
        break;
      case 'medical_guidelines':
        normalized['index_item_title'] = normalized['index_item_title'] ?? '';
        normalized['categories'] = _extractNames(normalized['categories_json']);
        normalized['tags'] = _extractNames(normalized['tags_json']);
        break;
      case 'abbreviations':
        normalized['category'] =
            normalized['category'] ??
            _extractFirstName(normalized['category_json']);
        normalized['tags'] =
            normalized['tags'] ?? _extractNames(normalized['tags_json']);
        break;
      case 'languages':
        normalized['translations'] =
            normalized['translations'] ??
            normalized['translations_json'] ??
            <String, dynamic>{};
        normalized['enabled_for_users'] =
            normalized['enabled_for_users'] ?? true;
        break;
      case 'ministry_directory':
        normalized['alternativePhone'] =
            normalized['alternativePhone'] ??
            normalized['alternative_phone'] ??
            '';
        normalized['district_name'] = normalized['district_name'] ?? '';
        normalized['region_name'] = normalized['region_name'] ?? '';
        break;
      case 'conversations':
        normalized['participant1'] =
            normalized['participant1'] ??
            normalized['participant1_user_id'] ??
            '';
        normalized['participant2'] =
            normalized['participant2'] ??
            normalized['participant2_user_id'] ??
            '';
        normalized['last_message_id'] = normalized['last_message_id'] ?? '';
        normalized['last_message'] = normalized['last_message'] ?? '';
        normalized['last_activity'] =
            normalized['last_activity'] ??
            normalized['updated_at'] ??
            normalized['updated'] ??
            '';
        _setRelatedUserExpand(
          normalized,
          fieldName: 'participant1',
          prefix: 'participant1',
        );
        _setRelatedUserExpand(
          normalized,
          fieldName: 'participant2',
          prefix: 'participant2',
        );
        _setSelfRelationExpand(
          normalized,
          fieldName: 'last_message',
          collectionName: 'messages',
          idKey: 'last_message_id',
          displayKey: 'last_message',
        );
        break;
      case 'messages':
        normalized['conversation'] =
            normalized['conversation'] ?? normalized['conversation_id'] ?? '';
        normalized['sender'] =
            normalized['sender'] ?? normalized['sender_user_id'] ?? '';
        normalized['reply_to'] =
            normalized['reply_to'] ?? normalized['reply_to_id'] ?? '';
        normalized['attachments'] =
            normalized['attachments'] ??
            normalized['attachments_json'] ??
            <dynamic>[];
        normalized['read_by'] =
            normalized['read_by'] ??
            normalized['read_by_json'] ??
            <String, dynamic>{};
        normalized['reactions'] =
            normalized['reactions'] ??
            normalized['reactions_json'] ??
            <String, dynamic>{};
        _setRelatedUserExpand(
          normalized,
          fieldName: 'sender',
          prefix: 'sender',
        );
        _setSelfRelationExpand(
          normalized,
          fieldName: 'reply_to',
          collectionName: 'messages',
          idKey: 'reply_to_id',
          displayKey: 'reply_to',
        );
        break;
      case 'support_ticket_replies':
        _setRelatedUserExpand(normalized, fieldName: 'user_id', prefix: 'user');
        break;
      case 'reading_progress':
        normalized['guideline_id'] =
            normalized['guideline_id'] ??
            normalized['guideline_document_id'] ??
            '';
        normalized['total_sections'] = normalized['total_sections'] ?? 0;
        normalized['is_completed'] =
            normalized['is_completed'] ??
            ((normalized['progress_percentage'] as num?)?.toDouble() ?? 0) >=
                0.95;
        break;
      case 'guideline_usage_logs':
        normalized['guideline_id'] =
            normalized['guideline_id'] ??
            normalized['guideline_document_id'] ??
            '';
        break;
    }

    return normalized;
  }

  String _extractFileValue(dynamic value) {
    if (value == null) return '';
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return '';
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final decoded = jsonDecode(trimmed);
          return _extractFileValue(decoded);
        } catch (_) {
          return trimmed;
        }
      }
      return trimmed;
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      for (final key in ['url', 'file_url', 'path', 'filename', 'name']) {
        final found = map[key];
        if (found != null && found.toString().isNotEmpty) {
          return found.toString();
        }
      }
    }
    return '';
  }

  List<String> _extractNames(dynamic value) {
    if (value is List) {
      return value
          .map((entry) {
            if (entry is Map) {
              final map = Map<String, dynamic>.from(entry);
              return map['name']?.toString() ??
                  map['title']?.toString() ??
                  entry.toString();
            }
            return entry.toString();
          })
          .where((entry) => entry.isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  String _extractFirstName(dynamic value) {
    final values = _extractNames(value);
    return values.isEmpty ? '' : values.first;
  }

  void _rename(Map<String, dynamic> map, String from, String to) {
    if (!map.containsKey(from) || map.containsKey(to)) return;
    map[to] = map.remove(from);
  }

  Map<String, dynamic> _ensureExpandMap(Map<String, dynamic> normalized) {
    final existing = normalized['expand'];
    if (existing is Map<String, dynamic>) {
      return existing;
    }
    if (existing is Map) {
      final map = Map<String, dynamic>.from(existing);
      normalized['expand'] = map;
      return map;
    }
    final map = <String, dynamic>{};
    normalized['expand'] = map;
    return map;
  }

  void _setRelatedUserExpand(
    Map<String, dynamic> normalized, {
    required String fieldName,
    required String prefix,
  }) {
    final id =
        normalized['${prefix}_expand_id']?.toString() ??
        normalized['${fieldName}_expand_id']?.toString() ??
        '';
    if (id.isEmpty) return;
    final expand = _ensureExpandMap(normalized);
    expand[fieldName] = {
      'id': id,
      'collectionName': User.collection,
      'collectionId': User.collection,
      'created': '',
      'updated': '',
      'name': normalized['${prefix}_expand_name']?.toString() ?? '',
      'email': normalized['${prefix}_expand_email']?.toString() ?? '',
      'avatar': normalized['${prefix}_expand_avatar']?.toString() ?? '',
      'verified': normalized['${prefix}_expand_verified'] == true,
      'emailVisibility': normalized['${prefix}_expand_verified'] == true,
    };
  }

  void _setSelfRelationExpand(
    Map<String, dynamic> normalized, {
    required String fieldName,
    required String collectionName,
    required String idKey,
    required String displayKey,
  }) {
    final id =
        normalized[idKey]?.toString() ??
        normalized[fieldName]?.toString() ??
        '';
    if (id.isEmpty) return;
    final expand = _ensureExpandMap(normalized);
    expand[fieldName] = {
      'id': id,
      'collectionName': collectionName,
      'collectionId': collectionName,
      'created': '',
      'updated': '',
      'content': normalized[displayKey]?.toString() ?? '',
    };
  }

  List<Map<String, dynamic>> _applyFilter(
    List<Map<String, dynamic>> items,
    String? filter,
  ) {
    final expression = filter?.trim() ?? '';
    if (expression.isEmpty) return items;
    return items
        .where((item) => _evaluateExpression(item, expression))
        .toList();
  }

  List<Map<String, dynamic>> _applySort(
    List<Map<String, dynamic>> items,
    String? sort,
  ) {
    final instructions = (sort ?? '')
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (instructions.isEmpty) return items;

    final sorted = List<Map<String, dynamic>>.from(items);
    sorted.sort((left, right) {
      for (final instruction in instructions) {
        final descending = instruction.startsWith('-');
        final field = descending ? instruction.substring(1) : instruction;
        final comparison = _compareValues(left[field], right[field]);
        if (comparison != 0) {
          return descending ? -comparison : comparison;
        }
      }
      return 0;
    });
    return sorted;
  }

  int _compareValues(dynamic left, dynamic right) {
    if (left == null && right == null) return 0;
    if (left == null) return -1;
    if (right == null) return 1;
    final leftNum = num.tryParse(left.toString());
    final rightNum = num.tryParse(right.toString());
    if (leftNum != null && rightNum != null) {
      return leftNum.compareTo(rightNum);
    }
    return left.toString().compareTo(right.toString());
  }

  bool _evaluateExpression(Map<String, dynamic> item, String expression) {
    final orParts = _splitExpression(expression, '||');
    for (final orPart in orParts) {
      final andParts = _splitExpression(orPart, '&&');
      var allMatch = true;
      for (final andPart in andParts) {
        if (!_evaluateAtomic(item, _trimParens(andPart.trim()))) {
          allMatch = false;
          break;
        }
      }
      if (allMatch) return true;
    }
    return false;
  }

  List<String> _splitExpression(String expression, String operator) {
    final parts = <String>[];
    var depth = 0;
    var inQuotes = false;
    var start = 0;
    for (var i = 0; i < expression.length; i++) {
      final char = expression[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (!inQuotes) {
        if (char == '(') depth++;
        if (char == ')') depth--;
        if (depth == 0 && expression.startsWith(operator, i)) {
          parts.add(expression.substring(start, i));
          start = i + operator.length;
          i += operator.length - 1;
        }
      }
    }
    parts.add(expression.substring(start));
    return parts;
  }

  String _trimParens(String value) {
    var trimmed = value.trim();
    while (trimmed.startsWith('(') && trimmed.endsWith(')')) {
      trimmed = trimmed.substring(1, trimmed.length - 1).trim();
    }
    return trimmed;
  }

  bool _evaluateAtomic(Map<String, dynamic> item, String expression) {
    final match = RegExp(
      r'^([a-zA-Z0-9_]+)\s*(=|!=|>=|<=|>|<|~)\s*(.+)$',
    ).firstMatch(expression);
    if (match == null) return true;

    final field = match.group(1)!;
    final operator = match.group(2)!;
    final rawValue = match.group(3)!.trim();
    final expected = _parseLiteral(rawValue);
    final actual = item[field];

    switch (operator) {
      case '=':
        return _asComparable(actual) == _asComparable(expected);
      case '!=':
        return _asComparable(actual) != _asComparable(expected);
      case '>':
        return (_asNum(actual) ?? double.negativeInfinity) >
            (_asNum(expected) ?? double.infinity);
      case '<':
        return (_asNum(actual) ?? double.infinity) <
            (_asNum(expected) ?? double.negativeInfinity);
      case '>=':
        return (_asNum(actual) ?? double.negativeInfinity) >=
            (_asNum(expected) ?? double.infinity);
      case '<=':
        return (_asNum(actual) ?? double.infinity) <=
            (_asNum(expected) ?? double.negativeInfinity);
      case '~':
        if (actual is List) {
          return actual
              .map((entry) => entry.toString().toLowerCase())
              .contains(expected.toString().toLowerCase());
        }
        return actual?.toString().toLowerCase().contains(
              expected.toString().toLowerCase(),
            ) ??
            false;
      default:
        return true;
    }
  }

  dynamic _parseLiteral(String rawValue) {
    final value = _trimParens(rawValue).trim();
    if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
      return value.substring(1, value.length - 1);
    }
    if (value == 'true') return true;
    if (value == 'false') return false;
    return num.tryParse(value) ?? value;
  }

  dynamic _asComparable(dynamic value) {
    if (value is bool || value is num) return value;
    return value?.toString();
  }

  num? _asNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  }
}
