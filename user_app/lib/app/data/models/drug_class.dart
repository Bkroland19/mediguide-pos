// ignore_for_file: unused_field

import 'package:pocketbase/pocketbase.dart';
import '../enums/common_enums.dart';
import 'base_model.dart';

/// Drug class model based on PocketBase drug_classes collection
class DrugClass extends BaseModel {
  DrugClass(super.data);

  /// PocketBase collection name
  static const String collection = 'drug_classes';

  // Self-registration for dynamic model creation
  static final _registered = (() {
    BaseModel.registerModel(collection, (data) => DrugClass(data));
    return true;
  })();

  /// Create DrugClass from PocketBase record
  static DrugClass fromRecord(RecordModel record) => DrugClass(record.data);

  /// Create JSON for new drug class record (excludes system fields)
  static Map<String, dynamic> forCreate({
    required String name,
    String? description,
    String? color,
    String? icon,
    double? sortOrder,
    Status? status,
  }) {
    return {
      'name': name,
      'description': ?description,
      'color': ?color,
      'icon': ?icon,
      'sort_order': ?sortOrder,
      'status': (status ?? Status.active).name,
    };
  }

  // Direct properties - late final for performance
  late final String name = get<String>("name", "");
  late final String description = get<String>("description", "");
  late final String color = get<String>("color", "");
  late final String icon = get<String>("icon", "");
  late final double sortOrder = get<double>("sort_order", 0);

  // Enum properties
  late final Status status =
      getEnum<Status>("status", Status.values) ?? Status.active;
}
