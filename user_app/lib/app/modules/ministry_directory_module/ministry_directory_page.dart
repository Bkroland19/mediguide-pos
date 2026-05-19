import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/ministry_directory.dart';
import '../../utils/app_spacing.dart';
import '../../widgets/filter_button.dart';
import '../../widgets/ministry_directory_card.dart';
import '../../widgets/pagination_indicators.dart';
import 'ministry_directory_controller.dart';

class MinistryDirectoryPage extends GetWidget<MinistryDirectoryController> {
  const MinistryDirectoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ministryDirectory'.tr),
        actions: [
          FilterButton(
            hasActiveFilters: controller.hasActiveFilters,
            onPressed: () => controller.showAdvancedFilter(context),
            onReset: controller.resetFilters,
            tooltip: 'filterDirectory'.tr,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            Future.sync(() => controller.pagingController.refresh()),
        child: PagingListener<int, MinistryDirectory>(
          controller: controller.pagingController,
          builder: (context, state, fetchNextPage) {
            return PagedListView<int, MinistryDirectory>(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              state: state,
              fetchNextPage: fetchNextPage,
              builderDelegate: PagedChildBuilderDelegate<MinistryDirectory>(
                itemBuilder: (context, entry, index) =>
                    MinistryDirectoryCard(entry: entry, index: index),

                // Error indicators
                firstPageErrorIndicatorBuilder: (context) =>
                    PaginationIndicators.firstPageError(
                      onRetry: fetchNextPage,
                      title: 'Failed to load directory',
                      subtitle: 'Please check your connection and try again',
                      icon: LucideIcons.phone,
                    ),

                newPageErrorIndicatorBuilder: (context) =>
                    PaginationIndicators.newPageError(
                      onRetry: fetchNextPage,
                      title: 'Failed to load more entries',
                      icon: LucideIcons.phone,
                    ),

                // Loading indicators
                firstPageProgressIndicatorBuilder: (context) =>
                    PaginationIndicators.firstPageProgress(),

                newPageProgressIndicatorBuilder: (context) =>
                    PaginationIndicators.newPageProgress(),

                // No items indicators
                noItemsFoundIndicatorBuilder: (context) {
                  return Obx(() {
                    String title;
                    String subtitle;

                    if (controller.hasActiveFilters.value) {
                      title = 'No entries match your filters';
                      subtitle = 'Try adjusting your search or filters';
                    } else {
                      title = 'No directory entries found';
                      subtitle =
                          'Directory entries will appear here when available';
                    }

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PaginationIndicators.noItemsFound(
                          icon: LucideIcons.phone,
                          title: title,
                          subtitle: subtitle,
                        ),
                        if (controller.hasActiveFilters.value) ...[
                          AppSpacing.md.gap,
                          ElevatedButton.icon(
                            onPressed: controller.resetFilters,
                            icon: const Icon(LucideIcons.x),
                            label: Text('clearFilters'.tr),
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
