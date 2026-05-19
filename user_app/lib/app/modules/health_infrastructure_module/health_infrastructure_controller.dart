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
import 'health_facility_detail_page.dart';

class HealthInfrastructureController extends GetxController {
  // Pagination controller
  late final PagingController<int, HealthFacility> pagingController;

  // Permanent tree filters from selector modal
  final RxMap<String, dynamic> treeFilters = <String, dynamic>{}.obs;

  // Search and filter state
  final RxString searchQuery = ''.obs;
  final RxBool hasActiveFilters = false.obs;
  final RxString selectedRegionId = ''.obs;
  final RxString selectedDistrictId = ''.obs;
  final RxString selectedFacilityLevelId = ''.obs;
  final RxString selectedOwnershipTypeId = ''.obs;

  // Data state
  final RxList<Region> availableRegions = <Region>[].obs;
  final RxList<District> availableDistricts = <District>[].obs;
  final RxList<FacilityLevel> availableFacilityLevels = <FacilityLevel>[].obs;
  final RxList<OwnershipType> availableOwnershipTypes = <OwnershipType>[].obs;
  final RxBool isLoadingFilters = false.obs;

  @override
  void onInit() {
    super.onInit();
    _applyTreeFiltersFromArguments();
    pagingController = PagingController<int, HealthFacility>(
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

  /// Load available filter options
  Future<void> _loadFilterOptions() async {
    try {
      isLoadingFilters.value = true;

      final regions = await getRegions(sort: 'name');
      final facilityLevels = await BackendService.to.getRecordList(
        collectionName: 'facility_levels',
        sort: 'name',
      );
      final ownershipTypes = await BackendService.to.getRecordList(
        collectionName: 'ownership_types',
        sort: 'name',
      );

      availableRegions.value = regions;
      availableFacilityLevels.value = facilityLevels.items
          .map((record) => FacilityLevel.fromRecord(record))
          .toList();
      availableOwnershipTypes.value = ownershipTypes.items
          .map((record) => OwnershipType.fromRecord(record))
          .toList();
    } catch (error) {
      Common.quickToast(title: 'errorLoadingFilters'.tr);
    } finally {
      isLoadingFilters.value = false;
    }
  }

  /// Load districts for selected region
  Future<void> _loadDistrictsForRegion(String regionId) async {
    try {
      final districts = await getDistricts(
        filter: 'region = "$regionId"',
        sort: 'name',
      );
      availableDistricts.value = districts;
    } catch (error) {
      Common.quickToast(title: 'errorLoadingDistricts'.tr);
    }
  }

  /// Load a page of health facilities
  Future<List<HealthFacility>> _loadPage(int pageKey) async {
    try {
      final filter = _buildFilter();
      const expand =
          'region,district,county,subcounty,parish,health_sub_district,health_sub_region,facility_level,ownership_type,authority';

      final facilities = await getHealthFacilities(
        page: pageKey,
        perPage: pageSize,
        filter: filter.isNotEmpty ? filter : null,
        expand: expand,
        sort: 'name',
      );

      return facilities;
    } catch (error) {
      Common.quickToast(title: 'errorLoadingFacilities'.tr);
      rethrow;
    }
  }

  /// Build filter string for API queries
  String _buildFilter() {
    final filters = <String>[];

    // Search filter
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value;
      filters.add(
        '(name ~ "$query" || nhpi_code ~ "$query" || hsdt_code ~ "$query")',
      );
    }

    // Region filter
    if (selectedRegionId.value.isNotEmpty) {
      filters.add('region = "${selectedRegionId.value}"');
    }

    // District filter
    if (selectedDistrictId.value.isNotEmpty) {
      filters.add('district = "${selectedDistrictId.value}"');
    }

    // Facility level filter
    if (selectedFacilityLevelId.value.isNotEmpty) {
      filters.add('facility_level = "${selectedFacilityLevelId.value}"');
    }

    // Ownership type filter
    if (selectedOwnershipTypeId.value.isNotEmpty) {
      filters.add('ownership_type = "${selectedOwnershipTypeId.value}"');
    }

    return filters.join(' && ');
  }

  /// Search health facilities
  void searchFacilities(String query) {
    searchQuery.value = query.trim();
    _updateActiveFiltersState();
    pagingController.refresh();
  }

  /// Clear all filters
  void clearAllFilters() {
    selectedRegionId.value = '';
    selectedDistrictId.value = '';
    selectedFacilityLevelId.value = '';
    selectedOwnershipTypeId.value = '';
    searchQuery.value = '';
    treeFilters.clear();
    availableDistricts.clear();
    _updateActiveFiltersState();
    pagingController.refresh();
  }

  /// Show filter modal using generic filter bottom sheet
  Future<void> showFilterModal(BuildContext context) async {
    // Ensure filter options are loaded
    if (availableRegions.isEmpty ||
        availableFacilityLevels.isEmpty ||
        availableOwnershipTypes.isEmpty) {
      await _loadFilterOptions();
    }

    final fields = <FilterField>[
      FilterField.text('search', 'search'.tr, hint: 'searchFacilities'.tr),
    ];

    // Region dropdown
    if (availableRegions.isNotEmpty) {
      final regionOptions = availableRegions
          .map((region) => region.name)
          .toList();
      fields.add(
        FilterField.dropdown('region', 'region'.tr, [''] + regionOptions),
      );
    }

    // District dropdown (only if region is selected)
    if (availableDistricts.isNotEmpty) {
      final districtOptions = availableDistricts
          .map((district) => district.name)
          .toList();
      fields.add(
        FilterField.dropdown('district', 'district'.tr, [''] + districtOptions),
      );
    }

    // Facility level dropdown
    if (availableFacilityLevels.isNotEmpty) {
      final levelOptions = availableFacilityLevels
          .map((level) => level.name)
          .toList();
      fields.add(
        FilterField.dropdown(
          'facilityLevel',
          'facilityLevel'.tr,
          [''] + levelOptions,
        ),
      );
    }

    // Ownership type dropdown
    if (availableOwnershipTypes.isNotEmpty) {
      final typeOptions = availableOwnershipTypes
          .map((type) => type.name)
          .toList();
      fields.add(
        FilterField.dropdown(
          'ownershipType',
          'ownershipType'.tr,
          [''] + typeOptions,
        ),
      );
    }

    // Get initial values
    final values = <String, dynamic>{};
    if (searchQuery.value.isNotEmpty) values['search'] = searchQuery.value;

    if (selectedRegionId.value.isNotEmpty) {
      final region = availableRegions
          .where((r) => r.id == selectedRegionId.value)
          .firstOrNull;
      if (region != null) values['region'] = region.name;
    }

    if (selectedDistrictId.value.isNotEmpty) {
      final district = availableDistricts
          .where((d) => d.id == selectedDistrictId.value)
          .firstOrNull;
      if (district != null) values['district'] = district.name;
    }

    if (selectedFacilityLevelId.value.isNotEmpty) {
      final level = availableFacilityLevels
          .where((l) => l.id == selectedFacilityLevelId.value)
          .firstOrNull;
      if (level != null) values['facilityLevel'] = level.name;
    }

    if (selectedOwnershipTypeId.value.isNotEmpty) {
      final type = availableOwnershipTypes
          .where((t) => t.id == selectedOwnershipTypeId.value)
          .firstOrNull;
      if (type != null) values['ownershipType'] = type.name;
    }

    if (!context.mounted) return;

    final result = await GenericFilterBottomSheet.show(
      context: context,
      title: 'filterFacilities'.tr,
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
    selectedRegionId.value = '';
    selectedDistrictId.value = '';
    selectedFacilityLevelId.value = '';
    selectedOwnershipTypeId.value = '';
    searchQuery.value = '';
    availableDistricts.clear();

    // Apply new filters
    final search = result.getValue<String>('search');
    if (search != null && search.isNotEmpty) {
      searchQuery.value = search;
    }

    final regionName = result.getValue<String>('region');
    if (regionName != null && regionName.isNotEmpty) {
      final region = availableRegions
          .where((r) => r.name == regionName)
          .firstOrNull;
      if (region != null) {
        selectedRegionId.value = region.id;
        // Load districts for this region
        _loadDistrictsForRegion(region.id);
      }
    }

    final districtName = result.getValue<String>('district');
    if (districtName != null && districtName.isNotEmpty) {
      final district = availableDistricts
          .where((d) => d.name == districtName)
          .firstOrNull;
      if (district != null) {
        selectedDistrictId.value = district.id;
      }
    }

    final levelName = result.getValue<String>('facilityLevel');
    if (levelName != null && levelName.isNotEmpty) {
      final level = availableFacilityLevels
          .where((l) => l.name == levelName)
          .firstOrNull;
      if (level != null) {
        selectedFacilityLevelId.value = level.id;
      }
    }

    final typeName = result.getValue<String>('ownershipType');
    if (typeName != null && typeName.isNotEmpty) {
      final type = availableOwnershipTypes
          .where((t) => t.name == typeName)
          .firstOrNull;
      if (type != null) {
        selectedOwnershipTypeId.value = type.id;
      }
    }

    _updateActiveFiltersState();
    pagingController.refresh();
  }

  /// Navigate to facility detail page
  void goToFacilityDetail(HealthFacility facility) {
    // Track facility usage
    _trackFacilityUsage(facility.id);

    Get.to(() => const HealthFacilityDetailPage(), arguments: facility);
  }

  // ==================== HEALTH FACILITY AND GEOGRAPHIC METHODS ====================

  /// Get health facilities with filtering and pagination
  Future<List<HealthFacility>> getHealthFacilities({
    int page = 1,
    int perPage = 30,
    String? filter,
    String? sort,
    String? expand,
  }) async {
    final result = await BackendService.to.getRecordList(
      collectionName: 'health_facilities',
      page: page,
      perPage: perPage,
      filter: filter,
      sort: sort,
      expand: expand,
    );
    return result.items
        .map((record) => HealthFacility.fromRecord(record))
        .toList();
  }

  /// Get regions with optional filtering
  Future<List<Region>> getRegions({String? filter, String? sort}) async {
    final result = await BackendService.to.getRecordList(
      collectionName: 'regions',
      filter: filter,
      sort: sort,
    );
    return result.items.map((record) => Region.fromRecord(record)).toList();
  }

  /// Get districts with optional filtering and expansion
  Future<List<District>> getDistricts({
    String? filter,
    String? sort,
    String? expand,
  }) async {
    final result = await BackendService.to.getRecordList(
      collectionName: 'districts',
      filter: filter,
      sort: sort,
      expand: expand,
    );
    return result.items.map((record) => District.fromRecord(record)).toList();
  }

  /// Get counties with optional filtering and expansion
  Future<List<County>> getCounties({
    String? filter,
    String? sort,
    String? expand,
  }) async {
    final result = await BackendService.to.getRecordList(
      collectionName: 'counties',
      filter: filter,
      sort: sort,
      expand: expand,
    );
    return result.items.map((record) => County.fromRecord(record)).toList();
  }

  /// Track facility usage
  Future<void> _trackFacilityUsage(String facilityId) async {
    try {
      if (AuthService.to.currentUser.value == null) return;

      // Create facility usage log
      final logData = FacilityUsageLog.forCreate(
        userId: AuthService.to.currentUser.value!.id,
        facilityId: facilityId,
      );

      await BackendService.to.createRecord(
        collectionName: FacilityUsageLog.collection,
        data: logData,
      );

      // Increment facility usage count
      await BackendService.to.incrementUsageCount(
        HealthFacility.collection,
        facilityId,
      );
    } catch (e) {
      // Handle error silently to not disrupt user experience
    }
  }

  void _applyTreeFiltersFromArguments() {
    final args = Get.arguments;
    if (args is! Map) return;

    final rawFilters = args['treeFilters'];
    if (rawFilters is! Map) return;

    final filters = Map<String, dynamic>.from(rawFilters);
    treeFilters.assignAll(filters);

    final region = _readString(filters, 'region');
    final district = _readString(filters, 'district');
    final facilityLevel = _readString(filters, 'facility_level');
    final ownershipType = _readString(filters, 'ownership_type');

    if (region.isNotEmpty) {
      selectedRegionId.value = region;
      _loadDistrictsForRegion(region);
    }
    if (district.isNotEmpty) selectedDistrictId.value = district;
    if (facilityLevel.isNotEmpty) {
      selectedFacilityLevelId.value = facilityLevel;
    }
    if (ownershipType.isNotEmpty) {
      selectedOwnershipTypeId.value = ownershipType;
    }

    _updateActiveFiltersState();
  }

  void _updateActiveFiltersState() {
    hasActiveFilters.value =
        searchQuery.value.isNotEmpty ||
        selectedRegionId.value.isNotEmpty ||
        selectedDistrictId.value.isNotEmpty ||
        selectedFacilityLevelId.value.isNotEmpty ||
        selectedOwnershipTypeId.value.isNotEmpty;
  }

  String _readString(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value == null) return '';
    return value.toString().trim();
  }
}
