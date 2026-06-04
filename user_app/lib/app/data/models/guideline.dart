import 'package:pocketbase/pocketbase.dart';
import 'base_model.dart';
import 'guideline_category.dart';
import 'guideline_tag.dart';
import 'guideline_index.dart';

/// Medical guideline model based on PocketBase medical_guidelines collection
class Guideline extends BaseModel {
  Guideline(super.data);
  
  /// PocketBase collection name
  static const String collection = 'medical_guidelines';
  
  // Self-registration for dynamic model creation
  static final _registered = (() {
    BaseModel.registerModel(collection, (data) => Guideline(data));
    return true;
  })();
  
  /// Create Guideline from PocketBase record
  static Guideline fromRecord(RecordModel record) => Guideline(record.data);
  
  /// Create JSON for new guideline record (excludes system fields)
  static Map<String, dynamic> forCreate({
    required String conditionName,
    String? icd10Code,
    String? targetPopulation,
    String? definition,
    String? causes,
    String? clinicalFeatures,
    String? differentialDiagnosis,
    String? classificationMild,
    String? classificationModerate,
    String? classificationSevere,
    String? classificationCritical,
    String? generalManagement,
    String? medicationPrimary,
    String? dosageAdult,
    String? dosagePediatric,
    String? medicationSecondary,
    String? dosageSecondaryAdult,
    String? dosageSecondaryPediatric,
    String? healthcareLevelRequired,
    String? routeAdministration,
    String? monitoringRequirements,
    String? contraindications,
    String? preventionMeasures,
    String? specialNotes,
    String? status,
    bool? isPublished,
    String? priority,
    String? version,
    List<String>? categoryIds,
    List<String>? tagIds,
    String? indexItemId,
  }) {
    return {
      'condition_name': conditionName,
      if (icd10Code != null) 'icd10_code': icd10Code,
      if (targetPopulation != null) 'target_population': targetPopulation,
      if (definition != null) 'definition': definition,
      if (causes != null) 'causes': causes,
      if (clinicalFeatures != null) 'clinical_features': clinicalFeatures,
      if (differentialDiagnosis != null) 'differential_diagnosis': differentialDiagnosis,
      if (classificationMild != null) 'classification_mild': classificationMild,
      if (classificationModerate != null) 'classification_moderate': classificationModerate,
      if (classificationSevere != null) 'classification_severe': classificationSevere,
      if (classificationCritical != null) 'classification_critical': classificationCritical,
      if (generalManagement != null) 'general_management': generalManagement,
      if (medicationPrimary != null) 'medication_primary': medicationPrimary,
      if (dosageAdult != null) 'dosage_adult': dosageAdult,
      if (dosagePediatric != null) 'dosage_pediatric': dosagePediatric,
      if (medicationSecondary != null) 'medication_secondary': medicationSecondary,
      if (dosageSecondaryAdult != null) 'dosage_secondary_adult': dosageSecondaryAdult,
      if (dosageSecondaryPediatric != null) 'dosage_secondary_pediatric': dosageSecondaryPediatric,
      if (healthcareLevelRequired != null) 'healthcare_level_required': healthcareLevelRequired,
      if (routeAdministration != null) 'route_administration': routeAdministration,
      if (monitoringRequirements != null) 'monitoring_requirements': monitoringRequirements,
      if (contraindications != null) 'contraindications': contraindications,
      if (preventionMeasures != null) 'prevention_measures': preventionMeasures,
      if (specialNotes != null) 'special_notes': specialNotes,
      'status': status ?? 'published',
      'is_published': isPublished ?? true,
      if (priority != null) 'priority': priority,
      if (version != null) 'version': version,
      if (categoryIds != null) 'categories': categoryIds,
      if (tagIds != null) 'tags': tagIds,
      if (indexItemId != null) 'index_item': indexItemId,
    };
  }
  
  // Core identification fields
  late final String conditionName = get<String>("condition_name", "");
  late final String icd10Code = get<String>("icd10_code", "");
  late final String targetPopulation = get<String>("target_population", "");
  late final String version = get<String>("version", "");
  
  // Clinical description fields
  late final String definition = get<String>("definition", "");
  late final String causes = get<String>("causes", "");
  late final String clinicalFeatures = get<String>("clinical_features", "");
  late final String differentialDiagnosis = get<String>("differential_diagnosis", "");
  
  // Classification fields
  late final String classificationMild = get<String>("classification_mild", "");
  late final String classificationModerate = get<String>("classification_moderate", "");
  late final String classificationSevere = get<String>("classification_severe", "");
  late final String classificationCritical = get<String>("classification_critical", "");
  
  // Management fields
  late final String generalManagement = get<String>("general_management", "");
  late final String medicationPrimary = get<String>("medication_primary", "");
  late final String dosageAdult = get<String>("dosage_adult", "");
  late final String dosagePediatric = get<String>("dosage_pediatric", "");
  late final String medicationSecondary = get<String>("medication_secondary", "");
  late final String dosageSecondaryAdult = get<String>("dosage_secondary_adult", "");
  late final String dosageSecondaryPediatric = get<String>("dosage_secondary_pediatric", "");
  
  // Healthcare system fields
  late final String healthcareLevelRequired = get<String>("healthcare_level_required", "");
  late final String routeAdministration = get<String>("route_administration", "");
  late final String monitoringRequirements = get<String>("monitoring_requirements", "");
  late final String contraindications = get<String>("contraindications", "");
  late final String preventionMeasures = get<String>("prevention_measures", "");
  late final String specialNotes = get<String>("special_notes", "");
  
  // Status and metadata fields
  late final String status = get<String>("status", "");
  late final bool isPublished = get<bool>("is_published", false);
  late final String priority = get<String>("priority", "");
  
  // Relationship properties
  late final List<GuidelineCategory> categories = _getCategories();
  late final List<GuidelineTag> tags = _getTags();
  late final GuidelineIndex? indexItem = _getIndexItem();
  
  /// Get categories from expanded data
  List<GuidelineCategory> _getCategories() {
    final categoryList = get<List>("expand.categories", []);
    return categoryList
        .map((data) => GuidelineCategory.fromRecord(RecordModel(data)))
        .toList();
  }
  
  /// Get tags from expanded data
  List<GuidelineTag> _getTags() {
    final tagList = get<List>("expand.tags", []);
    return tagList
        .map((data) => GuidelineTag.fromRecord(RecordModel(data)))
        .toList();
  }
  
  /// Get index item from expanded data
  GuidelineIndex? _getIndexItem() {
    final indexData = get<Map<String, dynamic>?>("expand.index_item", null);
    if (indexData != null) {
      return GuidelineIndex.fromRecord(RecordModel(indexData));
    }
    return null;
  }
  
  // Computed properties
  
  /// Get display name for the guideline
  String get displayName => conditionName;
  
  /// Check if this guideline is published
  bool get isActive => isPublished && status == 'published';
  
  /// Check if this guideline has categories
  bool get hasCategories => categories.isNotEmpty;
  
  /// Check if this guideline has tags
  bool get hasTags => tags.isNotEmpty;
  
  /// Check if this guideline has an associated index item
  bool get hasIndexItem => indexItem != null;
  
  /// Get the title of the associated index item
  String get indexItemTitle => indexItem?.title ?? '';
  
  /// Check if this guideline has a definition
  bool get hasDefinition => definition.isNotEmpty;
  
  /// Check if this guideline has causes information
  bool get hasCauses => causes.isNotEmpty;
  
  /// Check if this guideline has clinical features
  bool get hasClinicalFeatures => clinicalFeatures.isNotEmpty;
  
  /// Check if this guideline has primary medication
  bool get hasPrimaryMedication => medicationPrimary.isNotEmpty;
  
  /// Check if this guideline has secondary medication
  bool get hasSecondaryMedication => medicationSecondary.isNotEmpty;
  
  /// Check if this guideline has ICD-10 code
  bool get hasIcd10Code => icd10Code.isNotEmpty;
  
  /// Check if this guideline has target population specified
  bool get hasTargetPopulation => targetPopulation.isNotEmpty;
  
  /// Check if this guideline has any classification levels
  bool get hasClassifications => 
      classificationMild.isNotEmpty ||
      classificationModerate.isNotEmpty ||
      classificationSevere.isNotEmpty ||
      classificationCritical.isNotEmpty;
  
  /// Get priority level as enum
  GuidelinePriority get priorityLevel {
    switch (priority.toLowerCase()) {
      case 'critical':
        return GuidelinePriority.critical;
      case 'high':
        return GuidelinePriority.high;
      case 'medium':
        return GuidelinePriority.medium;
      case 'low':
        return GuidelinePriority.low;
      default:
        return GuidelinePriority.medium;
    }
  }
  
  /// Get short description (first 150 chars of definition)
  String get shortDescription {
    if (!hasDefinition) return '';
    
    // Strip HTML tags for clean text
    String cleanText = definition
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    if (cleanText.length <= 150) return cleanText;
    
    return '${cleanText.substring(0, 150)}...';
  }
  
  /// Get healthcare level as enum
  HealthcareLevel get healthcareLevelEnum {
    switch (healthcareLevelRequired.toUpperCase()) {
      case 'HC1':
        return HealthcareLevel.hc1;
      case 'HC2':
        return HealthcareLevel.hc2;
      case 'HC3':
        return HealthcareLevel.hc3;
      case 'HC4':
        return HealthcareLevel.hc4;
      default:
        return HealthcareLevel.hc2;
    }
  }
}

/// Priority levels for guidelines
enum GuidelinePriority {
  critical(label: 'Critical'),
  high(label: 'High'),
  medium(label: 'Medium'),
  low(label: 'Low');
  
  const GuidelinePriority({required this.label});
  
  final String label;
}

/// Healthcare levels
enum HealthcareLevel {
  hc1(label: 'HC I (Village Health Team)', shortName: 'HC I'),
  hc2(label: 'HC II (Health Center II)', shortName: 'HC II'),
  hc3(label: 'HC III (Health Center III)', shortName: 'HC III'),
  hc4(label: 'HC IV (Health Center IV)', shortName: 'HC IV');
  
  const HealthcareLevel({required this.label, required this.shortName});
  
  final String label;
  final String shortName;
}