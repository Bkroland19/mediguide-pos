import 'package:pocketbase/pocketbase.dart';
import 'base_model.dart';

/// Role model based on PocketBase roles collection
class Role extends BaseModel {
  Role(super.data);
  
  /// PocketBase collection name
  static const String collection = 'roles';
  
  // Self-registration for dynamic model creation
  static final _registered = (() {
    BaseModel.registerModel(collection, (data) => Role(data));
    return true;
  })();
  
  /// Create Role from PocketBase record
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
      if (description != null) 'description': description,
      if (permissions != null) 'permissions': permissions,
      if (isActive != null) 'isActive': isActive,
    };
  }
  
  // Direct properties - late final for performance
  late final String name = get<String>("name", "");
  late final String key = get<String>("key", "");
  late final String description = get<String>("description", "");
  late final Map<String, dynamic> permissions = get<Map<String, dynamic>>("permissions", {});
  late final bool isActive = get<bool>("isActive", true);
}