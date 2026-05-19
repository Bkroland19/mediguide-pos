import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:user_app/app/data/models/guideline_index.dart';
import 'package:user_app/app/routes/app_pages.dart';
import 'package:user_app/app/widgets/empty_state.dart';
import 'package:user_app/app/widgets/filter_button.dart';
import 'guidelines_indexer_controller.dart';
import 'widgets/guideline_tree_tile.dart';

class GuidelinesIndexerPage extends GetWidget<GuidelinesIndexerController> {
  const GuidelinesIndexerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          controller.channel?.toLowerCase().contains('red') == true
              ? 'Red Channel'
              : controller.channel?.toLowerCase().contains('blue') == true
              ? 'Blue Channel'
              : 'Guidelines Channel',
        ),
        actions: [
          FilterButton(
            hasActiveFilters: controller.hasActiveFilters,
            onPressed: () => controller.showFilterBottomSheet(context),
            onReset: controller.resetFilters,
          ),
        ],
      ),
      body: Obx(
        () => controller.isLoading.value
            ? const Center(child: CircularProgressIndicator())
            : controller.currentTreeNode.childrenAsList.isEmpty
            ? EmptyState.noData(
                title: 'No Guidelines Found',
                description:
                    'There are no guidelines available for ${controller.channel?.toLowerCase().contains('red') == true
                        ? 'Red Channel'
                        : controller.channel?.toLowerCase().contains('blue') == true
                        ? 'Blue Channel'
                        : 'Guidelines Channel'} at this time.',
                actionLabel: 'Refresh',
                onAction: () => controller.loadAllData(),
              )
            : TreeView.simpleTyped<GuidelineIndex, TreeNode<GuidelineIndex>>(
                tree: controller.currentTreeNode,
                showRootNode: false,
                onItemTap: (node) {
                  if (node.data?.hasChildren == false) {
                    Get.toNamed(AppRoutes.guidelines, arguments: node.data);
                  }
                },
                indentation: const Indentation(style: IndentStyle.squareJoint),
                onTreeReady: (treeController) {
                  controller.initializeTreeController(treeController);
                },
                expansionBehavior: ExpansionBehavior.collapseOthers,

                builder: (context, node) => GuidelineTreeTile(node: node),
              ),
      ),
    );
  }
}
