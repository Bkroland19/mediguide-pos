import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:get/get.dart';
import '../../translations/app_translations.dart';

class ForgotPasswordController extends GetxController {
  ForgotPasswordController();

  // Form key for FormBuilder
  final formKey = GlobalKey<FormBuilderState>();

  // Loading state
  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  // Form field keys
  static const String emailField = 'email';

  // Form validation
  List<String? Function(String?)> get emailValidators => [
    FormBuilderValidators.required(),
    FormBuilderValidators.email(),
  ];

  // Submit form
  Future<void> onSubmit() async {
    if (formKey.currentState?.saveAndValidate() ?? false) {
      _isLoading.value = true;

      final formData = formKey.currentState?.value;
      final email = formData?[emailField] as String?;

      try {
        // TODO: Implement actual password reset logic here
        await _performPasswordReset(email!);

        // Show success message
        Get.snackbar(
          AppTranslationKey.passwordResetSent,
          AppTranslationKey.checkEmailForReset,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );

        // Navigate back to login after a short delay
        await Future.delayed(const Duration(seconds: 1));
        Get.back();
      } catch (e) {
        // Show error message
        Get.snackbar(
          AppTranslationKey.passwordResetError,
          e.toString(),
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } finally {
        _isLoading.value = false;
      }
    }
  }

  // Mock password reset method
  Future<void> _performPasswordReset(String email) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // Mock password reset - replace with actual implementation
    // For demo purposes, we'll just succeed
    return;
  }

  // Back to login handler
  void onBackToLogin() {
    Get.back();
  }
}
