import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:user_app/app/router/route_names.dart';
import 'package:user_app/core/constants/app_spacing.dart';
import 'package:user_app/core/utils/app_message.dart';
import 'package:user_app/core/widgets/app_error_view.dart';
import 'package:user_app/core/widgets/app_loading_view.dart';
import 'package:user_app/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:user_app/features/library/data/models/guideline_library_models.dart';
import 'package:user_app/features/library/presentation/controllers/guideline_collection_controller.dart';
import 'package:user_app/features/library/presentation/widgets/collection_form_sheet.dart';

part '../widgets/guideline_collection_page_content.dart';

class GuidelineCollectionPage extends ConsumerWidget {
  const GuidelineCollectionPage({super.key, required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(authControllerProvider)
        .when(
          loading: () => const Scaffold(
            body: AppLoadingView(message: 'Preparing your library...'),
          ),
          error: (error, _) => Scaffold(body: AppErrorView(error: error)),
          data: (auth) {
            final user = auth.user;
            if (user == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Collection')),
                body: const AppErrorView(
                  error: 'Authentication required',
                  title: 'Sign in required',
                  message: 'Sign in to view and manage this collection.',
                ),
              );
            }
            if (collectionId.trim().isEmpty) {
              return Scaffold(
                appBar: AppBar(title: const Text('Collection')),
                body: const AppErrorView(
                  error: 'Collection ID is missing',
                  title: 'Collection unavailable',
                  message: 'This collection link is incomplete.',
                ),
              );
            }
            return _CollectionView(userId: user.id, collectionId: collectionId);
          },
        );
  }
}

class _CollectionView extends ConsumerWidget {
  const _CollectionView({required this.userId, required this.collectionId});

  final String userId;
  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = guidelineCollectionControllerProvider(
      userId,
      collectionId,
    );
    final result = ref.watch(provider);
    final value = result.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          value?.collection.name ?? 'Collection',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Edit collection',
            onPressed: value == null || value.isMutating
                ? null
                : () => _edit(context, ref, value.collection),
            icon: const Icon(LucideIcons.pencil),
          ),
          PopupMenuButton<_DetailAction>(
            enabled: value != null && !value.isMutating,
            tooltip: 'Collection actions',
            onSelected: (action) {
              if (action == _DetailAction.delete) _delete(context, ref);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _DetailAction.delete,
                child: ListTile(
                  leading: Icon(LucideIcons.trash2),
                  title: Text('Delete collection'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: result.when(
        loading: () => const AppLoadingView(message: 'Loading collection...'),
        error: (error, _) => AppErrorView(
          error: error,
          message: 'This collection could not be loaded. Please try again.',
          onRetry: () => ref.read(provider.notifier).refresh(),
        ),
        data: (state) => RefreshIndicator(
          onRefresh: () => ref.read(provider.notifier).refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              _CollectionHeader(
                collection: state.collection,
                itemCount: state.totalItems,
              ),
              AppSpacing.gapLg,
              Text(
                'Saved guidelines',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              AppSpacing.gapSm,
              if (state.items.isEmpty)
                const _EmptyCollection()
              else
                for (final item in state.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _CollectionGuidelineCard(
                      item: item,
                      enabled: !state.isMutating,
                      onOpen: () => context.push(
                        AppRoutes.publicGuideline(item.guideline.id),
                      ),
                      onRemove: () => _remove(context, ref, item),
                    ),
                  ),
              if (state.hasMore) ...[
                AppSpacing.gapSm,
                Center(
                  child: OutlinedButton.icon(
                    onPressed: state.isLoadingMore
                        ? null
                        : () => _loadMore(context, ref),
                    icon: state.isLoadingMore
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.chevronDown),
                    label: Text(
                      state.isLoadingMore ? 'Loading...' : 'Load more',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    GuidelineCollectionSummary collection,
  ) async {
    final value = await showCollectionFormSheet(
      context,
      initialName: collection.name,
      initialDescription: collection.description,
    );
    if (value == null || !context.mounted) return;
    try {
      await ref
          .read(
            guidelineCollectionControllerProvider(
              userId,
              collectionId,
            ).notifier,
          )
          .updateCollection(name: value.name, description: value.description);
      if (context.mounted) AppMessage.success(context, 'Collection updated.');
    } catch (_) {
      if (context.mounted) {
        AppMessage.error(context, 'The collection could not be updated.');
      }
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    GuidelineCollectionItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove guideline?'),
        content: Text('Remove “${item.guideline.title}” from this collection?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(
            guidelineCollectionControllerProvider(
              userId,
              collectionId,
            ).notifier,
          )
          .removeItem(item.guideline.id);
      if (context.mounted) {
        AppMessage.success(context, 'Guideline removed from collection.');
      }
    } catch (_) {
      if (context.mounted) {
        AppMessage.error(context, 'The guideline could not be removed.');
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final name = ref
        .read(guidelineCollectionControllerProvider(userId, collectionId))
        .valueOrNull
        ?.collection
        .name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete collection?'),
        content: Text(
          'Delete “${name ?? 'this collection'}”? Saved guidelines will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(
            guidelineCollectionControllerProvider(
              userId,
              collectionId,
            ).notifier,
          )
          .delete();
      if (context.mounted) {
        AppMessage.success(context, 'Collection deleted.');
        context.pop();
      }
    } catch (_) {
      if (context.mounted) {
        AppMessage.error(context, 'The collection could not be deleted.');
      }
    }
  }

  Future<void> _loadMore(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(
            guidelineCollectionControllerProvider(
              userId,
              collectionId,
            ).notifier,
          )
          .loadNextPage();
    } catch (_) {
      if (context.mounted) {
        AppMessage.error(context, 'More guidelines could not be loaded.');
      }
    }
  }
}

class _CollectionGuidelineCard extends StatelessWidget {
  const _CollectionGuidelineCard({
    required this.item,
    required this.enabled,
    required this.onOpen,
    required this.onRemove,
  });

  final GuidelineCollectionItem item;
  final bool enabled;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final publication = item.guideline;
    final metadata = [
      publication.programArea.trim(),
      publication.sourceOrganization.trim(),
      if (publication.version.trim().isNotEmpty)
        'Version ${publication.version.trim()}',
    ].where((value) => value.isNotEmpty).join(' · ');
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        enabled: enabled,
        onTap: onOpen,
        contentPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        leading: const CircleAvatar(child: Icon(LucideIcons.bookOpen)),
        title: Text(
          publication.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: metadata.isEmpty
            ? null
            : Text(metadata, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          tooltip: 'Remove from collection',
          onPressed: enabled ? onRemove : null,
          icon: const Icon(LucideIcons.x),
        ),
      ),
    );
  }
}

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection();

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Icon(LucideIcons.bookPlus, size: 44),
            AppSpacing.gapMd,
            Text(
              'No guidelines saved yet',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            AppSpacing.gapSm,
            Text(
              'Open a published guideline and choose “Save to collection”.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

enum _DetailAction { delete }
