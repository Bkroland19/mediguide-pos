import 'backend_record.dart';
import 'base_model.dart';

/// Region model based on backend regions collection
class Region extends BaseModel {
  Region(super.data) {
    _register();
  }

  /// backend collection name
  static const String collection = 'regions';
  // Self-registration for dynamic model creation
  static bool _didRegister = false;

  static void _register() {
    if (_didRegister) return;
    BaseModel.registerModel(collection, (data) => Region(data));
    _didRegister = true;
  }

  /// Create Region from backend record
  static Region fromRecord(RecordModel record) => Region(record.data);

  /// Create JSON for new region record (excludes system fields)
  static Map<String, dynamic> forCreate({
    required String name,
    String? description,
  }) {
    return {'name': name, 'description': ?description};
  }

  // Direct properties - late final for performance
  late final String name = get<String>("name", "");
  late final String description = get<String>("description", "");
}
