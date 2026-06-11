import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../routes/app_pages.dart';
import '../../translations/app_translations.dart';
import '../../utils/app_spacing.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/copyright_terms_widget.dart';
import '../../widgets/glass_card.dart';
import 'login_controller.dart';

class LoginPage extends GetWidget<LoginController> {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final cs = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: FlexColorScheme.themedSystemNavigationBar(
        context,
        noAppBar: true,
        systemNavBarStyle: FlexSystemNavBarStyle.transparent,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: GestureDetector(
          onTap: FocusScope.of(context).unfocus,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary.withValues(alpha: 0.10),
                  cs.secondary.withValues(alpha: 0.05),
                  cs.surface,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.symmetric(
                      vertical: Responsive.verticalPadding(context),
                      horizontal: Responsive.horizontalPadding(context),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: Responsive.value<double>(
                          context,
                          mobile: double.infinity,
                          tablet: 500,
                          desktop: 460,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ───────────────── Logo & Branding ─────────────────
                          const AppLogo(logoSize: 180),

                          // ───────────────── Login Card ─────────────────
                          GlassCard.auth(
                            child: FormBuilder(
                              key: controller.formKey,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    AppTranslationKey.signIn.tr,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: cs.onSurface,
                                          fontSize: Responsive.fontSize(
                                            context,
                                            mobile: 24,
                                            tablet: 28,
                                            desktop: 30,
                                          ),
                                        ),
                                  ),

                                  AppSpacing.contentGap,

                                  // ───────────────── Email ─────────────────
                                  FormBuilderTextField(
                                    name: LoginController.emailField,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.username,
                                      AutofillHints.email,
                                    ],
                                    decoration: _inputDecoration(
                                      context,
                                      label: AppTranslationKey.email.tr,
                                      icon: LucideIcons.mail,
                                    ),
                                    validator: FormBuilderValidators.compose([
                                      FormBuilderValidators.required(),
                                      FormBuilderValidators.email(),
                                    ]),
                                  ),

                                  AppSpacing.fieldGap,

                                  // ───────────────── Password ─────────────────
                                  Obx(
                                    () => FormBuilderTextField(
                                      name: LoginController.passwordField,
                                      obscureText:
                                          !controller.isPasswordVisible.value,
                                      textInputAction: TextInputAction.done,
                                      autofillHints: const [
                                        AutofillHints.password,
                                      ],
                                      onSubmitted: (_) => controller.onSubmit(),
                                      decoration: _inputDecoration(
                                        context,
                                        label: AppTranslationKey.password.tr,
                                        icon: LucideIcons.lock,
                                        suffixIcon: IconButton(
                                          tooltip:
                                              controller.isPasswordVisible.value
                                              ? 'Hide password'
                                              : 'Show password',
                                          icon: Icon(
                                            controller.isPasswordVisible.value
                                                ? LucideIcons.eyeOff
                                                : LucideIcons.eye,
                                            color: cs.primary,
                                          ),
                                          onPressed: controller
                                              .isPasswordVisible
                                              .toggle,
                                        ),
                                      ),
                                      validator: FormBuilderValidators.compose([
                                        FormBuilderValidators.required(),
                                        FormBuilderValidators.minLength(6),
                                      ]),
                                    ),
                                  ),

                                  AppSpacing.gapSm,

                                  // ───────────────── Forgot Password ─────────────────
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () =>
                                          Get.toNamed(AppRoutes.forgotPassword),
                                      child: Text(
                                        AppTranslationKey.forgotPassword.tr,
                                        style: TextStyle(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: Responsive.fontSize(
                                            context,
                                            mobile: 14,
                                            tablet: 15,
                                            desktop: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  AppSpacing.elementGap,

                                  // ───────────────── Sign In ─────────────────
                                  Obx(
                                    () => AppButton.large(
                                      text: AppTranslationKey.signIn.tr,
                                      onPressed: controller.isLoading.value
                                          ? null
                                          : controller.onSubmit,
                                      isLoading: controller.isLoading.value,
                                      loadingText:
                                          AppTranslationKey.signingIn.tr,
                                      width: double.infinity,
                                    ),
                                  ),

                                  AppSpacing.fieldGap,

                                  // ───────────────── Register ─────────────────
                                  AppButtonVariants.outlined(
                                    text: AppTranslationKey.createAccount.tr,
                                    onPressed: () =>
                                        Get.toNamed(AppRoutes.register),
                                    width: double.infinity,
                                    height: Responsive.doubleValue(
                                      context,
                                      mobile: 52.0,
                                      tablet: 56.0,
                                      desktop: 60.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          AppSpacing.gapXl,

                          // ───────────────── Copyright ─────────────────
                          const CopyrightTermsWidget(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final theme = context.theme;
    final cs = theme.colorScheme;

    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: cs.surface.withValues(alpha: 0.72),

      prefixIcon: Icon(
        icon,
        color: cs.primary,
        size: Responsive.iconSize(context, mobile: 20, tablet: 22, desktop: 24),
      ),

      suffixIcon: suffixIcon,

      border: _border(context),
      enabledBorder: _border(context),

      focusedBorder: _border(context, color: cs.primary, width: 2),

      errorBorder: _border(context, color: cs.error),

      focusedErrorBorder: _border(context, color: cs.error, width: 2),
    );
  }

  OutlineInputBorder _border(
    BuildContext context, {
    Color? color,
    double width = 1,
  }) {
    final cs = context.theme.colorScheme;

    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: color ?? cs.outlineVariant.withValues(alpha: 0.7),
        width: width,
      ),
    );
  }
}
