import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:toastification/toastification.dart';

import '../../data/services/auth_service.dart';
import '../../data/services/main_service.dart';
import '../../routes/app_pages.dart';
import '../../translations/app_translations.dart';
import '../../utils/app_spacing.dart';
import '../../utils/common.dart';
import '../../utils/constants.dart';
import '../../utils/preference_utils.dart';
import '../../utils/responsive.dart';
import '../../widgets/language_bottom_sheet.dart';
import '../../widgets/theme_bottom_sheet.dart';
import '../../widgets/user_avatar.dart';

import 'change_password_bottom_sheet.dart';
import 'edit_profile_dialog.dart';
import 'profile_controller.dart';

class ProfilePage extends GetWidget<ProfileController> {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          AppTranslationKey.profile.tr,
          style: TextStyle(
            fontSize: Responsive.fontSize(
              context,
              mobile: 20.0,
              tablet: 22.0,
              desktop: 24.0,
            ),
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: context.isMobile ? 0 : 2,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHorizontalPadding,
          vertical: context.responsiveVerticalPadding,
        ),
        children: [
          _ProfileHeaderCard(onEditProfile: _showEditProfileDialog),

          AppSpacing.lg.gap,

          _SettingsSection(
            title: AppTranslationKey.accountSettings.tr,
            children: [
              _SettingsTile(
                icon: LucideIcons.user,
                title: AppTranslationKey.editProfile.tr,
                subtitle: AppTranslationKey.updatePersonalInformation.tr,
                onTap: _showEditProfileDialog,
              ),
              _SettingsTile(
                icon: LucideIcons.lock,
                title: AppTranslationKey.changePassword.tr,
                subtitle: AppTranslationKey.updateSecurityCredentials.tr,
                onTap: _showChangePasswordBottomSheet,
              ),
              Obx(
                () => _SettingsTile(
                  icon: LucideIcons.fingerprint,
                  title: AppTranslationKey.biometricAuthentication.tr,
                  subtitle: AuthService.to.isBiometricAvailable.value
                      ? AppTranslationKey.biometricAuthDesc.tr
                      : AppTranslationKey.biometricNotAvailable.tr,
                  trailing: Switch(
                    value: AuthService.to.isBiometricEnabled.value,
                    onChanged: AuthService.to.isBiometricAvailable.value
                        ? _toggleBiometric
                        : null,
                  ),
                  showChevron: false,
                ),
              ),
            ],
          ),

          AppSpacing.lg.gap,

          _SettingsSection(
            title: AppTranslationKey.appPreferences.tr,
            children: [
              _SettingsTile(
                icon: LucideIcons.palette,
                title: AppTranslationKey.theme.tr,
                subtitle: _getThemeDisplayName(),
                onTap: () => ThemeBottomSheet.show(),
              ),
              _SettingsTile(
                icon: LucideIcons.languages,
                title: AppTranslationKey.language.tr,
                subtitle: controller.settings.languageDisplayName,
                onTap: () => LanguageBottomSheet.show(),
              ),
            ],
          ),

          AppSpacing.lg.gap,

          _SettingsSection(
            title: AppTranslationKey.supportAndAbout.tr,
            children: [
              _SettingsTile(
                icon: LucideIcons.circleHelp,
                title: AppTranslationKey.helpCenter.tr,
                subtitle: AppTranslationKey.getHelpAndSupport.tr,
                onTap: () => Get.toNamed(AppRoutes.helpCenter),
              ),
              _SettingsTile(
                icon: LucideIcons.messageCircleQuestion,
                title: AppTranslationKey.frequentlyAskedQuestions.tr,
                subtitle: AppTranslationKey.getAnswersToCommonQuestions.tr,
                onTap: () => Get.toNamed(AppRoutes.faq),
              ),
              Obx(
                () => _SettingsTile(
                  icon: LucideIcons.download,
                  title: AppTranslationKey.checkForUpdate.tr,
                  subtitle: MainService.to.isCheckingForUpdate.value
                      ? AppTranslationKey.checkingForUpdates.tr
                      : AppTranslationKey.upToDate.tr,
                  trailing: MainService.to.isCheckingForUpdate.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.chevronRight),
                  showChevron: false,
                  onTap: MainService.to.isCheckingForUpdate.value
                      ? null
                      : () => MainService.to.checkForUpdate(),
                ),
              ),
              _SettingsTile(
                icon: LucideIcons.info,
                title: AppTranslationKey.aboutMediGuide.tr,
                subtitle: AppTranslationKey.appVersionAndInfo.tr,
                onTap: () => Get.toNamed(AppRoutes.aboutUs),
              ),
              _SettingsTile(
                icon: LucideIcons.fileText,
                title: AppTranslationKey.termsAndPrivacy.tr,
                subtitle: AppTranslationKey.legalInformation.tr,
                onTap: () => Get.toNamed(AppRoutes.termsAndConditions),
              ),
              _SettingsTile(
                icon: LucideIcons.star,
                title: AppTranslationKey.rateApp.tr,
                subtitle: AppTranslationKey.rateUsOnAppStore.tr,
                onTap: () => controller.rateApp(),
              ),
            ],
          ),

          AppSpacing.lg.gap,

          _SettingsSection(
            title: AppTranslationKey.accountActions.tr,
            children: [
              Obx(
                () => _SettingsTile(
                  icon: LucideIcons.logOut,
                  title: AppTranslationKey.signOut.tr,
                  subtitle: AppTranslationKey.signOutOfAccount.tr,
                  iconColor: cs.primary,
                  titleColor: cs.primary,
                  trailing: controller.isLoading.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.chevronRight),
                  showChevron: false,
                  onTap: controller.isLoading.value
                      ? null
                      : () => controller.logout(),
                ),
              ),
              Obx(
                () => _SettingsTile(
                  icon: LucideIcons.trash2,
                  title: AppTranslationKey.deleteAccount.tr,
                  subtitle: AppTranslationKey.permanentlyDeleteAccount.tr,
                  iconColor: cs.error,
                  titleColor: cs.error,
                  trailing: controller.isLoading.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(LucideIcons.chevronRight, color: cs.error),
                  showChevron: false,
                  onTap: controller.isLoading.value
                      ? null
                      : () => controller.deleteAccount(),
                ),
              ),
            ],
          ),

          SizedBox(
            height: Responsive.doubleValue(
              context,
              mobile: 48.0,
              tablet: 64.0,
              desktop: 80.0,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditProfileDialog() async {
    final result = await Get.dialog(
      const EditProfileDialog(),
      barrierDismissible: false,
    );

    if (result == true) {
      controller.update();
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    final success = await AuthService.to.toggleBiometricSetting(value);

    if (success) {
      Common.quickToast(
        type: ToastificationType.success,
        title: AppTranslationKey.biometricAuthentication.tr,
        description: value
            ? AppTranslationKey.biometricEnabled.tr
            : AppTranslationKey.biometricDisabled.tr,
      );
    } else {
      Common.quickToast(
        type: ToastificationType.error,
        title: AppTranslationKey.biometricAuthentication.tr,
        description: AppTranslationKey.failedToUpdateBiometricSettings.tr,
      );
    }
  }

  String _getThemeDisplayName() {
    final savedTheme = PreferenceUtils.getString(
      SharedPreferencesKeys.themeMode,
      ThemeModes.system,
    );

    switch (savedTheme) {
      case ThemeModes.light:
        return AppTranslationKey.lightMode.tr;
      case ThemeModes.dark:
        return AppTranslationKey.darkMode.tr;
      case ThemeModes.system:
      default:
        return AppTranslationKey.systemDefault.tr;
    }
  }

  void _showChangePasswordBottomSheet() {
    Get.bottomSheet(
      const ChangePasswordBottomSheet(),
      backgroundColor: Get.theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final VoidCallback onEditProfile;

  const _ProfileHeaderCard({required this.onEditProfile});

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;

    return Obx(() {
      final user = AuthService.to.currentUser.value;
      final name = user?.name ?? AppTranslationKey.user.tr;
      final specialization = user?.specialization ?? '';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: cs.primaryContainer.withValues(alpha: 0.35),
          border: Border.all(color: cs.primary.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                UserAvatar(
                  name: AuthService.to.userName,
                  avatarUrl: AuthService.to.userProfilePicture,
                  radius: Responsive.doubleValue(
                    context,
                    mobile: 42.0,
                    tablet: 52.0,
                    desktop: 60.0,
                  ),
                ),
                Material(
                  color: cs.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onEditProfile,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        LucideIcons.pencil,
                        color: cs.onPrimary,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            AppSpacing.md.gap,

            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),

            if (specialization.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  specialization,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            title,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  Divider(
                    height: 1,
                    indent: 64,
                    color: cs.outlineVariant.withValues(alpha: 0.35),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showChevron;
  final Color? iconColor;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.showChevron = true,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final effectiveIconColor = iconColor ?? cs.primary;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: effectiveIconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: effectiveIconColor, size: 21),
      ),
      title: Text(
        title,
        style: context.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: titleColor,
        ),
      ),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing:
          trailing ??
          (showChevron
              ? Icon(LucideIcons.chevronRight, color: cs.onSurfaceVariant)
              : null),
    );
  }
}
