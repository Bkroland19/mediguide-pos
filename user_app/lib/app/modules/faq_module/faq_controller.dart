import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import '../../data/models/backend_record.dart';
import '../../data/models/models.dart';
import '../../data/models/filter_models.dart';
import '../../data/services/backend_service.dart';
import '../../utils/constants.dart';
import '../../utils/common.dart';
import '../../widgets/generic_filter_bottom_sheet.dart';
import '../../translations/app_translations.dart';

class FaqController extends GetxController {
  // Public reactive variables (no private with getters)
  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;
  final RxBool hasActiveFilters = false.obs;

  // Infinite scroll pagination
  late PagingController<int, FAQ> pagingController;

  @override
  void onInit() {
    super.onInit();
    initializePagination();
    setupSearchListener();
  }

  /// Initialize pagination controller
  void initializePagination() {
    pagingController = PagingController<int, FAQ>(
      getNextPageKey: (state) =>
          state.lastPageIsEmpty ? null : (state.keys?.last ?? 0) + 1,
      fetchPage: (pageKey) async => await loadAllFAQs(pageKey),
    );
  }

  /// Setup search query listener with debouncing
  void setupSearchListener() {
    debounce(
      searchQuery,
      (_) => pagingController.refresh(),
      time: const Duration(milliseconds: 500),
    );

    // Update hasActiveFilters when search changes
    ever(searchQuery, (_) => updateActiveFilters());
  }

  /// Update active filters indicator
  void updateActiveFilters() {
    hasActiveFilters.value = searchQuery.value.isNotEmpty;
  }

  // Public methods - no wrapper functions
  Future<List<FAQ>> loadAllFAQs(int pageKey) async {
    try {
      final result = searchQuery.value.isNotEmpty
          ? await _searchFAQs(
              query: searchQuery.value,
              page: pageKey,
              perPage: pageSize,
            )
          : await _getFAQs(page: pageKey, perPage: pageSize);

      final faqs = result.items
          .map((item) => FAQ.fromJson(item.toJson()))
          .toList();

      return faqs;
    } catch (error) {
      Common.quickToast(
        title: AppTranslationKey.error.tr,
        description: 'Failed to load FAQs: ${error.toString()}',
      );
      rethrow;
    }
  }

  void searchFAQs(String query) {
    searchQuery.value = query.trim();
  }

  void clearSearch() {
    searchQuery.value = '';
  }

  /// Clear all filters (for consistency with other controllers)
  void clearAllFilters() {
    searchQuery.value = '';
    hasActiveFilters.value = false;
    pagingController.refresh();
  }

  /// Show filter modal using generic filter bottom sheet
  Future<void> showFilterModal(BuildContext context) async {
    final fields = <FilterField>[
      FilterField.text('search', 'search'.tr, hint: 'searchFAQs'.tr),
    ];

    // Get initial values
    final values = <String, dynamic>{};
    if (searchQuery.value.isNotEmpty) values['search'] = searchQuery.value;

    if (!context.mounted) return;

    final result = await GenericFilterBottomSheet.show(
      context: context,
      title: 'searchFAQs'.tr,
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
    searchQuery.value = '';

    // Apply new filters
    final search = result.getValue<String>('search');
    if (search != null && search.isNotEmpty) {
      searchQuery.value = search;
    }

    hasActiveFilters.value = searchQuery.value.isNotEmpty;
    pagingController.refresh();
  }

  void refreshFAQs() {
    pagingController.refresh();
  }

  void retryLastFailedRequest() {
    pagingController.refresh();
  }

  // Private FAQ-specific methods using BackendService wrapper methods
  Future<ResultList<RecordModel>> _getFAQs({
    int page = 1,
    int perPage = 10,
    String? filter,
    String? sort,
    String? expand,
  }) async {
    // Base filter for published FAQs
    String baseFilter = 'status = "published"';

    // Combine with additional filter if provided
    String finalFilter = filter != null && filter.isNotEmpty
        ? '$baseFilter && ($filter)'
        : baseFilter;

    // Default sort by sort_order (ascending) then by created date (descending)
    String finalSort = sort ?? 'sort_order, -created';

    return await BackendService.to.getRecordList(
      collectionName: 'faqs',
      page: page,
      perPage: perPage,
      filter: finalFilter,
      sort: finalSort,
      expand: expand,
    );
  }

  Future<ResultList<RecordModel>> _searchFAQs({
    required String query,
    int page = 1,
    int perPage = 10,
  }) async {
    if (query.isEmpty) {
      return await _getFAQs(page: page, perPage: perPage);
    }

    // Search in question, answer, and keywords fields
    String searchFilter =
        'question ~ "$query" || keywords ~ "$query" || answer ~ "$query"';

    return await _getFAQs(
      page: page,
      perPage: perPage,
      filter: searchFilter,
      sort: '-is_featured, sort_order, -created', // Featured first
    );
  }

  Future<List<FAQ>> getFeaturedFAQs({int limit = 5}) async {
    try {
      String filter = 'is_featured = true';

      final result = await BackendService.to.getRecordList(
        collectionName: 'faqs',
        page: 1,
        perPage: limit,
        filter: filter,
        sort: 'sort_order, -created',
      );

      return result.items.map((item) => FAQ.fromJson(item.toJson())).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<FAQ?> getFAQById({required String faqId}) async {
    try {
      final record = await BackendService.to.getRecord(
        collectionName: 'faqs',
        recordId: faqId,
      );

      return record != null ? FAQ.fromJson(record.toJson()) : null;
    } catch (e) {
      rethrow;
    }
  }

  @override
  void onClose() {
    pagingController.dispose();
    super.onClose();
  }
}
