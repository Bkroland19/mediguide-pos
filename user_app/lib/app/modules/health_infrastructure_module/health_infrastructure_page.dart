import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:user_app/app/translations/app_translations.dart';

import '../../data/models/health_facility.dart';
import '../../utils/app_spacing.dart';
import '../../widgets/filter_button.dart';
import '../../widgets/pagination_indicators.dart';
import 'health_infrastructure_controller.dart';
import 'widgets/health_facility_card.dart';

class HealthInfrastructurePage
    extends GetWidget<HealthInfrastructureController> {
  const HealthInfrastructurePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslationKey.healthInfrastructure.tr),
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
        child: PagingListener<int, HealthFacility>(
          controller: controller.pagingController,
          builder: (context, state, fetchNextPage) {
            return PagedListView<int, HealthFacility>.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              state: state,
              fetchNextPage: fetchNextPage,
              separatorBuilder: (_, _) => const SizedBox.shrink(),
              builderDelegate: PagedChildBuilderDelegate<HealthFacility>(
                itemBuilder: (context, facility, index) => HealthFacilityCard(
                  facility: facility,
                  onTap: () => controller.goToFacilityDetail(facility),
                  showDivider: true,
                ),

                // Error indicators
                firstPageErrorIndicatorBuilder: (context) =>
                    PaginationIndicators.firstPageError(
                      onRetry: fetchNextPage,
                      title: AppTranslationKey.failedToLoadFacilities.tr,
                      subtitle:
                          AppTranslationKey.pleaseCheckConnectionAndTryAgain.tr,
                      icon: LucideIcons.building2,
                    ),

                newPageErrorIndicatorBuilder: (context) =>
                    PaginationIndicators.newPageError(
                      onRetry: fetchNextPage,
                      title: AppTranslationKey.failedToLoadMoreFacilities.tr,
                      icon: LucideIcons.building2,
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
                    title = AppTranslationKey.noFacilitiesMatchFilters.tr;
                    subtitle = AppTranslationKey.tryAdjustingSearchOrFilters.tr;
                  } else {
                    title = AppTranslationKey.noFacilitiesFound.tr;
                    subtitle = AppTranslationKey.facilitiesWillAppearHere.tr;
                  }

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PaginationIndicators.noItemsFound(
                        title: title,
                        subtitle: subtitle,
                        icon: LucideIcons.building2,
                      ),
                      if (controller.hasActiveFilters.value) ...[
                        AppSpacing.md.gap,
                        ElevatedButton.icon(
                          onPressed: controller.clearAllFilters,
                          icon: const Icon(LucideIcons.x),
                          label: Text(AppTranslationKey.clearFilters.tr),
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
