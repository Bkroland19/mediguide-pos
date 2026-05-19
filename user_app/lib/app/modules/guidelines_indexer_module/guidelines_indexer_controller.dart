import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:animated_tree_view/tree_view/tree_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:user_app/app/data/models/guideline_index.dart';
import 'package:user_app/app/data/models/filter_models.dart';
import 'package:user_app/app/data/services/backend_service.dart';
import 'package:user_app/app/translations/app_translations.dart';
import 'package:user_app/app/widgets/generic_filter_bottom_sheet.dart';

class GuidelinesIndexerController extends GetxController {
  late TreeViewController<GuidelineIndex, TreeNode<GuidelineIndex>>
  treeController;
  late TreeNode<GuidelineIndex> rootTreeNode;
  late TreeNode<GuidelineIndex> filteredTreeNode;
  String? channel;
  final RxBool isLoading = true.obs;

  // Search and filter state
  final RxString searchQuery = ''.obs;
  final RxBool hasActiveFilters = false.obs;
  final RxString selectedLevel = ''.obs;
  final RxBool showOnlyParents = false.obs;

  // All records for filtering
  List<GuidelineIndex> allRecords = [];

  @override
  void onInit() {
    super.onInit();
    rootTreeNode = TreeNode<GuidelineIndex>.root();
    filteredTreeNode = TreeNode<GuidelineIndex>.root();
    final args = Get.arguments as Map<String, dynamic>?;
    channel = args?['channel'];
    loadAllData();
  }

  void initializeTreeController(
    TreeViewController<GuidelineIndex, TreeNode<GuidelineIndex>> controller,
  ) {
    treeController = controller;
  }

  Future<void> loadAllData() async {
    isLoading.value = true;
    try {
      // Use offline-first approach with large batch size for tree data
      var result = await BackendService.to.getRecordList(
        collectionName: 'guideline_index',
        page: 1,
        perPage: 500, // Large batch for hierarchical data
        sort: 'level,order',
      );
      allRecords = result.items.map(GuidelineIndex.fromRecord).toList();

      if (allRecords.isEmpty) {
        isLoading.value = false;
        return;
      }

      var rootRecord = channel != null
          ? allRecords.cast<GuidelineIndex?>().firstWhere(
              (r) =>
                  r?.level == 0 &&
                  r!.title.toLowerCase().contains(channel!.toLowerCase()),
              orElse: () => null,
            )
          : null;

      rootRecord ??= allRecords.cast<GuidelineIndex?>().firstWhere(
        (r) => r?.level == 0,
        orElse: () => null,
      );

      if (rootRecord == null) {
        isLoading.value = false;
        return;
      }

      _buildInitialTree(rootRecord);
      _applyCurrentFilters();

      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
    }
  }

  List<GuidelineIndex> _getHierarchy(
    String rootId,
    List<GuidelineIndex> allRecords,
  ) {
    List<GuidelineIndex> result = [];
    List<String> parentIds = [rootId];

    while (parentIds.isNotEmpty) {
      var children = allRecords
          .where((r) => parentIds.contains(r.parentId))
          .toList();
      result.addAll(children);
      parentIds = children.map((c) => c.id).toList();
    }

    return result;
  }

  void _buildInitialTree(GuidelineIndex rootRecord) {
    // Clear existing trees
    rootTreeNode.clear();
    filteredTreeNode.clear();

    var hierarchyRecords = _getHierarchy(rootRecord.id, allRecords);
    var level1Records = hierarchyRecords.where(
      (r) => r.parentId == rootRecord.id && r.level == 1,
    );

    for (var record in level1Records) {
      rootTreeNode.add(_buildTree(record, hierarchyRecords));
    }
  }

  TreeNode<GuidelineIndex> _buildTree(
    GuidelineIndex record,
    List<GuidelineIndex> allRecords,
  ) {
    var node = TreeNode<GuidelineIndex>(key: record.id, data: record);
    var children = allRecords.where((r) => r.parentId == record.id);

    for (var child in children) {
      node.add(_buildTree(child, allRecords));
    }

    return node;
  }

  /// Show filter bottom sheet for guidelines search
  Future<void> showFilterBottomSheet(BuildContext context) async {
    if (!context.mounted) return;

    // Prepare filter fields
    final fields = [
      FilterField.text(
        'search',
        AppTranslationKey.searchGuidelines,
        hint: AppTranslationKey.searchGuidelinesHint,
      ),
      FilterField.dropdown('level', AppTranslationKey.level, [
        '1',
        '2',
        '3',
        '4',
        '5',
      ]),
      FilterField.boolean('hasChildren', AppTranslationKey.showOnlyParents),
    ];

    // Prepare initial values
    final values = <String, dynamic>{};
    if (searchQuery.value.isNotEmpty) {
      values['search'] = searchQuery.value;
    }
    if (selectedLevel.value.isNotEmpty) {
      values['level'] = selectedLevel.value;
    }
    if (showOnlyParents.value) {
      values['hasChildren'] = showOnlyParents.value;
    }

    final result = await GenericFilterBottomSheet.show(
      context: context,
      title: AppTranslationKey.filterGuidelines,
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
    selectedLevel.value = '';
    showOnlyParents.value = false;

    // Apply new filters
    if (result.hasValue('search')) {
      searchQuery.value = result.getValue<String>('search') ?? '';
    }
    if (result.hasValue('level')) {
      selectedLevel.value = result.getValue<String>('level') ?? '';
    }
    if (result.hasValue('hasChildren')) {
      showOnlyParents.value = result.getValue<bool>('hasChildren') ?? false;
    }

    // Update active filter state
    _updateActiveFilterState();

    // Apply filters to tree
    _applyCurrentFilters();
  }

  /// Update the active filters state
  void _updateActiveFilterState() {
    hasActiveFilters.value =
        searchQuery.value.isNotEmpty ||
        selectedLevel.value.isNotEmpty ||
        showOnlyParents.value;
  }

  /// Apply current filters to the tree structure
  void _applyCurrentFilters() {
    filteredTreeNode.clear();

    if (!hasActiveFilters.value) {
      // No filters - copy original tree
      for (var child in rootTreeNode.childrenAsList) {
        final typedChild = child as TreeNode<GuidelineIndex>;
        filteredTreeNode.add(_copyNode(typedChild));
      }
      return;
    }

    // Apply filters
    for (var child in rootTreeNode.childrenAsList) {
      final typedChild = child as TreeNode<GuidelineIndex>;
      var filteredChild = _filterNode(typedChild);
      if (filteredChild != null) {
        filteredTreeNode.add(filteredChild);
      }
    }
  }

  /// Filter a single node and its children
  TreeNode<GuidelineIndex>? _filterNode(TreeNode<GuidelineIndex> node) {
    if (node.data == null) return null;

    final record = node.data!;
    bool matchesFilter = true;

    // Apply search filter
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      matchesFilter =
          record.title.toLowerCase().contains(query) ||
          record.description.toLowerCase().contains(query);
    }

    // Apply level filter
    if (selectedLevel.value.isNotEmpty && matchesFilter) {
      final targetLevel = int.tryParse(selectedLevel.value) ?? -1;
      matchesFilter = record.level == targetLevel;
    }

    // Apply hasChildren filter
    if (showOnlyParents.value && matchesFilter) {
      matchesFilter = record.hasChildren;
    }

    // Check children recursively
    List<TreeNode<GuidelineIndex>> filteredChildren = [];
    for (var child in node.childrenAsList) {
      final typedChild = child as TreeNode<GuidelineIndex>;
      var filteredChild = _filterNode(typedChild);
      if (filteredChild != null) {
        filteredChildren.add(filteredChild);
      }
    }

    // Include node if it matches or has matching children
    if (matchesFilter || filteredChildren.isNotEmpty) {
      var newNode = TreeNode<GuidelineIndex>(key: node.key, data: record);
      for (var child in filteredChildren) {
        newNode.add(child);
      }
      return newNode;
    }

    return null;
  }

  /// Create a deep copy of a tree node
  TreeNode<GuidelineIndex> _copyNode(TreeNode<GuidelineIndex> original) {
    var newNode = TreeNode<GuidelineIndex>(
      key: original.key,
      data: original.data,
    );

    for (var child in original.childrenAsList) {
      final typedChild = child as TreeNode<GuidelineIndex>;
      newNode.add(_copyNode(typedChild));
    }

    return newNode;
  }

  /// Reset all filters
  void resetFilters() {
    searchQuery.value = '';
    selectedLevel.value = '';
    showOnlyParents.value = false;
    _updateActiveFilterState();
    // Re-initialize everything fresh like page just opened
    loadAllData();
  }

  /// Get the current tree to display (filtered or original)
  TreeNode<GuidelineIndex> get currentTreeNode {
    return hasActiveFilters.value ? filteredTreeNode : rootTreeNode;
  }
}
