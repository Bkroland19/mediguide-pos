import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/consultant.dart';
import '../../utils/app_spacing.dart';
import '../../widgets/filter_button.dart';
import '../../widgets/pagination_indicators.dart';
import 'consultants_controller.dart';
import 'widgets/consultant_card.dart';

class ConsultantsPage extends GetWidget<ConsultantsController> {
  const ConsultantsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('consultants'.tr),
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
        child: PagingListener<int, Consultant>(
          controller: controller.pagingController,
          builder: (context, state, fetchNextPage) {
            return PagedListView<int, Consultant>(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              state: state,
              fetchNextPage: fetchNextPage,
              builderDelegate: PagedChildBuilderDelegate<Consultant>(
                itemBuilder: (context, consultant, index) => ConsultantCard(
                  consultant: consultant,
                  onTap: () =>
                      controller.showConsultantDetail(context, consultant),
                ),

                // Error indicators
                firstPageErrorIndicatorBuilder: (context) =>
                    PaginationIndicators.firstPageError(
                      onRetry: fetchNextPage,
                      title: 'failedToLoadConsultants'.tr,
                      subtitle: 'pleaseCheckConnectionAndTryAgain'.tr,
                      icon: LucideIcons.userCheck,
                    ),

                newPageErrorIndicatorBuilder: (context) =>
                    PaginationIndicators.newPageError(
                      onRetry: fetchNextPage,
                      title: 'failedToLoadMoreConsultants'.tr,
                      icon: LucideIcons.userCheck,
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
                    title = 'noConsultantsMatchFilters'.tr;
                    subtitle = 'tryAdjustingSearchOrFilters'.tr;
                  } else {
                    title = 'noConsultantsFound'.tr;
                    subtitle = 'consultantsWillAppearHere'.tr;
                  }

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PaginationIndicators.noItemsFound(
                        title: title,
                        subtitle: subtitle,
                        icon: LucideIcons.userCheck,
                      ),
                      if (controller.hasActiveFilters.value) ...[
                        AppSpacing.md.gap,
                        ElevatedButton.icon(
                          onPressed: controller.clearAllFilters,
                          icon: const Icon(LucideIcons.x),
                          label: Text('clearFilters'.tr),
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
