import 'backend_record.dart';
import 'base_model.dart';
import 'region.dart';
import 'district.dart';
import 'county.dart';
import 'subcounty.dart';
import 'parish.dart';
import 'health_sub_region.dart';
import 'health_sub_district.dart';
import 'facility_level.dart';
import 'ownership_type.dart';
import 'authority.dart';

/// Health facility model based on backend health_facilities collection
class HealthFacility extends BaseModel {
  HealthFacility(super.data) {
    _register();
  }

  /// backend collection name
  static const String collection = 'health_facilities';
  // Self-registration for dynamic model creation
  static bool _didRegister = false;

  static void _register() {
    if (_didRegister) return;
    BaseModel.registerModel(collection, (data) => HealthFacility(data));
    _didRegister = true;
  }

  /// Create HealthFacility from backend record
  static HealthFacility fromRecord(RecordModel record) =>
      HealthFacility(record.data);

  /// Create JSON for new health facility record (excludes system fields)
  static Map<String, dynamic> forCreate({
    required String name,
    required String nhpiCode,
    required String hsdtCode,
    required String facilityLevelId,
    required String authorityId,
    required String ownershipTypeId,
    required String healthSubDistrictId,
    required String parishId,
    required String subcountyId,
    required String countyId,
    required String districtId,
    required String healthSubRegionId,
    required String regionId,
  }) {
    return {
      'name': name,
      'nhpi_code': nhpiCode,
      'hsdt_code': hsdtCode,
      'facility_level': facilityLevelId,
      'authority': authorityId,
      'ownership_type': ownershipTypeId,
      'health_sub_district': healthSubDistrictId,
      'parish': parishId,
      'subcounty': subcountyId,
      'county': countyId,
      'district': districtId,
      'health_sub_region': healthSubRegionId,
      'region': regionId,
    };
  }

  // Direct properties - late final for performance
  late final String name = get<String>("name", "");
  late final String nhpiCode = get<String>("nhpi_code", "");
  late final String hsdtCode = get<String>("hsdt_code", "");

  // Geographic and administrative relationships - properly typed
  late final FacilityLevel? facilityLevel = getRelation<FacilityLevel>(
    "facility_level",
  );
  late final Authority? authority = getRelation<Authority>("authority");
  late final OwnershipType? ownershipType = getRelation<OwnershipType>(
    "ownership_type",
  );
  late final HealthSubDistrict? healthSubDistrict =
      getRelation<HealthSubDistrict>("health_sub_district");
  late final Parish? parish = getRelation<Parish>("parish");
  late final Subcounty? subcounty = getRelation<Subcounty>("subcounty");
  late final County? county = getRelation<County>("county");
  late final District? district = getRelation<District>("district");
  late final HealthSubRegion? healthSubRegion = getRelation<HealthSubRegion>(
    "health_sub_region",
  );
  late final Region? region = getRelation<Region>("region");

  // Convenience methods
  String get facilityLevelName =>
      facilityLevel?.name ?? get<String>("facility_level_name", "");
  String get authorityName =>
      authority?.name ?? get<String>("authority_name", "");
  String get ownershipTypeName =>
      ownershipType?.name ?? get<String>("ownership_type_name", "");
  String get districtName => district?.name ?? get<String>("district_name", "");
  String get countyName => county?.name ?? get<String>("county_name", "");
  String get subcountyName =>
      subcounty?.name ?? get<String>("subcounty_name", "");
  String get parishName => parish?.name ?? get<String>("parish_name", "");
  String get regionName => region?.name ?? get<String>("region_name", "");

  /// Get ownership display with fallback to code
  String get ownershipDisplay {
    final ownershipName = ownershipTypeName;
    final ownershipCode = ownershipType?.code ?? '';

    if (ownershipName.isNotEmpty) {
      return ownershipName;
    } else if (ownershipCode.isNotEmpty) {
      return 'Type: $ownershipCode';
    }
    return 'Unknown Ownership';
  }

  /// Get the full address hierarchy as a string
  String get fullAddress {
    final parts = <String>[];
    if (parishName.isNotEmpty) parts.add(parishName);
    if (subcountyName.isNotEmpty) parts.add(subcountyName);
    if (countyName.isNotEmpty) parts.add(countyName);
    if (districtName.isNotEmpty) parts.add(districtName);
    if (regionName.isNotEmpty) parts.add(regionName);
    return parts.join(', ');
  }

  /// Get a shorter address format
  String get shortAddress {
    final parts = <String>[];
    if (subcountyName.isNotEmpty) parts.add(subcountyName);
    if (districtName.isNotEmpty) parts.add(districtName);
    return parts.join(', ');
  }
}
