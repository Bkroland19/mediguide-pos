import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../utils/responsive.dart';
import '../models/tree_selector_models.dart';

class TreeSelectorTile extends StatelessWidget {
  final TreeNode<TreeSelectorNodeModel> node;
  final bool isNodeLoading;
  final bool showParentSelectAction;
  final VoidCallback? onSelectParent;

  const TreeSelectorTile({
    super.key,
    required this.node,
    this.isNodeLoading = false,
    this.showParentSelectAction = false,
    this.onSelectParent,
  });

  @override
  Widget build(BuildContext context) {
    final data = node.data!;
    final hasChildren = data.hasChildren;
    final countText = data.count > 0 ? '${data.count}' : '';

    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: context.responsiveHorizontalPadding,
        vertical: 6,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: hasChildren
              ? context.theme.colorScheme.primaryContainer
              : context.theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          hasChildren ? LucideIcons.folderTree : LucideIcons.fileText,
          size: 20,
          color: hasChildren
              ? context.theme.colorScheme.primary
              : context.theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        data.title,
        style: context.textTheme.titleMedium?.copyWith(
          fontWeight: hasChildren ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      subtitle: data.subtitle.isNotEmpty || countText.isNotEmpty
          ? Text(
              [
                data.subtitle,
                if (countText.isNotEmpty) '$countText items',
              ].where((item) => item.isNotEmpty).join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: isNodeLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : showParentSelectAction
          ? IconButton(
              onPressed: onSelectParent,
              tooltip: 'done'.tr,
              icon: const Icon(LucideIcons.check),
            )
          : (!hasChildren
                ? Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: context.theme.colorScheme.onSurfaceVariant,
                  )
                : null),
    );
  }
}
