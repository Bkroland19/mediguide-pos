import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../translations/app_translations.dart';
import '../../utils/app_spacing.dart';
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

    try {
      return await Get.dialog<TreeSelectionResult>(
        Dialog.fullscreen(child: TreeSelectorPage(controllerTag: tag)),
        barrierDismissible: config.barrierDismissible,
      );
    } finally {
      if (Get.isRegistered<TreeSelectorController>(tag: tag)) {
        Get.delete<TreeSelectorController>(tag: tag);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TreeSelectorController>(tag: controllerTag);

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.config.title),
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          tooltip: AppTranslationKey.close.tr,
          onPressed: Get.back,
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          final hasNodes = controller.rootTreeNode.childrenAsList.isNotEmpty;

          if (controller.isLoading.value && !hasNodes) {
            return const CenteredLoading(loading: Loading.large());
          }

          if (controller.hasLoadError.value && !hasNodes) {
            return EmptyState.error(
              title: 'failedToLoadData'.tr,
              description: 'pleaseCheckConnectionAndTryAgain'.tr,
              actionLabel: AppTranslationKey.retry.tr,
              onAction: controller.loadRootNodes,
            );
          }

          if (!hasNodes) {
            return EmptyState.noData(
              title: 'noItemsFound'.tr,
              description: 'guidelinesWillAppearHere'.tr,
              actionLabel: AppTranslationKey.retry.tr,
              onAction: controller.loadRootNodes,
            );
          }

          return RefreshIndicator(
            onRefresh: controller.loadRootNodes,
            child:
                TreeView.simpleTyped<
                  TreeSelectorNodeModel,
                  TreeNode<TreeSelectorNodeModel>
                >(
                  tree: controller.rootTreeNode,
                  showRootNode: false,
                  indentation: const Indentation(
                    style: IndentStyle.squareJoint,
                  ),
                  expansionBehavior: ExpansionBehavior.collapseOthers,
                  onItemTap: controller.onNodeTap,
                  builder: (context, node) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: Obx(() {
                        final data = node.data;

                        return TreeSelectorTile(
                          node: node,
                          isNodeLoading: controller.isNodeLoading(node),
                          showParentSelectAction:
                              controller.config.allowParentSelection &&
                              data?.hasChildren == true,
                          onSelectParent: () =>
                              controller.selectParentNode(node),
                        );
                      }),
                    );
                  },
                ),
          );
        }),
      ),
    );
  }
}
