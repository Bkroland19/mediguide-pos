import 'package:flutter/foundation.dart';

const String _configuredApiBaseUrl = String.fromEnvironment(
  'MEDIGUIDE_API_BASE_URL',
  defaultValue: '',
);
final String mediguideApiBaseUrl = normalizeApiBaseUrlForPlatform(
  _configuredApiBaseUrl.isNotEmpty
      ? _configuredApiBaseUrl
      : _defaultLocalApiBaseUrl(),
  defaultTargetPlatform,
);

String normalizeApiBaseUrlForPlatform(String value, TargetPlatform platform) {
  final trimmed = value.trim().replaceFirst(RegExp(r'/$'), '');
  if (platform != TargetPlatform.android) return trimmed;

  final uri = Uri.tryParse(trimmed);
  if (uri == null || (uri.host != 'localhost' && uri.host != '127.0.0.1')) {
    return trimmed;
  }

  return uri.replace(host: '10.0.2.2').toString();
}

String _defaultLocalApiBaseUrl() {
  if (kIsWeb) {
    return 'http://127.0.0.1:8080';
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'http://10.0.2.2:8080',
    _ => 'http://127.0.0.1:8080',
  };
}

// Pagination constants
const int pageSize = 10;

class SharedPreferencesKeys {
  const SharedPreferencesKeys._();

  static const String notFirstTime = 'not_first_time';
  static const String isLoggedIn = 'is_logged_in';
  static const String userToken = 'user_token';
  static const String userId = 'user_id';
  static const String currentUser = 'current_user';
  static const String biometricEnabled = 'biometric_enabled';
  static const String themeMode = 'theme_mode';
  static const String language = 'language';
}

// Theme mode constants
class ThemeModes {
  const ThemeModes._();

  static const String light = 'light';
  static const String dark = 'dark';
  static const String system = 'system';
}
