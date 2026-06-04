import 'package:pocketbase/pocketbase.dart';
import 'base_model.dart';
import 'region.dart';

/// District model based on PocketBase districts collection
class District extends BaseModel {
  District(super.data);
  
  /// PocketBase collection name
  static const String collection = 'districts';
  
  // Self-registration for dynamic model creation
  static final _registered = (() {
    BaseModel.registerModel(collection, (data) => District(data));
    return true;
  })();
  
  /// Create District from PocketBase record
  static District fromRecord(RecordModel record) => District(record.data);
  
  /// Create JSON for new district record (excludes system fields)
  static Map<String, dynamic> forCreate({
    required String name,
    String? description,
    String? regionId,
  }) {
    return {
      'name': name,
      if (description != null) 'description': description,
      if (regionId != null) 'region': regionId,
    };
  }
  
  // Direct properties - late final for performance
  late final String name = get<String>("name", "");
  late final String description = get<String>("description", "");
  
  // Relationship properties
  late final Region? region = getRelation<Region>("region");
}