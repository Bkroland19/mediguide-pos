part of '../screens/guideline_collections_page.dart';

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.collection,
    required this.enabled,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final GuidelineCollectionSummary collection;
  final bool enabled;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final count = collection.itemCount;
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: enabled ? onOpen : null,
        contentPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        leading: const CircleAvatar(child: Icon(LucideIcons.folder)),
        title: Text(
          collection.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          collection.description.trim().isEmpty
              ? '$count ${count == 1 ? 'guideline' : 'guidelines'}'
              : '${collection.description}\n$count ${count == 1 ? 'guideline' : 'guidelines'}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: collection.description.trim().isNotEmpty,
        trailing: PopupMenuButton<_CollectionAction>(
          enabled: enabled,
          tooltip: 'Collection actions',
          onSelected: (action) {
            if (action == _CollectionAction.edit) onEdit();
            if (action == _CollectionAction.delete) onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: _CollectionAction.edit,
              child: ListTile(
                leading: Icon(LucideIcons.pencil),
                title: Text('Edit'),
              ),
            ),
            PopupMenuItem(
              value: _CollectionAction.delete,
              child: ListTile(
                leading: Icon(LucideIcons.trash2),
                title: Text('Delete'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CollectionAction { edit, delete }

class _EmptyCollections extends StatelessWidget {
  const _EmptyCollections({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: 80),
        Icon(
          LucideIcons.folderPlus,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        AppSpacing.gapMd,
        Text(
          'Organize your guidelines',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        AppSpacing.gapSm,
        const Text(
          'Create collections for topics, programmes or clinical workflows.',
          textAlign: TextAlign.center,
        ),
        AppSpacing.gapLg,
        Center(
          child: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(LucideIcons.plus),
            label: const Text('Create collection'),
          ),
        ),
      ],
    );
  }
}
