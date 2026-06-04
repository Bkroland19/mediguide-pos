import 'package:pocketbase/pocketbase.dart';
import 'base_model.dart';

/// Parish model based on PocketBase parishes collection
class Parish extends BaseModel {
  Parish(super.data);
  
  /// PocketBase collection name
  static const String collection = 'parishes';
  
  // Self-registration for dynamic model creation
  static final _registered = (() {
    BaseModel.registerModel(collection, (data) => Parish(data));
    return true;
  })();
  
  /// Create Parish from PocketBase record
  static Parish fromRecord(RecordModel record) => Parish(record.data);
  
  /// Create JSON for new parish record (excludes system fields)
  static Map<String, dynamic> forCreate({
    required String name,
    String? nhpiCode,
    String? hsdtCode,
    String? subcountyId,
    String? districtId,
  }) {
    return {
      'name': name,
      if (nhpiCode != null) 'nhpi_code': nhpiCode,
      if (hsdtCode != null) 'hsdt_code': hsdtCode,
      if (subcountyId != null) 'subcounty': subcountyId,
      if (districtId != null) 'district': districtId,
    };
  }
  
  // Direct properties - late final for performance
  late final String name = get<String>("name", "");
  late final String nhpiCode = get<String>("nhpi_code", "");
  late final String hsdtCode = get<String>("hsdt_code", "");
}