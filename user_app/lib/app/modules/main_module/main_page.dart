import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../routes/app_pages.dart';
import '../../translations/app_translations.dart';
import '../../../app/modules/main_module/main_controller.dart';

class MainPage extends GetWidget<MainController> {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: FlexColorScheme.themedSystemNavigationBar(
        context,
        noAppBar: true,
        systemNavBarStyle: FlexSystemNavBarStyle.navigationBar,
      ),
      child: Scaffold(
        body: Navigator(
          key: Get.nestedKey(1),
          initialRoute: AppRoutes.home,
          onGenerateRoute: controller.onGenerateRoute,
        ),
        bottomNavigationBar: Obx(
          () => BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: controller.currentIndex.value,
            onTap: controller.setCurrentIndex,
            items: [
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.house),
                label: AppTranslationKey.home,
              ),
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.grid3x3),
                label: AppTranslationKey.moreInfo,
              ),
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.calculator),
                label: AppTranslationKey.tools,
              ),
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.user),
                label: AppTranslationKey.profile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
