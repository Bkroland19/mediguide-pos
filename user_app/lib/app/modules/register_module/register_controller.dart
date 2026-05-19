import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';
import '../../routes/app_pages.dart';
import '../../translations/app_translations.dart';
import '../../data/models/models.dart';
import '../../data/services/backend_service.dart';
import '../../data/services/auth_service.dart';
import '../../utils/common.dart';

class RegisterController extends GetxController {
  final formKey = GlobalKey<FormBuilderState>();
  final RxBool isLoading = false.obs;
  final RxBool isPasswordVisible = false.obs;

  /// Validate if license number is required (required for healthcare providers)
  String? licenseNumberValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'License number is required';
    }
    if (value.trim().length < 3) {
      return 'License number must be at least 3 characters';
    }
    return null;
  }

  Future<void> onSubmit() async {
    if (formKey.currentState?.saveAndValidate() ?? false) {
      final formData = formKey.currentState!.value;

      if (formData['agreeToTerms'] != true) {
        Common.quickToast(
          type: ToastificationType.error,
          title: AppTranslationKey.registrationError,
          description: AppTranslationKey.pleaseAgreeToTerms,
        );
        return;
      }

      isLoading.value = true;

      try {
        // Create user data using backend model - only essential fields
        final userData = User.forCreate(
          email: formData['email'] as String,
          password: formData['password'] as String,
          name: formData['fullName'] as String,
          role: UserRole.healthcareProvider,
          status: UserStatus.pendingActivation,
          phone: formData['phoneNumber'] as String?,
          alternativePhone: formData['alternativePhone'] as String?,
          licenseNumber: formData['licenseNumber'] as String?,
          specialization: formData['specialization'] as String?,
          preferredLanguage: PreferredLanguage.english,
        );

        // Register with backend
        final userRecord = await BackendService.to.register(
          email: formData['email'] as String,
          password: formData['password'] as String,
          passwordConfirm: formData['password'] as String,
          additionalData: userData,
        );

        // Convert backend RecordModel to User model and save via AuthService
        final user = User.fromRecord(userRecord);
        await AuthService.to.saveUser(user);

        // Navigate to main screen since user is now registered and logged in
        Get.offNamed(AppRoutes.main);
      } catch (e) {
        final errorMessage = Common.parseApiError(e);
        Common.quickToast(
          type: ToastificationType.error,
          title: AppTranslationKey.registrationError,
          description: errorMessage,
        );
      } finally {
        isLoading.value = false;
      }
    }
  }
}
