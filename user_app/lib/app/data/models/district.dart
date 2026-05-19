import 'backend_record.dart';
import 'base_model.dart';
import 'region.dart';

/// District model based on backend districts collection
class District extends BaseModel {
  District(super.data) {
    _register();
  }

  /// backend collection name
  static const String collection = 'districts';
  // Self-registration for dynamic model creation
  static bool _didRegister = false;

  static void _register() {
    if (_didRegister) return;
    BaseModel.registerModel(collection, (data) => District(data));
    _didRegister = true;
  }

  /// Create District from backend record
  static District fromRecord(RecordModel record) => District(record.data);

  /// Create JSON for new district record (excludes system fields)
  static Map<String, dynamic> forCreate({
    required String name,
    String? description,
    String? regionId,
  }) {
    return {
      'name': name,
      'description': ?description,
      'region': ?regionId,
    };
  }

  // Direct properties - late final for performance
  late final String name = get<String>("name", "");
  late final String description = get<String>("description", "");

  // Relationship properties
  late final Region? region = getRelation<Region>("region");
}
