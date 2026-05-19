import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../data/models/models.dart';
import '../../data/models/filter_models.dart';
import '../../data/services/backend_service.dart';
import '../../utils/constants.dart';
import '../../utils/common.dart';
import '../../widgets/generic_filter_bottom_sheet.dart';

class GuidelinesController extends GetxController {
  // Pagination controller
  late final PagingController<int, Guideline> pagingController;

  // Permanent filter state (GuidelineIndex)
  final Rx<GuidelineIndex?> selectedIndex = Rx<GuidelineIndex?>(null);
  final RxBool isInIndexMode = false.obs;

  // Search and filter state (temporary filters)
  final RxString searchQuery = ''.obs;
  final RxBool hasActiveFilters = false.obs;
  final RxString selectedCategoryId = ''.obs;
  final RxList<String> selectedTagIds = <String>[].obs;
  final RxString selectedPriority = ''.obs;
  final RxString selectedHealthcareLevel = ''.obs;
  final RxString selectedTargetPopulation = ''.obs;
  final RxBool showHighPriorityOnly = false.obs;

  // Data state
  final RxList<GuidelineCategory> availableCategories =
      <GuidelineCategory>[].obs;
  final RxList<GuidelineTag> availableTags = <GuidelineTag>[].obs;
  final RxBool isLoadingFilters = false.obs;

  @override
  void onInit() {
    super.onInit();
    _handleArguments(); // Handle GuidelineIndex from navigation
    pagingController = PagingController<int, Guideline>(
      getNextPageKey: (state) =>
          state.lastPageIsEmpty ? null : state.nextIntPageKey,
      fetchPage: _loadPage,
    );
    _loadFilterOptions();
  }

  /// Handle arguments from navigation (GuidelineIndex)
  void _handleArguments() {
    final args = Get.arguments;
    if (args is GuidelineIndex) {
      selectedIndex.value = args;
      isInIndexMode.value = true;
    }
  }

  @override
  void onClose() {
    pagingController.dispose();
    super.onClose();
  }

  /// Load a page of guidelines
  Future<List<Guideline>> _loadPage(int pageKey) async {
    try {
      final List<Guideline> newItems;

      if (searchQuery.value.isNotEmpty ||
          hasActiveFilters.value ||
          isInIndexMode.value) {
        // Search with filters (including permanent index filter)
        newItems = await searchGuidelines(
          query: searchQuery.value,
          page: pageKey,
          perPage: pageSize,
          categoryFilter: selectedCategoryId.value.isNotEmpty
              ? selectedCategoryId.value
              : null,
          tagFilters: selectedTagIds.isNotEmpty
              ? selectedTagIds.toList()
              : null,
          priorityFilter: selectedPriority.value.isNotEmpty
              ? selectedPriority.value
              : null,
          healthcareLevelFilter: selectedHealthcareLevel.value.isNotEmpty
              ? selectedHealthcareLevel.value
              : null,
          targetPopulationFilter: selectedTargetPopulation.value.isNotEmpty
              ? selectedTargetPopulation.value
              : null,
          indexItemFilter: selectedIndex.value?.id, // Permanent index filter
        );
      } else if (showHighPriorityOnly.value) {
        // Show only high priority guidelines
        if (pageKey == 1) {
          newItems = await getHighPriorityGuidelines();
        } else {
          newItems = [];
        }
      } else {
        // Regular pagination (may still have permanent index filter)
        newItems = await getGuidelines(
          page: pageKey,
          perPage: pageSize,
          indexItemFilter: selectedIndex
              .value
              ?.id, // Apply index filter even without other filters
        );
      }

      return newItems;
    } catch (error) {
      Common.quickToast(title: 'errorLoadingGuidelines'.tr);
      rethrow;
    }
  }

  /// Load available categories and tags for filtering
  Future<void> _loadFilterOptions() async {
    try {
      isLoadingFilters.value = true;

      final categories = await getGuidelineCategories();
      final tags = await getGuidelineTags();

      availableCategories.value = categories;
      availableTags.value = tags;
    } catch (error) {
      Common.quickToast(title: 'errorLoadingFilters'.tr);
    } finally {
      isLoadingFilters.value = false;
    }
  }

  /// Clear all temporary filters (preserves permanent index filter)
  void clearAllFilters() {
    selectedCategoryId.value = '';
    selectedTagIds.clear();
    selectedPriority.value = '';
    selectedHealthcareLevel.value = '';
    selectedTargetPopulation.value = '';
    showHighPriorityOnly.value = false;
    searchQuery.value = '';
    hasActiveFilters.value = false;
    pagingController.refresh();
  }

  /// Clear the permanent index filter (used for navigation)
  void clearIndexFilter() {
    selectedIndex.value = null;
    isInIndexMode.value = false;
    pagingController.refresh();
  }

  /// Check if there are any temporary filters active (excluding permanent index)
  bool get hasTemporaryFilters {
    return searchQuery.value.isNotEmpty ||
        selectedCategoryId.value.isNotEmpty ||
        selectedTagIds.isNotEmpty ||
        selectedPriority.value.isNotEmpty ||
        selectedHealthcareLevel.value.isNotEmpty ||
        selectedTargetPopulation.value.isNotEmpty ||
        showHighPriorityOnly.value;
  }

  /// Update hasActiveFilters state (only for temporary filters)
  void _updateHasActiveFilters() {
    hasActiveFilters.value = hasTemporaryFilters;
  }

  /// Show filter modal using generic filter bottom sheet
  Future<void> showFilterModal(BuildContext context) async {
    // Ensure filter options are loaded
    if (availableCategories.isEmpty || availableTags.isEmpty) {
      await _loadFilterOptions();
    }

    final fields = <FilterField>[
      FilterField.text('search', 'search'.tr, hint: 'searchGuidelines'.tr),
      FilterField.boolean('showHighPriorityOnly', 'showHighPriorityOnly'.tr),
    ];

    // Priority dropdown
    final priorityOptions = ['', 'critical', 'high', 'medium', 'low'];
    fields.add(
      FilterField.dropdown(
        'priority',
        'priority'.tr,
        priorityOptions
            .map((p) => p.isEmpty ? 'allPriorities'.tr : p.capitalizeFirst!)
            .toList(),
      ),
    );

    // Healthcare level dropdown
    final healthcareLevelOptions = ['', 'HC1', 'HC2', 'HC3', 'HC4'];
    fields.add(
      FilterField.dropdown(
        'healthcareLevel',
        'healthcareLevel'.tr,
        healthcareLevelOptions
            .map((l) => l.isEmpty ? 'allLevels'.tr : l)
            .toList(),
      ),
    );

    // Target population
    fields.add(
      FilterField.text(
        'targetPopulation',
        'targetPopulation'.tr,
        hint: 'filterByTargetPopulation'.tr,
      ),
    );

    // Category dropdown
    if (availableCategories.isNotEmpty) {
      final categoryOptions = availableCategories
          .map((category) => category.displayName)
          .toList();
      fields.add(
        FilterField.dropdown(
          'category',
          'category'.tr,
          ['allCategories'.tr] + categoryOptions,
        ),
      );
    }

    // Tags multi-select
    if (availableTags.isNotEmpty) {
      final tagOptions = availableTags.map((tag) => tag.displayName).toList();
      fields.add(FilterField.multiSelect('tags', 'tags'.tr, tagOptions));
    }

    // Get initial values
    final values = <String, dynamic>{};
    if (searchQuery.value.isNotEmpty) values['search'] = searchQuery.value;
    if (showHighPriorityOnly.value) values['showHighPriorityOnly'] = true;

    if (selectedPriority.value.isNotEmpty) {
      values['priority'] = selectedPriority.value.capitalizeFirst!;
    }

    if (selectedHealthcareLevel.value.isNotEmpty) {
      values['healthcareLevel'] = selectedHealthcareLevel.value;
    }

    if (selectedTargetPopulation.value.isNotEmpty) {
      values['targetPopulation'] = selectedTargetPopulation.value;
    }

    if (selectedCategoryId.value.isNotEmpty) {
      final category = availableCategories
          .where((cat) => cat.id == selectedCategoryId.value)
          .firstOrNull;
      if (category != null) values['category'] = category.displayName;
    }

    if (selectedTagIds.isNotEmpty) {
      final tagNames = availableTags
          .where((tag) => selectedTagIds.contains(tag.id))
          .map((tag) => tag.displayName)
          .toList();
      if (tagNames.isNotEmpty) values['tags'] = tagNames;
    }

    if (!context.mounted) return;

    final result = await GenericFilterBottomSheet.show(
      context: context,
      title: 'filterGuidelines'.tr,
      fields: fields,
      initialValues: values,
    );

    if (result != null && result.isNotEmpty) {
      _applyFilters(result);
    }
  }

  /// Apply filters from the generic filter result (preserves permanent index filter)
  void _applyFilters(FilterResult result) {
    // Clear existing temporary filters first (preserve index filter)
    selectedCategoryId.value = '';
    selectedTagIds.clear();
    selectedPriority.value = '';
    selectedHealthcareLevel.value = '';
    selectedTargetPopulation.value = '';
    showHighPriorityOnly.value = false;
    searchQuery.value = '';

    // Apply new filters
    final search = result.getValue<String>('search');
    if (search != null && search.isNotEmpty) {
      searchQuery.value = search;
    }

    final highPriorityOnly = result.getValue<bool>('showHighPriorityOnly');
    if (highPriorityOnly == true) {
      showHighPriorityOnly.value = true;
    }

    final priority = result.getValue<String>('priority');
    if (priority != null &&
        priority.isNotEmpty &&
        priority != 'allPriorities'.tr) {
      selectedPriority.value = priority.toLowerCase();
    }

    final healthcareLevel = result.getValue<String>('healthcareLevel');
    if (healthcareLevel != null &&
        healthcareLevel.isNotEmpty &&
        healthcareLevel != 'allLevels'.tr) {
      selectedHealthcareLevel.value = healthcareLevel;
    }

    final targetPopulation = result.getValue<String>('targetPopulation');
    if (targetPopulation != null && targetPopulation.isNotEmpty) {
      selectedTargetPopulation.value = targetPopulation;
    }

    final categoryName = result.getValue<String>('category');
    if (categoryName != null &&
        categoryName.isNotEmpty &&
        categoryName != 'allCategories'.tr) {
      final category = availableCategories
          .where((cat) => cat.displayName == categoryName)
          .firstOrNull;
      if (category != null) {
        selectedCategoryId.value = category.id;
      }
    }

    final tagNames = result.getValue<List>('tags');
    if (tagNames != null && tagNames.isNotEmpty) {
      final tagIds = <String>[];
      for (final tagName in tagNames) {
        final tag = availableTags
            .where((t) => t.displayName == tagName)
            .firstOrNull;
        if (tag != null) {
          tagIds.add(tag.id);
        }
      }
      selectedTagIds.addAll(tagIds);
    }

    _updateHasActiveFilters();
    pagingController.refresh();
  }

  // ==================== GUIDELINE METHODS ====================

  /// Get all guidelines with pagination
  Future<List<Guideline>> getGuidelines({
    int page = 1,
    int perPage = 30,
    String? filter,
    String? sort,
    String? expand,
    String? indexItemFilter,
  }) async {
    // Build filter with index item filter if provided
    final List<String> filters = [];

    // Index item filter (permanent filter when present)
    if (indexItemFilter != null && indexItemFilter.isNotEmpty) {
      filters.add('index_item = "$indexItemFilter"');
    }

    // Published filter
    filters.add('is_published = true');

    // Add any additional filter
    if (filter != null && filter.isNotEmpty) {
      filters.add(filter);
    }

    final combinedFilter = filters.isNotEmpty ? filters.join(' && ') : null;

    final result = await BackendService.to.getRecordList(
      collectionName: Guideline.collection,
      page: page,
      perPage: perPage,
      filter: combinedFilter,
      sort: sort ?? '-created',
      expand: expand ?? 'categories,tags,index_item',
    );
    return result.items.map((record) => Guideline.fromRecord(record)).toList();
  }

  /// Get guideline by ID with expanded relationships
  Future<Guideline?> getGuidelineById(String guidelineId) async {
    final record = await BackendService.to.getRecord(
      collectionName: Guideline.collection,
      recordId: guidelineId,
      expand: 'categories,tags',
    );
    return record != null ? Guideline.fromRecord(record) : null;
  }

  /// Get high priority guidelines (critical and high priority)
  Future<List<Guideline>> getHighPriorityGuidelines({
    int perPage = 50,
    String? expand,
  }) async {
    final result = await BackendService.to.getRecordList(
      collectionName: Guideline.collection,
      perPage: perPage,
      filter:
          'is_published = true && (priority = "critical" || priority = "high")',
      sort: 'priority,condition_name',
      expand: expand ?? 'categories,tags',
    );
    return result.items.map((record) => Guideline.fromRecord(record)).toList();
  }

  /// Search guidelines by query string
  Future<List<Guideline>> searchGuidelines({
    required String query,
    int page = 1,
    int perPage = 30,
    String? categoryFilter,
    List<String>? tagFilters,
    String? priorityFilter,
    String? healthcareLevelFilter,
    String? targetPopulationFilter,
    String? indexItemFilter,
  }) async {
    final List<String> filters = [];

    // Index item filter (permanent filter when present)
    if (indexItemFilter != null && indexItemFilter.isNotEmpty) {
      filters.add('index_item = "$indexItemFilter"');
    }

    // Base filter - only published guidelines
    filters.add('is_published = true');

    // Search in condition name, definition, and clinical features
    if (query.isNotEmpty) {
      filters.add(
        '(condition_name ~ "$query" || definition ~ "$query" || clinical_features ~ "$query" || causes ~ "$query")',
      );
    }

    // Category filter
    if (categoryFilter != null && categoryFilter.isNotEmpty) {
      filters.add('categories ~ "$categoryFilter"');
    }

    // Tag filters
    if (tagFilters != null && tagFilters.isNotEmpty) {
      final tagFilterString = tagFilters
          .map((tag) => 'tags ~ "$tag"')
          .join(' || ');
      filters.add('($tagFilterString)');
    }

    // Priority filter
    if (priorityFilter != null && priorityFilter.isNotEmpty) {
      filters.add('priority = "$priorityFilter"');
    }

    // Healthcare level filter
    if (healthcareLevelFilter != null && healthcareLevelFilter.isNotEmpty) {
      filters.add('healthcare_level_required = "$healthcareLevelFilter"');
    }

    // Target population filter
    if (targetPopulationFilter != null && targetPopulationFilter.isNotEmpty) {
      filters.add('target_population ~ "$targetPopulationFilter"');
    }

    final filterString = filters.join(' && ');

    final result = await BackendService.to.getRecordList(
      collectionName: Guideline.collection,
      page: page,
      perPage: perPage,
      filter: filterString,
      sort: 'priority,condition_name',
      expand: 'categories,tags,index_item',
    );

    return result.items.map((record) => Guideline.fromRecord(record)).toList();
  }

  /// Get all guideline categories
  Future<List<GuidelineCategory>> getGuidelineCategories({
    String? filter,
    String? sort,
  }) async {
    final result = await BackendService.to.getRecordList(
      collectionName: GuidelineCategory.collection,
      filter: filter ?? 'status = "active"',
      sort: sort ?? 'sort_order,name',
      expand: 'parent_category',
    );
    return result.items
        .map((record) => GuidelineCategory.fromRecord(record))
        .toList();
  }

  /// Get all guideline tags
  Future<List<GuidelineTag>> getGuidelineTags({
    String? filter,
    String? sort,
  }) async {
    final result = await BackendService.to.getRecordList(
      collectionName: GuidelineTag.collection,
      filter: filter,
      sort: sort ?? 'name',
    );
    return result.items
        .map((record) => GuidelineTag.fromRecord(record))
        .toList();
  }
}
