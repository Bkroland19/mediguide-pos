import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:user_app/app/providers/app_providers.dart';
import 'package:user_app/app/router/route_names.dart';
import 'package:user_app/core/network/api_client.dart';
import 'package:user_app/features/library/data/repositories/guideline_library_repository.dart';
import 'package:user_app/features/library/presentation/controllers/guideline_collection_controller.dart';
import 'package:user_app/features/library/presentation/controllers/guideline_collections_controller.dart';
import 'package:user_app/features/authentication/data/models/user.dart';
import 'package:user_app/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:user_app/features/authentication/presentation/controllers/auth_state.dart';
import 'package:user_app/features/library/presentation/screens/guideline_collection_page.dart';
import 'package:user_app/features/library/presentation/screens/guideline_collections_page.dart';
import 'package:user_app/features/library/presentation/utils/collection_messages.dart';
import 'package:user_app/features/library/presentation/widgets/save_to_collection_sheet.dart';

import 'helpers/test_local_store.dart';

final class _AuthenticatedController extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.authenticated(
    User(id: 'user-1', name: 'Test clinician', email: 'test@example.test'),
  );
}

final class _UnauthenticatedController extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.unauthenticated();
}

class _SaveToCollectionHarness extends StatefulWidget {
  const _SaveToCollectionHarness();

  @override
  State<_SaveToCollectionHarness> createState() =>
      _SaveToCollectionHarnessState();
}

class _SaveToCollectionHarnessState extends State<_SaveToCollectionHarness> {
  String? savedCollection;
  bool alreadyPresent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async {
            final result = await showSaveToCollectionSheet(
              context,
              userId: 'user-1',
              guidelineId: 'guideline-1',
            );
            if (mounted && result != null) {
              setState(() {
                savedCollection = result.collectionName;
                alreadyPresent = result.alreadyPresent;
              });
            }
          },
          child: const Text('Open collection picker'),
        ),
      ),
      bottomNavigationBar: savedCollection == null
          ? null
          : Text(
              alreadyPresent
                  ? 'Already saved in $savedCollection'
                  : 'Saved to $savedCollection',
            ),
    );
  }
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
  int? nextFailureStatus;
  String? nextFailureCall;
  String? gatedCall;
  Completer<void>? callGate;

  @override
  Future<Map<String, dynamic>> requestJson(
    String path, {
    required String method,
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool includeAuth = true,
  }) async {
    calls.add('$method $path');
    if (nextFailureStatus != null &&
        (nextFailureCall == null || nextFailureCall == '$method $path')) {
      final status = nextFailureStatus!;
      nextFailureStatus = null;
      nextFailureCall = null;
      throw BackendApiException('request failed', statusCode: status);
    }
    final status = failureStatus;
    if (status != null) {
      throw BackendApiException('request failed', statusCode: status);
    }
    if (gatedCall == '$method $path' && callGate != null) {
      await callGate!.future;
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

  test('deleted collections do not reappear from the offline cache', () async {
    final store = TestLocalStore();
    addTearDown(store.close);
    final api = FakeGuidelineLibraryApi(collectionCount: 1);
    final repository = GuidelineLibraryRepository(api, store.cache);

    expect((await repository.listCollections('user-1')).totalItems, 1);
    await repository.deleteCollection('user-1', 'collection-1');

    api.failureStatus = 0;
    final offline = await repository.listCollections('user-1');
    expect(offline.items, isEmpty);
    expect(offline.totalItems, 0);
    expect(offline.totalPages, 0);
  });

  test('renamed collections replace their cached representation', () async {
    final store = TestLocalStore();
    addTearDown(store.close);
    final api = FakeGuidelineLibraryApi(collectionCount: 1);
    final repository = GuidelineLibraryRepository(api, store.cache);

    await repository.listCollections('user-1');
    await repository.updateCollection(
      'user-1',
      'collection-1',
      name: 'Renamed collection',
    );

    api.failureStatus = 503;
    final offline = await repository.listCollections('user-1');
    expect(offline.items.single.name, 'Renamed collection');
    expect(offline.totalItems, 1);
  });

  test(
    'partial refresh never removes cached pages outside its snapshot',
    () async {
      final store = TestLocalStore();
      addTearDown(store.close);
      final api = FakeGuidelineLibraryApi(collectionCount: 102);
      final repository = GuidelineLibraryRepository(api, store.cache);

      await repository.listCollections(
        'user-1',
        page: 2,
        perPage: 100,
        sort: 'name',
        order: 'asc',
      );
      api.collections.removeWhere((item) => item['id'] == 'collection-50');
      await repository.listCollections(
        'user-1',
        perPage: 100,
        sort: 'name',
        order: 'asc',
      );

      api.failureStatus = 0;
      final first = await repository.listCollections(
        'user-1',
        perPage: 100,
        sort: 'name',
        order: 'asc',
      );
      final second = await repository.listCollections(
        'user-1',
        page: 2,
        perPage: 100,
        sort: 'name',
        order: 'asc',
      );
      final ids = [...first.items, ...second.items].map((item) => item.id);
      expect(ids, contains('collection-102'));
      expect(first.totalItems, 101);
    },
  );

  test(
    'item mutations reconcile cached totals and collection counts',
    () async {
      final store = TestLocalStore();
      addTearDown(store.close);
      final api = FakeGuidelineLibraryApi(collectionCount: 1);
      final repository = GuidelineLibraryRepository(api, store.cache);

      await repository.listCollections('user-1');
      await repository.listCollectionItems('user-1', 'collection-1');
      await repository.addCollectionItem(
        'user-1',
        'collection-1',
        guidelineId: 'guideline-1',
      );

      api.failureStatus = 0;
      expect(
        (await repository.getCollection('user-1', 'collection-1')).itemCount,
        1,
      );
      final afterAdd = await repository.listCollectionItems(
        'user-1',
        'collection-1',
      );
      expect(afterAdd.totalItems, 1);
      expect(afterAdd.fromCache, isTrue);

      api.failureStatus = null;
      await repository.listCollectionItems('user-1', 'collection-1');
      await repository.removeCollectionItem(
        'user-1',
        'collection-1',
        'guideline-1',
      );
      api.failureStatus = 0;
      expect(
        (await repository.getCollection('user-1', 'collection-1')).itemCount,
        0,
      );
      final afterRemove = await repository.listCollectionItems(
        'user-1',
        'collection-1',
      );
      expect(afterRemove.items, isEmpty);
      expect(afterRemove.totalItems, 0);
    },
  );

  test('collection messages hide transport details and guide recovery', () {
    expect(
      CollectionMessages.failure(
        const BackendApiException('Dio stack trace', statusCode: 0),
        CollectionOperation.addGuideline,
      ),
      'You are offline. Connect to make this change.',
    );
    expect(
      CollectionMessages.failure(
        const BackendApiException('constraint detail', statusCode: 409),
        CollectionOperation.createCollection,
      ),
      'A collection with this name already exists.',
    );
    expect(
      CollectionMessages.failure(
        const BackendApiException('token detail', statusCode: 401),
        CollectionOperation.deleteCollection,
      ),
      'Your session expired. Sign in and try again.',
    );
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

  test('collection detail controller incrementally loads every item', () async {
    final store = TestLocalStore();
    addTearDown(store.close);
    final api = FakeGuidelineLibraryApi(collectionCount: 1);
    api.items['collection-1'] = [
      for (var index = 1; index <= 21; index++)
        {
          'id': 'item-$index',
          'sort_order': index,
          'added_at': '2026-09-07T11:00:00Z',
          'guideline': FakeGuidelineLibraryApi._guideline('guideline-$index'),
        },
    ];
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

    final firstPage = await container.read(provider.future);
    expect(firstPage.items, hasLength(20));
    expect(firstPage.hasMore, isTrue);
    await container.read(provider.notifier).loadNextPage();

    expect(container.read(provider).requireValue.items, hasLength(21));
    expect(container.read(provider).requireValue.hasMore, isFalse);
  });

  test(
    'collection item cache reconciles a complete published-only snapshot',
    () async {
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

      expect(
        (await repository.listCollectionItems('user-1', 'collection-1')).items,
        hasLength(1),
      );
      api.items['collection-1'] = [];
      expect(
        (await repository.listCollectionItems('user-1', 'collection-1')).items,
        isEmpty,
      );

      api.failureStatus = 0;
      final offline = await repository.listCollectionItems(
        'user-1',
        'collection-1',
      );
      expect(offline.items, isEmpty);
      expect(offline.fromCache, isTrue);
    },
  );

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

  testWidgets('collection creation validates, persists, and opens the result', (
    tester,
  ) async {
    final store = TestLocalStore();
    addTearDown(store.close);
    final api = FakeGuidelineLibraryApi();
    final repository = GuidelineLibraryRepository(api, store.cache);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const GuidelineCollectionsPage()),
        GoRoute(
          path: AppRoutes.collectionDetails,
          builder: (_, state) => Scaffold(
            body: Text('Opened ${state.pathParameters['collectionId']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_AuthenticatedController.new),
          guidelineLibraryRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create collection').last);
    await tester.pump();
    expect(find.text('Enter a collection name.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Ward rounds');
    await tester.enterText(find.byType(TextFormField).last, 'Rapid references');
    await tester.tap(find.text('Create collection').last);
    await tester.pumpAndSettle();

    expect(api.calls, contains('POST /api/v2/library/collections'));
    expect(find.text('Opened collection-1000'), findsOneWidget);
  });

  testWidgets('collection creation failure uses the canonical user message', (
    tester,
  ) async {
    final store = TestLocalStore();
    addTearDown(store.close);
    final api = FakeGuidelineLibraryApi();
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
    api
      ..nextFailureStatus = 409
      ..nextFailureCall = 'POST /api/v2/library/collections';

    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Duplicate');
    await tester.tap(find.text('Create collection').last);
    await tester.pumpAndSettle();

    expect(
      find.text('A collection with this name already exists.'),
      findsOneWidget,
    );
    expect(find.text('Collections'), findsOneWidget);
  });

  testWidgets('offline collection mutation gives actionable AppMessage', (
    tester,
  ) async {
    final store = TestLocalStore();
    addTearDown(store.close);
    final api = FakeGuidelineLibraryApi();
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
    api.failureStatus = 0;

    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Offline rounds');
    await tester.tap(find.text('Create collection').last);
    await tester.pumpAndSettle();

    expect(
      find.text('You are offline. Connect to make this change.'),
      findsOneWidget,
    );
    expect(api.collections, isEmpty);
  });

  testWidgets('collection creation disables duplicate submission', (
    tester,
  ) async {
    final store = TestLocalStore();
    addTearDown(store.close);
    final gate = Completer<void>();
    final api = FakeGuidelineLibraryApi()
      ..gatedCall = 'POST /api/v2/library/collections'
      ..callGate = gate;
    final repository = GuidelineLibraryRepository(api, store.cache);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const GuidelineCollectionsPage()),
        GoRoute(
          path: AppRoutes.collectionDetails,
          builder: (_, state) => Scaffold(
            body: Text('Opened ${state.pathParameters['collectionId']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_AuthenticatedController.new),
          guidelineLibraryRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'One request');
    await tester.tap(find.text('Create collection').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final action = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(action.onPressed, isNull);
    expect(
      api.calls
          .where((call) => call == 'POST /api/v2/library/collections')
          .length,
      1,
    );

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Opened collection-1000'), findsOneWidget);
  });

  testWidgets('collection detail supports edit with AppMessage feedback', (
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
        child: const MaterialApp(
          home: GuidelineCollectionPage(collectionId: 'collection-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit collection'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Renamed rounds');
    await tester.enterText(find.byType(TextFormField).last, 'New description');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Collection updated.'), findsOneWidget);
    expect(find.text('Renamed rounds'), findsWidgets);
    expect(find.text('New description'), findsOneWidget);
  });

  testWidgets('collection detail confirms deletion and returns to list', (
    tester,
  ) async {
    final store = TestLocalStore();
    addTearDown(store.close);
    final api = FakeGuidelineLibraryApi(collectionCount: 1);
    final repository = GuidelineLibraryRepository(api, store.cache);
    final router = GoRouter(
      initialLocation: AppRoutes.collection('collection-1'),
      routes: [
        GoRoute(
          path: AppRoutes.library,
          builder: (_, _) => const Scaffold(body: Text('Collection list')),
        ),
        GoRoute(
          path: AppRoutes.collectionDetails,
          builder: (_, state) => GuidelineCollectionPage(
            collectionId: state.pathParameters['collectionId']!,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_AuthenticatedController.new),
          guidelineLibraryRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Collection actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete collection'));
    await tester.pumpAndSettle();
    expect(find.text('Delete collection?'), findsOneWidget);
    expect(
      find.textContaining('Saved guidelines will not be deleted.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Collection list'), findsOneWidget);
    expect(api.collections, isEmpty);
  });

  testWidgets('published guideline can be saved from collection picker', (
    tester,
  ) async {
    final store = TestLocalStore();
    addTearDown(store.close);
    final api = FakeGuidelineLibraryApi(collectionCount: 1);
    final repository = GuidelineLibraryRepository(api, store.cache);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidelineLibraryRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: _SaveToCollectionHarness()),
      ),
    );
    await tester.tap(find.text('Open collection picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collection 1'));
    await tester.pumpAndSettle();

    expect(
      api.calls,
      contains('POST /api/v2/library/collections/collection-1/items'),
    );
    expect(find.text('Saved to Collection 1'), findsOneWidget);
    expect(api.items['collection-1'], hasLength(1));

    final addCalls = api.calls
        .where(
          (call) =>
              call == 'POST /api/v2/library/collections/collection-1/items',
        )
        .length;
    await tester.tap(find.text('Open collection picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collection 1'));
    await tester.pumpAndSettle();

    expect(find.text('Already saved in Collection 1'), findsOneWidget);
    expect(
      api.calls
          .where(
            (call) =>
                call == 'POST /api/v2/library/collections/collection-1/items',
          )
          .length,
      addCalls,
    );
  });

  testWidgets('empty collection offers a route to published guidelines', (
    tester,
  ) async {
    final store = TestLocalStore();
    addTearDown(store.close);
    final api = FakeGuidelineLibraryApi(collectionCount: 1);
    final repository = GuidelineLibraryRepository(api, store.cache);
    final router = GoRouter(
      initialLocation: AppRoutes.collection('collection-1'),
      routes: [
        GoRoute(
          path: AppRoutes.collectionDetails,
          builder: (_, state) => GuidelineCollectionPage(
            collectionId: state.pathParameters['collectionId']!,
          ),
        ),
        GoRoute(
          path: AppRoutes.publicGuidelines,
          builder: (_, _) => const Scaffold(body: Text('Guideline catalogue')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_AuthenticatedController.new),
          guidelineLibraryRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add guidelines'), findsOneWidget);
    await tester.tap(find.text('Add guidelines'));
    await tester.pumpAndSettle();

    expect(find.text('Guideline catalogue'), findsOneWidget);
  });

  testWidgets('saved guideline removal requires confirmation and updates UI', (
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
    await tester.tap(find.byTooltip('Remove from collection'));
    await tester.pumpAndSettle();
    expect(find.text('Remove guideline?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Guideline removed from collection.'), findsOneWidget);
    expect(find.text('No guidelines saved yet'), findsOneWidget);
    expect(api.items['collection-1'], isEmpty);
  });

  testWidgets('collection routes explain authentication when opened as guest', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_UnauthenticatedController.new),
        ],
        child: MaterialApp(
          builder: (context, child) => ResponsiveBreakpoints.builder(
            child: child!,
            breakpoints: const [
              Breakpoint(start: 0, end: 450, name: MOBILE),
              Breakpoint(start: 451, end: double.infinity, name: TABLET),
            ],
          ),
          home: const GuidelineCollectionsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in required'), findsOneWidget);
    expect(
      find.text('Sign in to create and sync your guideline collections.'),
      findsOneWidget,
    );
  });

  testWidgets('collections remain usable at 320px and 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = TestLocalStore();
    addTearDown(store.close);
    final api = FakeGuidelineLibraryApi(collectionCount: 1);
    api.collections[0] = {
      ...api.collections[0],
      'name': 'Emergency and critical care references',
      'description': 'A long description for a multidisciplinary ward team',
    };
    final repository = GuidelineLibraryRepository(api, store.cache);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_AuthenticatedController.new),
          guidelineLibraryRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          builder: (context, child) => ResponsiveBreakpoints.builder(
            child: child!,
            breakpoints: const [
              Breakpoint(start: 0, end: 450, name: MOBILE),
              Breakpoint(start: 451, end: double.infinity, name: TABLET),
            ],
          ),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 900),
              textScaler: TextScaler.linear(2),
            ),
            child: const GuidelineCollectionsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Emergency and critical care references'), findsOneWidget);
    expect(find.byTooltip('Collection actions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
