import 'package:user_app/core/network/api_client.dart';
import 'package:user_app/core/network/contracts/generated/backend_contracts.dart';
import 'package:user_app/core/storage/local_cache_service.dart';
import 'package:user_app/features/library/data/models/guideline_library_models.dart';

final class GuidelineLibraryRepository {
  GuidelineLibraryRepository(this._api, this._cache);

  static const _collectionsType = 'guideline_library_collection';
  static const _collectionsSnapshotType =
      'guideline_library_collection_snapshot';
  static const _collectionItemsType = 'guideline_library_collection_item';
  static const _collectionItemsSnapshotType =
      'guideline_library_collection_item_snapshot';
  static const _downloadsType = 'guideline_library_download';
  static const _cacheTtl = Duration(days: 7);
  static const _collectionSorts = {'name', 'created_at', 'updated_at'};
  static const _orders = {'asc', 'desc'};

  final BackendApiService _api;
  final LocalCacheService _cache;

  String _scope(String userId) {
    final id = userId.trim();
    if (id.isEmpty) throw ArgumentError.value(userId, 'userId', 'is required');
    return 'user:$id';
  }

  /// Compatibility helper for library summary consumers. New collection
  /// screens should use [listCollections] so pagination metadata is preserved.
  Future<List<GuidelineCollectionSummary>> collections(String userId) async {
    final result = await listCollections(
      userId,
      perPage: 100,
      sort: 'updated_at',
      order: 'desc',
    );
    return result.items;
  }

  Future<GuidelineCollectionPage> listCollections(
    String userId, {
    int page = 1,
    int perPage = 20,
    String sort = 'updated_at',
    String order = 'desc',
  }) async {
    final scope = _scope(userId);
    _validatePage(page, perPage);
    final normalizedSort = sort.trim().toLowerCase();
    final normalizedOrder = order.trim().toLowerCase();
    if (!_collectionSorts.contains(normalizedSort)) {
      throw ArgumentError.value(sort, 'sort', 'is not supported');
    }
    if (!_orders.contains(normalizedOrder)) {
      throw ArgumentError.value(order, 'order', 'is not supported');
    }

    try {
      final response = await _api.requestJson(
        '/api/v2/library/collections',
        method: 'GET',
        query: {
          'page': '$page',
          'per_page': '$perPage',
          'sort': normalizedSort,
          'order': normalizedOrder,
        },
      );
      final result = GuidelineCollectionPage.fromContract(
        HandlersPaginatedGuidelineCollections.fromJson(_data(response)),
      );
      await _cacheCollectionPage(scope, result);
      return result;
    } catch (error) {
      if (!_canUseCache(error)) rethrow;
      return _cachedCollectionPage(
        scope,
        page: page,
        perPage: perPage,
        sort: normalizedSort,
        order: normalizedOrder,
        originalError: error,
      );
    }
  }

  Future<GuidelineCollectionDetail> getCollection(
    String userId,
    String collectionId,
  ) async {
    final scope = _scope(userId);
    final id = _requiredId(collectionId, 'collectionId');
    try {
      final response = await _api.requestJson(
        '/api/v2/library/collections/$id',
        method: 'GET',
      );
      final result = GuidelineCollectionSummary.fromContract(
        ServicesGuidelineCollectionDTO.fromJson(_data(response)),
      );
      await _bestEffort(() => _cacheCollection(scope, result));
      return result;
    } catch (error) {
      if (!_canUseCache(error)) rethrow;
      final cached = await _cache.get(
        type: _collectionsType,
        id: id,
        scope: scope,
      );
      if (cached == null) rethrow;
      return GuidelineCollectionSummary.fromJson(cached);
    }
  }

  Future<GuidelineCollectionDetail> createCollection(
    String userId, {
    required String name,
    String description = '',
  }) async {
    final scope = _scope(userId);
    final response = await _api.requestJson(
      '/api/v2/library/collections',
      method: 'POST',
      body: ServicesGuidelineCollectionInput.fromJson({
        'name': name.trim(),
        'description': description.trim(),
      }).toJson(),
    );
    final result = GuidelineCollectionSummary.fromContract(
      ServicesGuidelineCollectionDTO.fromJson(_data(response)),
    );
    await _bestEffort(() async {
      await _cacheCollection(scope, result);
      await _updateCollectionSnapshotAfterMutation(
        scope,
        delta: 1,
        addedId: result.id,
      );
    });
    return result;
  }

  Future<GuidelineCollectionDetail> updateCollection(
    String userId,
    String collectionId, {
    required String name,
    String description = '',
  }) async {
    final scope = _scope(userId);
    final id = _requiredId(collectionId, 'collectionId');
    final response = await _api.requestJson(
      '/api/v2/library/collections/$id',
      method: 'PATCH',
      body: ServicesGuidelineCollectionInput.fromJson({
        'name': name.trim(),
        'description': description.trim(),
      }).toJson(),
    );
    final result = GuidelineCollectionSummary.fromContract(
      ServicesGuidelineCollectionDTO.fromJson(_data(response)),
    );
    await _bestEffort(() => _cacheCollection(scope, result));
    return result;
  }

  Future<void> deleteCollection(String userId, String collectionId) async {
    final scope = _scope(userId);
    final id = _requiredId(collectionId, 'collectionId');
    await _api.requestJson('/api/v2/library/collections/$id', method: 'DELETE');
    await _bestEffort(() async {
      await _cache.tombstone(type: _collectionsType, id: id, scope: scope);
      await _updateCollectionSnapshotAfterMutation(
        scope,
        delta: -1,
        removedId: id,
      );
      await _cache.clearType(type: _itemsType(id), scope: scope);
      await _cache.remove(
        type: _collectionItemsSnapshotType,
        id: id,
        scope: scope,
      );
    });
  }

  Future<GuidelineCollectionItemPage> listCollectionItems(
    String userId,
    String collectionId, {
    int page = 1,
    int perPage = 20,
  }) async {
    final scope = _scope(userId);
    final id = _requiredId(collectionId, 'collectionId');
    _validatePage(page, perPage);
    try {
      final response = await _api.requestJson(
        '/api/v2/library/collections/$id/items',
        method: 'GET',
        query: {'page': '$page', 'per_page': '$perPage'},
      );
      final result = GuidelineCollectionItemPage.fromContract(
        HandlersPaginatedGuidelineCollectionItems.fromJson(_data(response)),
      );
      await _cacheItemPage(scope, id, result);
      return result;
    } catch (error) {
      if (!_canUseCache(error)) rethrow;
      return _cachedItemPage(
        scope,
        id,
        page: page,
        perPage: perPage,
        originalError: error,
      );
    }
  }

  Future<void> addCollectionItem(
    String userId,
    String collectionId, {
    required String guidelineId,
    int sortOrder = 0,
  }) async {
    final scope = _scope(userId);
    final id = _requiredId(collectionId, 'collectionId');
    final publicationId = _requiredId(guidelineId, 'guidelineId');
    if (sortOrder < 0) {
      throw ArgumentError.value(sortOrder, 'sortOrder', 'must be non-negative');
    }
    final knownAbsent = await _isGuidelineKnownAbsent(scope, id, publicationId);
    await _api.requestJson(
      '/api/v2/library/collections/$id/items',
      method: 'POST',
      body: ServicesGuidelineCollectionItemInput.fromJson({
        'guideline_id': publicationId,
        'sort_order': sortOrder,
      }).toJson(),
    );
    await _bestEffort(() async {
      await _markItemSnapshotAfterAdd(scope, id, incrementTotal: knownAbsent);
      if (knownAbsent) {
        await _updateCachedCollectionItemCount(scope, id, 1);
      }
    });
  }

  /// Checks the authoritative paginated collection contents before an add so
  /// the UI can distinguish an idempotent repeat from a new membership.
  Future<bool> collectionContainsGuideline(
    String userId,
    String collectionId,
    String guidelineId,
  ) async {
    final id = _requiredId(collectionId, 'collectionId');
    final publicationId = _requiredId(guidelineId, 'guidelineId');
    var page = 1;
    while (true) {
      final result = await listCollectionItems(
        userId,
        id,
        page: page,
        perPage: 100,
      );
      if (result.items.any((item) => item.guideline.id == publicationId)) {
        return true;
      }
      if (!result.hasMore) return false;
      page += 1;
    }
  }

  Future<void> removeCollectionItem(
    String userId,
    String collectionId,
    String guidelineId,
  ) async {
    final scope = _scope(userId);
    final id = _requiredId(collectionId, 'collectionId');
    final publicationId = _requiredId(guidelineId, 'guidelineId');
    await _api.requestJson(
      '/api/v2/library/collections/$id/items/$publicationId',
      method: 'DELETE',
    );
    await _bestEffort(() async {
      final items = await _cache.list(
        type: _itemsType(id),
        scope: scope,
        limit: 1000,
      );
      for (final item in items) {
        final guideline = item['guideline'];
        if (guideline is Map && guideline['id']?.toString() == publicationId) {
          final itemId = item['id']?.toString() ?? '';
          if (itemId.isNotEmpty) {
            await _cache.tombstone(
              type: _itemsType(id),
              id: itemId,
              scope: scope,
            );
          }
        }
      }
      await _updateItemSnapshotAfterRemoval(scope, id);
      await _updateCachedCollectionItemCount(scope, id, -1);
    });
  }

  Future<List<GuidelineDownloadRecord>> downloads(String userId) async {
    final scope = _scope(userId);
    try {
      final response = await _api.requestJson(
        '/api/v2/library/downloads',
        method: 'GET',
        query: const {
          'page': '1',
          'per_page': '100',
          'sort': 'downloaded_at',
          'order': 'desc',
        },
      );
      final data = _data(response);
      final items = _maps(data['items'])
          .map(ServicesGuidelineDownloadDTO.fromJson)
          .map(GuidelineDownloadRecord.fromContract)
          .toList(growable: false);
      await _bestEffort(
        () => _cache.putMany(
          type: _downloadsType,
          scope: scope,
          entities: items.map(
            (item) => CachedEntityInput(
              id: item.id,
              data: item.toJson(),
              searchableText: '${item.guidelineId} ${item.assetType}',
              remoteUpdatedAt: item.downloadedAt,
            ),
          ),
        ),
      );
      return items;
    } catch (error) {
      if (!_canUseCache(error)) rethrow;
      final cached = await _cache.list(
        type: _downloadsType,
        scope: scope,
        limit: 100,
      );
      if (cached.isEmpty) rethrow;
      return cached.map(GuidelineDownloadRecord.fromJson).toList();
    }
  }

  Future<GuidelineDownloadRecord> recordDownload({
    required String guidelineId,
    required String assetType,
  }) async {
    final response = await _api.requestJson(
      '/api/v2/library/downloads',
      method: 'POST',
      body: ServicesGuidelineDownloadInput.fromJson({
        'guideline_id': guidelineId,
        'asset_type': assetType,
      }).toJson(),
    );
    return GuidelineDownloadRecord.fromContract(
      ServicesGuidelineDownloadDTO.fromJson(_data(response)),
    );
  }

  Future<void> _cacheCollectionPage(
    String scope,
    GuidelineCollectionPage page,
  ) async {
    await _bestEffort(() async {
      final entities = page.items.map(_collectionCacheInput);
      if (page.page == 1 && page.totalPages <= 1) {
        await _cache.replaceSnapshot(
          type: _collectionsType,
          snapshotType: _collectionsSnapshotType,
          snapshotId: 'all',
          entities: entities,
          scope: scope,
          ttl: _cacheTtl,
          reconcileMissing: true,
          snapshotData: {'total_items': page.totalItems, 'complete': true},
        );
      } else {
        await _cache.putMany(
          type: _collectionsType,
          entities: entities,
          scope: scope,
          ttl: _cacheTtl,
        );
        await _cache.put(
          type: _collectionsSnapshotType,
          id: 'all',
          scope: scope,
          ttl: _cacheTtl,
          data: {'total_items': page.totalItems, 'complete': false},
        );
      }
    });
  }

  Future<GuidelineCollectionPage> _cachedCollectionPage(
    String scope, {
    required int page,
    required int perPage,
    required String sort,
    required String order,
    required Object originalError,
  }) async {
    final cached = await _cache.list(
      type: _collectionsType,
      scope: scope,
      limit: 1000,
    );
    final snapshot = await _cache.get(
      type: _collectionsSnapshotType,
      id: 'all',
      scope: scope,
    );
    if (cached.isEmpty && snapshot == null) throw originalError;
    final values = cached.map(GuidelineCollectionSummary.fromJson).toList();
    values.sort((a, b) {
      final comparison = switch (sort) {
        'name' => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        'created_at' => _compareDates(a.createdAt, b.createdAt),
        _ => _compareDates(a.updatedAt, b.updatedAt),
      };
      return order == 'asc' ? comparison : -comparison;
    });
    final offset = (page - 1) * perPage;
    final items = offset >= values.length
        ? const <GuidelineCollectionSummary>[]
        : values.skip(offset).take(perPage).toList(growable: false);
    final snapshotTotal = (snapshot?['total_items'] as num?)?.toInt() ?? 0;
    final snapshotIsComplete = snapshot?['complete'] == true;
    final totalItems = snapshotIsComplete
        ? values.length
        : (snapshotTotal > values.length ? snapshotTotal : values.length);
    return GuidelineCollectionPage(
      items: items,
      page: page,
      perPage: perPage,
      totalItems: totalItems,
      totalPages: totalItems == 0 ? 0 : (totalItems / perPage).ceil(),
    );
  }

  Future<void> _cacheCollection(
    String scope,
    GuidelineCollectionSummary collection,
  ) => _cache.put(
    type: _collectionsType,
    id: collection.id,
    scope: scope,
    ttl: _cacheTtl,
    data: collection.toJson(),
    searchableText: '${collection.name} ${collection.description}',
    remoteUpdatedAt: collection.updatedAt,
  );

  CachedEntityInput _collectionCacheInput(
    GuidelineCollectionSummary collection,
  ) => CachedEntityInput(
    id: collection.id,
    data: collection.toJson(),
    searchableText: '${collection.name} ${collection.description}',
    remoteUpdatedAt: collection.updatedAt,
  );

  Future<void> _cacheItemPage(
    String scope,
    String collectionId,
    GuidelineCollectionItemPage page,
  ) async {
    await _bestEffort(() async {
      final type = _itemsType(collectionId);
      final entities = page.items.map(
        (item) => CachedEntityInput(
          id: item.id,
          data: item.toJson(),
          searchableText:
              '${item.guideline.title} ${item.guideline.description}',
          remoteUpdatedAt: item.addedAt,
        ),
      );
      if (page.page == 1 && page.totalPages <= 1) {
        await _cache.replaceSnapshot(
          type: type,
          snapshotType: _collectionItemsSnapshotType,
          snapshotId: collectionId,
          entities: entities,
          scope: scope,
          ttl: _cacheTtl,
          reconcileMissing: true,
          snapshotData: {'total_items': page.totalItems, 'complete': true},
        );
      } else {
        await _cache.putMany(
          type: type,
          entities: entities,
          scope: scope,
          ttl: _cacheTtl,
        );
        await _cache.put(
          type: _collectionItemsSnapshotType,
          id: collectionId,
          scope: scope,
          ttl: _cacheTtl,
          data: {'total_items': page.totalItems, 'complete': false},
        );
      }
    });
  }

  Future<GuidelineCollectionItemPage> _cachedItemPage(
    String scope,
    String collectionId, {
    required int page,
    required int perPage,
    required Object originalError,
  }) async {
    final cached = await _cache.list(
      type: _itemsType(collectionId),
      scope: scope,
      limit: 1000,
    );
    final snapshot = await _cache.get(
      type: _collectionItemsSnapshotType,
      id: collectionId,
      scope: scope,
    );
    if (cached.isEmpty && snapshot == null) throw originalError;
    final values = cached.map(GuidelineCollectionItem.fromJson).toList()
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order != 0 ? order : _compareDates(a.addedAt, b.addedAt);
      });
    final offset = (page - 1) * perPage;
    final items = offset >= values.length
        ? const <GuidelineCollectionItem>[]
        : values.skip(offset).take(perPage).toList(growable: false);
    final snapshotTotal = (snapshot?['total_items'] as num?)?.toInt() ?? 0;
    final snapshotIsComplete = snapshot?['complete'] == true;
    final totalItems = snapshotIsComplete
        ? values.length
        : (snapshotTotal > values.length ? snapshotTotal : values.length);
    return GuidelineCollectionItemPage(
      items: items,
      page: page,
      perPage: perPage,
      totalItems: totalItems,
      totalPages: totalItems == 0 ? 0 : (totalItems / perPage).ceil(),
      fromCache: true,
    );
  }

  Future<void> _updateCollectionSnapshotAfterMutation(
    String scope, {
    required int delta,
    String? addedId,
    String? removedId,
  }) async {
    final snapshot = await _cache.get(
      type: _collectionsSnapshotType,
      id: 'all',
      scope: scope,
    );
    if (snapshot == null) return;
    final complete = snapshot['complete'] == true;
    final active = complete
        ? await _cache.list(type: _collectionsType, scope: scope, limit: 1000)
        : const <Map<String, dynamic>>[];
    final previousTotal = (snapshot['total_items'] as num?)?.toInt() ?? 0;
    final ids = (snapshot['ids'] as List? ?? const [])
        .map((value) => value.toString())
        .toSet();
    if (addedId != null) ids.add(addedId);
    if (removedId != null) ids.remove(removedId);
    await _cache.put(
      type: _collectionsSnapshotType,
      id: 'all',
      scope: scope,
      ttl: _cacheTtl,
      data: {
        'total_items': complete
            ? active.length
            : (previousTotal + delta).clamp(0, 1 << 31),
        'complete': complete,
        'ids': ids.toList(growable: false),
      },
    );
  }

  Future<bool> _isGuidelineKnownAbsent(
    String scope,
    String collectionId,
    String guidelineId,
  ) async {
    try {
      final snapshot = await _cache.get(
        type: _collectionItemsSnapshotType,
        id: collectionId,
        scope: scope,
      );
      if (snapshot?['complete'] != true) return false;
      final cached = await _cache.list(
        type: _itemsType(collectionId),
        scope: scope,
        limit: 1000,
      );
      return !cached.any((item) {
        final guideline = item['guideline'];
        return guideline is Map && guideline['id']?.toString() == guidelineId;
      });
    } catch (_) {
      return false;
    }
  }

  Future<void> _markItemSnapshotAfterAdd(
    String scope,
    String collectionId, {
    required bool incrementTotal,
  }) async {
    final snapshot = await _cache.get(
      type: _collectionItemsSnapshotType,
      id: collectionId,
      scope: scope,
    );
    if (snapshot == null) return;
    final previousTotal = (snapshot['total_items'] as num?)?.toInt() ?? 0;
    await _cache.put(
      type: _collectionItemsSnapshotType,
      id: collectionId,
      scope: scope,
      ttl: _cacheTtl,
      data: {
        ...snapshot,
        'total_items': previousTotal + (incrementTotal ? 1 : 0),
        // The 204 add response does not contain the new item entity.
        'complete': false,
      },
    );
  }

  Future<void> _updateItemSnapshotAfterRemoval(
    String scope,
    String collectionId,
  ) async {
    final snapshot = await _cache.get(
      type: _collectionItemsSnapshotType,
      id: collectionId,
      scope: scope,
    );
    if (snapshot == null) return;
    final previousTotal = (snapshot['total_items'] as num?)?.toInt() ?? 0;
    final activeItems = await _cache.list(
      type: _itemsType(collectionId),
      scope: scope,
      limit: 1000,
    );
    final ids = (snapshot['ids'] as List? ?? const [])
        .map((value) => value.toString())
        .where((id) => activeItems.any((item) => item['id']?.toString() == id))
        .toList(growable: false);
    await _cache.put(
      type: _collectionItemsSnapshotType,
      id: collectionId,
      scope: scope,
      ttl: _cacheTtl,
      data: {
        'total_items': (previousTotal - 1).clamp(0, 1 << 31),
        'complete': snapshot['complete'] == true,
        'ids': ids,
      },
    );
  }

  Future<void> _updateCachedCollectionItemCount(
    String scope,
    String collectionId,
    int delta,
  ) async {
    final value = await _cache.get(
      type: _collectionsType,
      id: collectionId,
      scope: scope,
    );
    if (value == null) return;
    final collection = GuidelineCollectionSummary.fromJson(value);
    await _cacheCollection(
      scope,
      GuidelineCollectionSummary(
        id: collection.id,
        name: collection.name,
        description: collection.description,
        itemCount: (collection.itemCount + delta).clamp(0, 1 << 31).toInt(),
        createdAt: collection.createdAt,
        updatedAt: collection.updatedAt,
      ),
    );
  }

  String _itemsType(String collectionId) =>
      '$_collectionItemsType:$collectionId';

  void _validatePage(int page, int perPage) {
    if (page < 1) throw ArgumentError.value(page, 'page', 'must be positive');
    if (perPage < 1 || perPage > 100) {
      throw ArgumentError.value(perPage, 'perPage', 'must be from 1 to 100');
    }
  }

  String _requiredId(String value, String name) {
    final id = value.trim();
    if (id.isEmpty) throw ArgumentError.value(value, name, 'is required');
    return id;
  }

  bool _canUseCache(Object error) =>
      error is BackendApiException &&
      (error.statusCode == 0 || error.statusCode >= 500);

  int _compareDates(DateTime? left, DateTime? right) {
    if (left == null && right == null) return 0;
    if (left == null) return -1;
    if (right == null) return 1;
    return left.compareTo(right);
  }

  Future<void> _bestEffort(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // The server remains authoritative. A local persistence failure must not
      // turn a completed remote mutation or read into a user-visible failure.
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic> response) {
    final value = response['data'];
    return value is Map ? Map<String, dynamic>.from(value) : response;
  }

  List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
}
