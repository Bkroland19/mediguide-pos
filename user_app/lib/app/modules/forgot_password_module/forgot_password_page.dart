import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import '../../translations/app_translations.dart';
import '../../utils/app_spacing.dart';
import '../../utils/responsive.dart';
import '../../widgets/copyright_terms_widget.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/app_button.dart';
import '../../widgets/glass_card.dart';
import 'forgot_password_controller.dart';

class ForgotPasswordPage extends GetWidget<ForgotPasswordController> {
  const ForgotPasswordPage({super.key});

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

                    // Forgot Password Form Card
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
                                AppTranslationKey.resetPassword.tr,
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

                              // Description
                              Text(
                                AppTranslationKey.resetPasswordDescription.tr,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: Responsive.fontSize(
                                    context,
                                    mobile: 14.0,
                                    tablet: 15.0,
                                    desktop: 16.0,
                                  ),
                                ),
                                textAlign: TextAlign.center,
                              ),

                              AppSpacing.contentGap,

                              // Email Field
                              FormBuilderTextField(
                                name: ForgotPasswordController.emailField,
                                decoration: InputDecoration(
                                  labelText: AppTranslationKey.email.tr,
                                  hintText: AppTranslationKey.email.tr,
                                  prefixIcon: Icon(
                                    LucideIcons.mail,
                                    color: theme.colorScheme.primary,
                                    size: Responsive.iconSize(
                                      context,
                                      mobile: 20,
                                      tablet: 22,
                                      desktop: 24,
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
                                  FormBuilderValidators.email(),
                                ]),
                              ),

                              AppSpacing.elementGap,

                              // Send Reset Button
                              Obx(
                                () => AppButton.large(
                                  text: AppTranslationKey.sendResetLink.tr,
                                  onPressed: controller.onSubmit,
                                  isLoading: controller.isLoading,
                                  loadingText:
                                      AppTranslationKey.sendingResetLink.tr,
                                  width: double.infinity,
                                ),
                              ),

                              AppSpacing.fieldGap,

                              // Back to Login Button
                              AppButtonVariants.textButton(
                                text: AppTranslationKey.backToLogin.tr,
                                onPressed: controller.onBackToLogin,
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
