import 'backend_record.dart';
import 'base_model.dart';
import 'county.dart';
import 'district.dart';

/// Subcounty model based on backend subcounties collection
class Subcounty extends BaseModel {
  Subcounty(super.data) {
    _register();
  }

  /// backend collection name
  static const String collection = 'subcounties';
  // Self-registration for dynamic model creation
  static bool _didRegister = false;

  static void _register() {
    if (_didRegister) return;
    BaseModel.registerModel(collection, (data) => Subcounty(data));
    _didRegister = true;
  }

  /// Create Subcounty from backend record
  static Subcounty fromRecord(RecordModel record) => Subcounty(record.data);

  /// Create JSON for new subcounty record (excludes system fields)
  static Map<String, dynamic> forCreate({
    required String name,
    required String nhpiCode,
    required String hsdtCode,
    required String countyId,
    required String districtId,
  }) {
    return {
      'name': name,
      'nhpi_code': nhpiCode,
      'hsdt_code': hsdtCode,
      'county': countyId,
      'district': districtId,
    };
  }

  // Direct properties - late final for performance
  late final String name = get<String>("name", "");
  late final String nhpiCode = get<String>("nhpi_code", "");
  late final String hsdtCode = get<String>("hsdt_code", "");

  // Relationship properties
  late final County? county = getRelation<County>("county");
  late final District? district = getRelation<District>("district");
}
