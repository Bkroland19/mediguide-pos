import 'dart:convert';

import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:get/get.dart';

import '../../data/services/backend_service.dart';
import '../../translations/app_translations.dart';
import '../../utils/common.dart';
import 'models/tree_selector_models.dart';

class TreeSelectorController extends GetxController {
  final TreeSelectorConfig config;

  TreeSelectorController(this.config);

  late final TreeNode<TreeSelectorNodeModel> rootTreeNode;
  final RxBool isLoading = true.obs;
  final RxBool hasLoadError = false.obs;
  final RxMap<String, bool> loadingNodeKeys = <String, bool>{}.obs;

  @override
  void onInit() {
    super.onInit();
    rootTreeNode = TreeNode<TreeSelectorNodeModel>.root();
    loadRootNodes();
  }

  Future<void> loadRootNodes() async {
    isLoading.value = true;
    hasLoadError.value = false;

    try {
      rootTreeNode.clear();
      final nodes = await _fetchNodes(level: 0, filters: const {});
      for (final node in nodes) {
        rootTreeNode.add(_toTreeNode(node));
      }
    } catch (_) {
      hasLoadError.value = true;
      Common.quickToast(
        title: AppTranslationKey.error,
        description: 'failedToLoadData'.tr,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> onNodeTap(TreeNode<TreeSelectorNodeModel> node) async {
    final data = node.data;
    if (data == null) return;

    if (!data.hasChildren) {
      _selectNode(node);
      return;
    }

    await loadChildren(node);
  }

  void selectParentNode(TreeNode<TreeSelectorNodeModel> node) {
    if (!config.allowParentSelection) return;
    _selectNode(node);
  }

  Future<void> loadChildren(TreeNode<TreeSelectorNodeModel> node) async {
    final data = node.data;
    if (data == null || !data.hasChildren) return;
    if (node.childrenAsList.isNotEmpty) return;

    loadingNodeKeys[node.key] = true;
    try {
      final children = await _fetchNodes(
        level: data.level + 1,
        filters: data.filters,
      );
      for (final child in children) {
        node.add(_toTreeNode(child));
      }
    } catch (_) {
      Common.quickToast(
        title: AppTranslationKey.error,
        description: 'errorLoadingMore'.tr,
      );
    } finally {
      loadingNodeKeys.remove(node.key);
    }
  }

  bool isNodeLoading(TreeNode<TreeSelectorNodeModel> node) {
    return loadingNodeKeys[node.key] == true;
  }

  void _selectNode(TreeNode<TreeSelectorNodeModel> node) {
    final data = node.data;
    if (data == null) return;

    Get.back(
      result: TreeSelectionResult(
        selectedNode: data,
        filters: Map<String, dynamic>.from(data.filters),
      ),
    );
  }

  TreeNode<TreeSelectorNodeModel> _toTreeNode(TreeSelectorNodeModel model) {
    return TreeNode<TreeSelectorNodeModel>(
      key: '${model.level}-${model.id}',
      data: model,
    );
  }

  Future<List<TreeSelectorNodeModel>> _fetchNodes({
    required int level,
    required Map<String, dynamic> filters,
  }) async {
    final query = <String, dynamic>{
      'level': level.toString(),
      if (filters.isNotEmpty) 'filters': jsonEncode(filters),
      if (config.context.isNotEmpty) 'context': jsonEncode(config.context),
    };

    final response = await BackendService.to.getCustomEndpoint(
      path: config.endpointPath,
      query: query,
    );

    if (response['success'] == false) {
      throw Exception(response['error'] ?? 'Unknown error');
    }

    final dynamic data =
        response['data'] ?? response['nodes'] ?? response['items'];
    if (data is! List) return const <TreeSelectorNodeModel>[];

    return data
        .whereType<Map>()
        .map(
          (item) =>
              TreeSelectorNodeModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }
}
