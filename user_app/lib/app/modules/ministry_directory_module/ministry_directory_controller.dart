import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../data/models/models.dart';
import '../../data/models/filter_models.dart';
import '../../data/services/backend_service.dart';
import '../../utils/constants.dart';
import '../../utils/common.dart';
import '../../widgets/generic_filter_bottom_sheet.dart';

class MinistryDirectoryController extends GetxController {
  // Pagination controller
  late final PagingController<int, MinistryDirectory> pagingController;

  // Permanent tree filters from selector modal
  final RxMap<String, dynamic> treeFilters = <String, dynamic>{}.obs;

  // Search and filter state
  final RxString searchQuery = ''.obs;
  final RxBool hasActiveFilters = false.obs;
  final RxString selectedMinistry = ''.obs;
  final RxString selectedDistrict = ''.obs;
  final RxString selectedRegion = ''.obs;
  final RxString selectedDepartment = ''.obs;
  final RxString selectedStatus = ''.obs;
  final RxBool showEmergencyOnly = false.obs;
  final RxBool showActiveOnly = true.obs;

  // Available filter options
  final RxList<String> availableMinistries = <String>[].obs;
  final RxList<String> availableDistricts = <String>[].obs;
  final RxList<String> availableRegions = <String>[].obs;
  final RxBool isLoadingFilters = false.obs;

  @override
  void onInit() {
    super.onInit();
    _applyTreeFiltersFromArguments();
    pagingController = PagingController<int, MinistryDirectory>(
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

  /// Load a page of ministry directory entries
  Future<List<MinistryDirectory>> _loadPage(int pageKey) async {
    try {
      final List<MinistryDirectory> newItems;

      // Build filter string for backend
      String filter = '';
      final filters = <String>[];

      // Status filter - show active by default
      if (selectedStatus.value.isNotEmpty) {
        filters.add('status="${selectedStatus.value}"');
      } else if (showActiveOnly.value) {
        filters.add('status="active"');
      }

      // Search query filter - includes name, title, department, ministry, and email
      if (searchQuery.value.isNotEmpty) {
        filters.add(
          '(name~"${searchQuery.value}" || title~"${searchQuery.value}" || department~"${searchQuery.value}" || ministry~"${searchQuery.value}" || email~"${searchQuery.value}")',
        );
      }

      // Ministry filter
      if (selectedMinistry.value.isNotEmpty) {
        filters.add('ministry="${selectedMinistry.value}"');
      }

      // District filter (using relation)
      if (selectedDistrict.value.isNotEmpty) {
        filters.add('district.name~"${selectedDistrict.value}"');
      }

      // Region filter (using relation)
      if (selectedRegion.value.isNotEmpty) {
        filters.add('region.name~"${selectedRegion.value}"');
      }

      // Department filter
      if (selectedDepartment.value.isNotEmpty) {
        filters.add('department~"${selectedDepartment.value}"');
      }

      // Emergency contacts only filter
      if (showEmergencyOnly.value) {
        filters.add('priority_level=1');
      }

      if (filters.isNotEmpty) {
        filter = filters.join(' && ');
      }

      // Load ministry directory with filters and expand district/region relations
      final result = await BackendService.to.getRecordList(
        collectionName: 'ministry_directory',
        page: pageKey,
        perPage: pageSize,
        filter: filter.isNotEmpty ? filter : null,
        sort: 'priority_level,name',
        expand: 'district,region',
      );

      newItems = result.items
          .map((item) => MinistryDirectory.fromRecord(item))
          .toList();

      return newItems;
    } catch (e) {
      Common.quickToast(
        title: 'Error loading directory',
        description: e.toString(),
      );
      rethrow;
    }
  }

  /// Load available filter options
  Future<void> _loadFilterOptions() async {
    try {
      isLoadingFilters.value = true;

      // Load available ministries from enum
      availableMinistries.value = Ministry.values.map((m) => m.label).toList();

      // Load available districts
      final districtsResult = await BackendService.to.getRecordList(
        collectionName: 'districts',
        perPage: 500, // Load all districts
        sort: 'name',
      );
      availableDistricts.value = districtsResult.items
          .map((d) => d.data['name'] as String)
          .toList();

      // Load available regions
      final regionsResult = await BackendService.to.getRecordList(
        collectionName: 'regions',
        perPage: 500, // Load all regions
        sort: 'name',
      );
      availableRegions.value = regionsResult.items
          .map((r) => r.data['name'] as String)
          .toList();
    } catch (e) {
      Common.quickToast(
        title: 'Error loading filters',
        description: e.toString(),
      );
    } finally {
      isLoadingFilters.value = false;
    }
  }

  /// Handle search query change
  void onSearchQueryChanged(String query) {
    if (searchQuery.value != query) {
      searchQuery.value = query;
      _refreshList();
    }
  }

  /// Show advanced filter bottom sheet
  Future<void> showAdvancedFilter(BuildContext context) async {
    final result = await GenericFilterBottomSheet.show(
      context: context,
      title: 'Filter Directory',
      fields: [
        FilterField.text(
          'search',
          'Search by name, title, email...',
          initialValue: searchQuery.value.isEmpty ? null : searchQuery.value,
          hint: 'Enter name, title, department, ministry, or email',
        ),
        FilterField.dropdown(
          'ministry',
          'Ministry',
          availableMinistries,
          initialValue: selectedMinistry.value.isEmpty
              ? null
              : selectedMinistry.value,
        ),
        FilterField.dropdown(
          'district',
          'District',
          availableDistricts,
          initialValue: selectedDistrict.value.isEmpty
              ? null
              : selectedDistrict.value,
        ),
        FilterField.dropdown(
          'region',
          'Region',
          availableRegions,
          initialValue: selectedRegion.value.isEmpty
              ? null
              : selectedRegion.value,
        ),
        FilterField.boolean(
          'emergency_only',
          'Emergency contacts only',
          initialValue: showEmergencyOnly.value,
        ),
        FilterField.boolean(
          'active_only',
          'Active contacts only',
          initialValue: showActiveOnly.value,
        ),
      ],
      initialValues: {
        'search': searchQuery.value.isEmpty ? null : searchQuery.value,
        'ministry': selectedMinistry.value.isEmpty
            ? null
            : selectedMinistry.value,
        'district': selectedDistrict.value.isEmpty
            ? null
            : selectedDistrict.value,
        'region': selectedRegion.value.isEmpty ? null : selectedRegion.value,
        'emergency_only': showEmergencyOnly.value,
        'active_only': showActiveOnly.value,
      },
    );

    if (result != null && result.hasValues) {
      _applyAdvancedFilters(result.values);
    }
  }

  /// Apply advanced filters from bottom sheet
  void _applyAdvancedFilters(Map<String, dynamic> filters) {
    // Search query
    searchQuery.value = filters['search'] as String? ?? '';

    // Ministry filter
    selectedMinistry.value = filters['ministry'] as String? ?? '';

    // District filter
    selectedDistrict.value = filters['district'] as String? ?? '';

    // Region filter
    selectedRegion.value = filters['region'] as String? ?? '';

    // Boolean filters
    showEmergencyOnly.value = filters['emergency_only'] as bool? ?? false;
    showActiveOnly.value = filters['active_only'] as bool? ?? true;

    _updateActiveFiltersState();
    _refreshList();
  }

  /// Reset all filters
  void resetFilters() {
    selectedMinistry.value = '';
    selectedDistrict.value = '';
    selectedRegion.value = '';
    selectedDepartment.value = '';
    selectedStatus.value = '';
    showEmergencyOnly.value = false;
    showActiveOnly.value = true;
    searchQuery.value = '';
    treeFilters.clear();

    _updateActiveFiltersState();
    _refreshList();
  }

  /// Update active filters state
  void _updateActiveFiltersState() {
    hasActiveFilters.value =
        selectedMinistry.value.isNotEmpty ||
        selectedDistrict.value.isNotEmpty ||
        selectedRegion.value.isNotEmpty ||
        selectedDepartment.value.isNotEmpty ||
        selectedStatus.value.isNotEmpty ||
        showEmergencyOnly.value ||
        !showActiveOnly.value ||
        searchQuery.value.isNotEmpty;
  }

  /// Refresh the list
  void _refreshList() {
    pagingController.refresh();
  }

  /// Public method to refresh data
  void refreshData() {
    _refreshList();
  }

  /// Get active filters count
  int get activeFiltersCount {
    int count = 0;
    if (selectedMinistry.value.isNotEmpty) count++;
    if (selectedDistrict.value.isNotEmpty) count++;
    if (selectedRegion.value.isNotEmpty) count++;
    if (selectedDepartment.value.isNotEmpty) count++;
    if (selectedStatus.value.isNotEmpty) count++;
    if (showEmergencyOnly.value) count++;
    if (!showActiveOnly.value) count++;
    return count;
  }

  /// Get active filters summary
  String get activeFiltersSummary {
    final filters = <String>[];

    if (selectedMinistry.value.isNotEmpty) {
      filters.add(selectedMinistry.value);
    }
    if (selectedDistrict.value.isNotEmpty) {
      filters.add(selectedDistrict.value);
    }
    if (selectedRegion.value.isNotEmpty) {
      filters.add(selectedRegion.value);
    }
    if (selectedDepartment.value.isNotEmpty) {
      filters.add(selectedDepartment.value);
    }
    if (selectedStatus.value.isNotEmpty) {
      filters.add(selectedStatus.value.capitalizeFirst ?? selectedStatus.value);
    }
    if (showEmergencyOnly.value) {
      filters.add('Emergency Only');
    }
    if (!showActiveOnly.value) {
      filters.add('All Statuses');
    }

    return filters.join(', ');
  }

  void _applyTreeFiltersFromArguments() {
    final args = Get.arguments;
    if (args is! Map) return;

    final rawFilters = args['treeFilters'];
    if (rawFilters is! Map) return;

    final filters = Map<String, dynamic>.from(rawFilters);
    treeFilters.assignAll(filters);

    final ministry = _readString(filters, 'ministry');
    final district = _readString(filters, 'district');
    final region = _readString(filters, 'region');
    final department = _readString(filters, 'department');
    final status = _readString(filters, 'status');

    if (ministry.isNotEmpty) selectedMinistry.value = ministry;
    if (district.isNotEmpty) selectedDistrict.value = district;
    if (region.isNotEmpty) selectedRegion.value = region;
    if (department.isNotEmpty) selectedDepartment.value = department;
    if (status.isNotEmpty) selectedStatus.value = status;

    final emergency = filters['emergency_only'];
    if (emergency is bool && emergency) {
      showEmergencyOnly.value = true;
    }

    final priorityLevel = filters['priority_level'];
    if ((priorityLevel is num && priorityLevel == 1) ||
        priorityLevel?.toString() == '1') {
      showEmergencyOnly.value = true;
    }

    if (selectedStatus.value == 'active') {
      showActiveOnly.value = true;
    }

    _updateActiveFiltersState();
  }

  String _readString(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value == null) return '';
    return value.toString().trim();
  }
}
