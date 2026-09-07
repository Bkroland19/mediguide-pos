import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/app/providers/app_providers.dart';
import 'package:user_app/core/network/api_client.dart';
import 'package:user_app/features/library/data/repositories/guideline_library_repository.dart';
import 'package:user_app/features/library/presentation/controllers/guideline_collection_controller.dart';
import 'package:user_app/features/library/presentation/controllers/guideline_collections_controller.dart';
import 'package:user_app/features/authentication/data/models/user.dart';
import 'package:user_app/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:user_app/features/authentication/presentation/controllers/auth_state.dart';
import 'package:user_app/features/library/presentation/screens/guideline_collection_page.dart';
import 'package:user_app/features/library/presentation/screens/guideline_collections_page.dart';

import 'helpers/test_local_store.dart';

final class _AuthenticatedController extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.authenticated(
    User(id: 'user-1', name: 'Test clinician', email: 'test@example.test'),
  );
}

final class FakeGuidelineLibraryApi extends BackendApiService {
  FakeGuidelineLibraryApi({int collectionCount = 0}) {
    for (var index = 1; index <= collectionCount; index++) {
      collections.add(_collection('collection-$index', 'Collection $index'));
    }
  }

  final collections = <Map<String, dynamic>>[];
  final items = <String, List<Map<String, dynamic>>>{};
  final calls = <String>[];
  int nextCollection = 1000;
  int nextItem = 100;
  int? failureStatus;

  @override
  Future<Map<String, dynamic>> requestJson(
    String path, {
    required String method,
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool includeAuth = true,
  }) async {
    calls.add('$method $path');
    final status = failureStatus;
    if (status != null) {
      throw BackendApiException('request failed', statusCode: status);
    }

    if (path == '/api/v2/library/collections' && method == 'GET') {
      final page = int.parse(query?['page'] ?? '1');
      final perPage = int.parse(query?['per_page'] ?? '20');
      final start = (page - 1) * perPage;
      final sorted = [...collections];
      if (query?['sort'] == 'name') {
        sorted.sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
      }
      if (query?['order'] == 'desc' && query?['sort'] == 'name') {
        sorted.setAll(0, sorted.reversed.toList());
      }
      return _page(
        start >= sorted.length
            ? const []
            : sorted.skip(start).take(perPage).toList(),
        page,
        perPage,
        sorted.length,
      );
    }

    if (path == '/api/v2/library/collections' && method == 'POST') {
      final value = _collection(
        'collection-${nextCollection++}',
        '${body?['name']}',
        description: '${body?['description'] ?? ''}',
      );
      collections.insert(0, value);
      return {'data': value};
    }

    final match = RegExp(
      r'^/api/v2/library/collections/([^/]+)(?:/items(?:/([^/]+))?)?$',
    ).firstMatch(path);
    if (match == null) throw StateError('Unexpected $method $path');
    final collectionId = match.group(1)!;
    final guidelineId = match.group(2);
    final collectionIndex = collections.indexWhere(
      (item) => item['id'] == collectionId,
    );
    if (collectionIndex < 0) {
      throw const BackendApiException('not found', statusCode: 404);
    }
    final isItemsPath = path.contains('/items');

    if (!isItemsPath && method == 'GET') {
      return {
        'data': {
          ...collections[collectionIndex],
          'item_count': items[collectionId]?.length ?? 0,
        },
      };
    }
    if (!isItemsPath && method == 'PATCH') {
      final updated = {
        ...collections[collectionIndex],
        'name': body?['name'],
        'description': body?['description'],
        'updated_at': '2026-09-07T12:00:00Z',
      };
      collections[collectionIndex] = updated;
      return {'data': updated};
    }
    if (!isItemsPath && method == 'DELETE') {
      collections.removeAt(collectionIndex);
      items.remove(collectionId);
      return const {'success': true};
    }

    final collectionItems = items.putIfAbsent(collectionId, () => []);
    if (guidelineId == null && method == 'GET') {
      final page = int.parse(query?['page'] ?? '1');
      final perPage = int.parse(query?['per_page'] ?? '20');
      final start = (page - 1) * perPage;
      return _page(
        start >= collectionItems.length
            ? const []
            : collectionItems.skip(start).take(perPage).toList(),
        page,
        perPage,
        collectionItems.length,
      );
    }
    if (guidelineId == null && method == 'POST') {
      final publicationId = '${body?['guideline_id']}';
      if (!collectionItems.any(
        (item) => (item['guideline'] as Map)['id'] == publicationId,
      )) {
        collectionItems.add({
          'id': 'item-${nextItem++}',
          'sort_order': body?['sort_order'] ?? 0,
          'added_at': '2026-09-07T11:00:00Z',
          'guideline': _guideline(publicationId),
        });
      }
      return const {'success': true};
    }
    if (guidelineId != null && method == 'DELETE') {
      collectionItems.removeWhere(
        (item) => (item['guideline'] as Map)['id'] == guidelineId,
      );
      return const {'success': true};
    }
    throw StateError('Unexpected $method $path');
  }

  static Map<String, dynamic> _collection(
    String id,
    String name, {
    String description = '',
  }) => {
    'id': id,
    'name': name,
    'description': description,
    'item_count': 0,
    'created_at': '2026-09-01T08:00:00Z',
    'updated_at': '2026-09-01T08:00:00Z',
  };

  static Map<String, dynamic> _guideline(String id) => {
    'id': id,
    'slug': id,
    'title': 'Guideline $id',
    'description': 'Published guidance',
    'country': 'Uganda',
    'source_org': 'MOH',
    'program_area': 'Clinical care',
    'language': 'en',
    'publication_date': '2026-01-01',
    'review_date': '2027-01-01',
    'version': '1',
    'last_updated': '2026-09-01T08:00:00Z',
  };

  static Map<String, dynamic> _page(
    List<Map<String, dynamic>> values,
    int page,
    int perPage,
    int total,
  ) => {
    'data': {
      'items': values,
      'page': page,
      'per_page': perPage,
      'total_items': total,
      'total_pages': total == 0 ? 0 : (total / perPage).ceil(),
    },
  };
}

void main() {
  test('repository exposes complete collection and item operations', () async {
    final store = TestLocalStore();
    addTearDown(store.close);
    final api = FakeGuidelineLibraryApi();
    final repository = GuidelineLibraryRepository(api, store.cache);

    final created = await repository.createCollection(
      'user-1',
      name: '  Emergency care  ',
      description: '  Rapid references  ',
    );
    expect(created.name, 'Emergency care');
    expect(created.description, 'Rapid references');

    final listed = await repository.listCollections(
      'user-1',
      sort: 'name',
      order: 'asc',
    );
    expect(listed.items.single.id, created.id);

    final updated = await repository.updateCollection(
      'user-1',
      created.id,
      name: 'Ward round',
      description: 'Daily references',
    );
    expect(updated.name, 'Ward round');

    await repository.addCollectionItem(
      'user-1',
      created.id,
      guidelineId: 'guideline-1',
      sortOrder: 4,
    );
    final itemPage = await repository.listCollectionItems('user-1', created.id);
    expect(itemPage.items.single.guideline.id, 'guideline-1');
    expect(itemPage.items.single.sortOrder, 4);
    expect((await repository.getCollection('user-1', created.id)).itemCount, 1);

    await repository.removeCollectionItem('user-1', created.id, 'guideline-1');
    expect(
      (await repository.listCollectionItems('user-1', created.id)).items,
      isEmpty,
    );

    await repository.deleteCollection('user-1', created.id);
    expect((await repository.listCollections('user-1')).items, isEmpty);
  });

  test(
    'offline cache is owner scoped and does not hide authorization',
    () async {
      final store = TestLocalStore();
      addTearDown(store.close);
      final api = FakeGuidelineLibraryApi(collectionCount: 1);
      final repository = GuidelineLibraryRepository(api, store.cache);

      await repository.listCollections('user-a');
      api.failureStatus = 0;
      expect(
        (await repository.listCollections('user-a')).items.single.id,
        'collection-1',
      );
      await expectLater(
        repository.listCollections('user-b'),
        throwsA(isA<BackendApiException>()),
      );

      api.failureStatus = 401;
      await expectLater(
        repository.listCollections('user-a'),
        throwsA(
          isA<BackendApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    },
  );

  test('an empty canonical snapshot remains available offline', () async {
    final store = TestLocalStore();
    addTearDown(store.close);
    final api = FakeGuidelineLibraryApi();
    final repository = GuidelineLibraryRepository(api, store.cache);

    expect((await repository.listCollections('user-1')).items, isEmpty);
    api.failureStatus = 503;
    final offline = await repository.listCollections('user-1');
    expect(offline.items, isEmpty);
    expect(offline.totalItems, 0);
  });

  test('offline pagination preserves the authoritative total', () async {
    final store = TestLocalStore();
    addTearDown(store.close);
    final api = FakeGuidelineLibraryApi(collectionCount: 21);
    final repository = GuidelineLibraryRepository(api, store.cache);

    await repository.listCollections('user-1', perPage: 20);
    api.failureStatus = 0;
    final offline = await repository.listCollections(
      'user-1',
      page: 2,
      perPage: 20,
    );
    expect(offline.items, isEmpty);
    expect(offline.totalItems, 21);
    expect(offline.totalPages, 2);
  });

  test(
    'collection list controller paginates and refreshes mutations',
    () async {
      final store = TestLocalStore();
      addTearDown(store.close);
      final api = FakeGuidelineLibraryApi(collectionCount: 101);
      final repository = GuidelineLibraryRepository(api, store.cache);
      final container = ProviderContainer(
        overrides: [
          guidelineLibraryRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final provider = guidelineCollectionsControllerProvider('user-1');
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      expect((await container.read(provider.future)).items, hasLength(100));
      await container.read(provider.notifier).loadNextPage();
      expect(container.read(provider).requireValue.items, hasLength(101));

      final created = await container
          .read(provider.notifier)
          .create(name: 'Critical care');
      expect(created.name, 'Critical care');
      expect(container.read(provider).requireValue.totalItems, 102);

      await container
          .read(provider.notifier)
          .addGuideline(created.id, 'guideline-1');
      await container
          .read(provider.notifier)
          .addGuideline(created.id, 'guideline-1');
      expect(
        container
            .read(provider)
            .requireValue
            .items
            .firstWhere((item) => item.id == created.id)
            .itemCount,
        1,
      );

      await container.read(provider.notifier).delete(created.id);
      expect(container.read(provider).requireValue.totalItems, 101);

      api.failureStatus = 409;
      await expectLater(
        container.read(provider.notifier).create(name: 'Duplicate'),
        throwsA(isA<BackendApiException>()),
      );
      expect(container.read(provider).requireValue.isMutating, isFalse);
      expect(container.read(provider).requireValue.totalItems, 101);
    },
  );

  test('collection detail controller manages metadata and items', () async {
    final store = TestLocalStore();
    addTearDown(store.close);
    final api = FakeGuidelineLibraryApi(collectionCount: 1);
    final repository = GuidelineLibraryRepository(api, store.cache);
    final container = ProviderContainer(
      overrides: [
        guidelineLibraryRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final provider = guidelineCollectionControllerProvider(
      'user-1',
      'collection-1',
    );
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    expect((await container.read(provider.future)).items, isEmpty);
    await container.read(provider.notifier).addItem('guideline-1');
    expect(
      container.read(provider).requireValue.items.single.guideline.id,
      'guideline-1',
    );

    await container
        .read(provider.notifier)
        .updateCollection(name: 'Updated care', description: 'New detail');
    expect(
      container.read(provider).requireValue.collection.name,
      'Updated care',
    );

    await container.read(provider.notifier).removeItem('guideline-1');
    expect(container.read(provider).requireValue.items, isEmpty);
  });

  testWidgets('collection list renders canonical collection metadata', (
    tester,
  ) async {
    final store = TestLocalStore();
    addTearDown(store.close);
    final api = FakeGuidelineLibraryApi(collectionCount: 1);
    final repository = GuidelineLibraryRepository(api, store.cache);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_AuthenticatedController.new),
          guidelineLibraryRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: GuidelineCollectionsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Collection 1'), findsOneWidget);
    expect(find.text('0 guidelines'), findsOneWidget);
    expect(find.text('New collection'), findsOneWidget);
  });

  testWidgets('collection detail renders saved published guidelines', (
    tester,
  ) async {
    final store = TestLocalStore();
    addTearDown(store.close);
    final api = FakeGuidelineLibraryApi(collectionCount: 1);
    api.items['collection-1'] = [
      {
        'id': 'item-1',
        'sort_order': 0,
        'added_at': '2026-09-07T11:00:00Z',
        'guideline': FakeGuidelineLibraryApi._guideline('guideline-1'),
      },
    ];
    final repository = GuidelineLibraryRepository(api, store.cache);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_AuthenticatedController.new),
          guidelineLibraryRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: GuidelineCollectionPage(collectionId: 'collection-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guideline guideline-1'), findsOneWidget);
    expect(find.text('Clinical care · MOH · Version 1'), findsOneWidget);
    expect(find.text('1 guideline'), findsOneWidget);
  });
}
