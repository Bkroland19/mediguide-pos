import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:user_app/app/translations/app_translations.dart';

import '../../data/models/guideline.dart';
import '../../utils/app_spacing.dart';
import '../../widgets/filter_button.dart';
import '../../widgets/pagination_indicators.dart';
import '../../routes/app_pages.dart';
import 'guidelines_controller.dart';
import 'widgets/guideline_card.dart';

class GuidelinesPage extends GetWidget<GuidelinesController> {
  const GuidelinesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(
            controller.isInIndexMode.value
                ? controller.selectedIndex.value?.title ??
                      AppTranslationKey.clinicalGuidelines
                : AppTranslationKey.clinicalGuidelines,
          ),
        ),
        actions: [
          FilterButton(
            hasActiveFilters: controller.hasActiveFilters,
            onPressed: () => controller.showFilterModal(context),
            onReset: controller.clearAllFilters,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            Future.sync(() => controller.pagingController.refresh()),
        child: PagingListener<int, Guideline>(
          controller: controller.pagingController,
          builder: (context, state, fetchNextPage) {
            return PagedListView<int, Guideline>(
              padding: AppSpacing.hPaddingSm + AppSpacing.vPaddingSm,
              state: state,
              fetchNextPage: fetchNextPage,
              builderDelegate: PagedChildBuilderDelegate<Guideline>(
                itemBuilder: (context, guideline, index) => GuidelineCard(
                  guideline: guideline,
                  onTap: () => Get.toNamed(
                    AppRoutes.readGuideline,
                    arguments: guideline,
                  ),
                ),

                // Error indicators
                firstPageErrorIndicatorBuilder: (context) =>
                    PaginationIndicators.firstPageError(
                      onRetry: fetchNextPage,
                      title: AppTranslationKey.failedToLoadGuidelines,
                      subtitle:
                          AppTranslationKey.pleaseCheckConnectionAndTryAgain,
                      icon: LucideIcons.stethoscope,
                    ),

                newPageErrorIndicatorBuilder: (context) =>
                    PaginationIndicators.newPageError(
                      onRetry: fetchNextPage,
                      title: AppTranslationKey.failedToLoadMoreGuidelines,
                      icon: LucideIcons.stethoscope,
                    ),

                // Loading indicators
                firstPageProgressIndicatorBuilder: (context) =>
                    PaginationIndicators.firstPageProgress(),

                newPageProgressIndicatorBuilder: (context) =>
                    PaginationIndicators.newPageProgress(),

                // No items indicators - context-aware logic
                noItemsFoundIndicatorBuilder: (context) {
                  return Obx(() {
                    String title;
                    String subtitle;

                    if (controller.isInIndexMode.value) {
                      // In index mode
                      if (controller.hasActiveFilters.value) {
                        title = 'No Guidelines Match Filters';
                        subtitle =
                            'No guidelines found in "${controller.selectedIndex.value?.title}" matching your filters';
                      } else {
                        title = 'No Guidelines in Index';
                        subtitle =
                            'No guidelines found in "${controller.selectedIndex.value?.title}"';
                      }
                    } else {
                      // All guidelines mode
                      if (controller.hasActiveFilters.value) {
                        title = AppTranslationKey.noGuidelinesMatchFilters;
                        subtitle =
                            AppTranslationKey.tryAdjustingSearchOrFilters;
                      } else {
                        title = AppTranslationKey.noGuidelinesFound;
                        subtitle = AppTranslationKey.guidelinesWillAppearHere;
                      }
                    }

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PaginationIndicators.noItemsFound(
                          title: title,
                          subtitle: subtitle,
                          icon: LucideIcons.stethoscope,
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
                  });
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
