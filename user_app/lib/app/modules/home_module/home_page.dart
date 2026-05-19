import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:user_app/app/routes/app_pages.dart';
import '../../translations/app_translations.dart';
import '../../utils/app_spacing.dart';
import '../../utils/loading.dart';
import '../../utils/responsive.dart';
import '../../utils/common.dart';
import '../../data/services/auth_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/global_search_delegate.dart';
import './home_controller.dart';
import './widgets/quick_action_card.dart';
import './widgets/continue_reading_card.dart';
import './widgets/featured_calculator_card.dart';
import '../../widgets/section_header.dart';

import '../tree_selector_module/models/tree_selector_models.dart';
import '../tree_selector_module/tree_selector_page.dart';

class HomePage extends GetWidget<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello,',
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              AuthService.to.userName,
              style: context.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () =>
                showSearch(context: context, delegate: GlobalSearchDelegate()),
            icon: const Icon(LucideIcons.search),
          ),
          IconButton(
            onPressed: () => Get.toNamed(AppRoutes.notifications),
            icon: const Icon(LucideIcons.bell),
          ),
        ],
      ),
      floatingActionButton: Obx(() {
        final unread = controller.unreadMessagesCount.value;
        return FloatingActionButton.small(
          onPressed: () => Get.toNamed(AppRoutes.chatList),
          backgroundColor: cs.primary,
          child: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : unread.toString()),
            child: Icon(
              LucideIcons.messageCircle,
              color: cs.onPrimary,
              size: 20,
            ),
          ),
        );
      }),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: Loading.large());
        }

        return RefreshIndicator(
          onRefresh: controller.refreshData,
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: context.responsiveHorizontalPadding,
              vertical: AppSpacing.sm,
            ),
            children: [
              // ── Guidelines (Blue & Red channels) ──
              SectionHeader(
                title: AppTranslationKey.guidelines,
                subtitle: AppTranslationKey.accessTreatmentGuidelines,
                icon: LucideIcons.bookOpen,
              ),
              AppSpacing.md.gap,
              GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1 / .5,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  QuickActionCards.blueChannel(
                    title: AppTranslationKey.blueChannel,
                    subtitle: AppTranslationKey.primaryGuidelines,
                    onTap: () => Get.toNamed(
                      AppRoutes.guidelinesIndexer,
                      arguments: {'channel': 'blue'},
                    ),
                  ),
                  QuickActionCards.redChannel(
                    title: AppTranslationKey.redChannel,
                    subtitle: AppTranslationKey.emergencyProtocols,
                    onTap: () => Get.toNamed(
                      AppRoutes.guidelinesIndexer,
                      arguments: {'channel': 'red'},
                    ),
                  ),
                ],
              ),

              AppSpacing.lg.gap,

              // ── AI Assistant banner ──
              GestureDetector(
                onTap: () => Get.toNamed(AppRoutes.aiAssistant),
                child: GlassCard.compact(
                  baseColor: cs.primaryContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 4,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          LucideIcons.bot,
                          size: 20,
                          color: cs.primary,
                        ),
                      ),
                      AppSpacing.hGapMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppTranslationKey.aiChatAssistant,
                              style: context.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              AppTranslationKey.getInstantMedicalAssistance,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        LucideIcons.arrowRight,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),

              AppSpacing.lg.gap,

              // ── Quick Access (horizontal scroll) ──
              SectionHeader(
                title: AppTranslationKey.quickActions,
                subtitle: AppTranslationKey.accessEssentialFeatures,
                icon: LucideIcons.zap,
                onSeeAll: () => Get.toNamed(AppRoutes.allActions),
              ),
              AppSpacing.md.gap,
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _QuickAccessTile(
                      icon: LucideIcons.pill,
                      label: AppTranslationKey.drugIndex,
                      color: Colors.blue,
                      onTap: () => Get.toNamed(AppRoutes.drugIndex),
                    ),
                    _QuickAccessTile(
                      icon: LucideIcons.messageCircle,
                      label: AppTranslationKey.chatWithConsultant,
                      color: Colors.teal,
                      onTap: () async {
                        final result = await TreeSelectorPage.show(
                          config: TreeSelectorConfig(
                            title: AppTranslationKey.chatWithConsultant,
                            endpointPath: '/api/consultants/tree',
                          ),
                        );
                        if (result != null) {
                          Get.toNamed(
                            AppRoutes.consultants,
                            arguments: {'treeFilters': result.filters},
                          );
                        }
                      },
                    ),
                    _QuickAccessTile(
                      icon: LucideIcons.mapPin,
                      label: AppTranslationKey.healthInfrastructure,
                      color: Colors.orange,
                      onTap: () async {
                        final result = await TreeSelectorPage.show(
                          config: TreeSelectorConfig(
                            title: AppTranslationKey.healthInfrastructure,
                            endpointPath: '/api/health-facilities/tree',
                          ),
                        );
                        if (result != null) {
                          Get.toNamed(
                            AppRoutes.healthInfrastructure,
                            arguments: {'treeFilters': result.filters},
                          );
                        }
                      },
                    ),
                    _QuickAccessTile(
                      icon: LucideIcons.phone,
                      label: AppTranslationKey.emergencyContacts,
                      color: Colors.red,
                      onTap: () async {
                        final result = await TreeSelectorPage.show(
                          config: TreeSelectorConfig(
                            title: AppTranslationKey.emergencyContacts,
                            endpointPath: '/api/ministry-directory/tree',
                          ),
                        );
                        if (result != null) {
                          Get.toNamed(
                            AppRoutes.ministryDirectory,
                            arguments: {'treeFilters': result.filters},
                          );
                        }
                      },
                    ),
                    _QuickAccessTile(
                      icon: LucideIcons.bookText,
                      label: AppTranslationKey.medicalAbbreviations,
                      color: Colors.indigo,
                      onTap: () => Get.toNamed(AppRoutes.abbreviations),
                    ),
                    _QuickAccessTile(
                      icon: LucideIcons.info,
                      label: 'FAQs',
                      color: Colors.blueGrey,
                      onTap: () => Get.toNamed(AppRoutes.faq),
                    ),
                  ],
                ),
              ),

              AppSpacing.lg.gap,

              // ── Continue Reading ──
              if (controller.continueReadingItems.isNotEmpty) ...[
                SectionHeader(
                  title: AppTranslationKey.continueReading,
                  subtitle: AppTranslationKey.resumeWhereYouLeftOff,
                  icon: LucideIcons.bookOpen,
                  onSeeAll: () {
                    Common.quickToast(
                      title: 'Reading',
                      description: AppTranslationKey.openingReadingLibrary,
                    );
                  },
                ),
                AppSpacing.md.gap,
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.continueReadingItems.length,
                    separatorBuilder: (_, _) => AppSpacing.md.gap,
                    itemBuilder: (context, index) {
                      final progress = controller.continueReadingItems[index];
                      return ContinueReadingCard(
                        progress: progress,
                        onTap: () =>
                            controller.navigateToContinueReading(progress),
                      );
                    },
                  ),
                ),
                AppSpacing.lg.gap,
              ],

              // ── Featured Tools ──
              if (controller.featuredCalculators.isNotEmpty) ...[
                SectionHeader(
                  title: AppTranslationKey.featuredTools,
                  subtitle: AppTranslationKey.essentialCalculatorsAndTools,
                  icon: LucideIcons.calculator,
                  onSeeAll: () => Get.toNamed(AppRoutes.tools),
                ),
                AppSpacing.md.gap,
                SizedBox(
                  height: 140,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.featuredCalculators.length,
                    separatorBuilder: (_, _) => AppSpacing.sm.gap,
                    itemBuilder: (context, index) {
                      final calculator = controller.featuredCalculators[index];
                      return FeaturedCalculatorChip(
                        calculator: calculator,
                        onTap: () => Get.toNamed(
                          AppRoutes.useCalculator,
                          arguments: calculator,
                        ),
                      );
                    },
                  ),
                ),
              ],

              AppSpacing.xxxl.gap,
            ],
          ),
        );
      }),
    );
  }
}

/// Compact icon tile for horizontal quick access scroll.
class _QuickAccessTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: context.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: context.theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
