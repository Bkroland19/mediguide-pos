import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import '../../utils/app_spacing.dart';
import '../../data/models/models.dart';
import '../../data/services/backend_service.dart';
import '../../translations/app_translations.dart';
import '../../utils/common.dart';
import '../../widgets/pagination_indicators.dart';
import '../../../app/modules/help_center_module/help_center_controller.dart';
import 'widgets/create_ticket_dialog.dart';
import 'widgets/support_ticket_card.dart';
import 'package:toastification/toastification.dart';

class HelpCenterPage extends GetWidget<HelpCenterController> {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppTranslationKey.mySupportCenter),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.search),
              onPressed: () => controller.showFilterBottomSheet(context),
              tooltip: 'Filter tickets',
            ),
          ],
          bottom: TabBar(
            onTap: (index) => controller.updateStatusFilter(
              const ['all', 'open', 'inProgress', 'resolved', 'closed'][index],
            ),
            isScrollable: true,
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Open'),
              Tab(text: 'In Progress'),
              Tab(text: 'Resolved'),
              Tab(text: 'Closed'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (!BackendService.to.supportsSupportTickets) {
              Common.quickToast(
                type: ToastificationType.info,
                title: 'Support Center',
                description: BackendService.to
                    .unsupportedCollectionWriteMessage('support_tickets'),
              );
              return;
            }
            CreateTicketDialog.show();
          },
          child: const Icon(LucideIcons.plus),
        ),
        body: RefreshIndicator(
          onRefresh: () async => controller.refreshTickets(),
          child: PagingListener(
            controller: controller.pagingController,
            builder: (context, state, fetchNextPage) =>
                PagedListView<int, SupportTicket>.separated(
                  state: state,
                  fetchNextPage: fetchNextPage,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    indent: AppSpacing.md + 10 + AppSpacing.md,
                    color: context.theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                  builderDelegate: PagedChildBuilderDelegate<SupportTicket>(
                    itemBuilder: (context, ticket, index) =>
                        SupportTicketCard(ticket: ticket),

                    firstPageErrorIndicatorBuilder: (context) =>
                        PaginationIndicators.firstPageError(
                          onRetry: fetchNextPage,
                          title: 'Failed to load tickets',
                          subtitle:
                              'Please check your connection and try again',
                          icon: LucideIcons.messageCircle,
                        ),

                    newPageErrorIndicatorBuilder: (context) =>
                        PaginationIndicators.newPageError(
                          onRetry: fetchNextPage,
                          title: 'Error loading more tickets',
                          icon: LucideIcons.messageCircle,
                        ),

                    firstPageProgressIndicatorBuilder: (context) =>
                        PaginationIndicators.firstPageProgress(),

                    newPageProgressIndicatorBuilder: (context) =>
                        PaginationIndicators.newPageProgress(),

                    noItemsFoundIndicatorBuilder: (context) =>
                        PaginationIndicators.noItemsFound(
                          title: AppTranslationKey.noSupportTicketsYet,
                          subtitle:
                              AppTranslationKey.createYourFirstSupportTicket,
                          icon: LucideIcons.messageCircle,
                        ),

                    noMoreItemsIndicatorBuilder: (context) =>
                        PaginationIndicators.noMoreItems(),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
