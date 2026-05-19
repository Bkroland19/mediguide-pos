import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../data/models/models.dart';
import '../../translations/app_translations.dart';
import '../../utils/app_spacing.dart';
import '../../widgets/filter_button.dart';
import '../../widgets/pagination_indicators.dart';
import 'drug_index_controller.dart';
import 'widgets/drug_card.dart';

class DrugIndexPage extends GetWidget<DrugIndexController> {
  const DrugIndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslationKey.drugIndex),
        actions: [
          FilterButton(
            hasActiveFilters: controller.hasActiveFilters,
            onPressed: () => controller.showFilterModal(context),
            onReset: controller.clearAllFilters,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.sync(() => controller.refreshData()),
        child: PagingListener<int, Drug>(
          controller: controller.pagingController,
          builder: (context, state, fetchNextPage) {
            return PagedListView<int, Drug>(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              state: state,
              fetchNextPage: fetchNextPage,
              builderDelegate: PagedChildBuilderDelegate<Drug>(
                itemBuilder: (context, drug, index) => DrugCard(
                  drug: drug,
                  onTap: () => controller.navigateToDrugDetail(drug),
                  onBookmarkTap: () => controller.toggleBookmark(drug),
                ),

                // Error indicators
                firstPageErrorIndicatorBuilder: (context) =>
                    PaginationIndicators.firstPageError(
                      onRetry: fetchNextPage,
                      title: 'failedToLoadDrugs'.tr,
                      subtitle:
                          AppTranslationKey.pleaseCheckConnectionAndTryAgain,
                      icon: LucideIcons.pill,
                    ),

                newPageErrorIndicatorBuilder: (context) =>
                    PaginationIndicators.newPageError(
                      onRetry: fetchNextPage,
                      title: 'failedToLoadMoreDrugs'.tr,
                      icon: LucideIcons.pill,
                    ),

                // Loading indicators
                firstPageProgressIndicatorBuilder: (context) =>
                    PaginationIndicators.firstPageProgress(),

                newPageProgressIndicatorBuilder: (context) =>
                    PaginationIndicators.newPageProgress(),

                // No items indicators - inline logic
                noItemsFoundIndicatorBuilder: (context) {
                  String title;
                  String subtitle;

                  if (controller.hasActiveFilters.value) {
                    title = AppTranslationKey.noDrugsMatchFilters;
                    subtitle = AppTranslationKey.tryAdjustingSearchOrFilters;
                  } else {
                    title = 'noDrugsFound'.tr;
                    subtitle = AppTranslationKey.drugsWillAppearHere;
                  }

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PaginationIndicators.noItemsFound(
                        title: title,
                        subtitle: subtitle,
                        icon: LucideIcons.pill,
                      ),
                      if (controller.hasActiveFilters.value) ...[
                        AppSpacing.md.gap,
                        ElevatedButton.icon(
                          onPressed: controller.clearAllFilters,
                          icon: const Icon(LucideIcons.x),
                          label: Text(AppTranslationKey.clearFilters),
                        ),
                      ],
                    ],
                  );
                },

                noMoreItemsIndicatorBuilder: (context) =>
                    PaginationIndicators.noMoreItems(),
              ),
            );
          },
        ),
      ),
    );
  }
}
