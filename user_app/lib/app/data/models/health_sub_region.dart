import 'backend_record.dart';
import 'base_model.dart';
import 'region.dart';

/// Health sub-region model based on backend health_sub_regions collection
class HealthSubRegion extends BaseModel {
  HealthSubRegion(super.data) {
    _register();
  }

  /// backend collection name
  static const String collection = 'health_sub_regions';
  // Self-registration for dynamic model creation
  static bool _didRegister = false;

  static void _register() {
    if (_didRegister) return;
    BaseModel.registerModel(collection, (data) => HealthSubRegion(data));
    _didRegister = true;
  }

  /// Create HealthSubRegion from backend record
  static HealthSubRegion fromRecord(RecordModel record) =>
      HealthSubRegion(record.data);

  /// Create JSON for new health sub-region record (excludes system fields)
  static Map<String, dynamic> forCreate({
    required String name,
    required String nhpiCode,
    required String hsdtCode,
    required String regionId,
  }) {
    return {
      'name': name,
      'nhpi_code': nhpiCode,
      'hsdt_code': hsdtCode,
      'region': regionId,
    };
  }

  // Direct properties - late final for performance
  late final String name = get<String>("name", "");
  late final String nhpiCode = get<String>("nhpi_code", "");
  late final String hsdtCode = get<String>("hsdt_code", "");

  // Relationship properties
  late final Region? region = getRelation<Region>("region");
}
