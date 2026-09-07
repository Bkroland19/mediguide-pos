import 'package:user_app/features/library/data/models/guideline_library_models.dart';

final class GuidelineCollectionState {
  const GuidelineCollectionState({
    required this.collection,
    required this.items,
    required this.page,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
    this.isLoadingMore = false,
    this.isMutating = false,
    this.isOffline = false,
  });

  factory GuidelineCollectionState.fromResults(
    GuidelineCollectionDetail collection,
    GuidelineCollectionItemPage page,
  ) => GuidelineCollectionState(
    collection: collection,
    items: page.items,
    page: page.page,
    perPage: page.perPage,
    totalItems: page.totalItems,
    totalPages: page.totalPages,
    isOffline: page.fromCache,
  );

  final GuidelineCollectionDetail collection;
  final List<GuidelineCollectionItem> items;
  final int page;
  final int perPage;
  final int totalItems;
  final int totalPages;
  final bool isLoadingMore;
  final bool isMutating;
  final bool isOffline;

  bool get hasMore => page < totalPages;

  GuidelineCollectionState copyWith({
    GuidelineCollectionDetail? collection,
    List<GuidelineCollectionItem>? items,
    int? page,
    int? perPage,
    int? totalItems,
    int? totalPages,
    bool? isLoadingMore,
    bool? isMutating,
    bool? isOffline,
  }) => GuidelineCollectionState(
    collection: collection ?? this.collection,
    items: items ?? this.items,
    page: page ?? this.page,
    perPage: perPage ?? this.perPage,
    totalItems: totalItems ?? this.totalItems,
    totalPages: totalPages ?? this.totalPages,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isMutating: isMutating ?? this.isMutating,
    isOffline: isOffline ?? this.isOffline,
  );
}
