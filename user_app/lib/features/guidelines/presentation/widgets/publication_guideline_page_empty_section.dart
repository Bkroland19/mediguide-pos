import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:user_app/core/constants/app_spacing.dart';
import 'package:user_app/features/guidelines/data/models/guideline_publication.dart';

class PublicationEmptyReviewedSection extends StatelessWidget {
  const PublicationEmptyReviewedSection({
    super.key,
    required this.hasOriginalDocument,
    required this.reviewedDescendants,
    required this.onSection,
    required this.onOpenOriginal,
  });

  final bool hasOriginalDocument;
  final List<PublicationSection> reviewedDescendants;
  final ValueChanged<String> onSection;
  final VoidCallback onOpenOriginal;

  @override
  Widget build(BuildContext context) {
    if (reviewedDescendants.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reviewed content in this chapter',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          AppSpacing.gapXs,
          const Text(
            'This is a container section. Continue to a reviewed subsection.',
          ),
          AppSpacing.gapSm,
          for (final section in reviewedDescendants)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(section.title),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => onSection(section.id),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: const Key('empty-reviewed-block-count'),
          '0 reviewed blocks',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        AppSpacing.gapXs,
        Text(
          key: const Key('empty-reviewed-section-message'),
          hasOriginalDocument
              ? 'No approved structured content is available for this section.'
              : 'This section has not yet been published as reviewed content.',
        ),
        if (hasOriginalDocument) ...[
          AppSpacing.gapSm,
          OutlinedButton.icon(
            key: const Key('open-original-document'),
            onPressed: onOpenOriginal,
            icon: const Icon(LucideIcons.fileText),
            label: const Text('Open original document'),
          ),
        ],
      ],
    );
  }
}
