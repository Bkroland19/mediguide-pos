import 'package:pocketbase/pocketbase.dart';
import '../enums/common_enums.dart';
import 'base_model.dart';

/// Drug tag model based on PocketBase drug_tags collection
class DrugTag extends BaseModel {
  DrugTag(super.data);
  
  /// PocketBase collection name
  static const String collection = 'drug_tags';
  
  // Self-registration for dynamic model creation
  static final _registered = (() {
    BaseModel.registerModel(collection, (data) => DrugTag(data));
    return true;
  })();
  
  /// Create DrugTag from PocketBase record
  static DrugTag fromRecord(RecordModel record) => DrugTag(record.data);
  
  /// Create JSON for new drug tag record (excludes system fields)
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
      if (description != null) 'description': description,
      if (color != null) 'color': color,
      if (icon != null) 'icon': icon,
      if (sortOrder != null) 'sort_order': sortOrder,
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
  late final Status status = getEnum<Status>("status", Status.values) ?? Status.active;
}