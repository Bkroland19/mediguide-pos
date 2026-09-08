import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/network/api_client.dart';
import 'package:user_app/features/guidelines/data/repositories/guideline_publication_repository.dart';

import 'helpers/test_local_store.dart';

void main() {
  test('loads all chapter blocks through one content request', () async {
    final store = TestLocalStore();
    addTearDown(store.close);
    final api = _ContentBundleApi();
    final repository = GuidelinePublicationRepository(api, store.cache);

    final content = await repository.content('guideline-1');

    expect(content.sections, hasLength(2));
    expect(content.blocks, hasLength(1));
    expect(api.paths.where((path) => path.endsWith('/content')), hasLength(1));
    expect(api.paths.where((path) => path.contains('/sections')), isEmpty);
  });
}

final class _ContentBundleApi extends BackendApiService {
  final paths = <String>[];

  @override
  Future<Map<String, dynamic>> requestJson(
    String path, {
    required String method,
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool includeAuth = true,
  }) async {
    paths.add(path);
    if (path.endsWith('/manifest')) {
      return {
        'data': {
          'guideline_id': 'guideline-1',
          'version_id': 'version-1',
          'version': '1',
          'recommended_mode': 'structured',
          'has_chapters': true,
          'section_count': 2,
          'block_count': 1,
        },
      };
    }
    if (path.endsWith('/content')) {
      return {
        'data': {
          'sections': [
            {
              'id': 'parent',
              'title': 'Clinical care',
              'level': 1,
              'sort_order': 1,
            },
            {
              'id': 'child',
              'parent_id': 'parent',
              'title': 'Assessment',
              'level': 2,
              'sort_order': 2,
            },
          ],
          'blocks': [
            {
              'id': 'block-1',
              'section_id': 'child',
              'type': 'paragraph',
              'sort_order': 1,
              'content': {'text': 'Assess the patient'},
            },
          ],
        },
      };
    }
    if (path.endsWith('/figures')) {
      return {
        'data': {'items': <Map<String, dynamic>>[]},
      };
    }
    return {
      'data': {
        'id': 'guideline-1',
        'title': 'Clinical guideline',
        'version': '1',
      },
    };
  }
}
