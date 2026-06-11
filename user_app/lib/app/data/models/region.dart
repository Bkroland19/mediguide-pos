// ignore_for_file: unused_field

import 'package:pocketbase/pocketbase.dart';
import 'base_model.dart';

/// Region model based on PocketBase regions collection
class Region extends BaseModel {
  Region(super.data);

  /// PocketBase collection name
  static const String collection = 'regions';

  // Self-registration for dynamic model creation
  static final _registered = (() {
    BaseModel.registerModel(collection, (data) => Region(data));
    return true;
  })();

  /// Create Region from PocketBase record
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
