import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../routes/app_pages.dart';

class MainController extends GetxController {
  MainController();

  // Navigation routes for bottom navigation bar
  var navigationRoutes = [
    AppRoutes.home,
    AppRoutes.allActions,
    AppRoutes.tools,
    AppRoutes.profile,
  ];

  var currentIndex = 0.obs;

  /// Sets the current tab index and navigates to the corresponding route
  void setCurrentIndex(int i) {
    if (currentIndex.value != i) {
      currentIndex.value = i;
      Get.offNamed(navigationRoutes[i], id: 1);
    }
  }

  /// Generates routes for nested navigation by reusing existing GetPage definitions
  Route? onGenerateRoute(RouteSettings settings) {
    Get.routing.args = settings.arguments;

    // Find the matching GetPage from existing app pages
    final matchingPage = AppPages.pages.firstWhereOrNull(
      (page) => page.name == settings.name,
    );

    if (matchingPage != null) {
      // Reuse the existing GetPage configuration
      return GetPageRoute(
        settings: settings,
        page: matchingPage.page,
        binding: matchingPage.binding,
        transition: matchingPage.transition ?? Transition.fadeIn,
      );
    }

    // Default to home route if no match found
    currentIndex(0);
    final homePage = AppPages.pages.firstWhereOrNull(
      (page) => page.name == AppRoutes.home,
    );

    if (homePage != null) {
      return GetPageRoute(
        settings: settings,
        page: homePage.page,
        binding: homePage.binding,
        transition: homePage.transition ?? Transition.fadeIn,
      );
    }

    return null;
  }
}
