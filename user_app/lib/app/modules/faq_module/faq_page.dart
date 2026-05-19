import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import '../../data/models/models.dart';
import '../../widgets/pagination_indicators.dart';
import '../../utils/app_spacing.dart';
import '../../translations/app_translations.dart';
import '../../widgets/filter_button.dart';
import 'faq_controller.dart';
import 'widgets/faq_expansion_item.dart';

class FaqPage extends GetWidget<FaqController> {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslationKey.frequentlyAskedQuestions.tr),
        actions: [
          FilterButton(
            hasActiveFilters: controller.hasActiveFilters,
            onPressed: () => controller.showFilterModal(context),
            onReset: controller.clearAllFilters,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => controller.refreshFAQs(),
        child: PagingListener(
          controller: controller.pagingController,
          builder: (context, state, fetchNextPage) => PagedListView<int, FAQ>(
            state: state,
            fetchNextPage: fetchNextPage,
            padding: AppSpacing.vPaddingSm,
            builderDelegate: PagedChildBuilderDelegate<FAQ>(
              itemBuilder: (context, faq, index) => FaqExpansionItem(faq: faq),
              firstPageErrorIndicatorBuilder: (context) =>
                  PaginationIndicators.firstPageError(
                    onRetry: fetchNextPage,
                    title: AppTranslationKey.failedToLoadFAQs.tr,
                    subtitle: AppTranslationKey.checkInternetAndRetry.tr,
                    icon: LucideIcons.messageCircle,
                  ),
              firstPageProgressIndicatorBuilder: (context) =>
                  PaginationIndicators.firstPageProgress(),
              newPageProgressIndicatorBuilder: (context) =>
                  PaginationIndicators.newPageProgress(),
              noItemsFoundIndicatorBuilder: (context) {
                final hasSearchQuery = controller.searchQuery.value.isNotEmpty;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PaginationIndicators.noItemsFound(
                      title: hasSearchQuery
                          ? AppTranslationKey.noFAQsFound.tr
                          : AppTranslationKey.noFAQsAvailable.tr,
                      subtitle: hasSearchQuery
                          ? AppTranslationKey.tryDifferentSearchTerm.tr
                          : AppTranslationKey.faqsWillAppearHere.tr,
                      icon: hasSearchQuery
                          ? LucideIcons.search
                          : LucideIcons.messageCircle,
                    ),
                    if (hasSearchQuery) ...[
                      AppSpacing.md.gap,
                      ElevatedButton.icon(
                        onPressed: controller.clearSearch,
                        icon: const Icon(LucideIcons.x),
                        label: Text(AppTranslationKey.clearSearch.tr),
                      ),
                    ],
                  ],
                );
              },
              newPageErrorIndicatorBuilder: (context) =>
                  PaginationIndicators.newPageError(
                    onRetry: fetchNextPage,
                    title: AppTranslationKey.errorLoadingMore.tr,
                    icon: LucideIcons.messageCircle,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
