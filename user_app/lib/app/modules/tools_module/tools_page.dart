import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../data/models/models.dart';
import '../../routes/app_pages.dart';
import '../../translations/app_translations.dart';
import '../../utils/app_spacing.dart';
import '../../widgets/filter_button.dart';
import '../../widgets/pagination_indicators.dart';
import '../../../app/modules/tools_module/tools_controller.dart';
import 'widgets/calculator_card.dart';

class ToolsPage extends GetWidget<ToolsController> {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: controller.selectedTabIndex.value,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('Tools'.tr),
          actions: [
            FilterButton(
              hasActiveFilters: controller.hasActiveFilters,
              onPressed: () => controller.showFilterModal(context),
              onReset: controller.clearAllFilters,
            ),
          ],
          bottom: TabBar(
            onTap: controller.onTabChanged,
            tabs: [
              Tab(text: AppTranslationKey.all),
              Tab(text: AppTranslationKey.calculator),
              Tab(text: AppTranslationKey.decisionTool),
              Tab(text: AppTranslationKey.checklist),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () => Future.sync(() => controller.refreshData()),
          child: PagingListener<int, Calculator>(
            controller: controller.pagingController,
            builder: (context, state, fetchNextPage) {
              return PagedListView<int, Calculator>(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                state: state,
                fetchNextPage: fetchNextPage,
                builderDelegate: PagedChildBuilderDelegate<Calculator>(
                  itemBuilder: (context, calculator, index) {
                    final isLast = index == (state.items?.length ?? 0) - 1;
                    return CalculatorTile(
                      calculator: calculator,
                      onTap: () => Get.toNamed(
                        AppRoutes.useCalculator,
                        arguments: calculator,
                      ),
                      showDivider: !isLast,
                    );
                  },

                  firstPageErrorIndicatorBuilder: (context) =>
                      PaginationIndicators.firstPageError(
                        onRetry: fetchNextPage,
                        title: 'Failed to load calculators',
                        subtitle: 'Please check your connection and try again',
                        icon: LucideIcons.calculator,
                      ),

                  newPageErrorIndicatorBuilder: (context) =>
                      PaginationIndicators.newPageError(
                        onRetry: fetchNextPage,
                        title: 'Failed to load more calculators',
                        icon: LucideIcons.calculator,
                      ),

                  firstPageProgressIndicatorBuilder: (context) =>
                      PaginationIndicators.firstPageProgress(),

                  newPageProgressIndicatorBuilder: (context) =>
                      PaginationIndicators.newPageProgress(),

                  noItemsFoundIndicatorBuilder: (context) {
                    final hasFilters = controller.hasActiveFilters.value;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PaginationIndicators.noItemsFound(
                          title: hasFilters
                              ? 'No calculators match filters'
                              : 'No calculators found',
                          subtitle: hasFilters
                              ? 'Try adjusting your search or filters'
                              : 'Calculators will appear here when available',
                          icon: LucideIcons.calculator,
                        ),
                        if (hasFilters) ...[
                          AppSpacing.gapMd,
                          ElevatedButton.icon(
                            onPressed: controller.clearAllFilters,
                            icon: const Icon(LucideIcons.x),
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
      ),
    );
  }
}
