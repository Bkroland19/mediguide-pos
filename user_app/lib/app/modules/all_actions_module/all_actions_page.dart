import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:user_app/app/routes/app_pages.dart';
import '../../translations/app_translations.dart';
import '../../utils/loading.dart';
import '../../utils/app_spacing.dart';
import '../../widgets/section_group.dart';
import './all_actions_controller.dart';

class AllActionsPage extends GetWidget<AllActionsController> {
  const AllActionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppTranslationKey.allActions)),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        children: [
          SectionGroup(
            title: 'Clinical Tools',
            items: [
              ActionItem(
                icon: LucideIcons.pill,
                iconBgColor: Colors.blue,
                title: 'Essential Medicines List 2017',
                subtitle: 'WHO essential medicines reference',
                onTap: controller.navigateToEssentialMedicines,
              ),
              ActionItem(
                icon: LucideIcons.fileText,
                iconBgColor: Colors.teal,
                title: 'Clinical Care Algorithms',
                subtitle: 'Clinical decision support tools',
                onTap: controller.navigateToClinicalAlgorithms,
              ),
              ActionItem(
                icon: LucideIcons.shield,
                iconBgColor: Colors.orange,
                title: 'Infection Prevention Guidelines',
                subtitle: 'Infection control protocols',
                onTap: controller.navigateToInfectionPrevention,
              ),
            ],
          ),
          AppSpacing.gapMd,
          SectionGroup(
            title: 'AI & Reference',
            items: [
              ActionItem(
                icon: LucideIcons.bot,
                iconBgColor: Colors.deepPurple,
                title: AppTranslationKey.aiChatAssistant,
                subtitle: AppTranslationKey.getInstantMedicalAssistance,
                onTap: controller.navigateToAIChat,
              ),
              ActionItem(
                icon: LucideIcons.bookText,
                iconBgColor: Colors.indigo,
                title: AppTranslationKey.medicalAbbreviations,
                subtitle: AppTranslationKey.lookupMedicalTerms,
                onTap: () => Get.toNamed(AppRoutes.abbreviations),
              ),
            ],
          ),
          AppSpacing.gapMd,
          Obx(() {
            if (controller.isLoadingPages.value) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: CenteredLoading(loading: Loading.medium()),
              );
            }
            if (controller.genericPages.isEmpty) return const SizedBox.shrink();
            return SectionGroup(
              title: 'Additional Content',
              items: controller.genericPages
                  .map(
                    (page) => ActionItem(
                      icon: LucideIcons.fileText,
                      iconBgColor: Colors.blueGrey,
                      title: page.title,
                      subtitle: page.description ?? 'Tap to view content',
                      onTap: () => controller.navigateToGenericPage(page),
                    ),
                  )
                  .toList(),
            );
          }),
          AppSpacing.gapLg,
        ],
      ),
    );
  }
}
