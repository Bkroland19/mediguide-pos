import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/app_pages.dart';
import '../utils/constants.dart';
import '../utils/preference_utils.dart';

class OnboardingMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (!PreferenceUtils.containsKey(SharedPreferencesKeys.notFirstTime)) {
      return const RouteSettings(name: AppRoutes.onboarding);
    }

    return null;
  }
}
