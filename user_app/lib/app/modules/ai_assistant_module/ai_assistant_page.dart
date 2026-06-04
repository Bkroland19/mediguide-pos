import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:user_app/app/utils/app_spacing.dart';

import '../../translations/app_translations.dart';
import 'ai_assistant_controller.dart';

class AiAssistantPage extends GetWidget<AiAssistantController> {
  const AiAssistantPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.md,
        backgroundColor: cs.surface,
        elevation: 0,
        title: Obx(() {
          final currentContext = controller.currentContext.value;

          return Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(LucideIcons.sparkles, color: cs.primary, size: 20),
              ),

              AppSpacing.sm.gap,

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentContext != null
                          ? currentContext.title
                          : AppTranslationKey.aiChatAssistant.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentContext != null
                          ? 'Context-aware assistant'
                          : 'MediGuide clinical assistant',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
      body: Obx(() {
        final currentContext = controller.currentContext.value;

        return Column(
          children: [
            if (currentContext != null)
              _AssistantContextBanner(
                title: currentContext.title,
                onClear: () {
                  controller.currentContext.value = null;
                  controller.contextualWelcomeMessage.value = '';
                },
              ),

            Expanded(
              child: AiChatWidget(
                currentUser: controller.currentUser,
                aiUser: controller.aiUser,
                controller: controller.chatController,
                loadingConfig: LoadingConfig(
                  isLoading: controller.isLoading.value,
                ),
                quickReplyOptions: QuickReplyOptions(
                  textStyle: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                welcomeMessageConfig: WelcomeMessageConfig(
                  titleStyle: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onPrimaryContainer,
                    height: 1.35,
                  ),
                  containerDecoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.08),
                    ),
                  ),
                  title: controller.contextualWelcomeMessage.value.isNotEmpty
                      ? controller.contextualWelcomeMessage.value
                      : 'Hello! I’m your MediGuide AI assistant. I can help with medical questions, drug information, clinical guidelines, and health-related queries. How can I assist you today?',
                ),
                onSendMessage: controller.handleSendMessage,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                inputOptions: InputOptions(
                  sendOnEnter: true,
                  sendButtonIcon: LucideIcons.send,
                  margin: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  materialPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xs,
                  ),
                  containerPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(
                      alpha: 0.65,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: cs.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
      backgroundColor: cs.surface,
    );
  }
}

class _AssistantContextBanner extends StatelessWidget {
  final String title;
  final VoidCallback onClear;

  const _AssistantContextBanner({required this.title, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.secondary.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cs.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(LucideIcons.fileText, color: cs.secondary, size: 20),
          ),

          AppSpacing.sm.gap,

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current context',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: cs.onSecondaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: cs.onSecondaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: onClear,
            tooltip: 'Clear context',
            icon: Icon(LucideIcons.x, color: cs.onSecondaryContainer, size: 18),
          ),
        ],
      ),
    );
  }
}
