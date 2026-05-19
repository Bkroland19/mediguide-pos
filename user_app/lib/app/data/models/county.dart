import 'backend_record.dart';
import 'base_model.dart';
import 'district.dart';

/// County model based on backend counties collection
class County extends BaseModel {
  County(super.data) {
    _register();
  }

  /// backend collection name
  static const String collection = 'counties';
  // Self-registration for dynamic model creation
  static bool _didRegister = false;

  static void _register() {
    if (_didRegister) return;
    BaseModel.registerModel(collection, (data) => County(data));
    _didRegister = true;
  }

  /// Create County from backend record
  static County fromRecord(RecordModel record) => County(record.data);

  /// Create JSON for new county record (excludes system fields)
  static Map<String, dynamic> forCreate({
    required String name,
    required String districtId,
    String? nhpiCode,
    String? hsdtCode,
  }) {
    return {
      'name': name,
      'district': districtId,
      'nhpi_code': ?nhpiCode,
      'hsdt_code': ?hsdtCode,
    };
  }

  // Direct properties - late final for performance
  late final String name = get<String>("name", "");
  late final String nhpiCode = get<String>("nhpi_code", "");
  late final String hsdtCode = get<String>("hsdt_code", "");

  // Relationship properties
  late final District? district = getRelation<District>("district");
}
