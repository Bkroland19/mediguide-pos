import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../data/models/search_models.dart';
import '../data/models/drug.dart';
import '../data/models/guideline.dart';
import '../data/models/consultant.dart';
import '../data/models/health_facility.dart';
import '../data/models/abbreviation.dart';
import '../data/models/calculator.dart';
import '../data/models/drug_usage_log.dart';
import '../data/services/pocketbase_service.dart';
import '../data/services/auth_service.dart';
import '../modules/drug_index_module/widgets/drug_details_bottom_sheet.dart';
import '../routes/app_pages.dart';
import '../utils/common.dart';

/// Controller for managing global search state and logic
class GlobalSearchController extends GetxController {
  static GlobalSearchController get to => Get.find();

  // Search text controller
  final TextEditingController searchController = TextEditingController();

  // Observable state (simplified)
  final RxList<SearchResult> searchResults = <SearchResult>[].obs;
  final RxBool isLoading = false.obs;
  final RxString currentQuery = ''.obs;

  // Pagination
  static const int pageSize = 10;

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  /// Handle search submission (Enter key or manual trigger)
  void onSearchSubmitted() {
    final query = searchController.text.trim();
    currentQuery.value = query;

    if (query.isEmpty) {
      searchResults.clear();
      return;
    }

    if (query.length < 2) return;

    // Start search on submit/enter
    performSearch(query);
  }

  /// Perform search with the given query
  Future<void> performSearch(String query) async {
    if (query.trim().isEmpty) return;

    try {
      isLoading.value = true;
      searchResults.clear();

      final results = await _searchAllCollections(query.trim());

      searchResults.assignAll(results);
      currentQuery.value = query;
    } catch (e) {
      Common.quickToast(title: 'Search failed. Please try again.');
    } finally {
      isLoading.value = false;
    }
  }

  /// Clear search and reset state
  void clearSearch() {
    searchController.clear();
    currentQuery.value = '';
    searchResults.clear();
  }

  /// Handle search result selection using stored objects
  Future<void> selectSearchResult(SearchResult result) async {
    switch (result.category) {
      case SearchCategory.drugs:
        final drug = result.getItem<Drug>();
        if (drug != null) {
          await _showDrugDetails(drug);
        } else {
          Common.quickToast(title: 'drugNotFound'.tr);
        }
        break;

      case SearchCategory.guidelines:
        final guideline = result.getItem<Guideline>();
        if (guideline != null) {
          Get.toNamed(AppRoutes.readGuideline, arguments: guideline);
        }
        break;

      case SearchCategory.consultants:
        final consultant = result.getItem<Consultant>();
        if (consultant != null) {
          Get.toNamed(AppRoutes.consultants, arguments: consultant);
        }
        break;

      case SearchCategory.healthFacilities:
        final facility = result.getItem<HealthFacility>();
        if (facility != null) {
          Get.toNamed(AppRoutes.healthInfrastructure, arguments: facility);
        }
        break;

      case SearchCategory.abbreviations:
        final abbreviation = result.getItem<Abbreviation>();
        if (abbreviation != null) {
          Get.toNamed(AppRoutes.abbreviations, arguments: abbreviation);
        }
        break;

      case SearchCategory.tools:
        final calculator = result.getItem<Calculator>();
        if (calculator != null) {
          Get.toNamed(AppRoutes.useCalculator, arguments: calculator);
        } else {
          Get.toNamed(
            AppRoutes.useCalculator,
            arguments: {'calculatorId': result.id},
          );
        }
        break;

      case SearchCategory.faq:
        // FAQ items store raw record data
        final faqRecord = result.item;
        if (faqRecord != null) {
          Get.toNamed(AppRoutes.faq, arguments: faqRecord);
        }
        break;

      case SearchCategory.all:
        // Should not happen, but fallback to route navigation
        if (result.route != null) {
          if (result.routeArguments != null) {
            Get.toNamed(result.route!, arguments: result.routeArguments);
          } else {
            Get.toNamed(result.route!);
          }
        }
        break;
    }
  }

  /// Show drug details bottom sheet
  Future<void> _showDrugDetails(Drug drug) async {
    try {
      // Track drug usage
      await _trackDrugUsage(drug.id);

      // Get context after async operations
      final context = Get.context;
      if (context == null || !context.mounted) return;

      // Show drug details bottom sheet
      await DrugDetailsBottomSheet.show(context: context, drug: drug);
    } catch (e) {
      Common.quickToast(title: 'errorLoadingDrugDetails'.tr);
    }
  }

  /// Track drug usage
  Future<void> _trackDrugUsage(String drugId) async {
    try {
      if (AuthService.to.currentUser.value == null) return;

      // Create drug usage log
      final logData = DrugUsageLog.forCreate(
        userId: AuthService.to.currentUser.value!.id,
        drugId: drugId,
      );

      await PocketBaseService.to.createRecord(
        collectionName: DrugUsageLog.collection,
        data: logData,
      );

      // Increment drug usage count
      await PocketBaseService.to.incrementUsageCount(Drug.collection, drugId);
    } catch (e) {
      // Handle error silently to not disrupt user experience
    }
  }

  /// Get search result count text
  String get resultCountText {
    final count = searchResults.length;
    if (count == 0) return 'No results found';
    if (count == 1) return '1 result';
    return '$count results';
  }

  // Collection search configuration
  static const Map<SearchCategory, Map<String, dynamic>> _searchConfig = {
    SearchCategory.drugs: {
      'collection': 'drugs',
      'fields': ['name', 'brand_names', 'description'],
      'expand': 'categories,tags,therapeutic_category',
    },
    SearchCategory.guidelines: {
      'collection': 'medical_guidelines',
      'fields': ['condition_name', 'definition', 'causes'],
      'expand': null,
    },
    SearchCategory.consultants: {
      'collection': 'consultants',
      'fields': ['name', 'specialty', 'department'],
      'expand': null,
    },
    SearchCategory.healthFacilities: {
      'collection': 'health_facilities',
      'fields': ['name', 'parish', 'subcounty'],
      'expand': null,
    },
    SearchCategory.abbreviations: {
      'collection': 'abbreviations',
      'fields': ['abbreviation', 'meaning', 'description'],
      'expand': null,
    },
    SearchCategory.faq: {
      'collection': 'faqs',
      'fields': ['question', 'answer'],
      'expand': null,
    },
    SearchCategory.tools: {
      'collection': 'calculators',
      'fields': ['name', 'description'],
      'expand': null,
    },
  };

  /// Search all collections in parallel with error handling
  Future<List<SearchResult>> _searchAllCollections(String query) async {
    // Launch all searches in parallel with individual error handling
    final searchFutures =
        [
          SearchCategory.drugs,
          SearchCategory.guidelines,
          SearchCategory.consultants,
          SearchCategory.healthFacilities,
          SearchCategory.abbreviations,
          SearchCategory.faq,
          SearchCategory.tools,
        ].map((category) async {
          try {
            return await _searchCollection(category, query);
          } catch (e) {
            // Return empty list if individual search fails
            return <SearchResult>[];
          }
        });

    // Wait for all searches to complete (no individual failures will break this)
    final results = await Future.wait(searchFutures);

    // Combine all successful results
    final allResults = <SearchResult>[];
    for (final categoryResults in results) {
      allResults.addAll(categoryResults);
    }

    // Return top results (limited to 20)
    return allResults.take(20).toList();
  }

  /// Generic method to search a specific collection
  Future<List<SearchResult>> _searchCollection(
    SearchCategory category,
    String query,
  ) async {
    final config = _searchConfig[category];
    if (config == null) return [];

    try {
      // Build filter for search fields
      final fields = config['fields'] as List<String>;
      final filterParts = fields.map((field) => '$field ~ "$query"').toList();
      final filter = '(${filterParts.join(' || ')})';

      final response = await PocketBaseService.to.getRecordList(
        collectionName: config['collection'],
        page: 1,
        perPage: 10,
        filter: filter,
        sort: '-created',
        expand: config['expand'],
      );

      return response.items
          .map((record) => _createSearchResult(record, category, query))
          .toList();
    } catch (e) {
      // Try fallback collection name for FAQ
      if (category == SearchCategory.faq) {
        return _searchFAQFallback(query);
      }
      return [];
    }
  }

  /// Strip HTML tags from rich text fields
  String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  /// Create SearchResult from PocketBase record
  SearchResult _createSearchResult(
    dynamic record,
    SearchCategory category,
    String query,
  ) {
    switch (category) {
      case SearchCategory.drugs:
        final drug = Drug.fromRecord(record);
        final drugDesc = _stripHtml(drug.description);
        return SearchResult(
          id: drug.id,
          title: drug.name,
          subtitle: drug.brandNames.isNotEmpty
              ? _stripHtml(drug.brandNames)
              : null,
          description: drugDesc.isNotEmpty ? drugDesc : null,
          category: category,
          route: null,
          routeArguments: null,
          relevanceScore: 0.0,
          item: drug,
        );

      case SearchCategory.guidelines:
        final guideline = Guideline.fromRecord(record);
        final guidelineDesc = _stripHtml(guideline.definition);
        return SearchResult(
          id: guideline.id,
          title: guideline.conditionName,
          subtitle: guideline.icd10Code.isNotEmpty ? guideline.icd10Code : null,
          description: guidelineDesc.isNotEmpty ? guidelineDesc : null,
          category: category,
          route: AppRoutes.readGuideline,
          routeArguments: {'guidelineId': guideline.id},
          relevanceScore: 0.0,
          item: guideline,
        );

      case SearchCategory.consultants:
        final consultant = Consultant.fromRecord(record);
        return SearchResult(
          id: consultant.id,
          title: consultant.name,
          subtitle: consultant.specialty?.name,
          description: consultant.department.isNotEmpty
              ? consultant.department
              : null,
          category: category,
          route: AppRoutes.consultants,
          routeArguments: {'consultantId': consultant.id},
          relevanceScore: 0.0,
          item: consultant,
        );

      case SearchCategory.healthFacilities:
        final facility = HealthFacility.fromRecord(record);
        return SearchResult(
          id: facility.id,
          title: facility.name,
          subtitle: facility.facilityLevelName.isNotEmpty
              ? facility.facilityLevelName
              : null,
          description: facility.parishName.isNotEmpty
              ? facility.parishName
              : null,
          category: category,
          route: AppRoutes.healthInfrastructure,
          routeArguments: {'facilityId': facility.id},
          relevanceScore: 0.0,
          item: facility,
        );

      case SearchCategory.abbreviations:
        final abbreviation = Abbreviation.fromRecord(record);
        final abbrDesc = _stripHtml(abbreviation.description);
        return SearchResult(
          id: abbreviation.id,
          title: abbreviation.displayAbbreviation,
          subtitle: abbreviation.meaning,
          description: abbrDesc.isNotEmpty ? abbrDesc : null,
          category: category,
          route: AppRoutes.abbreviations,
          routeArguments: {'abbreviationId': abbreviation.id},
          relevanceScore: 0.0,
          item: abbreviation,
        );

      case SearchCategory.tools:
        final calculator = Calculator.fromRecord(record);
        final calcDesc = _stripHtml(calculator.description);
        return SearchResult(
          id: calculator.id,
          title: calculator.name,
          subtitle: calculator.type.name,
          description: calcDesc.isNotEmpty ? calcDesc : null,
          category: category,
          route: AppRoutes.useCalculator,
          routeArguments: {'calculatorId': calculator.id},
          relevanceScore: 0.0,
          item: calculator,
        );

      case SearchCategory.faq:
        final data = record.data;
        final faqAnswer = _stripHtml(data['answer'] ?? '');
        return SearchResult(
          id: record.id,
          title: _stripHtml(data['question'] ?? 'FAQ'),
          subtitle: null,
          description: faqAnswer.length > 100
              ? '${faqAnswer.substring(0, 100)}...'
              : faqAnswer,
          category: category,
          route: AppRoutes.faq,
          routeArguments: {'faqId': record.id},
          relevanceScore: 0.0,
          item: record,
        );

      default:
        throw UnsupportedError('Unsupported search category: $category');
    }
  }

  /// Fallback search for FAQ with alternative collection name
  Future<List<SearchResult>> _searchFAQFallback(String query) async {
    try {
      final filter = '(question ~ "$query" || answer ~ "$query")';
      final response = await PocketBaseService.to.getRecordList(
        collectionName: 'faq',
        page: 1,
        perPage: 10,
        filter: filter,
        sort: '-created',
      );

      return response.items
          .map(
            (record) => _createSearchResult(record, SearchCategory.faq, query),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }
}
