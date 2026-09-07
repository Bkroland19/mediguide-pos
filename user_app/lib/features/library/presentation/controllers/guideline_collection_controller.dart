import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:user_app/app/providers/app_providers.dart';
import 'package:user_app/features/library/data/models/guideline_library_models.dart';
import 'package:user_app/features/library/data/repositories/guideline_library_repository.dart';
import 'package:user_app/features/library/presentation/controllers/guideline_collection_state.dart';
import 'package:user_app/features/library/presentation/controllers/guideline_collections_controller.dart';

part 'guideline_collection_controller.g.dart';

@riverpod
class GuidelineCollectionController extends _$GuidelineCollectionController {
  static const _pageSize = 20;

  late String _userId;
  late String _collectionId;

  GuidelineLibraryRepository get _repository =>
      ref.read(guidelineLibraryRepositoryProvider);

  @override
  Future<GuidelineCollectionState> build(String userId, String collectionId) {
    _userId = userId.trim();
    _collectionId = collectionId.trim();
    if (_userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'is required');
    }
    if (_collectionId.isEmpty) {
      throw ArgumentError.value(collectionId, 'collectionId', 'is required');
    }
    return _load();
  }

  Future<GuidelineCollectionState> _load() async {
    final results = await Future.wait<Object>([
      _repository.getCollection(_userId, _collectionId),
      _repository.listCollectionItems(
        _userId,
        _collectionId,
        perPage: _pageSize,
      ),
    ]);
    return GuidelineCollectionState.fromResults(
      results[0] as GuidelineCollectionDetail,
      results[1] as GuidelineCollectionItemPage,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading<GuidelineCollectionState>().copyWithPrevious(
      state,
    );
    state = await AsyncValue.guard(_load);
  }

  Future<void> loadNextPage() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await _repository.listCollectionItems(
        _userId,
        _collectionId,
        page: current.page + 1,
        perPage: current.perPage,
      );
      final items = <String, GuidelineCollectionItem>{
        for (final item in current.items) item.id: item,
        for (final item in next.items) item.id: item,
      }.values.toList(growable: false);
      state = AsyncData(
        current.copyWith(
          items: items,
          page: next.page,
          perPage: next.perPage,
          totalItems: next.totalItems,
          totalPages: next.totalPages,
          isLoadingMore: false,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<GuidelineCollectionDetail> updateCollection({
    required String name,
    String description = '',
  }) => _mutate(() async {
    final updated = await _repository.updateCollection(
      _userId,
      _collectionId,
      name: name,
      description: description,
    );
    final current = state.requireValue;
    state = AsyncData(current.copyWith(collection: updated, isMutating: false));
    ref.invalidate(guidelineCollectionsControllerProvider(_userId));
    return updated;
  });

  Future<void> addItem(String guidelineId, {int sortOrder = 0}) =>
      _mutate(() async {
        await _repository.addCollectionItem(
          _userId,
          _collectionId,
          guidelineId: guidelineId,
          sortOrder: sortOrder,
        );
        await _replaceWithFreshState();
        ref.invalidate(guidelineCollectionsControllerProvider(_userId));
      });

  Future<void> removeItem(String guidelineId) => _mutate(() async {
    await _repository.removeCollectionItem(_userId, _collectionId, guidelineId);
    await _replaceWithFreshState();
    ref.invalidate(guidelineCollectionsControllerProvider(_userId));
  });

  Future<void> delete() => _mutate(() async {
    await _repository.deleteCollection(_userId, _collectionId);
    final current = state.requireValue;
    state = AsyncData(current.copyWith(isMutating: false));
    ref.invalidate(guidelineCollectionsControllerProvider(_userId));
  });

  Future<T> _mutate<T>(Future<T> Function() operation) async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(isMutating: true));
    }
    try {
      return await operation();
    } catch (error, stackTrace) {
      if (current != null) state = AsyncData(current);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _replaceWithFreshState() async {
    state = AsyncData(await _load());
  }
}
