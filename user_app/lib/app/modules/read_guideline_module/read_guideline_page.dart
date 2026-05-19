import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../utils/app_spacing.dart';
import '../../utils/responsive.dart';
import '../../utils/loading.dart';
import '../../widgets/ai_context_button.dart';
import '../../data/services/ai_context_service.dart';
import '../../data/models/ai_context.dart';
import 'read_guideline_controller.dart';
import 'widgets/guideline_header.dart';
import 'widgets/guideline_section.dart';

class ReadGuidelinePage extends GetWidget<ReadGuidelineController> {
  const ReadGuidelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => controller.guideline.value == null
          ? const Scaffold(body: CenteredLoading(loading: Loading.large()))
          : DefaultTabController(
              length: controller.availableSections.length,
              child: Scaffold(
                appBar: AppBar(
                  title: Text(
                    controller.guideline.value!.conditionName,
                    style: context.textTheme.titleMedium,
                  ),
                  actions: [
                    AiContextButton.iconButton(
                      context: _buildGuidelineContext(),
                    ),
                    Obx(
                      () => IconButton(
                        onPressed: controller.toggleBookmark,
                        icon: controller.isLoading.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                controller.isBookmarked.value
                                    ? LucideIcons.bookmark
                                    : LucideIcons.bookmarkPlus,
                              ),
                      ),
                    ),
                  ],
                  bottom: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: controller.availableSections
                        .map((section) => Tab(text: section.label))
                        .toList(),
                    onTap: (index) {
                      controller.navigateToSection(
                        controller.availableSections[index],
                      );
                    },
                  ),
                ),
                body: SingleChildScrollView(
                  controller: controller.scrollController,
                  padding: EdgeInsets.all(
                    Responsive.horizontalPadding(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GuidelineHeader(guideline: controller.guideline.value!),
                      AppSpacing.contentGap,
                      ...controller.availableSections.map(
                        (section) => GuidelineSectionWidget(
                          key: controller.getSectionKey(section),
                          section: section,
                          content: controller.getSectionContent(section),
                        ),
                      ),
                      AppSpacing.xxl.gap,
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  /// Build AI context from current guideline data
  AiContext _buildGuidelineContext() {
    if (controller.guideline.value == null) {
      return QuickAiContext.guideline(
        title: 'Medical Guideline',
        content: 'No guideline content available',
      );
    }

    final guideline = controller.guideline.value!;

    // Build guideline data map from available sections
    final guidelineData = <String, dynamic>{};
    for (final section in controller.availableSections) {
      final content = controller.getSectionContent(section);
      if (content.isNotEmpty) {
        guidelineData[section.label] = content;
      }
    }

    return AiContextService.to.extractGuidelineContext(
      conditionName: guideline.conditionName,
      guidelineData: guidelineData,
      guidelineId: guideline.id,
    );
  }
}
