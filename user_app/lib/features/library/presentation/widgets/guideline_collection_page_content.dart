part of '../screens/guideline_collection_page.dart';

class _CollectionHeader extends StatelessWidget {
  const _CollectionHeader({required this.collection, required this.itemCount});

  final GuidelineCollectionSummary collection;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(child: Icon(LucideIcons.folderOpen)),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (collection.description.trim().isNotEmpty) ...[
                    AppSpacing.gapXs,
                    Text(collection.description),
                  ],
                  AppSpacing.gapSm,
                  Text(
                    '$itemCount ${itemCount == 1 ? 'guideline' : 'guidelines'}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
