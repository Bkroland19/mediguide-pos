import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:get/get.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:toastification/toastification.dart';
import '../../routes/app_pages.dart';
import '../../data/services/pocketbase_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/models/models.dart';
import '../../translations/app_translations.dart';
import '../../utils/common.dart';

class LoginController extends GetxController {
  final formKey = GlobalKey<FormBuilderState>();
  final RxBool isLoading = false.obs;
  final RxBool isPasswordVisible = false.obs;

  static const String emailField = 'email';
  static const String passwordField = 'password';

  Future<void> onSubmit() async {
    if (formKey.currentState?.saveAndValidate() ?? false) {
      isLoading.value = true;
      final formData = formKey.currentState!.value;

      try {
        final email = formData[emailField] as String;
        final password = formData[passwordField] as String;

        // Authenticate with PocketBase
        final userRecord = await PocketBaseService.to.login(
          email: email,
          password: password,
        );

        // Convert PocketBase RecordModel to User model and save via AuthService
        final user = User.fromRecord(userRecord);
        await AuthService.to.saveUser(user);

        // Navigate to main screen
        Get.offAllNamed(AppRoutes.main);
      } on ClientException catch (e) {
        // Handle PocketBase specific errors
        final errorMessage = Common.parsePocketBaseError(e);
        Common.quickToast(
          type: ToastificationType.error,
          title: AppTranslationKey.loginError,
          description: errorMessage,
        );
      } catch (e) {
        Common.quickToast(
          type: ToastificationType.error,
          title: AppTranslationKey.loginError,
          description: 'An unexpected error occurred',
        );
      } finally {
        isLoading.value = false;
      }
    }
  }

}
