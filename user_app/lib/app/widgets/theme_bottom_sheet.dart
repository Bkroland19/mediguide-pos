import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../translations/app_translations.dart';
import '../utils/constants.dart';
import '../utils/preference_utils.dart';
import '../utils/app_spacing.dart';

/// Theme controller - minimal, focused on theme management only
class ThemeController extends GetxController {
  final RxString currentThemeMode = ThemeModes.system.obs;
  
  @override
  void onInit() {
    super.onInit();
    currentThemeMode.value = PreferenceUtils.getString(SharedPreferencesKeys.themeMode, ThemeModes.system);
  }

  ThemeMode _getThemeMode() => switch (currentThemeMode.value) {
    ThemeModes.light => ThemeMode.light,
    ThemeModes.dark => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setThemeMode(String mode) async {
    currentThemeMode.value = mode;
    await PreferenceUtils.setString(SharedPreferencesKeys.themeMode, mode);
    Get.changeThemeMode(_getThemeMode());
    update(); // Trigger GetBuilder update
    HapticFeedback.selectionClick();
  }
}

/// Compact theme selection bottom sheet
class ThemeBottomSheet extends StatelessWidget {
  const ThemeBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeController>(
      init: ThemeController(),
      builder: (controller) => Container(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: context.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppTranslationKey.chooseTheme.tr,
                style: context.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            AppSpacing.gapMd,
            Column(
              children: [
                _buildOption(context, controller, ThemeModes.light, AppTranslationKey.lightMode.tr, 
                            AppTranslationKey.lightModeDesc.tr, LucideIcons.sun),
                _buildOption(context, controller, ThemeModes.dark, AppTranslationKey.darkMode.tr, 
                            AppTranslationKey.darkModeDesc.tr, LucideIcons.moon),
                _buildOption(context, controller, ThemeModes.system, AppTranslationKey.systemDefault.tr, 
                            AppTranslationKey.systemDefaultDesc.tr, LucideIcons.monitor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, ThemeController controller, String mode, String title, String subtitle, IconData icon) {
    final isSelected = controller.currentThemeMode.value == mode;
    return ListTile(
      leading: Icon(icon, color: isSelected ? context.theme.colorScheme.primary : null),
      title: Text(title, style: TextStyle(
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        color: isSelected ? context.theme.colorScheme.primary : null,
      )),
      subtitle: Text(subtitle),
      trailing: isSelected ? Icon(LucideIcons.check, color: context.theme.colorScheme.primary, size: 20) : null,
      onTap: () async {
        await controller.setThemeMode(mode);
        Get.back();
      },
      contentPadding: AppSpacing.listItemPadding,
    );
  }

  static void show() {
    Get.bottomSheet(
      const ThemeBottomSheet(),
      backgroundColor: Get.theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      isScrollControlled: false,
      enableDrag: true,
      isDismissible: true,
    );
  }
}