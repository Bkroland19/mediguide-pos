import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../data/models/abbreviation.dart';
import '../../../utils/app_spacing.dart';

/// Clean bottom sheet for abbreviation details — dictionary style, no cards.
class AbbreviationDetailModal extends StatelessWidget {
  final Abbreviation abbreviation;

  const AbbreviationDetailModal({super.key, required this.abbreviation});

  static Future<void> show(BuildContext context, Abbreviation abbreviation) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => AbbreviationDetailModal(
          abbreviation: abbreviation,
        )._buildContent(context, scrollController),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ScrollController scrollController,
  ) {
    final cs = context.theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Hero abbreviation
          Text(
            abbreviation.displayAbbreviation,
            style: context.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.primary,
              letterSpacing: 1,
            ),
          ),
          if (abbreviation.isCommon) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(LucideIcons.star, size: 12, color: cs.primary),
                const SizedBox(width: 4),
                Text(
                  'commonlyUsedAbbreviation'.tr,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          AppSpacing.gapLg,

          // Meaning
          Text(
            abbreviation.meaning,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),

          // Description
          if (abbreviation.hasDescription) ...[
            AppSpacing.gapMd,
            Text(
              abbreviation.description,
              style: context.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],

          // Category & tags
          if (abbreviation.hasCategory || abbreviation.hasTags) ...[
            AppSpacing.gapLg,
            Divider(color: cs.outlineVariant.withValues(alpha: 0.3)),
            AppSpacing.gapSm,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (abbreviation.hasCategory)
                  _tag(
                    context,
                    abbreviation.category!.displayName,
                    LucideIcons.folder,
                    cs.primary,
                  ),
                ...abbreviation.tags.map(
                  (tag) => _tag(
                    context,
                    tag.displayName,
                    LucideIcons.tag,
                    cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],

          AppSpacing.gapXl,
        ],
      ),
    );
  }

  Widget _tag(BuildContext context, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
