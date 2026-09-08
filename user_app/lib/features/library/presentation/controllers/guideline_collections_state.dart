import 'package:user_app/features/library/data/models/guideline_library_models.dart';

final class GuidelineCollectionsState {
  const GuidelineCollectionsState({
    required this.items,
    required this.page,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
    this.isLoadingMore = false,
    this.isMutating = false,
  });

  factory GuidelineCollectionsState.fromPage(GuidelineCollectionPage page) =>
      GuidelineCollectionsState(
        items: page.items,
        page: page.page,
        perPage: page.perPage,
        totalItems: page.totalItems,
        totalPages: page.totalPages,
      );

  final List<GuidelineCollectionSummary> items;
  final int page;
  final int perPage;
  final int totalItems;
  final int totalPages;
  final bool isLoadingMore;
  final bool isMutating;

  bool get hasMore => page < totalPages;

  GuidelineCollectionsState copyWith({
    List<GuidelineCollectionSummary>? items,
    int? page,
    int? perPage,
    int? totalItems,
    int? totalPages,
    bool? isLoadingMore,
    bool? isMutating,
  }) => GuidelineCollectionsState(
    items: items ?? this.items,
    page: page ?? this.page,
    perPage: perPage ?? this.perPage,
    totalItems: totalItems ?? this.totalItems,
    totalPages: totalPages ?? this.totalPages,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isMutating: isMutating ?? this.isMutating,
  );
}
