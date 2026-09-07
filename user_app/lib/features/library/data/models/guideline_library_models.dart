import 'package:user_app/core/network/contracts/generated/backend_contracts.dart';
import 'package:user_app/features/guidelines/data/models/guideline_publication.dart';

final class GuidelineCollectionSummary {
  const GuidelineCollectionSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.itemCount,
    this.createdAt,
    this.updatedAt,
  });

  factory GuidelineCollectionSummary.fromContract(
    ServicesGuidelineCollectionDTO value,
  ) => GuidelineCollectionSummary(
    id: value.id ?? '',
    name: value.name ?? '',
    description: value.description ?? '',
    itemCount: value.itemCount ?? 0,
    createdAt: DateTime.tryParse(value.createdAt ?? ''),
    updatedAt: DateTime.tryParse(value.updatedAt ?? ''),
  );

  factory GuidelineCollectionSummary.fromJson(Map<String, dynamic> value) =>
      GuidelineCollectionSummary(
        id: value['id']?.toString() ?? '',
        name: value['name']?.toString() ?? '',
        description: value['description']?.toString() ?? '',
        itemCount: (value['item_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(value['created_at']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(value['updated_at']?.toString() ?? ''),
      );

  final String id;
  final String name;
  final String description;
  final int itemCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'item_count': itemCount,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}

/// Collection detail currently has the same backend representation as its
/// summary. Keeping an explicit domain name lets detail APIs evolve without
/// coupling presentation code to generated transport contracts.
typedef GuidelineCollectionDetail = GuidelineCollectionSummary;

final class GuidelineCollectionItem {
  const GuidelineCollectionItem({
    required this.id,
    required this.guideline,
    required this.sortOrder,
    this.addedAt,
  });

  factory GuidelineCollectionItem.fromContract(
    ServicesGuidelineCollectionItemDTO value,
  ) {
    final guideline = value.guideline;
    if (guideline == null || (guideline.id ?? '').trim().isEmpty) {
      throw const FormatException('Collection item guideline is required');
    }
    return GuidelineCollectionItem(
      id: value.id ?? '',
      guideline: GuidelinePublication.fromJson(guideline.toJson()),
      sortOrder: value.sortOrder ?? 0,
      addedAt: DateTime.tryParse(value.addedAt ?? ''),
    );
  }

  factory GuidelineCollectionItem.fromJson(Map<String, dynamic> value) {
    final rawGuideline = value['guideline'];
    if (rawGuideline is! Map) {
      throw const FormatException('Collection item guideline is required');
    }
    final guideline = Map<String, dynamic>.from(rawGuideline);
    if ((guideline['id']?.toString() ?? '').trim().isEmpty) {
      throw const FormatException('Collection item guideline is required');
    }
    return GuidelineCollectionItem(
      id: value['id']?.toString() ?? '',
      guideline: GuidelinePublication.fromJson(guideline),
      sortOrder: (value['sort_order'] as num?)?.toInt() ?? 0,
      addedAt: DateTime.tryParse(value['added_at']?.toString() ?? ''),
    );
  }

  final String id;
  final GuidelinePublication guideline;
  final int sortOrder;
  final DateTime? addedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'guideline': guideline.toJson(),
    'sort_order': sortOrder,
    'added_at': addedAt?.toIso8601String(),
  };
}

final class GuidelineCollectionPage {
  const GuidelineCollectionPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
  });

  factory GuidelineCollectionPage.fromContract(
    HandlersPaginatedGuidelineCollections value,
  ) => GuidelineCollectionPage(
    items: value.items
        .map(GuidelineCollectionSummary.fromContract)
        .toList(growable: false),
    page: value.page ?? 1,
    perPage: value.perPage ?? value.items.length,
    totalItems: value.totalItems ?? value.items.length,
    totalPages: value.totalPages ?? (value.items.isEmpty ? 0 : 1),
  );

  factory GuidelineCollectionPage.fromJson(Map<String, dynamic> value) {
    final rawItems = value['items'] as List? ?? const [];
    final items = rawItems
        .whereType<Map>()
        .map(
          (item) => GuidelineCollectionSummary.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
    return GuidelineCollectionPage(
      items: items,
      page: (value['page'] as num?)?.toInt() ?? 1,
      perPage: (value['per_page'] as num?)?.toInt() ?? items.length,
      totalItems: (value['total_items'] as num?)?.toInt() ?? items.length,
      totalPages:
          (value['total_pages'] as num?)?.toInt() ?? (items.isEmpty ? 0 : 1),
    );
  }

  final List<GuidelineCollectionSummary> items;
  final int page;
  final int perPage;
  final int totalItems;
  final int totalPages;

  bool get hasMore => page < totalPages;

  Map<String, dynamic> toJson() => {
    'items': items.map((item) => item.toJson()).toList(growable: false),
    'page': page,
    'per_page': perPage,
    'total_items': totalItems,
    'total_pages': totalPages,
  };
}

final class GuidelineCollectionItemPage {
  const GuidelineCollectionItemPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
  });

  factory GuidelineCollectionItemPage.fromContract(
    HandlersPaginatedGuidelineCollectionItems value,
  ) => GuidelineCollectionItemPage(
    items: value.items
        .map(GuidelineCollectionItem.fromContract)
        .toList(growable: false),
    page: value.page ?? 1,
    perPage: value.perPage ?? value.items.length,
    totalItems: value.totalItems ?? value.items.length,
    totalPages: value.totalPages ?? (value.items.isEmpty ? 0 : 1),
  );

  factory GuidelineCollectionItemPage.fromJson(Map<String, dynamic> value) {
    final rawItems = value['items'] as List? ?? const [];
    final items = rawItems
        .whereType<Map>()
        .map(
          (item) =>
              GuidelineCollectionItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
    return GuidelineCollectionItemPage(
      items: items,
      page: (value['page'] as num?)?.toInt() ?? 1,
      perPage: (value['per_page'] as num?)?.toInt() ?? items.length,
      totalItems: (value['total_items'] as num?)?.toInt() ?? items.length,
      totalPages:
          (value['total_pages'] as num?)?.toInt() ?? (items.isEmpty ? 0 : 1),
    );
  }

  final List<GuidelineCollectionItem> items;
  final int page;
  final int perPage;
  final int totalItems;
  final int totalPages;

  bool get hasMore => page < totalPages;

  Map<String, dynamic> toJson() => {
    'items': items.map((item) => item.toJson()).toList(growable: false),
    'page': page,
    'per_page': perPage,
    'total_items': totalItems,
    'total_pages': totalPages,
  };
}

final class GuidelineDownloadRecord {
  const GuidelineDownloadRecord({
    required this.id,
    required this.guidelineId,
    required this.versionId,
    required this.assetType,
    this.downloadedAt,
  });

  factory GuidelineDownloadRecord.fromContract(
    ServicesGuidelineDownloadDTO value,
  ) => GuidelineDownloadRecord(
    id: value.id ?? '',
    guidelineId: value.guidelineId ?? '',
    versionId: value.versionId ?? '',
    assetType: value.assetType ?? '',
    downloadedAt: DateTime.tryParse(value.downloadedAt ?? ''),
  );

  factory GuidelineDownloadRecord.fromJson(Map<String, dynamic> value) =>
      GuidelineDownloadRecord(
        id: value['id']?.toString() ?? '',
        guidelineId: value['guideline_id']?.toString() ?? '',
        versionId: value['version_id']?.toString() ?? '',
        assetType: value['asset_type']?.toString() ?? '',
        downloadedAt: DateTime.tryParse(
          value['downloaded_at']?.toString() ?? '',
        ),
      );

  final String id;
  final String guidelineId;
  final String versionId;
  final String assetType;
  final DateTime? downloadedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'guideline_id': guidelineId,
    'version_id': versionId,
    'asset_type': assetType,
    'downloaded_at': downloadedAt?.toIso8601String(),
  };
}
