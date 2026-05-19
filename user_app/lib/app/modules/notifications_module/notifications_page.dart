import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import '../../../app/modules/notifications_module/notifications_controller.dart';
import '../../data/models/models.dart';
import '../../utils/app_spacing.dart';
import '../../widgets/my_notification_card.dart';
import '../../widgets/pagination_indicators.dart';
import '../../widgets/filter_button.dart';
import '../../translations/app_translations.dart';

class NotificationsPage extends GetWidget<NotificationsController> {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslationKey.notifications),
        actions: [
          FilterButton(
            hasActiveFilters: controller.hasActiveFilters,
            onPressed: () => _showFilterModal(context),
            onReset: controller.clearAllFilters,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            Future.sync(() => controller.pagingController.refresh()),
        child: PagingListener<int, MyNotification>(
          controller: controller.pagingController,
          builder: (context, state, fetchNextPage) {
            return PagedListView<int, MyNotification>(
              padding: const EdgeInsets.all(AppSpacing.md),
              state: state,
              fetchNextPage: fetchNextPage,
              builderDelegate: PagedChildBuilderDelegate<MyNotification>(
                itemBuilder: (context, notification, index) =>
                    MyNotificationCard(
                      notification: notification,
                      onTap: () => _handleNotificationTap(notification),
                    ),

                firstPageErrorIndicatorBuilder: (context) =>
                    PaginationIndicators.firstPageError(
                      onRetry: fetchNextPage,
                      title: 'Failed to load notifications',
                      subtitle: 'Please check your connection and try again',
                    ),

                newPageErrorIndicatorBuilder: (context) =>
                    PaginationIndicators.newPageError(
                      onRetry: fetchNextPage,
                      title: 'Failed to load more notifications',
                    ),

                firstPageProgressIndicatorBuilder: (context) =>
                    PaginationIndicators.firstPageProgress(),

                newPageProgressIndicatorBuilder: (context) =>
                    PaginationIndicators.newPageProgress(),

                noItemsFoundIndicatorBuilder: (context) {
                  String title = controller.hasActiveFilters.value
                      ? 'No notifications match filters'
                      : 'No notifications found';
                  String subtitle = controller.hasActiveFilters.value
                      ? 'Try adjusting your search or filters'
                      : 'Notifications will appear here when available';

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PaginationIndicators.noItemsFound(
                        title: title,
                        subtitle: subtitle,
                      ),
                      if (controller.hasActiveFilters.value) ...[
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton.icon(
                          onPressed: controller.clearAllFilters,
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear Filters'),
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

  void _handleNotificationTap(MyNotification notification) {
    // Handle notification tap - could navigate to related content
    // For now, just show a simple message
    Get.snackbar(
      notification.title,
      notification.message,
      duration: const Duration(seconds: 3),
    );
  }

  void _showFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter Notifications', style: context.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),

            // Type filter
            Text('Type', style: context.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: ['', 'info', 'success', 'warning', 'error']
                  .map(
                    (type) => FilterChip(
                      label: Text(type.isEmpty ? 'All' : type.toUpperCase()),
                      selected: controller.selectedType.value == type,
                      onSelected: (_) => controller.setTypeFilter(type),
                    ),
                  )
                  .toList(),
            ),

            const SizedBox(height: AppSpacing.md),

            // Priority filter
            Text('Priority', style: context.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: ['', 'low', 'normal', 'high', 'urgent']
                  .map(
                    (priority) => FilterChip(
                      label: Text(
                        priority.isEmpty ? 'All' : priority.toUpperCase(),
                      ),
                      selected: controller.selectedPriority.value == priority,
                      onSelected: (_) => controller.setPriorityFilter(priority),
                    ),
                  )
                  .toList(),
            ),

            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      controller.clearAllFilters();
                      Navigator.pop(context);
                    },
                    child: const Text('Clear All'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
