import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../translations/app_translations.dart';
import '../../utils/loading.dart';
import '../../widgets/empty_state.dart';
import 'models/tree_selector_models.dart';
import 'tree_selector_controller.dart';
import 'widgets/tree_selector_tile.dart';

class TreeSelectorPage extends StatelessWidget {
  final String controllerTag;

  const TreeSelectorPage({super.key, required this.controllerTag});

  static Future<TreeSelectionResult?> show({
    required TreeSelectorConfig config,
  }) async {
    final tag = 'tree_selector_${DateTime.now().microsecondsSinceEpoch}';
    Get.put<TreeSelectorController>(TreeSelectorController(config), tag: tag);

    final result = await Get.dialog<TreeSelectionResult>(
      Dialog.fullscreen(child: TreeSelectorPage(controllerTag: tag)),
      barrierDismissible: config.barrierDismissible,
    );

    Get.delete<TreeSelectorController>(tag: tag);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TreeSelectorController>(tag: controllerTag);

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.config.title),
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(LucideIcons.x),
          tooltip: AppTranslationKey.close,
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value &&
            controller.rootTreeNode.childrenAsList.isEmpty) {
          return const CenteredLoading(loading: Loading.large());
        }

        if (controller.hasLoadError.value &&
            controller.rootTreeNode.childrenAsList.isEmpty) {
          return EmptyState.error(
            title: 'failedToLoadData'.tr,
            description: 'pleaseCheckConnectionAndTryAgain'.tr,
            actionLabel: AppTranslationKey.retry,
            onAction: controller.loadRootNodes,
          );
        }

        if (controller.rootTreeNode.childrenAsList.isEmpty) {
          return EmptyState.noData(
            title: 'noItemsFound'.tr,
            description: 'guidelinesWillAppearHere'.tr,
            actionLabel: AppTranslationKey.retry,
            onAction: controller.loadRootNodes,
          );
        }

        return TreeView.simpleTyped<
          TreeSelectorNodeModel,
          TreeNode<TreeSelectorNodeModel>
        >(
          tree: controller.rootTreeNode,
          showRootNode: false,
          indentation: const Indentation(style: IndentStyle.squareJoint),
          expansionBehavior: ExpansionBehavior.collapseOthers,
          onItemTap: controller.onNodeTap,
          builder: (context, node) => TreeSelectorTile(
            node: node,
            isNodeLoading: controller.isNodeLoading(node),
            showParentSelectAction:
                controller.config.allowParentSelection &&
                node.data?.hasChildren == true,
            onSelectParent: () => controller.selectParentNode(node),
          ),
        );
      }),
    );
  }
}
