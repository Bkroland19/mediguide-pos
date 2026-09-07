import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/network/contracts/generated/backend_contracts.dart';
import 'package:user_app/features/library/data/models/guideline_library_models.dart';

void main() {
  test('collection summary preserves detail fields and timestamps', () {
    final summary = GuidelineCollectionSummary.fromContract(
      ServicesGuidelineCollectionDTO.fromJson({
        'id': 'collection-1',
        'name': 'Ward round',
        'description': 'Daily clinical references',
        'item_count': 3,
        'created_at': '2026-09-01T08:00:00Z',
        'updated_at': '2026-09-02T09:30:00Z',
      }),
    );

    expect(summary.id, 'collection-1');
    expect(summary.name, 'Ward round');
    expect(summary.description, 'Daily clinical references');
    expect(summary.itemCount, 3);
    expect(summary.createdAt, DateTime.utc(2026, 9, 1, 8));
    expect(summary.updatedAt, DateTime.utc(2026, 9, 2, 9, 30));

    final GuidelineCollectionDetail detail = summary;
    expect(
      GuidelineCollectionSummary.fromJson(detail.toJson()).toJson(),
      detail.toJson(),
    );
  });

  test('collection page maps generated pagination metadata', () {
    final page = GuidelineCollectionPage.fromContract(
      HandlersPaginatedGuidelineCollections.fromJson({
        'items': [
          {
            'id': 'collection-1',
            'name': 'Emergency care',
            'description': '',
            'item_count': 2,
          },
        ],
        'page': 1,
        'per_page': 1,
        'total_items': 2,
        'total_pages': 2,
      }),
    );

    expect(page.items.single.name, 'Emergency care');
    expect(page.totalItems, 2);
    expect(page.hasMore, isTrue);

    final restored = GuidelineCollectionPage.fromJson(page.toJson());
    expect(restored.items.single.id, 'collection-1');
    expect(restored.totalPages, 2);
  });

  test('collection item maps a typed published guideline and round trips', () {
    final item = GuidelineCollectionItem.fromContract(
      ServicesGuidelineCollectionItemDTO.fromJson({
        'id': 'item-1',
        'sort_order': 4,
        'added_at': '2026-09-03T10:15:00Z',
        'guideline': {
          'id': 'guideline-1',
          'slug': 'malaria-care',
          'title': 'Malaria care',
          'description': 'Approved malaria guidance',
          'country': 'Uganda',
          'source_org': 'MOH',
          'program_area': 'Communicable diseases',
          'language': 'en',
          'publication_date': '2026-01-01',
          'review_date': '2027-01-01',
          'version': '2.1',
          'last_updated': '2026-09-03T09:00:00Z',
          'intended_population': 'Adults',
          'healthcare_level': 'All levels',
        },
      }),
    );

    expect(item.guideline.id, 'guideline-1');
    expect(item.guideline.title, 'Malaria care');
    expect(item.guideline.sourceOrganization, 'MOH');
    expect(item.sortOrder, 4);
    expect(item.addedAt, DateTime.utc(2026, 9, 3, 10, 15));

    final restored = GuidelineCollectionItem.fromJson(item.toJson());
    expect(restored.guideline, item.guideline);
    expect(restored.sortOrder, item.sortOrder);
  });

  test(
    'collection item page maps pagination and rejects missing guideline',
    () {
      final page = GuidelineCollectionItemPage.fromContract(
        HandlersPaginatedGuidelineCollectionItems.fromJson({
          'items': [
            {
              'id': 'item-1',
              'sort_order': 0,
              'guideline': {'id': 'guideline-1', 'title': 'Diabetes care'},
            },
          ],
          'page': 2,
          'per_page': 10,
          'total_items': 21,
          'total_pages': 3,
        }),
      );

      expect(page.items.single.guideline.title, 'Diabetes care');
      expect(page.page, 2);
      expect(page.hasMore, isTrue);
      expect(
        GuidelineCollectionItemPage.fromJson(page.toJson()).totalItems,
        21,
      );

      expect(
        () => GuidelineCollectionItem.fromContract(
          ServicesGuidelineCollectionItemDTO.fromJson({'id': 'broken'}),
        ),
        throwsFormatException,
      );
      expect(
        () => GuidelineCollectionItem.fromJson({
          'id': 'broken',
          'guideline': {'title': 'Missing identifier'},
        }),
        throwsFormatException,
      );
    },
  );
}
