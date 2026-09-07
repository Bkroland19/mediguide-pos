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
import 'package:user_app/features/library/presentation/controllers/guideline_collections_controller.dart';
import 'package:user_app/features/library/presentation/widgets/collection_form_sheet.dart';

part '../widgets/guideline_collections_page_content.dart';

class GuidelineCollectionsPage extends ConsumerWidget {
  const GuidelineCollectionsPage({super.key});

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
            if (user != null) return _CollectionsView(userId: user.id);
            return Scaffold(
              appBar: AppBar(title: const Text('Collections')),
              body: const AppErrorView(
                error: 'Authentication required',
                title: 'Sign in required',
                message:
                    'Sign in to create and sync your guideline collections.',
              ),
            );
          },
        );
  }
}

class _CollectionsView extends ConsumerWidget {
  const _CollectionsView({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = guidelineCollectionsControllerProvider(userId);
    final collections = ref.watch(provider);
    final state = collections.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collections'),
        actions: [
          IconButton(
            tooltip: 'Create collection',
            onPressed: state?.isMutating == true
                ? null
                : () => _createCollection(context, ref),
            icon: const Icon(LucideIcons.folderPlus),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state?.isMutating == true
            ? null
            : () => _createCollection(context, ref),
        icon: const Icon(LucideIcons.plus),
        label: const Text('New collection'),
      ),
      body: collections.when(
        loading: () => const AppLoadingView(message: 'Loading collections...'),
        error: (error, _) => AppErrorView(
          error: error,
          message: 'Your collections could not be loaded. Please try again.',
          onRetry: () => ref.read(provider.notifier).refresh(),
        ),
        data: (value) => RefreshIndicator(
          onRefresh: () => ref.read(provider.notifier).refresh(),
          child: value.items.isEmpty
              ? _EmptyCollections(
                  onCreate: () => _createCollection(context, ref),
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    96,
                  ),
                  itemCount: value.items.length + (value.hasMore ? 1 : 0),
                  separatorBuilder: (_, _) => AppSpacing.gapSm,
                  itemBuilder: (context, index) {
                    if (index == value.items.length) {
                      return Center(
                        child: OutlinedButton.icon(
                          onPressed: value.isLoadingMore
                              ? null
                              : () => _loadMore(context, ref),
                          icon: value.isLoadingMore
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(LucideIcons.chevronDown),
                          label: Text(
                            value.isLoadingMore ? 'Loading...' : 'Load more',
                          ),
                        ),
                      );
                    }
                    return _CollectionCard(
                      collection: value.items[index],
                      enabled: !value.isMutating,
                      onOpen: () => context.push(
                        AppRoutes.collection(value.items[index].id),
                      ),
                      onEdit: () =>
                          _editCollection(context, ref, value.items[index]),
                      onDelete: () =>
                          _deleteCollection(context, ref, value.items[index]),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _createCollection(BuildContext context, WidgetRef ref) async {
    final value = await showCollectionFormSheet(context);
    if (value == null || !context.mounted) return;
    try {
      final created = await ref
          .read(guidelineCollectionsControllerProvider(userId).notifier)
          .create(name: value.name, description: value.description);
      if (context.mounted) {
        AppMessage.success(context, 'Collection created.');
        context.push(AppRoutes.collection(created.id));
      }
    } catch (_) {
      if (context.mounted) {
        AppMessage.error(context, 'The collection could not be created.');
      }
    }
  }

  Future<void> _editCollection(
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
          .read(guidelineCollectionsControllerProvider(userId).notifier)
          .updateCollection(
            collection.id,
            name: value.name,
            description: value.description,
          );
      if (context.mounted) AppMessage.success(context, 'Collection updated.');
    } catch (_) {
      if (context.mounted) {
        AppMessage.error(context, 'The collection could not be updated.');
      }
    }
  }

  Future<void> _deleteCollection(
    BuildContext context,
    WidgetRef ref,
    GuidelineCollectionSummary collection,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete collection?'),
        content: Text(
          'Delete “${collection.name}”? Saved guidelines will not be deleted.',
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
          .read(guidelineCollectionsControllerProvider(userId).notifier)
          .delete(collection.id);
      if (context.mounted) AppMessage.success(context, 'Collection deleted.');
    } catch (_) {
      if (context.mounted) {
        AppMessage.error(context, 'The collection could not be deleted.');
      }
    }
  }

  Future<void> _loadMore(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(guidelineCollectionsControllerProvider(userId).notifier)
          .loadNextPage();
    } catch (_) {
      if (context.mounted) {
        AppMessage.error(context, 'More collections could not be loaded.');
      }
    }
  }
}
