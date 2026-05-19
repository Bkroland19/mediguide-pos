import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:toastification/toastification.dart';
import '../../data/services/backend_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/main_service.dart';
import '../../routes/app_pages.dart';
import '../../translations/app_translations.dart';
import '../../utils/app_spacing.dart';
import '../../utils/common.dart';
import '../../utils/responsive.dart';
import '../../widgets/profile_section_header.dart';
import '../../widgets/theme_bottom_sheet.dart';
import '../../widgets/language_bottom_sheet.dart';
import '../../widgets/user_avatar.dart';
import '../../utils/constants.dart';
import '../../utils/preference_utils.dart';
import 'edit_profile_dialog.dart';
import 'profile_controller.dart';

class ProfilePage extends GetWidget<ProfileController> {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
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
          // Profile Header
          Obx(() {
            final user = AuthService.to.currentUser.value;

            return Column(
              children: [
                // Avatar
                UserAvatar(
                  name: AuthService.to.userName,
                  avatarUrl: AuthService.to.userProfilePicture,
                  radius: Responsive.doubleValue(
                    context,
                    mobile: 40.0,
                    tablet: 50.0,
                    desktop: 60.0,
                  ),
                ),

                SizedBox(height: AppSpacing.md),

                // User Name
                Text(
                  user?.name ?? AppTranslationKey.user.tr,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Specialization (if available)
                if (user?.specialization.isNotEmpty == true) ...[
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    user!.specialization,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            );
          }),

          AppSpacing.gapXxl,

          // Account Settings Section
          ProfileSectionHeader(title: AppTranslationKey.accountSettings.tr),
          ListTile(
            leading: Icon(LucideIcons.user),
            title: Text(
              AppTranslationKey.editProfile.tr,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(AppTranslationKey.updatePersonalInformation.tr),
            trailing: Icon(LucideIcons.chevronRight),
            onTap: () async {
              if (!BackendService.to.supportsProfileEditing) {
                Common.quickToast(
                  type: ToastificationType.info,
                  title: AppTranslationKey.editProfile.tr,
                  description: BackendService.to
                      .unsupportedCollectionWriteMessage('users'),
                );
                return;
              }
              final result = await Get.dialog(
                const EditProfileDialog(),
                barrierDismissible: false,
              );
              // Optionally handle the result if needed
              if (result == true) {
                // Profile was updated, could refresh UI if needed
                controller.update();
              }
            },
            contentPadding: AppSpacing.listItemPadding,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(LucideIcons.lock),
            title: Text(
              AppTranslationKey.changePassword.tr,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(AppTranslationKey.updateSecurityCredentials.tr),
            trailing: Icon(LucideIcons.chevronRight),
            onTap: () {
              Common.quickToast(
                type: ToastificationType.info,
                title: AppTranslationKey.changePassword.tr,
                description:
                    'Password change is not exposed by the backend yet.',
              );
            },
            contentPadding: AppSpacing.listItemPadding,
          ),
          const Divider(height: 1),
          Obx(
            () => ListTile(
              leading: Icon(LucideIcons.fingerprintPattern),
              title: Text(
                AppTranslationKey.biometricAuthentication.tr,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                AuthService.to.isBiometricAvailable.value
                    ? AppTranslationKey.biometricAuthDesc.tr
                    : AppTranslationKey.biometricNotAvailable.tr,
              ),
              trailing: Switch(
                value: AuthService.to.isBiometricEnabled.value,
                onChanged: AuthService.to.isBiometricAvailable.value
                    ? (value) async {
                        final success = await AuthService.to
                            .toggleBiometricSetting(value);
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
                            description: AppTranslationKey
                                .failedToUpdateBiometricSettings
                                .tr,
                          );
                        }
                      }
                    : null,
              ),
              contentPadding: AppSpacing.listItemPadding,
            ),
          ),

          SizedBox(
            height: Responsive.doubleValue(
              context,
              mobile: 24.0,
              tablet: 32.0,
              desktop: 40.0,
            ),
          ),

          // App Preferences Section
          ProfileSectionHeader(title: AppTranslationKey.appPreferences.tr),
          ListTile(
            leading: Icon(LucideIcons.palette),
            title: Text(
              AppTranslationKey.theme.tr,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(_getThemeDisplayName()),
            trailing: Icon(LucideIcons.chevronRight),
            onTap: () => ThemeBottomSheet.show(),
            contentPadding: AppSpacing.listItemPadding,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(LucideIcons.languages),
            title: Text(
              AppTranslationKey.language.tr,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(controller.settings.languageDisplayName),
            trailing: Icon(LucideIcons.chevronRight),
            onTap: () => LanguageBottomSheet.show(),
            contentPadding: AppSpacing.listItemPadding,
          ),

          SizedBox(
            height: Responsive.doubleValue(
              context,
              mobile: 24.0,
              tablet: 32.0,
              desktop: 40.0,
            ),
          ),

          // Support & About Section
          ProfileSectionHeader(title: AppTranslationKey.supportAndAbout.tr),
          ListTile(
            leading: Icon(LucideIcons.info),
            title: Text(
              AppTranslationKey.helpCenter.tr,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(AppTranslationKey.getHelpAndSupport.tr),
            trailing: Icon(LucideIcons.chevronRight),
            onTap: () => Get.toNamed(AppRoutes.helpCenter),
            contentPadding: AppSpacing.listItemPadding,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(LucideIcons.messageCircle),
            title: Text(
              AppTranslationKey.frequentlyAskedQuestions.tr,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(AppTranslationKey.getAnswersToCommonQuestions.tr),
            trailing: Icon(LucideIcons.chevronRight),
            onTap: () => Get.toNamed(AppRoutes.faq),
            contentPadding: AppSpacing.listItemPadding,
          ),
          const Divider(height: 1),
          Obx(
            () => ListTile(
              leading: Icon(LucideIcons.download),
              title: Text(
                AppTranslationKey.checkForUpdate.tr,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                MainService.to.isCheckingForUpdate.value
                    ? AppTranslationKey.checkingForUpdates.tr
                    : AppTranslationKey.upToDate.tr,
              ),
              trailing: MainService.to.isCheckingForUpdate.value
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(LucideIcons.chevronRight),
              onTap: MainService.to.isCheckingForUpdate.value
                  ? null
                  : () => MainService.to.checkForUpdate(),
              contentPadding: AppSpacing.listItemPadding,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(LucideIcons.info),
            title: Text(
              AppTranslationKey.aboutMediGuide.tr,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(AppTranslationKey.appVersionAndInfo.tr),
            trailing: Icon(LucideIcons.chevronRight),
            onTap: () => Get.toNamed(AppRoutes.aboutUs),
            contentPadding: AppSpacing.listItemPadding,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(LucideIcons.fileText),
            title: Text(
              AppTranslationKey.termsAndPrivacy.tr,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(AppTranslationKey.legalInformation.tr),
            trailing: Icon(LucideIcons.chevronRight),
            onTap: () => Get.toNamed(AppRoutes.termsAndConditions),
            contentPadding: AppSpacing.listItemPadding,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(LucideIcons.star),
            title: Text(
              AppTranslationKey.rateApp.tr,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(AppTranslationKey.rateUsOnAppStore.tr),
            trailing: Icon(LucideIcons.chevronRight),
            onTap: () => controller.rateApp(),
            contentPadding: AppSpacing.listItemPadding,
          ),

          SizedBox(
            height: Responsive.doubleValue(
              context,
              mobile: 24.0,
              tablet: 32.0,
              desktop: 40.0,
            ),
          ),

          // Account Actions Section
          ProfileSectionHeader(title: AppTranslationKey.accountActions.tr),
          Obx(
            () => ListTile(
              leading: Icon(
                LucideIcons.logOut,
                color: context.theme.colorScheme.primary,
              ),
              title: Text(
                AppTranslationKey.signOut.tr,
                style: TextStyle(
                  color: context.theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(AppTranslationKey.signOutOfAccount.tr),
              trailing: controller.isLoading.value
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(LucideIcons.chevronRight),
              onTap: controller.isLoading.value
                  ? null
                  : () => controller.logout(),
              contentPadding: AppSpacing.listItemPadding,
            ),
          ),
          const Divider(height: 1),
          Obx(
            () => ListTile(
              leading: Icon(
                LucideIcons.trash2,
                color: context.theme.colorScheme.error,
              ),
              title: Text(
                AppTranslationKey.deleteAccount.tr,
                style: TextStyle(
                  color: context.theme.colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(AppTranslationKey.permanentlyDeleteAccount.tr),
              trailing: controller.isLoading.value
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(LucideIcons.chevronRight),
              onTap: controller.isLoading.value
                  ? null
                  : () => controller.deleteAccount(),
              contentPadding: AppSpacing.listItemPadding,
            ),
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

  /// Get current theme display name from SharedPreferences
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
}
