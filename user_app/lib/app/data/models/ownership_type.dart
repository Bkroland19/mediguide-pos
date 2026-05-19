import 'backend_record.dart';
import 'base_model.dart';

/// Ownership type model based on backend ownership_types collection
class OwnershipType extends BaseModel {
  OwnershipType(super.data) {
    _register();
  }

  /// backend collection name
  static const String collection = 'ownership_types';
  // Self-registration for dynamic model creation
  static bool _didRegister = false;

  static void _register() {
    if (_didRegister) return;
    BaseModel.registerModel(collection, (data) => OwnershipType(data));
    _didRegister = true;
  }

  /// Create OwnershipType from backend record
  static OwnershipType fromRecord(RecordModel record) =>
      OwnershipType(record.data);

  /// Create JSON for new ownership type record (excludes system fields)
  static Map<String, dynamic> forCreate({
    required String name,
    String? description,
    String? code,
  }) {
    return {
      'name': name,
      'description': ?description,
      'code': ?code,
    };
  }

  // Direct properties - late final for performance
  late final String name = get<String>("name", "");
  late final String description = get<String>("description", "");
  late final String code = get<String>("code", "");
}
