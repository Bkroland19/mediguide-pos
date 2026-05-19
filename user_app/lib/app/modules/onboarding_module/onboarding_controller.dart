import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:introduction_screen/introduction_screen.dart';
import '../../routes/app_pages.dart';
import '../../utils/constants.dart';
import '../../utils/preference_utils.dart';

class OnboardingController extends GetxController {
  OnboardingController();

  final introKey = GlobalKey<IntroductionScreenState>();

  void onIntroEnd() async {
    await PreferenceUtils.setBool(SharedPreferencesKeys.notFirstTime, true);
    Get.offAllNamed(AppRoutes.login);
  }

  void onPageCompleted(int page) {
    // Optional: Track which pages user has seen
  }

  void skipOnboarding() async {
    await PreferenceUtils.setBool(SharedPreferencesKeys.notFirstTime, true);
    Get.offAllNamed(AppRoutes.login);
  }
}
