import 'backend_record.dart';
import 'base_model.dart';

/// Facility level model based on backend facility_levels collection
class FacilityLevel extends BaseModel {
  FacilityLevel(super.data) {
    _register();
  }

  /// backend collection name
  static const String collection = 'facility_levels';
  // Self-registration for dynamic model creation
  static bool _didRegister = false;

  static void _register() {
    if (_didRegister) return;
    BaseModel.registerModel(collection, (data) => FacilityLevel(data));
    _didRegister = true;
  }

  /// Create FacilityLevel from backend record
  static FacilityLevel fromRecord(RecordModel record) =>
      FacilityLevel(record.data);

  /// Create JSON for new facility level record (excludes system fields)
  static Map<String, dynamic> forCreate({
    required String name,
    String? description,
    int? level,
  }) {
    return {
      'name': name,
      'description': ?description,
      'level': ?level,
    };
  }

  // Direct properties - late final for performance
  late final String name = get<String>("name", "");
  late final String description = get<String>("description", "");
  late final int level = get<int>("level", 0);
}
