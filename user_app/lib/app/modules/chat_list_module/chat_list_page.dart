import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/models.dart';
import '../../translations/app_translations.dart';
import '../../utils/app_spacing.dart';
import '../../utils/common.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_button.dart';
import '../../widgets/conversation_card.dart';
import '../../utils/loading.dart';
import '../../data/services/backend_service.dart';
import 'package:toastification/toastification.dart';
import 'chat_list_controller.dart';

class ChatListPage extends GetView<ChatListController> {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslationKey.conversations),
        actions: [
          Obx(
            () => FilterButton(
              hasActiveFilters: controller.hasActiveFilters,
              onPressed: () => controller.showFilterModal(context),
              onReset: controller.hasActiveFilters.value
                  ? controller.clearAllFilters
                  : null,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            Future.sync(() => controller.pagingController.refresh()),
        child: PagingListener<int, Conversation>(
          controller: controller.pagingController,
          builder: (context, state, fetchNextPage) {
            return PagedListView<int, Conversation>(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              state: state,
              fetchNextPage: fetchNextPage,
              builderDelegate: PagedChildBuilderDelegate<Conversation>(
                itemBuilder: (context, conversation, index) => ConversationCard(
                  conversation: conversation,
                  onTap: () => _openConversation(conversation),
                  getOtherParticipant: controller.getOtherParticipant,
                  getConversationName: controller.getConversationName,
                  getRelativeTime: controller.getRelativeTime,
                ),
                firstPageErrorIndicatorBuilder: (context) => EmptyState(
                  icon: LucideIcons.messageCircle,
                  title: AppTranslationKey.error,
                  description: AppTranslationKey.checkInternetAndRetry,
                  onAction: controller.refreshConversations,
                ),
                noItemsFoundIndicatorBuilder: (context) => EmptyState(
                  icon: LucideIcons.messageCircle,
                  title: AppTranslationKey.noConversationsFound,
                  description: AppTranslationKey.startNewConversation,
                ),
                firstPageProgressIndicatorBuilder: (context) =>
                    const CenteredLoading.large(),
                newPageProgressIndicatorBuilder: (context) => const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CenteredLoading.medium(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openConversation(Conversation conversation) {
    if (!BackendService.to.supportsMessaging) {
      Common.quickToast(
        type: ToastificationType.info,
        title: AppTranslationKey.conversations,
        description: BackendService.to.unsupportedCollectionWriteMessage(
          'messages',
        ),
      );
      return;
    }
    final otherUser = controller.getOtherParticipant(conversation);
    if (otherUser != null) {
      controller.openChatWith(otherUser);
    }
  }
}
