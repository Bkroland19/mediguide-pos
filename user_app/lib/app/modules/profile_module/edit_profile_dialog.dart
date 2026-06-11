import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:toastification/toastification.dart';
import '../../data/services/auth_service.dart';
import '../../translations/app_translations.dart';
import '../../utils/app_spacing.dart';
import '../../utils/loading.dart';
import '../../utils/responsive.dart';
import '../../utils/common.dart';
import '../../widgets/user_avatar.dart';
import 'edit_profile_controller.dart';

class EditProfileDialog extends StatelessWidget {
  const EditProfileDialog({super.key});

  static Future<bool?> show() async {
    return await Get.dialog<bool>(
      EditProfileDialog(),
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<EditProfileController>(
      init: EditProfileController(),
      builder: (controller) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop) {
            if (!controller.hasChanges.value) {
              Get.back();
              return;
            }

            final shouldDiscard = await Get.dialog<bool>(
              AlertDialog(
                title: Text(AppTranslationKey.discardChanges.tr),
                content: Text(AppTranslationKey.discardChangesConfirmation.tr),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(result: false),
                    child: Text(AppTranslationKey.cancel.tr),
                  ),
                  TextButton(
                    onPressed: () => Get.back(result: true),
                    child: Text(AppTranslationKey.discard.tr),
                  ),
                ],
              ),
            );

            if (shouldDiscard == true) {
              Get.back();
            }
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(AppTranslationKey.editProfile.tr),
            leading: IconButton(
              icon: Icon(LucideIcons.x),
              onPressed: () async {
                if (!controller.hasChanges.value) {
                  Get.back();
                  return;
                }

                final shouldDiscard = await Get.dialog<bool>(
                  AlertDialog(
                    title: Text(AppTranslationKey.discardChanges.tr),
                    content: Text(
                      AppTranslationKey.discardChangesConfirmation.tr,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(result: false),
                        child: Text(AppTranslationKey.cancel.tr),
                      ),
                      TextButton(
                        onPressed: () => Get.back(result: true),
                        child: Text(AppTranslationKey.discard.tr),
                      ),
                    ],
                  ),
                );

                if (shouldDiscard == true) {
                  Get.back();
                }
              },
            ),
            actions: [
              Obx(
                () => TextButton(
                  onPressed: controller.isLoading.value
                      ? null
                      : () => controller.saveProfile(),
                  child: controller.isLoading.value
                      ? SizedBox(width: 20, height: 20, child: Loading.small())
                      : Text(
                          AppTranslationKey.done.tr,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: controller.hasChanges.value
                                ? context.theme.colorScheme.primary
                                : context.theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                          ),
                        ),
                ),
              ),
            ],
          ),
          body: GetBuilder<EditProfileController>(
            builder: (controller) {
              final user = AuthService.to.currentUser.value;
              return FormBuilder(
                key: controller.formKey,
                initialValue: user == null
                    ? {}
                    : {
                        'name': user.name,
                        'phone': user.phone,
                        'alternativePhone': user.alternativePhone,
                        'address': user.address,
                        'city': user.city,
                        'state': user.state,
                        'country': user.country,
                        'postalCode': user.postalCode,
                        'organization': user.organization,
                        'department': user.department,
                        'jobTitle': user.jobTitle,
                        'specialization': user.specialization,
                      },
                onChanged: () {
                  final user = AuthService.to.currentUser.value;
                  if (user == null) return;

                  final formValues =
                      controller.formKey.currentState?.instantValue;
                  if (formValues == null) return;

                  final hasFormChanges =
                      formValues['name'] != user.name ||
                      formValues['phone'] != user.phone ||
                      formValues['alternativePhone'] != user.alternativePhone ||
                      formValues['address'] != user.address ||
                      formValues['city'] != user.city ||
                      formValues['state'] != user.state ||
                      formValues['country'] != user.country ||
                      formValues['postalCode'] != user.postalCode ||
                      formValues['organization'] != user.organization ||
                      formValues['department'] != user.department ||
                      formValues['jobTitle'] != user.jobTitle ||
                      formValues['specialization'] != user.specialization;

                  controller.hasChanges.value = hasFormChanges;
                },
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.responsiveHorizontalPadding,
                    vertical: context.responsiveVerticalPadding,
                  ),
                  children: [
                    // Avatar Section
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              debugPrint('Avatar tapped'); // Debug
                              _pickAndUploadAvatar(controller);
                            },
                            child: Obx(
                              () => UserAvatar.xlarge(
                                name: AuthService.to.userName,
                                avatarUrl: AuthService.to.userProfilePicture,
                                showEditButton: true,
                                isLoading: controller.isUploadingAvatar.value,
                                onEdit: () {
                                  debugPrint('Edit button tapped'); // Debug
                                  _pickAndUploadAvatar(controller);
                                },
                              ),
                            ),
                          ),
                          AppSpacing.gapSm,
                          GestureDetector(
                            onTap: () {
                              debugPrint('Text tapped'); // Debug
                              _pickAndUploadAvatar(controller);
                            },
                            child: Text(
                              'Tap to change photo',
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    AppSpacing.gapXl,

                    // Basic Information Section
                    Row(
                      children: [
                        Icon(
                          LucideIcons.user,
                          size: Responsive.iconSize(
                            context,
                            mobile: 20,
                            tablet: 22,
                            desktop: 24,
                          ),
                          color: context.theme.colorScheme.primary,
                        ),
                        AppSpacing.gapSm,
                        Text(
                          AppTranslationKey.accountSettings.tr,
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapMd,

                    // Name Field
                    FormBuilderTextField(
                      name: 'name',
                      decoration: InputDecoration(
                        labelText: '${AppTranslationKey.fullName.tr} *',
                        hintText: 'Enter your full name',
                        prefixIcon: Icon(LucideIcons.user),
                      ),
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(
                          errorText: AppTranslationKey.nameRequired.tr,
                        ),
                        FormBuilderValidators.minLength(
                          2,
                          errorText: 'Name must be at least 2 characters',
                        ),
                      ]),
                    ),

                    AppSpacing.gapMd,

                    // Phone Field
                    FormBuilderTextField(
                      name: 'phone',
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: AppTranslationKey.phoneNumber.tr,
                        hintText: '+256 123 456 789',
                        prefixIcon: Icon(LucideIcons.phone),
                      ),
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.match(
                          RegExp(r'^[+]?[0-9\s\-\(\)]{7,20}$'),
                          errorText: AppTranslationKey.invalidPhoneFormat.tr,
                        ),
                      ]),
                    ),

                    AppSpacing.gapMd,

                    // Alternative Phone Field
                    FormBuilderTextField(
                      name: 'alternativePhone',
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Alternative Phone (Optional)',
                        hintText: '+256 987 654 321',
                        prefixIcon: Icon(LucideIcons.phone),
                      ),
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.match(
                          RegExp(r'^[+]?[0-9\s\-\(\)]{7,20}$'),
                          errorText: AppTranslationKey
                              .invalidAlternativePhoneFormat
                              .tr,
                        ),
                      ]),
                    ),

                    AppSpacing.gapXl,

                    // Address Information Section
                    Row(
                      children: [
                        Icon(
                          LucideIcons.mapPin,
                          size: Responsive.iconSize(
                            context,
                            mobile: 20,
                            tablet: 22,
                            desktop: 24,
                          ),
                          color: context.theme.colorScheme.primary,
                        ),
                        AppSpacing.gapSm,
                        Text(
                          'Address Information',
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapMd,

                    FormBuilderTextField(
                      name: 'address',
                      decoration: InputDecoration(
                        labelText: 'Address',
                        hintText: 'Street address',
                        prefixIcon: Icon(LucideIcons.mapPin),
                      ),
                    ),

                    AppSpacing.gapMd,

                    // City, State, Country Row
                    if (context.isLargerThanMobile) ...[
                      Row(
                        children: [
                          Expanded(
                            child: FormBuilderTextField(
                              name: 'city',
                              decoration: InputDecoration(
                                labelText: 'City',
                                hintText: 'Kampala',
                                prefixIcon: Icon(LucideIcons.building),
                              ),
                            ),
                          ),
                          AppSpacing.gapMd,
                          Expanded(
                            child: FormBuilderTextField(
                              name: 'state',
                              decoration: InputDecoration(
                                labelText: 'State/Province',
                                hintText: 'Central',
                                prefixIcon: Icon(LucideIcons.building2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.gapMd,
                      Row(
                        children: [
                          Expanded(
                            child: FormBuilderTextField(
                              name: 'country',
                              decoration: InputDecoration(
                                labelText: 'Country',
                                hintText: 'Uganda',
                                prefixIcon: Icon(LucideIcons.globe),
                              ),
                            ),
                          ),
                          AppSpacing.gapMd,
                          Expanded(
                            child: FormBuilderTextField(
                              name: 'postalCode',
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Postal Code',
                                hintText: '12345',
                                prefixIcon: Icon(LucideIcons.mailbox),
                              ),
                              validator: FormBuilderValidators.compose([
                                FormBuilderValidators.numeric(
                                  errorText: 'Please enter a valid postal code',
                                ),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      FormBuilderTextField(
                        name: 'city',
                        decoration: InputDecoration(
                          labelText: 'City',
                          hintText: 'Kampala',
                          prefixIcon: Icon(LucideIcons.building),
                        ),
                      ),
                      AppSpacing.gapMd,
                      FormBuilderTextField(
                        name: 'state',
                        decoration: InputDecoration(
                          labelText: 'State/Province',
                          hintText: 'Central',
                          prefixIcon: Icon(LucideIcons.building2),
                        ),
                      ),
                      AppSpacing.gapMd,
                      FormBuilderTextField(
                        name: 'country',
                        decoration: InputDecoration(
                          labelText: 'Country',
                          hintText: 'Uganda',
                          prefixIcon: Icon(LucideIcons.globe),
                        ),
                      ),
                      AppSpacing.gapMd,
                      FormBuilderTextField(
                        name: 'postalCode',
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Postal Code',
                          hintText: '12345',
                          prefixIcon: Icon(LucideIcons.mailbox),
                        ),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.numeric(
                            errorText: 'Please enter a valid postal code',
                          ),
                        ]),
                      ),
                    ],

                    AppSpacing.gapXl,

                    // Professional Information Section
                    Row(
                      children: [
                        Icon(
                          LucideIcons.briefcase,
                          size: Responsive.iconSize(
                            context,
                            mobile: 20,
                            tablet: 22,
                            desktop: 24,
                          ),
                          color: context.theme.colorScheme.primary,
                        ),
                        AppSpacing.gapSm,
                        Text(
                          AppTranslationKey.professionalInfo.tr,
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapMd,

                    FormBuilderTextField(
                      name: 'organization',
                      decoration: InputDecoration(
                        labelText: 'Organization',
                        hintText: 'Ministry of Health',
                        prefixIcon: Icon(LucideIcons.building),
                      ),
                    ),

                    AppSpacing.gapMd,

                    if (context.isLargerThanMobile) ...[
                      Row(
                        children: [
                          Expanded(
                            child: FormBuilderTextField(
                              name: 'department',
                              decoration: InputDecoration(
                                labelText: 'Department',
                                hintText: 'Emergency Medicine',
                                prefixIcon: Icon(LucideIcons.building2),
                              ),
                            ),
                          ),
                          AppSpacing.gapMd,
                          Expanded(
                            child: FormBuilderTextField(
                              name: 'jobTitle',
                              decoration: InputDecoration(
                                labelText: 'Job Title',
                                hintText: 'Clinical Officer',
                                prefixIcon: Icon(LucideIcons.userCheck),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      FormBuilderTextField(
                        name: 'department',
                        decoration: InputDecoration(
                          labelText: 'Department',
                          hintText: 'Emergency Medicine',
                          prefixIcon: Icon(LucideIcons.building2),
                        ),
                      ),
                      AppSpacing.gapMd,
                      FormBuilderTextField(
                        name: 'jobTitle',
                        decoration: InputDecoration(
                          labelText: 'Job Title',
                          hintText: 'Clinical Officer',
                          prefixIcon: Icon(LucideIcons.userCheck),
                        ),
                      ),
                    ],

                    AppSpacing.gapMd,

                    FormBuilderTextField(
                      name: 'specialization',
                      decoration: InputDecoration(
                        labelText: 'Specialization',
                        hintText: 'General Practice',
                        prefixIcon: Icon(LucideIcons.stethoscope),
                      ),
                    ),

                    AppSpacing.gapXxl,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Pick and upload avatar image
  Future<void> _pickAndUploadAvatar(EditProfileController controller) async {
    debugPrint(
      '_pickAndUploadAvatar called',
    ); // Debug: Check if function is called
    try {
      debugPrint('About to call FilePicker.platform.pickFiles'); // Debug

      final result = await FilePicker.platform.pickFiles();

      debugPrint('FilePicker result: $result'); // Debug: Check picker result

      if (result != null) {
        final file = File(result.files.single.path!);

        // Validate file size (limit to 5MB)
        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) {
          Common.quickToast(
            type: ToastificationType.warning,
            title: 'File too large',
            description: 'Please select an image smaller than 5MB',
          );
          return;
        }

        // Upload avatar
        await controller.uploadAvatar(file);
      } else {
        // User canceled the picker
        debugPrint('User canceled the picker');
      }
    } catch (e) {
      Common.quickToast(
        type: ToastificationType.error,
        title: 'Error',
        description: 'Failed to pick image. Please try again.',
      );
    }
  }
}
