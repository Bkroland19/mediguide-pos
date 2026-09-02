import 'package:user_app/core/config/flavor.dart';

abstract final class Environment {
  static const productionApiBaseUrl = 'https://mediguide.health.go.ug';

  static const flavorName = String.fromEnvironment(
    'MEDIGUIDE_FLAVOR',
    defaultValue: 'development',
  );
  static const configuredApiBaseUrl = String.fromEnvironment(
    'MEDIGUIDE_API_BASE_URL',
    defaultValue: '',
  );
  static const configuredDebugToolsEnabled = bool.fromEnvironment(
    'MEDIGUIDE_DEBUG_TOOLS_ENABLED',
    defaultValue: false,
  );

  static Flavor get flavor => Flavor.fromEnvironment(flavorName);

  static String defaultApiBaseUrl([Flavor? selectedFlavor]) {
    return switch (selectedFlavor ?? flavor) {
      Flavor.development ||
      Flavor.staging ||
      Flavor.production => productionApiBaseUrl,
    };
  }
}
