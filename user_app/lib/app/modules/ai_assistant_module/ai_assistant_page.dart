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
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(
            controller.currentContext.value != null
                ? 'AI: ${controller.currentContext.value!.title}'
                : AppTranslationKey.aiChatAssistant.tr,
          ),
        ),
        backgroundColor: context.theme.colorScheme.surface,
        elevation: 0,
      ),
      body: Obx(
        () => AiChatWidget(
          currentUser: controller.currentUser,
          aiUser: controller.aiUser,
          loadingConfig: LoadingConfig(isLoading: controller.isLoading.value),

          controller: controller.chatController,
          quickReplyOptions: QuickReplyOptions(
            textStyle: context.textTheme.bodyMedium,
          ),
          welcomeMessageConfig: WelcomeMessageConfig(
            titleStyle: context.textTheme.titleMedium,
            containerDecoration: BoxDecoration(
              color: context.theme.colorScheme.primaryContainer.withValues(
                alpha: 0.7,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            title: controller.contextualWelcomeMessage.value.isNotEmpty
                ? controller.contextualWelcomeMessage.value
                : 'Hello! I\'m your MediGuide AI assistant. I can help you with medical questions, drug information, clinical guidelines, and health-related queries. How can I assist you today?',
          ),
          onSendMessage: controller.handleSendMessage,
          padding: AppSpacing.vPaddingSm,

          inputOptions: InputOptions(
            sendOnEnter: true,
            decoration: InputDecoration(hintText: "Type your message..."),
            margin: EdgeInsets.all(AppSpacing.md),
            sendButtonIcon: LucideIcons.send,
            materialPadding: AppSpacing.vPaddingSm,
            containerPadding: AppSpacing.formFieldSpacing,
          ),
        ),
      ),
    );
  }
}
