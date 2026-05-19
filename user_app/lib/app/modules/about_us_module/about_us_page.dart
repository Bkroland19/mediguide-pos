import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../translations/app_translations.dart';
import '../../utils/app_spacing.dart';
import '../../utils/responsive.dart';
import '../../routes/app_pages.dart';
import 'about_us_controller.dart';

class AboutUsPage extends GetWidget<AboutUsController> {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppTranslationKey.aboutUs.tr,
          style: TextStyle(
            fontSize: Responsive.fontSize(
              context,
              mobile: 20.0,
              tablet: 22.0,
              desktop: 24.0,
            ),
          ),
        ),
        elevation: context.isMobile ? 0 : 2,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHorizontalPadding,
          vertical: context.responsiveVerticalPadding,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.maxContentWidth(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header Section with Logo
                Image.asset(
                  'assets/logo.png',
                  width: Responsive.doubleValue(
                    context,
                    mobile: 120.0,
                    tablet: 140.0,
                    desktop: 160.0,
                  ),
                  height: Responsive.doubleValue(
                    context,
                    mobile: 120.0,
                    tablet: 140.0,
                    desktop: 160.0,
                  ),
                  fit: BoxFit.contain,
                ),
                AppSpacing.gapLg,
                Text(
                  AppTranslationKey.aboutMediGuide.tr,
                  style: context.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapSm,
                Text(
                  '${AppTranslationKey.appVersion.tr} 1.0.0',
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.theme.colorScheme.onSurface.withValues(
                      alpha: 0.7,
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapSm,
                Text(
                  'Made with love by Gother Technologies',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),

                AppSpacing.contentGap,

                // Mission Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.target,
                          color: context.theme.colorScheme.primary,
                          size: Responsive.iconSize(context, mobile: 24.0),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          AppTranslationKey.ourMission.tr,
                          style: context.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapMd,
                    Text(
                      AppTranslationKey.missionDescription.tr,
                      style: context.textTheme.bodyLarge?.copyWith(height: 1.6),
                    ),
                  ],
                ),

                AppSpacing.contentGap,

                // Key Features Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.sparkles,
                          color: context.theme.colorScheme.primary,
                          size: Responsive.iconSize(context, mobile: 24.0),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          AppTranslationKey.keyFeatures.tr,
                          style: context.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapLg,
                    _FeatureItem(
                      icon: LucideIcons.bookOpen,
                      title: AppTranslationKey.guidelines.tr,
                      description:
                          AppTranslationKey.accessToClinicGuidelines.tr,
                    ),
                    _FeatureItem(
                      icon: LucideIcons.pillBottle,
                      title: AppTranslationKey.drugIndex.tr,
                      description:
                          AppTranslationKey.comprehensiveMedicationDatabase.tr,
                    ),
                    _FeatureItem(
                      icon: LucideIcons.stethoscope,
                      title: AppTranslationKey.consultants.tr,
                      description: AppTranslationKey.medicalExpertsDirectory.tr,
                    ),
                    _FeatureItem(
                      icon: LucideIcons.building2,
                      title: AppTranslationKey.healthInfrastructure.tr,
                      description:
                          AppTranslationKey.healthcareFacilitiesList.tr,
                    ),
                  ],
                ),

                AppSpacing.contentGap,

                // Contact & Support Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.headphones,
                          color: context.theme.colorScheme.primary,
                          size: Responsive.iconSize(context, mobile: 24.0),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          AppTranslationKey.contactSupport.tr,
                          style: context.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapMd,
                    ListTile(
                      leading: Icon(
                        LucideIcons.mail,
                        color: context.theme.colorScheme.onSurface,
                      ),
                      title: Text(AppTranslationKey.emailSupport.tr),
                      subtitle: const Text('support@mediguide.ug'),
                      trailing: Icon(LucideIcons.externalLink),
                      onTap: () =>
                          controller.launchEmail('support@mediguide.ug'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    ListTile(
                      leading: Icon(
                        LucideIcons.messageSquare,
                        color: context.theme.colorScheme.onSurface,
                      ),
                      title: Text(AppTranslationKey.feedback.tr),
                      subtitle: Text(AppTranslationKey.shareYourFeedback.tr),
                      trailing: Icon(LucideIcons.chevronRight),
                      onTap: () => Get.toNamed(AppRoutes.helpCenter),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),

                AppSpacing.contentGap,

                // Development Team Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.users,
                          color: context.theme.colorScheme.primary,
                          size: Responsive.iconSize(context, mobile: 24.0),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          AppTranslationKey.developmentTeam.tr,
                          style: context.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapMd,
                    Text(
                      'MediGuide is developed by a dedicated team of healthcare professionals and software engineers committed to improving healthcare delivery through technology.',
                      style: context.textTheme.bodyLarge?.copyWith(height: 1.6),
                    ),
                  ],
                ),

                AppSpacing.contentGap,

                // Legal Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.scale,
                          color: context.theme.colorScheme.primary,
                          size: Responsive.iconSize(context, mobile: 24.0),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          AppTranslationKey.legalInformation.tr,
                          style: context.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapMd,
                    ListTile(
                      leading: Icon(
                        LucideIcons.fileText,
                        color: context.theme.colorScheme.onSurface,
                      ),
                      title: Text(AppTranslationKey.termsAndPrivacy.tr),
                      subtitle: Text(AppTranslationKey.legalInformation.tr),
                      trailing: Icon(LucideIcons.chevronRight),
                      onTap: () => Get.toNamed(AppRoutes.termsAndConditions),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),

                AppSpacing.sectionGap,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: context.theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Icon(
              icon,
              size: Responsive.iconSize(context, mobile: 16.0),
              color: context.theme.colorScheme.primary,
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppSpacing.gapXs,
                Text(
                  description,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.theme.colorScheme.onSurface.withValues(
                      alpha: 0.7,
                    ),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
