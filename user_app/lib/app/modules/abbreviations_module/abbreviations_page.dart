import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:user_app/app/translations/app_translations.dart';

import '../../data/models/abbreviation.dart';
import '../../utils/app_spacing.dart';
import '../../widgets/filter_button.dart';
import '../../widgets/pagination_indicators.dart';
import 'abbreviations_controller.dart';
import 'widgets/abbreviation_card.dart';

class AbbreviationsPage extends GetWidget<AbbreviationsController> {
  const AbbreviationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslationKey.medicalAbbreviations),
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
        child: PagingListener<int, Abbreviation>(
          controller: controller.pagingController,
          builder: (context, state, fetchNextPage) {
            return PagedListView<int, Abbreviation>(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              state: state,
              fetchNextPage: fetchNextPage,
              builderDelegate: PagedChildBuilderDelegate<Abbreviation>(
                itemBuilder: (context, abbreviation, index) => AbbreviationCard(
                  abbreviation: abbreviation,
                  onTap: () =>
                      controller.showAbbreviationDetail(context, abbreviation),
                ),

                // Error indicators
                firstPageErrorIndicatorBuilder: (context) =>
                    PaginationIndicators.firstPageError(
                      onRetry: fetchNextPage,
                      title: AppTranslationKey.failedToLoadAbbreviations,
                      subtitle:
                          AppTranslationKey.pleaseCheckConnectionAndTryAgain,
                      icon: LucideIcons.bookOpen,
                    ),

                newPageErrorIndicatorBuilder: (context) =>
                    PaginationIndicators.newPageError(
                      onRetry: fetchNextPage,
                      title: AppTranslationKey.failedToLoadMoreAbbreviations,
                      icon: LucideIcons.bookOpen,
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
                    title = AppTranslationKey.noAbbreviationsMatchFilters;
                    subtitle = AppTranslationKey.tryAdjustingSearchOrFilters;
                  } else {
                    title = AppTranslationKey.noAbbreviationsFound;
                    subtitle = AppTranslationKey.abbreviationsWillAppearHere;
                  }

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PaginationIndicators.noItemsFound(
                        title: title,
                        subtitle: subtitle,
                        icon: LucideIcons.bookOpen,
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
