import 'package:pocketbase/pocketbase.dart';
import 'base_model.dart';

/// Guideline tag model based on PocketBase guideline_tags collection
class GuidelineTag extends BaseModel {
  GuidelineTag(super.data);
  
  /// PocketBase collection name
  static const String collection = 'guideline_tags';
  
  // Self-registration for dynamic model creation
  static final _registered = (() {
    BaseModel.registerModel(collection, (data) => GuidelineTag(data));
    return true;
  })();
  
  /// Create GuidelineTag from PocketBase record
  static GuidelineTag fromRecord(RecordModel record) => GuidelineTag(record.data);
  
  /// Create JSON for new guideline tag record (excludes system fields)
  static Map<String, dynamic> forCreate({
    required String name,
    String? description,
  }) {
    return {
      'name': name,
      if (description != null) 'description': description,
    };
  }
  
  // Direct properties - late final for performance
  late final String name = get<String>("name", "");
  late final String description = get<String>("description", "");
  
  /// Get display name
  String get displayName => name;
  
  /// Check if tag has description
  bool get hasDescription => description.isNotEmpty;
}