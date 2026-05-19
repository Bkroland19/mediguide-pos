import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import '../../data/models/models.dart';
import '../../data/models/filter_models.dart';
import '../../data/services/backend_service.dart';
import '../../utils/common.dart';
import '../../utils/constants.dart';
import '../../widgets/generic_filter_bottom_sheet.dart';

class ToolsController extends GetxController {
  // Dependencies
  final BackendService _pbService = BackendService.to;

  // Controllers
  late final PagingController<int, Calculator> pagingController;

  // Filter state
  final hasActiveFilters = false.obs;
  final searchQuery = ''.obs;
  final selectedTypes = <CalculatorType>[].obs;
  final selectedStatuses = <CalculatorStatus>[].obs;
  final selectedTabIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _initializePagingController();
    _handleNavigationArguments();
  }

  /// Handle navigation arguments for initial tab selection
  void _handleNavigationArguments() {
    final args = Get.arguments;
    if (args is Map<String, dynamic> && args.containsKey('initialTab')) {
      final initialTab = args['initialTab'] as int?;
      if (initialTab != null && initialTab >= 0 && initialTab <= 3) {
        selectedTabIndex.value = initialTab;
        _updateActiveFiltersState();
      }
    }
  }

  /// Initialize the paging controller with v5 constructor API
  void _initializePagingController() {
    pagingController = PagingController<int, Calculator>(
      getNextPageKey: (state) =>
          state.lastPageIsEmpty ? null : state.nextIntPageKey,
      fetchPage: (pageKey) => _fetchPage(pageKey),
    );
  }

  @override
  void onClose() {
    pagingController.dispose();
    super.onClose();
  }

  /// Fetch calculators from backend
  Future<List<Calculator>> _fetchPage(int pageKey) async {
    try {
      final filters = <String>[];

      // Search filter
      if (searchQuery.value.isNotEmpty) {
        filters.add(
          'name ~ "${searchQuery.value}" || description ~ "${searchQuery.value}"',
        );
      }

      // Tab-based type filter (primary)
      if (selectedTabIndex.value > 0) {
        final tabType = _getTabType(selectedTabIndex.value);
        if (tabType != null) {
          filters.add('type = "${_typeToString(tabType)}"');
        }
      }

      // Additional type filters from filter modal
      if (selectedTypes.isNotEmpty) {
        final typeFilters = selectedTypes
            .map((type) => 'type = "${_typeToString(type)}"')
            .join(' || ');
        filters.add('($typeFilters)');
      }

      // Status filters
      if (selectedStatuses.isNotEmpty) {
        final statusFilters = selectedStatuses
            .map((status) => 'status = "${_statusToString(status)}"')
            .join(' || ');
        filters.add('($statusFilters)');
      }

      // Only show active calculators by default unless status filter is applied
      if (selectedStatuses.isEmpty) {
        filters.add('status = "active"');
      }

      final filterString = filters.isNotEmpty ? filters.join(' && ') : '';

      final calculators = await getCalculators(
        page: pageKey,
        perPage: pageSize,
        filter: filterString,
        sort: '-created',
        expand: 'addedBy',
      );

      return calculators;
    } catch (error) {
      Common.quickToast(title: 'Failed to load calculators');
      rethrow;
    }
  }

  /// Refresh data
  void refreshData() {
    pagingController.refresh();
  }

  /// Handle tab change
  void onTabChanged(int index) {
    selectedTabIndex.value = index;
    _updateActiveFiltersState();
    pagingController.refresh();
  }

  /// Show filter modal using generic filter bottom sheet
  Future<void> showFilterModal(BuildContext context) async {
    final fields = <FilterField>[
      FilterField.text('search', 'Search', hint: 'Search calculators'),
    ];

    // Calculator type multi-select
    final typeValues = CalculatorType.values.map((type) => type.name).toList();
    fields.add(FilterField.multiSelect('types', 'Calculator Type', typeValues));

    // Status multi-select
    final statusValues = CalculatorStatus.values
        .map((status) => status.name)
        .toList();
    fields.add(FilterField.multiSelect('statuses', 'Status', statusValues));

    // Get initial values
    final values = <String, dynamic>{};
    if (searchQuery.value.isNotEmpty) {
      values['search'] = searchQuery.value;
    }
    if (selectedTypes.isNotEmpty) {
      values['types'] = selectedTypes.map((t) => t.name).toList();
    }
    if (selectedStatuses.isNotEmpty) {
      values['statuses'] = selectedStatuses.map((s) => s.name).toList();
    }

    if (!context.mounted) return;

    final result = await GenericFilterBottomSheet.show(
      context: context,
      title: 'Filter Calculators',
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
    selectedTypes.clear();
    selectedStatuses.clear();

    // Apply new filters
    final search = result.getValue<String>('search');
    if (search != null && search.isNotEmpty) {
      searchQuery.value = search;
    }

    final typesList = result.getValue<List>('types');
    if (typesList != null && typesList.isNotEmpty) {
      selectedTypes.addAll(
        typesList.cast<String>().map(
          (name) => CalculatorType.values.firstWhere((t) => t.name == name),
        ),
      );
    }

    final statusesList = result.getValue<List>('statuses');
    if (statusesList != null && statusesList.isNotEmpty) {
      selectedStatuses.addAll(
        statusesList.cast<String>().map(
          (name) => CalculatorStatus.values.firstWhere((s) => s.name == name),
        ),
      );
    }

    _updateActiveFiltersState();
    pagingController.refresh();
  }

  /// Clear all filters
  void clearAllFilters() {
    searchQuery.value = '';
    selectedTypes.clear();
    selectedStatuses.clear();
    selectedTabIndex.value = 0;
    _updateActiveFiltersState();
    refreshData();
  }

  /// Update active filters state
  void _updateActiveFiltersState() {
    hasActiveFilters.value =
        searchQuery.value.isNotEmpty ||
        selectedTypes.isNotEmpty ||
        selectedStatuses.isNotEmpty ||
        selectedTabIndex.value > 0;
  }

  /// Get calculator type for tab index
  CalculatorType? _getTabType(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return CalculatorType.calculator;
      case 2:
        return CalculatorType.decisionTool;
      case 3:
        return CalculatorType.checklist;
      default:
        return null; // All tab
    }
  }

  // Helper methods for enum conversion
  String _typeToString(CalculatorType type) {
    switch (type) {
      case CalculatorType.calculator:
        return 'calculator';
      case CalculatorType.decisionTool:
        return 'decision_tool';
      case CalculatorType.checklist:
        return 'checklist';
    }
  }

  String _statusToString(CalculatorStatus status) {
    switch (status) {
      case CalculatorStatus.active:
        return 'active';
      case CalculatorStatus.draft:
        return 'draft';
      case CalculatorStatus.archived:
        return 'archived';
    }
  }

  // ==================== CALCULATOR-SPECIFIC METHODS ====================

  /// Get calculators with optional filtering and pagination
  Future<List<Calculator>> getCalculators({
    int page = 1,
    int perPage = 30,
    String? filter,
    String? sort,
    String? expand,
  }) async {
    final result = await _pbService.getRecordList(
      collectionName: Calculator.collection,
      page: page,
      perPage: perPage,
      filter: filter,
      sort: sort,
      expand: expand,
    );
    return result.items.map((record) => Calculator.fromRecord(record)).toList();
  }

  /// Create a new calculator
  Future<Calculator> createCalculator(
    Map<String, dynamic> calculatorData,
  ) async {
    final record = await _pbService.createRecord(
      collectionName: Calculator.collection,
      data: calculatorData,
    );
    return Calculator.fromRecord(record);
  }

  /// Update an existing calculator
  Future<Calculator> updateCalculator(
    String calculatorId,
    Map<String, dynamic> calculatorData,
  ) async {
    final record = await _pbService.updateRecord(
      collectionName: Calculator.collection,
      recordId: calculatorId,
      data: calculatorData,
    );
    return Calculator.fromRecord(record);
  }
}
