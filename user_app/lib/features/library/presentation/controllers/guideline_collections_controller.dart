import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:user_app/app/providers/app_providers.dart';
import 'package:user_app/features/library/data/models/guideline_library_models.dart';
import 'package:user_app/features/library/data/repositories/guideline_library_repository.dart';
import 'package:user_app/features/library/presentation/controllers/guideline_collections_state.dart';

part 'guideline_collections_controller.g.dart';

@riverpod
class GuidelineCollectionsController extends _$GuidelineCollectionsController {
  // Preserve the existing My Library snapshot size while still supporting
  // subsequent pages for unusually large libraries.
  static const _pageSize = 100;

  late String _userId;

  GuidelineLibraryRepository get _repository =>
      ref.read(guidelineLibraryRepositoryProvider);

  @override
  Future<GuidelineCollectionsState> build(String userId) {
    _userId = userId.trim();
    if (_userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'is required');
    }
    return _loadPage(1);
  }

  Future<GuidelineCollectionsState> _loadPage(int page) async {
    final result = await _repository.listCollections(
      _userId,
      page: page,
      perPage: _pageSize,
    );
    return GuidelineCollectionsState.fromPage(result);
  }

  Future<void> refresh() async {
    state = const AsyncLoading<GuidelineCollectionsState>().copyWithPrevious(
      state,
    );
    state = await AsyncValue.guard(() => _loadPage(1));
  }

  Future<void> loadNextPage() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await _repository.listCollections(
        _userId,
        page: current.page + 1,
        perPage: current.perPage,
      );
      final items = <String, GuidelineCollectionSummary>{
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

  Future<GuidelineCollectionDetail> create({
    required String name,
    String description = '',
  }) => _mutate(() async {
    final created = await _repository.createCollection(
      _userId,
      name: name,
      description: description,
    );
    _upsertCollection(created);
    return created;
  });

  Future<GuidelineCollectionDetail> updateCollection(
    String collectionId, {
    required String name,
    String description = '',
  }) => _mutate(() async {
    final updated = await _repository.updateCollection(
      _userId,
      collectionId,
      name: name,
      description: description,
    );
    _upsertCollection(updated);
    return updated;
  });

  Future<void> delete(String collectionId) => _mutate(() async {
    await _repository.deleteCollection(_userId, collectionId);
    final current = state.requireValue;
    final items = current.items
        .where((item) => item.id != collectionId)
        .toList(growable: false);
    final totalItems = current.totalItems > 0 ? current.totalItems - 1 : 0;
    state = AsyncData(
      current.copyWith(
        items: items,
        totalItems: totalItems,
        totalPages: totalItems == 0 ? 0 : (totalItems / current.perPage).ceil(),
        isMutating: false,
      ),
    );
  });

  Future<void> addGuideline(
    String collectionId,
    String guidelineId, {
    int sortOrder = 0,
  }) => _mutate(() async {
    await _repository.addCollectionItem(
      _userId,
      collectionId,
      guidelineId: guidelineId,
      sortOrder: sortOrder,
    );
    try {
      _upsertCollection(await _repository.getCollection(_userId, collectionId));
    } catch (_) {
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncData(current.copyWith(isMutating: false));
      }
    }
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

  void _upsertCollection(GuidelineCollectionSummary collection) {
    final current = state.requireValue;
    final existed = current.items.any((item) => item.id == collection.id);
    final items = [
      collection,
      ...current.items.where((item) => item.id != collection.id),
    ];
    final totalItems = current.totalItems + (existed ? 0 : 1);
    state = AsyncData(
      current.copyWith(
        items: items,
        totalItems: totalItems,
        totalPages: totalItems == 0 ? 0 : (totalItems / current.perPage).ceil(),
        isMutating: false,
      ),
    );
  }
}
