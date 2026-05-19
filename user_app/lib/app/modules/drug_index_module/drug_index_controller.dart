import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import '../../data/models/models.dart';
import '../../data/models/filter_models.dart';
import '../../data/services/backend_service.dart';
import '../../data/services/auth_service.dart';
import '../../translations/app_translations.dart';
import '../../utils/common.dart';
import '../../utils/constants.dart';
import '../../widgets/generic_filter_bottom_sheet.dart';
import 'widgets/drug_details_bottom_sheet.dart';

class DrugIndexController extends GetxController {
  // Dependencies
  final BackendService _pbService = BackendService.to;

  // Controllers
  late final PagingController<int, Drug> pagingController;

  // Search and filter state
  final RxString searchQuery = ''.obs;
  final RxBool hasActiveFilters = false.obs;
  final selectedCategories = <String>[].obs;
  final selectedTags = <String>[].obs;
  final selectedRoutes = <String>[].obs;
  final selectedPregnancyCategories = <String>[].obs;
  final whoEmlOnly = false.obs;
  final antimicrobialOnly = false.obs;

  // Filter options
  final categories = <String>[].obs;
  final tags = <String>[].obs;
  final routes = <String>[].obs;
  final pregnancyCategories = <String>[].obs;
  final isLoadingFilters = false.obs;

  @override
  void onInit() {
    super.onInit();
    _initializePagingController();
    _loadFilterOptions();
  }

  @override
  void onClose() {
    pagingController.dispose();
    super.onClose();
  }

  /// Initialize the paging controller with v5 constructor API
  void _initializePagingController() {
    pagingController = PagingController<int, Drug>(
      getNextPageKey: (state) =>
          state.lastPageIsEmpty ? null : state.nextIntPageKey,
      fetchPage: (pageKey) => _fetchDrugsPage(pageKey),
    );
  }

  /// Load available filter options using offline-first approach
  Future<void> _loadFilterOptions() async {
    try {
      isLoadingFilters.value = true;

      // Load categories using offline-first pattern
      final categoriesResult = await _pbService.getRecordList(
        collectionName: DrugCategory.collection,
        page: 1,
        perPage: 100,
        sort: 'name',
      );
      categories.value = categoriesResult.items
          .map((record) => record.data['name'] as String)
          .toList();

      // Load tags using offline-first pattern
      final tagsResult = await _pbService.getRecordList(
        collectionName: DrugTag.collection,
        page: 1,
        perPage: 100,
        sort: 'name',
      );
      tags.value = tagsResult.items
          .map((record) => record.data['name'] as String)
          .toList();

      // Static routes and pregnancy categories from enums
      routes.value = [
        'oral',
        'IV',
        'IM',
        'topical',
        'inhaled',
        'sublingual',
        'rectal',
        'transdermal',
        'intranasal',
        'subcutaneous',
      ];
      pregnancyCategories.value = ['A', 'B', 'C', 'D', 'X', 'Unknown'];
    } catch (e) {
      Common.quickToast(title: 'errorLoadingFilters'.tr);
    } finally {
      isLoadingFilters.value = false;
    }
  }

  /// Fetch drugs page for infinite scroll pagination
  Future<List<Drug>> _fetchDrugsPage(int pageKey) async {
    try {
      final filter = _buildFilter();

      final drugs = await getDrugs(
        page: pageKey,
        perPage: pageSize,
        filter: filter,
        sort: 'name',
        expand: 'categories,tags,therapeutic_category',
      );

      return drugs;
    } catch (e) {
      Common.quickToast(title: 'failedToLoadDrugs'.tr);
      rethrow;
    }
  }

  /// Build filter string based on current filter state
  String _buildFilter() {
    final filterParts = <String>['status = "active"'];

    // Search query filter
    if (searchQuery.value.isNotEmpty) {
      final searchFilter =
          'name ~ "${searchQuery.value}" || generic_name ~ "${searchQuery.value}" || brand_names ~ "${searchQuery.value}"';
      filterParts.add('($searchFilter)');
    }

    // Categories filter
    if (selectedCategories.isNotEmpty) {
      final categoriesFilter = selectedCategories
          .map((cat) => 'categories ~ "$cat"')
          .join(' || ');
      filterParts.add('($categoriesFilter)');
    }

    // Tags filter
    if (selectedTags.isNotEmpty) {
      final tagsFilter = selectedTags
          .map((tag) => 'tags ~ "$tag"')
          .join(' || ');
      filterParts.add('($tagsFilter)');
    }

    // Routes filter
    if (selectedRoutes.isNotEmpty) {
      final routesFilter = selectedRoutes
          .map((route) => 'route_of_administration ~ "$route"')
          .join(' || ');
      filterParts.add('($routesFilter)');
    }

    // Pregnancy categories filter
    if (selectedPregnancyCategories.isNotEmpty) {
      final pregnancyFilter = selectedPregnancyCategories
          .map((cat) => 'pregnancy_category ~ "$cat"')
          .join(' || ');
      filterParts.add('($pregnancyFilter)');
    }

    // WHO EML filter
    if (whoEmlOnly.value) {
      filterParts.add('who_eml_status = true');
    }

    // Antimicrobial filter
    if (antimicrobialOnly.value) {
      filterParts.add('antimicrobial_status = true');
    }

    return filterParts.join(' && ');
  }

  /// Update active filters state
  void _updateActiveFiltersState() {
    hasActiveFilters.value =
        searchQuery.value.isNotEmpty ||
        selectedCategories.isNotEmpty ||
        selectedTags.isNotEmpty ||
        selectedRoutes.isNotEmpty ||
        selectedPregnancyCategories.isNotEmpty ||
        whoEmlOnly.value ||
        antimicrobialOnly.value;
  }

  /// Refresh data (pull-to-refresh)
  Future<void> refreshData() async {
    pagingController.refresh();
  }

  /// Toggle category filter
  void toggleCategory(String category) {
    if (selectedCategories.contains(category)) {
      selectedCategories.remove(category);
    } else {
      selectedCategories.add(category);
    }
    _updateActiveFiltersState();
    pagingController.refresh();
  }

  /// Toggle tag filter
  void toggleTag(String tag) {
    if (selectedTags.contains(tag)) {
      selectedTags.remove(tag);
    } else {
      selectedTags.add(tag);
    }
    _updateActiveFiltersState();
    pagingController.refresh();
  }

  /// Toggle route filter
  void toggleRoute(String route) {
    if (selectedRoutes.contains(route)) {
      selectedRoutes.remove(route);
    } else {
      selectedRoutes.add(route);
    }
    _updateActiveFiltersState();
    pagingController.refresh();
  }

  /// Toggle pregnancy category filter
  void togglePregnancyCategory(String category) {
    if (selectedPregnancyCategories.contains(category)) {
      selectedPregnancyCategories.remove(category);
    } else {
      selectedPregnancyCategories.add(category);
    }
    _updateActiveFiltersState();
    pagingController.refresh();
  }

  /// Toggle WHO EML filter
  void toggleWhoEml() {
    whoEmlOnly.value = !whoEmlOnly.value;
    _updateActiveFiltersState();
    pagingController.refresh();
  }

  /// Toggle antimicrobial filter
  void toggleAntimicrobial() {
    antimicrobialOnly.value = !antimicrobialOnly.value;
    _updateActiveFiltersState();
    pagingController.refresh();
  }

  /// Clear all filters
  void clearAllFilters() {
    searchQuery.value = '';
    selectedCategories.clear();
    selectedTags.clear();
    selectedRoutes.clear();
    selectedPregnancyCategories.clear();
    whoEmlOnly.value = false;
    antimicrobialOnly.value = false;
    hasActiveFilters.value = false;
    pagingController.refresh();
  }

  /// Show filter modal using generic filter bottom sheet
  Future<void> showFilterModal(BuildContext context) async {
    // Ensure filter options are loaded
    if (categories.isEmpty || tags.isEmpty) {
      await _loadFilterOptions();
    }

    final fields = <FilterField>[
      FilterField.text('search', 'search'.tr, hint: 'searchDrugs'.tr),
      FilterField.boolean('whoEmlOnly', AppTranslationKey.whoEmlOnly),
      FilterField.boolean(
        'antimicrobialOnly',
        AppTranslationKey.antimicrobialOnly,
      ),
    ];

    // Categories multi-select
    if (categories.isNotEmpty) {
      fields.add(
        FilterField.multiSelect(
          'categories',
          'categories'.tr,
          categories.toList(),
        ),
      );
    }

    // Tags multi-select
    if (tags.isNotEmpty) {
      fields.add(FilterField.multiSelect('tags', 'tags'.tr, tags.toList()));
    }

    // Routes multi-select
    if (routes.isNotEmpty) {
      fields.add(
        FilterField.multiSelect('routes', 'routes'.tr, routes.toList()),
      );
    }

    // Pregnancy categories multi-select
    if (pregnancyCategories.isNotEmpty) {
      fields.add(
        FilterField.multiSelect(
          'pregnancyCategories',
          'pregnancyCategories'.tr,
          pregnancyCategories.toList(),
        ),
      );
    }

    // Get initial values
    final values = <String, dynamic>{};
    if (searchQuery.value.isNotEmpty) values['search'] = searchQuery.value;
    if (whoEmlOnly.value) values['whoEmlOnly'] = true;
    if (antimicrobialOnly.value) values['antimicrobialOnly'] = true;
    if (selectedCategories.isNotEmpty) {
      values['categories'] = selectedCategories.toList();
    }
    if (selectedTags.isNotEmpty) values['tags'] = selectedTags.toList();
    if (selectedRoutes.isNotEmpty) values['routes'] = selectedRoutes.toList();
    if (selectedPregnancyCategories.isNotEmpty) {
      values['pregnancyCategories'] = selectedPregnancyCategories.toList();
    }

    if (!context.mounted) return;

    final result = await GenericFilterBottomSheet.show(
      context: context,
      title: AppTranslationKey.filterDrugs,
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
    selectedCategories.clear();
    selectedTags.clear();
    selectedRoutes.clear();
    selectedPregnancyCategories.clear();
    whoEmlOnly.value = false;
    antimicrobialOnly.value = false;

    // Apply new filters
    final search = result.getValue<String>('search');
    if (search != null && search.isNotEmpty) {
      searchQuery.value = search;
    }

    final who = result.getValue<bool>('whoEmlOnly');
    if (who == true) {
      whoEmlOnly.value = true;
    }

    final antimicrobial = result.getValue<bool>('antimicrobialOnly');
    if (antimicrobial == true) {
      antimicrobialOnly.value = true;
    }

    final categoriesList = result.getValue<List>('categories');
    if (categoriesList != null && categoriesList.isNotEmpty) {
      selectedCategories.addAll(categoriesList.cast<String>());
    }

    final tagsList = result.getValue<List>('tags');
    if (tagsList != null && tagsList.isNotEmpty) {
      selectedTags.addAll(tagsList.cast<String>());
    }

    final routesList = result.getValue<List>('routes');
    if (routesList != null && routesList.isNotEmpty) {
      selectedRoutes.addAll(routesList.cast<String>());
    }

    final pregnancyList = result.getValue<List>('pregnancyCategories');
    if (pregnancyList != null && pregnancyList.isNotEmpty) {
      selectedPregnancyCategories.addAll(pregnancyList.cast<String>());
    }

    _updateActiveFiltersState();
    pagingController.refresh();
  }

  /// Show drug detail bottom sheet
  Future<void> navigateToDrugDetail(Drug drug) async {
    final context = Get.context;
    if (context != null && context.mounted) {
      // Track drug usage
      _trackDrugUsage(drug.id);

      await DrugDetailsBottomSheet.show(context: context, drug: drug);
    }
  }

  /// Toggle bookmark for drug
  void toggleBookmark(Drug drug) {
    // TODO: Implement bookmark functionality
    Common.quickToast(title: 'Bookmark toggled for ${drug.name}');
  }

  // ==================== DRUG-SPECIFIC METHODS ====================

  /// Get drugs with optional filtering and pagination
  Future<List<Drug>> getDrugs({
    int page = 1,
    int perPage = 30,
    String? filter,
    String? sort,
    String? expand,
  }) async {
    final result = await _pbService.getRecordList(
      collectionName: Drug.collection,
      page: page,
      perPage: perPage,
      filter: filter,
      sort: sort,
      expand: expand,
    );
    return result.items.map((record) => Drug.fromRecord(record)).toList();
  }

  /// Get drug by ID with expanded relationships
  Future<Drug?> getDrugById(String drugId, {String? expand}) async {
    final record = await _pbService.getRecord(
      collectionName: Drug.collection,
      recordId: drugId,
      expand: expand,
    );
    return record != null ? Drug.fromRecord(record) : null;
  }

  /// Create a new drug
  Future<Drug> createDrug(Map<String, dynamic> drugData) async {
    final record = await _pbService.createRecord(
      collectionName: Drug.collection,
      data: drugData,
    );
    return Drug.fromRecord(record);
  }

  /// Update an existing drug
  Future<Drug> updateDrug(String drugId, Map<String, dynamic> drugData) async {
    final record = await _pbService.updateRecord(
      collectionName: Drug.collection,
      recordId: drugId,
      data: drugData,
    );
    return Drug.fromRecord(record);
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

      await BackendService.to.createRecord(
        collectionName: DrugUsageLog.collection,
        data: logData,
      );

      // Increment drug usage count
      await BackendService.to.incrementUsageCount(Drug.collection, drugId);
    } catch (e) {
      // Handle error silently to not disrupt user experience
    }
  }
}
