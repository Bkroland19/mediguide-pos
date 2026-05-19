import 'backend_record.dart';
import 'base_model.dart';
import 'ownership_type.dart';

/// Authority model based on backend authorities collection
class Authority extends BaseModel {
  Authority(super.data) {
    _register();
  }

  /// backend collection name
  static const String collection = 'authorities';
  // Self-registration for dynamic model creation
  static bool _didRegister = false;

  static void _register() {
    if (_didRegister) return;
    BaseModel.registerModel(collection, (data) => Authority(data));
    _didRegister = true;
  }

  /// Create Authority from backend record
  static Authority fromRecord(RecordModel record) => Authority(record.data);

  /// Create JSON for new authority record (excludes system fields)
  static Map<String, dynamic> forCreate({
    required String name,
    String? code,
    required String ownershipTypeId,
  }) {
    return {
      'name': name,
      'code': ?code,
      'ownership_type': ownershipTypeId,
    };
  }

  // Direct properties - late final for performance
  late final String name = get<String>("name", "");
  late final String code = get<String>("code", "");

  // Relationship properties
  late final OwnershipType? ownershipType = getRelation<OwnershipType>(
    "ownership_type",
  );
}
