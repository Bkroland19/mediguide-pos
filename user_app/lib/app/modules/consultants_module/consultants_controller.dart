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
import 'widgets/consultant_detail_modal.dart';

class ConsultantsController extends GetxController {
  // Pagination controller
  late final PagingController<int, Consultant> pagingController;

  // Permanent tree filters from selector modal
  final RxMap<String, dynamic> treeFilters = <String, dynamic>{}.obs;

  // Search and filter state
  final RxString searchQuery = ''.obs;
  final RxBool hasActiveFilters = false.obs;
  final RxString selectedSpecialty = ''.obs;
  final RxString selectedLocation = ''.obs;
  final RxString selectedRegion = ''.obs;
  final RxString selectedCity = ''.obs;
  final RxBool showOnlineOnly = false.obs;
  final RxBool showVerifiedOnly = false.obs;

  // Available filter options
  final RxList<String> availableSpecialties = <String>[].obs;
  final RxList<String> availableLocations = <String>[].obs;
  final RxBool isLoadingFilters = false.obs;

  @override
  void onInit() {
    super.onInit();
    _applyTreeFiltersFromArguments();
    pagingController = PagingController<int, Consultant>(
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

  /// Load a page of consultants
  Future<List<Consultant>> _loadPage(int pageKey) async {
    try {
      final List<Consultant> newItems;

      // Build filter string for backend
      String filter = '';
      final filters = <String>[];

      // Status filter - always show active or pending approval
      filters.add('(status="active" || status="pendingApproval")');

      // Search query filter
      if (searchQuery.value.isNotEmpty) {
        filters.add(
          '(name~"${searchQuery.value}" || organization~"${searchQuery.value}" || specialty~"${searchQuery.value}")',
        );
      }

      // Specialty filter
      if (selectedSpecialty.value.isNotEmpty) {
        filters.add('specialty="${selectedSpecialty.value}"');
      }

      // Tree region filter
      if (selectedRegion.value.isNotEmpty) {
        filters.add('region="${selectedRegion.value}"');
      }

      // Tree city filter
      if (selectedCity.value.isNotEmpty) {
        filters.add('city="${selectedCity.value}"');
      }

      // Location filter
      if (selectedLocation.value.isNotEmpty) {
        filters.add(
          '(city~"${selectedLocation.value}" || region~"${selectedLocation.value}")',
        );
      }

      // Online only filter
      if (showOnlineOnly.value) {
        filters.add('status="active"');
      }

      // Verified only filter
      if (showVerifiedOnly.value) {
        filters.add('isVerified=true');
      }

      if (filters.isNotEmpty) {
        filter = filters.join(' && ');
      }

      // Load consultants with filters and expand user relation
      final result = await BackendService.to.getRecordList(
        collectionName: Consultant.collection,
        page: pageKey,
        perPage: pageSize,
        filter: filter.isNotEmpty ? filter : null,
        sort: '-rating,-totalConsultations',
        expand: 'user',
      );

      newItems = result.items
          .map((record) => Consultant.fromRecord(record))
          .toList();

      return newItems;
    } catch (error) {
      Common.quickToast(title: 'errorLoadingConsultants'.tr);
      rethrow;
    }
  }

  /// Load available filter options from existing consultants
  Future<void> _loadFilterOptions() async {
    try {
      isLoadingFilters.value = true;

      // Get all active consultants to extract filter options
      final result = await BackendService.to.getRecordList(
        collectionName: Consultant.collection,
        perPage: 100,
        filter: 'status="active"',
        expand: 'user',
      );

      final consultants = result.items
          .map((record) => Consultant.fromRecord(record))
          .toList();

      // Extract unique specialties
      final specialties = consultants
          .map(
            (c) => c.specialty?.toString().split('.').last ?? 'generalPractice',
          )
          .where((s) => s.isNotEmpty)
          .toSet()
          .map((s) => _getSpecialtyDisplayName(s))
          .toList();
      specialties.sort();
      availableSpecialties.value = specialties;

      // Extract unique locations (cities)
      final locations = consultants
          .map((c) => c.city)
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();
      locations.sort();
      availableLocations.value = locations;
    } catch (error) {
      Common.quickToast(title: 'errorLoadingFilters'.tr);
    } finally {
      isLoadingFilters.value = false;
    }
  }

  /// Search consultants
  void searchConsultants(String query) {
    searchQuery.value = query.trim();
    _updateHasActiveFilters();
    pagingController.refresh();
  }

  /// Clear all filters
  void clearAllFilters() {
    selectedSpecialty.value = '';
    selectedLocation.value = '';
    selectedRegion.value = '';
    selectedCity.value = '';
    showOnlineOnly.value = false;
    showVerifiedOnly.value = false;
    searchQuery.value = '';
    treeFilters.clear();
    _updateHasActiveFilters();
    pagingController.refresh();
  }

  /// Show filter modal using generic filter bottom sheet
  Future<void> showFilterModal(BuildContext context) async {
    // Ensure filter options are loaded
    if (availableSpecialties.isEmpty) {
      await _loadFilterOptions();
    }

    final fields = <FilterField>[
      FilterField.text('search', 'search'.tr, hint: 'searchConsultants'.tr),
      FilterField.boolean('showOnlineOnly', 'showOnlineOnly'.tr),
      FilterField.boolean('showVerifiedOnly', 'showVerifiedOnly'.tr),
    ];

    // Specialty dropdown
    if (availableSpecialties.isNotEmpty) {
      fields.add(
        FilterField.dropdown(
          'specialty',
          'specialty'.tr,
          [''] + availableSpecialties,
        ),
      );
    }

    // Location dropdown
    if (availableLocations.isNotEmpty) {
      fields.add(
        FilterField.dropdown(
          'location',
          'location'.tr,
          [''] + availableLocations,
        ),
      );
    }

    // Get initial values
    final values = <String, dynamic>{};
    if (searchQuery.value.isNotEmpty) values['search'] = searchQuery.value;
    if (showOnlineOnly.value) values['showOnlineOnly'] = true;
    if (showVerifiedOnly.value) values['showVerifiedOnly'] = true;
    if (selectedSpecialty.value.isNotEmpty) {
      values['specialty'] = selectedSpecialty.value;
    }
    if (selectedLocation.value.isNotEmpty) {
      values['location'] = selectedLocation.value;
    }

    if (!context.mounted) return;

    final result = await GenericFilterBottomSheet.show(
      context: context,
      title: 'filterConsultants'.tr,
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
    selectedSpecialty.value = '';
    selectedLocation.value = '';
    selectedRegion.value = '';
    selectedCity.value = '';
    showOnlineOnly.value = false;
    showVerifiedOnly.value = false;
    searchQuery.value = '';

    // Apply new filters
    final search = result.getValue<String>('search');
    if (search != null && search.isNotEmpty) {
      searchQuery.value = search;
    }

    final onlineOnly = result.getValue<bool>('showOnlineOnly');
    if (onlineOnly == true) {
      showOnlineOnly.value = true;
    }

    final verifiedOnly = result.getValue<bool>('showVerifiedOnly');
    if (verifiedOnly == true) {
      showVerifiedOnly.value = true;
    }

    final specialty = result.getValue<String>('specialty');
    if (specialty != null && specialty.isNotEmpty) {
      selectedSpecialty.value = specialty;
    }

    final location = result.getValue<String>('location');
    if (location != null && location.isNotEmpty) {
      selectedLocation.value = location;
    }

    _updateHasActiveFilters();
    pagingController.refresh();
  }

  /// Update hasActiveFilters based on current filter state
  void _updateHasActiveFilters() {
    hasActiveFilters.value =
        searchQuery.value.isNotEmpty ||
        selectedSpecialty.value.isNotEmpty ||
        selectedLocation.value.isNotEmpty ||
        selectedRegion.value.isNotEmpty ||
        selectedCity.value.isNotEmpty ||
        showOnlineOnly.value ||
        showVerifiedOnly.value;
  }

  void _applyTreeFiltersFromArguments() {
    final args = Get.arguments;
    if (args is! Map) return;

    final rawFilters = args['treeFilters'];
    if (rawFilters is! Map) return;

    final filters = Map<String, dynamic>.from(rawFilters);
    treeFilters.assignAll(filters);

    final region = _readString(filters, 'region');
    final city = _readString(filters, 'city');
    final specialty = _readString(filters, 'specialty');
    final location = city.isNotEmpty ? city : region;

    if (specialty.isNotEmpty) selectedSpecialty.value = specialty;
    if (region.isNotEmpty) selectedRegion.value = region;
    if (city.isNotEmpty) selectedCity.value = city;
    if (location.isNotEmpty) selectedLocation.value = location;

    final verified = filters['verified'];
    if ((verified is bool && verified) ||
        verified?.toString().toLowerCase() == 'true' ||
        verified?.toString() == '1') {
      showVerifiedOnly.value = true;
    }

    _updateHasActiveFilters();
  }

  String _readString(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value == null) return '';
    return value.toString().trim();
  }

  /// Get display name for specialty enum value
  String _getSpecialtyDisplayName(String enumValue) {
    switch (enumValue) {
      case 'generalPractice':
        return 'General Practice';
      case 'internalMedicine':
        return 'Internal Medicine';
      case 'emergencyMedicine':
        return 'Emergency Medicine';
      case 'infectiousDiseases':
        return 'Infectious Diseases';
      case 'publicHealth':
        return 'Public Health';
      case 'laboratoryMedicine':
        return 'Laboratory Medicine';
      default:
        // Convert enum name to Title Case
        return enumValue[0].toUpperCase() + enumValue.substring(1);
    }
  }

  /// Show consultant detail with usage tracking
  Future<void> showConsultantDetail(
    BuildContext context,
    Consultant consultant,
  ) async {
    // Track consultant usage
    _trackConsultantUsage(consultant.id);

    // Show detail modal
    await ConsultantDetailModal.show(context, consultant);
  }

  /// Track consultant usage
  Future<void> _trackConsultantUsage(String consultantId) async {
    try {
      if (AuthService.to.currentUser.value == null) return;

      // Create consultant usage log
      final logData = ConsultantUsageLog.forCreate(
        userId: AuthService.to.currentUser.value!.id,
        consultantId: consultantId,
      );

      await BackendService.to.createRecord(
        collectionName: ConsultantUsageLog.collection,
        data: logData,
      );

      // Increment consultant usage count
      await BackendService.to.incrementUsageCount(
        Consultant.collection,
        consultantId,
      );
    } catch (e) {
      // Handle error silently to not disrupt user experience
    }
  }
}
