import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_app_update/in_app_update.dart';
import '../../../app/utils/common.dart';
import '../../../app/translations/app_translations.dart';
import '../../../app/utils/preference_utils.dart';
import '../../../app/utils/constants.dart';
import 'package:toastification/toastification.dart';

/// MainService handles app updates, language initialization, and network connectivity
class MainService extends GetxService {
  static MainService get to => Get.find();

  final RxBool isCheckingForUpdate = false.obs;
  
  // Connectivity properties
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  
  final RxBool isOnline = false.obs;
  final RxBool wasOffline = false.obs;
  
  Future<MainService> init() async {
    // Initialize language settings
    await _initializeLanguage();
    
    // Initialize connectivity monitoring
    await _initConnectivity();
    _startListening();
    
    // Check for app updates on Android
    if (Platform.isAndroid) checkForUpdate(showToast: false);
    return this;
  }

  @override
  void onClose() {
    _connectivitySubscription.cancel();
    super.onClose();
  }

  /// Initialize language settings on app startup
  Future<void> _initializeLanguage() async {
    try {
      // Load saved language from preferences
      final savedLanguageCode = PreferenceUtils.getString(SharedPreferencesKeys.language, 'en');
      
      // Set the initial GetX locale
      final locale = _getLocaleForCode(savedLanguageCode);
      Get.updateLocale(locale);
      
    } catch (e) {
      // Fallback to English if something goes wrong
      Get.updateLocale(const Locale('en', 'US'));
    }
  }

  /// Convert language code to locale for initialization
  Locale _getLocaleForCode(String languageCode) => switch (languageCode) {
    'sw' => const Locale('sw', 'TZ'),
    'lg' => const Locale('lg', 'UG'),
    'fr' => const Locale('fr', 'FR'),
    'ar' => const Locale('ar', 'SA'),
    _ => const Locale('en', 'US'),
  };

  Future<void> checkForUpdate({bool showToast = true}) async {
    if (!Platform.isAndroid) {
      if (showToast) Common.quickToast(type: ToastificationType.info, title: AppTranslationKey.update.tr, description: 'Updates are only supported on Android devices');
      return;
    }

    try {
      isCheckingForUpdate.value = true;
      final updateInfo = await InAppUpdate.checkForUpdate();
      
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        // Try flexible update first, fallback to immediate if needed
        try {
          await InAppUpdate.startFlexibleUpdate();
          if (showToast) Common.quickToast(type: ToastificationType.success, title: AppTranslationKey.downloadingUpdate.tr, description: AppTranslationKey.updateDownloadingInBackground.tr);
        } catch (flexError) {
          // Fallback to immediate update
          await InAppUpdate.performImmediateUpdate();
        }
      } else if (updateInfo.updateAvailability == UpdateAvailability.updateNotAvailable) {
        if (showToast) Common.quickToast(type: ToastificationType.info, title: AppTranslationKey.upToDate.tr, description: AppTranslationKey.appIsUpToDate.tr);
      }
    } catch (e) {
      if (showToast) Common.quickToast(type: ToastificationType.error, title: AppTranslationKey.error.tr, description: AppTranslationKey.failedToCheckForUpdates.tr);
    } finally {
      isCheckingForUpdate.value = false;
    }
  }

  /// Initialize connectivity status
  Future<void> _initConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      isOnline.value = false;
    }
  }

  /// Start listening to connectivity changes
  void _startListening() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
      onError: (error) {
        isOnline.value = false;
      },
    );
  }

  /// Update connection status based on connectivity results
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final hasConnection = results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);

    if (!hasConnection && isOnline.value) {
      wasOffline.value = true;
    }

    isOnline.value = hasConnection;
    
    if (hasConnection && wasOffline.value) {
      wasOffline.value = false;
    }
  }

  /// Force check connectivity status
  Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _updateConnectionStatus(results);
    return isOnline.value;
  }

  /// Reset the offline flag (useful after sync completion)
  void resetOfflineFlag() {
    wasOffline.value = false;
  }

}