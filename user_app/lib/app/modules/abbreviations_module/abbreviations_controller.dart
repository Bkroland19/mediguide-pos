import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../data/models/models.dart';
import '../../data/models/filter_models.dart';
import '../../data/services/backend_service.dart';
import '../../data/services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/common.dart';
import '../../widgets/generic_filter_bottom_sheet.dart';
import 'widgets/abbreviation_detail_modal.dart';

class AbbreviationsController extends GetxController {
  // Pagination controller
  late final PagingController<int, Abbreviation> pagingController;

  // Search and filter state
  final RxString searchQuery = ''.obs;
  final RxBool hasActiveFilters = false.obs;
  final RxString selectedCategoryId = ''.obs;
  final RxList<String> selectedTagIds = <String>[].obs;
  final RxBool showCommonOnly = false.obs;

  // Data state
  final RxList<GuidelineCategory> availableCategories =
      <GuidelineCategory>[].obs;
  final RxList<GuidelineTag> availableTags = <GuidelineTag>[].obs;
  final RxBool isLoadingFilters = false.obs;

  @override
  void onInit() {
    super.onInit();
    pagingController = PagingController<int, Abbreviation>(
      getNextPageKey: (state) =>
          state.lastPageIsEmpty ? null : state.nextIntPageKey,
      fetchPage: _loadPage,
    );
    _loadFilterOptions();
  }

  @override
  void onClose() {
    pagingController.dispose();
    super.onClose();
  }

  /// Load a page of abbreviations
  Future<List<Abbreviation>> _loadPage(int pageKey) async {
    try {
      final List<Abbreviation> newItems;

      if (searchQuery.value.isNotEmpty || hasActiveFilters.value) {
        // Search with filters
        newItems = await _searchAbbreviations(
          query: searchQuery.value,
          page: pageKey,
          perPage: pageSize,
          categoryFilter: selectedCategoryId.value.isNotEmpty
              ? selectedCategoryId.value
              : null,
          tagFilters: selectedTagIds.isNotEmpty
              ? selectedTagIds.toList()
              : null,
        );
      } else if (showCommonOnly.value) {
        // Show only common abbreviations
        if (pageKey == 1) {
          newItems = await getCommonAbbreviations();
        } else {
          newItems = [];
        }
      } else {
        // Regular pagination
        newItems = await getAbbreviations(page: pageKey, perPage: pageSize);
      }

      return newItems;
    } catch (error) {
      Common.quickToast(title: 'errorLoadingAbbreviations'.tr);
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

  /// Search abbreviations
  void searchAbbreviations(String query) {
    searchQuery.value = query.trim();
    hasActiveFilters.value =
        searchQuery.value.isNotEmpty ||
        selectedCategoryId.value.isNotEmpty ||
        selectedTagIds.isNotEmpty ||
        showCommonOnly.value;
    pagingController.refresh();
  }

  /// Clear all filters
  void clearAllFilters() {
    selectedCategoryId.value = '';
    selectedTagIds.clear();
    showCommonOnly.value = false;
    searchQuery.value = '';
    hasActiveFilters.value = false;
    pagingController.refresh();
  }

  /// Show filter modal using generic filter bottom sheet
  Future<void> showFilterModal(BuildContext context) async {
    // Ensure filter options are loaded
    if (availableCategories.isEmpty || availableTags.isEmpty) {
      await _loadFilterOptions();
    }

    final fields = <FilterField>[
      FilterField.text('search', 'search'.tr, hint: 'searchAbbreviations'.tr),
      FilterField.boolean('showCommonOnly', 'showCommonOnly'.tr),
    ];

    // Category dropdown
    if (availableCategories.isNotEmpty) {
      final categoryOptions = availableCategories
          .map((category) => category.displayName)
          .toList();
      fields.add(
        FilterField.dropdown('category', 'category'.tr, [''] + categoryOptions),
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
    if (showCommonOnly.value) values['showCommonOnly'] = true;

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
      title: 'filterAbbreviations'.tr,
      fields: fields,
      initialValues: values,
    );

    if (result != null && result.isNotEmpty) {
      _applyFilters(result);
    }
  }

  /// Apply filters from the generic filter result
  void _applyFilters(FilterResult result) {
    // Clear existing filters first
    selectedCategoryId.value = '';
    selectedTagIds.clear();
    showCommonOnly.value = false;
    searchQuery.value = '';

    // Apply new filters
    final search = result.getValue<String>('search');
    if (search != null && search.isNotEmpty) {
      searchQuery.value = search;
    }

    final commonOnly = result.getValue<bool>('showCommonOnly');
    if (commonOnly == true) {
      showCommonOnly.value = true;
    }

    final categoryName = result.getValue<String>('category');
    if (categoryName != null && categoryName.isNotEmpty) {
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

    hasActiveFilters.value =
        searchQuery.value.isNotEmpty ||
        selectedCategoryId.value.isNotEmpty ||
        selectedTagIds.isNotEmpty ||
        showCommonOnly.value;
    pagingController.refresh();
  }

  // ==================== ABBREVIATION-SPECIFIC METHODS ====================

  /// Get abbreviations with optional filtering and pagination
  Future<List<Abbreviation>> getAbbreviations({
    int page = 1,
    int perPage = 30,
    String? filter,
    String? sort,
    String? expand,
  }) async {
    final result = await BackendService.to.getRecordList(
      collectionName: Abbreviation.collection,
      page: page,
      perPage: perPage,
      filter: filter,
      sort: sort ?? '-created',
      expand: expand ?? 'category,tags',
    );
    return result.items
        .map((record) => Abbreviation.fromRecord(record))
        .toList();
  }

  /// Get abbreviation by ID with expanded relationships
  Future<Abbreviation?> getAbbreviationById(String abbreviationId) async {
    final record = await BackendService.to.getRecord(
      collectionName: Abbreviation.collection,
      recordId: abbreviationId,
      expand: 'category,tags',
    );
    return record != null ? Abbreviation.fromRecord(record) : null;
  }

  /// Get common abbreviations (commonly used ones)
  Future<List<Abbreviation>> getCommonAbbreviations({
    int perPage = 50,
    String? expand,
  }) async {
    final result = await BackendService.to.getRecordList(
      collectionName: Abbreviation.collection,
      perPage: perPage,
      filter: 'common_usage = true',
      sort: 'abbreviation',
      expand: expand ?? 'category,tags',
    );
    return result.items
        .map((record) => Abbreviation.fromRecord(record))
        .toList();
  }

  /// Search abbreviations by query string
  Future<List<Abbreviation>> _searchAbbreviations({
    required String query,
    int page = 1,
    int perPage = 30,
    String? categoryFilter,
    List<String>? tagFilters,
  }) async {
    final List<String> filters = [];

    // Search in abbreviation, meaning, and description
    if (query.isNotEmpty) {
      filters.add(
        '(abbreviation ~ "$query" || meaning ~ "$query" || description ~ "$query")',
      );
    }

    // Category filter
    if (categoryFilter != null && categoryFilter.isNotEmpty) {
      filters.add('category = "$categoryFilter"');
    }

    // Tag filters
    if (tagFilters != null && tagFilters.isNotEmpty) {
      final tagFilterString = tagFilters
          .map((tag) => 'tags ~ "$tag"')
          .join(' || ');
      filters.add('($tagFilterString)');
    }

    final filterString = filters.isNotEmpty ? filters.join(' && ') : null;

    final result = await BackendService.to.getRecordList(
      collectionName: Abbreviation.collection,
      page: page,
      perPage: perPage,
      filter: filterString,
      sort: 'abbreviation',
      expand: 'category,tags',
    );

    return result.items
        .map((record) => Abbreviation.fromRecord(record))
        .toList();
  }

  /// Get abbreviations by category
  Future<List<Abbreviation>> getAbbreviationsByCategory(
    String categoryId,
  ) async {
    final result = await BackendService.to.getRecordList(
      collectionName: Abbreviation.collection,
      filter: 'category = "$categoryId"',
      sort: 'abbreviation',
      expand: 'category,tags',
    );
    return result.items
        .map((record) => Abbreviation.fromRecord(record))
        .toList();
  }

  /// Get abbreviations by tag
  Future<List<Abbreviation>> getAbbreviationsByTag(String tagId) async {
    final result = await BackendService.to.getRecordList(
      collectionName: Abbreviation.collection,
      filter: 'tags ~ "$tagId"',
      sort: 'abbreviation',
      expand: 'category,tags',
    );
    return result.items
        .map((record) => Abbreviation.fromRecord(record))
        .toList();
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

  /// Show abbreviation detail with usage tracking
  Future<void> showAbbreviationDetail(
    BuildContext context,
    Abbreviation abbreviation,
  ) async {
    // Track abbreviation usage
    _trackAbbreviationUsage(abbreviation.id);

    // Show detail modal
    await AbbreviationDetailModal.show(context, abbreviation);
  }

  /// Track abbreviation usage
  Future<void> _trackAbbreviationUsage(String abbreviationId) async {
    try {
      if (AuthService.to.currentUser.value == null) return;

      // Create abbreviation usage log
      final logData = AbbreviationUsageLog.forCreate(
        userId: AuthService.to.currentUser.value!.id,
        abbreviationId: abbreviationId,
      );

      await BackendService.to.createRecord(
        collectionName: AbbreviationUsageLog.collection,
        data: logData,
      );

      // Increment abbreviation usage count
      await BackendService.to.incrementUsageCount(
        Abbreviation.collection,
        abbreviationId,
      );
    } catch (e) {
      // Handle error silently to not disrupt user experience
    }
  }
}
