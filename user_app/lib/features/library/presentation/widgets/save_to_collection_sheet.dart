import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:user_app/core/constants/app_spacing.dart';
import 'package:user_app/core/utils/app_message.dart';
import 'package:user_app/core/widgets/app_error_view.dart';
import 'package:user_app/core/widgets/app_loading_view.dart';
import 'package:user_app/features/library/data/models/guideline_library_models.dart';
import 'package:user_app/features/library/presentation/controllers/guideline_collections_controller.dart';
import 'package:user_app/features/library/presentation/widgets/collection_form_sheet.dart';

Future<String?> showSaveToCollectionSheet(
  BuildContext context, {
  required String userId,
  required String guidelineId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) =>
        _SaveToCollectionSheet(userId: userId, guidelineId: guidelineId),
  );
}

class _SaveToCollectionSheet extends ConsumerStatefulWidget {
  const _SaveToCollectionSheet({
    required this.userId,
    required this.guidelineId,
  });

  final String userId;
  final String guidelineId;

  @override
  ConsumerState<_SaveToCollectionSheet> createState() =>
      _SaveToCollectionSheetState();
}

class _SaveToCollectionSheetState
    extends ConsumerState<_SaveToCollectionSheet> {
  String? _savingCollectionId;

  @override
  Widget build(BuildContext context) {
    final provider = guidelineCollectionsControllerProvider(widget.userId);
    final result = ref.watch(provider);
    return FractionallySizedBox(
      heightFactor: 0.72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Save to collection',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: _savingCollectionId == null
                      ? () => _createAndSave(context)
                      : null,
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('New'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: result.when(
              loading: () =>
                  const AppLoadingView(message: 'Loading collections...'),
              error: (error, _) => AppErrorView(
                error: error,
                message: 'Your collections could not be loaded.',
                onRetry: () => ref.read(provider.notifier).refresh(),
              ),
              data: (value) => value.items.isEmpty
                  ? _EmptyPicker(onCreate: () => _createAndSave(context))
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: value.items.length + (value.hasMore ? 1 : 0),
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        if (index == value.items.length) {
                          return Center(
                            child: TextButton(
                              onPressed: value.isLoadingMore
                                  ? null
                                  : () => _loadMore(context),
                              child: Text(
                                value.isLoadingMore
                                    ? 'Loading...'
                                    : 'Load more collections',
                              ),
                            ),
                          );
                        }
                        final collection = value.items[index];
                        return _CollectionOption(
                          collection: collection,
                          saving: _savingCollectionId == collection.id,
                          enabled: _savingCollectionId == null,
                          onTap: () => _save(context, collection),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    GuidelineCollectionSummary collection,
  ) async {
    setState(() => _savingCollectionId = collection.id);
    try {
      await ref
          .read(guidelineCollectionsControllerProvider(widget.userId).notifier)
          .addGuideline(collection.id, widget.guidelineId);
      if (context.mounted) Navigator.pop(context, collection.name);
    } catch (_) {
      if (!context.mounted) return;
      setState(() => _savingCollectionId = null);
      AppMessage.error(context, 'The guideline could not be saved.');
    }
  }

  Future<void> _createAndSave(BuildContext context) async {
    final value = await showCollectionFormSheet(context);
    if (value == null || !context.mounted) return;
    setState(() => _savingCollectionId = 'creating');
    try {
      final controller = ref.read(
        guidelineCollectionsControllerProvider(widget.userId).notifier,
      );
      final collection = await controller.create(
        name: value.name,
        description: value.description,
      );
      await controller.addGuideline(collection.id, widget.guidelineId);
      if (context.mounted) Navigator.pop(context, collection.name);
    } catch (_) {
      if (!context.mounted) return;
      setState(() => _savingCollectionId = null);
      AppMessage.error(
        context,
        'The collection or saved guideline could not be completed.',
      );
    }
  }

  Future<void> _loadMore(BuildContext context) async {
    try {
      await ref
          .read(guidelineCollectionsControllerProvider(widget.userId).notifier)
          .loadNextPage();
    } catch (_) {
      if (context.mounted) {
        AppMessage.error(context, 'More collections could not be loaded.');
      }
    }
  }
}

class _CollectionOption extends StatelessWidget {
  const _CollectionOption({
    required this.collection,
    required this.saving,
    required this.enabled,
    required this.onTap,
  });

  final GuidelineCollectionSummary collection;
  final bool saving;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(LucideIcons.folder)),
      title: Text(collection.name),
      subtitle: collection.description.trim().isEmpty
          ? Text(
              '${collection.itemCount} '
              '${collection.itemCount == 1 ? 'guideline' : 'guidelines'}',
            )
          : Text(
              collection.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: saving
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(LucideIcons.plus),
    );
  }
}

class _EmptyPicker extends StatelessWidget {
  const _EmptyPicker({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.folderPlus, size: 48),
            AppSpacing.gapMd,
            Text(
              'No collections yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            AppSpacing.gapSm,
            const Text(
              'Create your first collection and save this guideline to it.',
              textAlign: TextAlign.center,
            ),
            AppSpacing.gapMd,
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(LucideIcons.plus),
              label: const Text('Create collection'),
            ),
          ],
        ),
      ),
    );
  }
}
