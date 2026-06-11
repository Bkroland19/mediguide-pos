import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:form_builder_phone_field/form_builder_phone_field.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import '../../routes/app_pages.dart';
import '../../translations/app_translations.dart';
import '../../utils/app_spacing.dart';
import '../../utils/responsive.dart';
import '../../widgets/copyright_terms_widget.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/app_button.dart';
import '../../widgets/glass_card.dart';
import '../../data/enums/user_enums.dart';
import 'register_controller.dart';

class RegisterPage extends GetWidget<RegisterController> {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: FlexColorScheme.themedSystemNavigationBar(
        context,
        noAppBar: true,
        systemNavBarStyle: FlexSystemNavBarStyle.transparent,
      ),
      child: Scaffold(
        body: Container(
          width: size.width,
          height: size.height,
          padding: EdgeInsets.symmetric(
            vertical: Responsive.verticalPadding(context),
            horizontal: Responsive.horizontalPadding(context),
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.1),
                theme.colorScheme.secondary.withValues(alpha: 0.05),
                theme.colorScheme.surface,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo
                    const AppLogo(logoSize: 200),
                    AppSpacing.gapXl,

                    // Register Form Card
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        maxWidth: Responsive.value<double>(
                          context,
                          mobile: double.infinity,
                          tablet: 500,
                          desktop: 450,
                        ),
                      ),
                      child: GlassCard.auth(
                        child: FormBuilder(
                          key: controller.formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Form Title
                              Text(
                                AppTranslationKey.createAccount.tr,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                  fontSize: Responsive.fontSize(
                                    context,
                                    mobile: 24.0,
                                    tablet: 28.0,
                                    desktop: 32.0,
                                  ),
                                ),
                              ),

                              AppSpacing.contentGap,

                              // Full Name Field
                              FormBuilderTextField(
                                name: 'fullName',
                                decoration: InputDecoration(
                                  labelText: AppTranslationKey.fullName.tr,
                                  prefixIcon: Icon(
                                    LucideIcons.user,
                                    color: theme.colorScheme.primary,
                                    size: Responsive.iconSize(
                                      context,
                                      mobile: 20.0,
                                      tablet: 22.0,
                                      desktop: 24.0,
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: FormBuilderValidators.compose([
                                  FormBuilderValidators.required(),
                                  FormBuilderValidators.minLength(2),
                                ]),
                              ),

                              AppSpacing.fieldGap,

                              // Email Field
                              FormBuilderTextField(
                                name: 'email',
                                decoration: InputDecoration(
                                  labelText: AppTranslationKey.email.tr,
                                  prefixIcon: Icon(
                                    LucideIcons.mail,
                                    color: theme.colorScheme.primary,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: FormBuilderValidators.compose([
                                  FormBuilderValidators.required(),
                                  FormBuilderValidators.email(),
                                ]),
                              ),

                              AppSpacing.fieldGap,

                              // Phone Number Field
                              FormBuilderPhoneField(
                                name: 'phoneNumber',
                                decoration: InputDecoration(
                                  labelText: AppTranslationKey.phoneNumber.tr,
                                  hintText: '7XX XXX XXX',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                iconSelector: const SizedBox.shrink(),
                                countryPicker: (flag, code) => Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 14,
                                      child: flag,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      code,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                                defaultSelectedCountryIsoCode: 'UG',
                                priorityListByIsoCode: ['UG', 'KE', 'TZ', 'RW'],
                                validator: FormBuilderValidators.compose([
                                  FormBuilderValidators.required(),
                                ]),
                              ),

                              AppSpacing.fieldGap,

                              // Alternative Phone Field
                              FormBuilderPhoneField(
                                name: 'alternativePhone',
                                decoration: InputDecoration(
                                  labelText: 'Alternative Phone (Optional)',
                                  hintText: '7XX XXX XXX',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                iconSelector: const SizedBox.shrink(),
                                countryPicker: (flag, code) => Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 14,
                                      child: flag,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      code,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                                defaultSelectedCountryIsoCode: 'UG',
                                priorityListByIsoCode: ['UG', 'KE', 'TZ', 'RW'],
                              ),

                              AppSpacing.fieldGap,

                              // License Number Field
                              FormBuilderTextField(
                                name: 'licenseNumber',
                                decoration: InputDecoration(
                                  labelText: AppTranslationKey.licenseNumber,
                                  prefixIcon: Icon(
                                    LucideIcons.fileText,
                                    color: theme.colorScheme.primary,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: controller.licenseNumberValidator,
                              ),

                              AppSpacing.fieldGap,

                              // Specialization Dropdown Field
                              FormBuilderDropdown<String>(
                                name: 'specialization',
                                decoration: InputDecoration(
                                  labelText:
                                      AppTranslationKey.specialization.tr,
                                  hintText:
                                      AppTranslationKey.selectSpecialization.tr,
                                  prefixIcon: Icon(
                                    LucideIcons.userCheck,
                                    color: theme.colorScheme.primary,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                items: Specialization.values
                                    .map(
                                      (specialization) => DropdownMenuItem(
                                        value: specialization.name,
                                        child: Text(specialization.label),
                                      ),
                                    )
                                    .toList(),
                                validator: FormBuilderValidators.required(),
                              ),

                              AppSpacing.gapMd,

                              // Password Field
                              Obx(
                                () => FormBuilderTextField(
                                  name: 'password',
                                  obscureText:
                                      !controller.isPasswordVisible.value,
                                  decoration: InputDecoration(
                                    labelText: AppTranslationKey.password.tr,
                                    prefixIcon: Icon(
                                      LucideIcons.lock,
                                      color: theme.colorScheme.primary,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        controller.isPasswordVisible.value
                                            ? LucideIcons.eyeOff
                                            : LucideIcons.eye,
                                        color: theme.colorScheme.primary,
                                      ),
                                      onPressed: () =>
                                          controller.isPasswordVisible.toggle(),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: theme.colorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  validator: FormBuilderValidators.compose([
                                    FormBuilderValidators.required(),
                                    FormBuilderValidators.minLength(8),
                                  ]),
                                ),
                              ),

                              AppSpacing.fieldGap,

                              // Terms and Conditions Checkbox
                              FormBuilderCheckbox(
                                name: 'agreeToTerms',
                                title: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'I agree to the ',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      TextSpan(
                                        text: 'Terms of Service',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme.colorScheme.primary,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () => Get.toNamed(
                                            AppRoutes.termsAndConditions,
                                          ),
                                      ),
                                      TextSpan(
                                        text: ' and ',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      TextSpan(
                                        text: 'Privacy Policy',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme.colorScheme.primary,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () => Get.toNamed(
                                            AppRoutes.termsAndConditions,
                                          ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              AppSpacing.gapMd,

                              // Register Button
                              Obx(
                                () => AppButton.large(
                                  text: AppTranslationKey.createAccount.tr,
                                  onPressed: controller.onSubmit,
                                  isLoading: controller.isLoading.value,
                                  loadingText:
                                      AppTranslationKey.creatingAccount.tr,
                                  width: double.infinity,
                                ),
                              ),

                              AppSpacing.fieldGap,

                              // Back to Login Button
                              AppButtonVariants.textButton(
                                text: AppTranslationKey.backToLogin.tr,
                                onPressed: () => Get.back(),
                                width: double.infinity,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    AppSpacing.gapXl,

                    // Copyright and Terms
                    const CopyrightTermsWidget(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
