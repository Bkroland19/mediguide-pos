// ignore_for_file: unused_field

import 'package:pocketbase/pocketbase.dart';
import 'base_model.dart';

/// Ownership type model based on PocketBase ownership_types collection
class OwnershipType extends BaseModel {
  OwnershipType(super.data);

  /// PocketBase collection name
  static const String collection = 'ownership_types';

  // Self-registration for dynamic model creation
  static final _registered = (() {
    BaseModel.registerModel(collection, (data) => OwnershipType(data));
    return true;
  })();

  /// Create OwnershipType from PocketBase record
  static OwnershipType fromRecord(RecordModel record) =>
      OwnershipType(record.data);

  /// Create JSON for new ownership type record (excludes system fields)
  static Map<String, dynamic> forCreate({
    required String name,
    String? description,
    String? code,
  }) {
    return {'name': name, 'description': ?description, 'code': ?code};
  }

  // Direct properties - late final for performance
  late final String name = get<String>("name", "");
  late final String description = get<String>("description", "");
  late final String code = get<String>("code", "");
}
