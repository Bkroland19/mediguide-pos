import 'backend_record.dart';
import 'base_model.dart';

/// Role model based on backend roles collection
class Role extends BaseModel {
  Role(super.data) {
    _register();
  }

  /// backend collection name
  static const String collection = 'roles';
  // Self-registration for dynamic model creation
  static bool _didRegister = false;

  static void _register() {
    if (_didRegister) return;
    BaseModel.registerModel(collection, (data) => Role(data));
    _didRegister = true;
  }

  /// Create Role from backend record
  static Role fromRecord(RecordModel record) => Role(record.data);

  /// Create JSON for new role record (excludes system fields)
  static Map<String, dynamic> forCreate({
    required String name,
    required String key,
    String? description,
    Map<String, dynamic>? permissions,
    bool? isActive,
  }) {
    return {
      'name': name,
      'key': key,
      'description': ?description,
      'permissions': ?permissions,
      'isActive': ?isActive,
    };
  }

  // Direct properties - late final for performance
  late final String name = get<String>("name", "");
  late final String key = get<String>("key", "");
  late final String description = get<String>("description", "");
  late final Map<String, dynamic> permissions = get<Map<String, dynamic>>(
    "permissions",
    {},
  );
  late final bool isActive = get<bool>("isActive", true);
}
