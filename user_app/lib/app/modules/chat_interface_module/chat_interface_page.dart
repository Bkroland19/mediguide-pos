import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bubble/bubble.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:user_app/app/utils/app_spacing.dart';
import '../../../app/modules/chat_interface_module/chat_interface_controller.dart';
import '../../utils/loading.dart';
import '../../widgets/user_avatar.dart';
import '../../data/services/auth_service.dart';
import '../../data/models/message.dart';

class ChatInterfacePage extends GetWidget<ChatInterfaceController> {
  const ChatInterfacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          spacing: AppSpacing.md,
          children: [
            UserAvatar.small(
              name:
                  controller.otherUser?.name ??
                  controller.otherUser?.email ??
                  'Unknown',
            ),
            Expanded(
              child: Text(
                controller.otherUser?.name.isNotEmpty == true
                    ? controller.otherUser!.name
                    : controller.otherUser?.email ?? 'Chat',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Message List
          Expanded(
            child: Obx(
              () => controller.isLoading.value
                  ? const CenteredLoading.medium()
                  : controller.messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.messageCircle,
                            size: 64,
                            color: context.theme.colorScheme.onSurface
                                .withValues(alpha: 0.3),
                          ),
                          AppSpacing.md.gap,
                          Text(
                            'Start a conversation',
                            style: context.textTheme.headlineSmall?.copyWith(
                              color: context.theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          AppSpacing.sm.gap,
                          Text(
                            'Send a message to get started',
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: controller.scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: controller.messages.length,
                      itemBuilder: (context, index) {
                        final message = controller.messages[index];
                        return _buildMessageBubble(context, message);
                      },
                    ),
            ),
          ),

          // Message Input
          _buildMessageInput(context),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, Message message) {
    final currentUserId = AuthService.to.currentUser.value?.id;
    final isMe = message.sender == currentUserId;

    return Padding(
      padding: EdgeInsets.only(
        bottom: AppSpacing.sm,
        left: isMe ? 50 : 0,
        right: isMe ? 0 : 50,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Bubble(
          alignment: isMe ? Alignment.topRight : Alignment.topLeft,
          nip: isMe ? BubbleNip.rightTop : BubbleNip.leftTop,
          color: isMe
              ? context.theme.colorScheme.primaryContainer
              : context.theme.colorScheme.surfaceContainerHighest,
          margin: const BubbleEdges.symmetric(horizontal: 16, vertical: 12),
          radius: const Radius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reply-to message if exists
              if (message.replyTo.isNotEmpty) ...[
                _buildReplyToMessage(context, message),
                AppSpacing.xs.gap,
              ],

              // Message content
              Text(
                message.content,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: isMe
                      ? context.theme.colorScheme.onPrimaryContainer
                      : context.theme.colorScheme.onSurface,
                ),
              ),

              AppSpacing.xs.gap,

              // Message timestamp and status
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatMessageTime(message.createdDate),
                    style: context.textTheme.labelSmall?.copyWith(
                      color:
                          (isMe
                                  ? context.theme.colorScheme.onPrimaryContainer
                                  : context.theme.colorScheme.onSurface)
                              .withValues(alpha: 0.6),
                    ),
                  ),
                  if (isMe) ...[
                    AppSpacing.xs.gap,
                    _buildMessageStatusIcon(context, message, currentUserId),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyToMessage(BuildContext context, Message message) {
    final replyToMessage = message.replyToMessage;
    if (replyToMessage == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: context.theme.colorScheme.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replyToMessage.senderUser?.name ?? 'User',
            style: context.textTheme.labelMedium?.copyWith(
              color: context.theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            replyToMessage.content,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageStatusIcon(
    BuildContext context,
    Message message,
    String? currentUserId,
  ) {
    // Only show status for sent messages
    if (currentUserId == null || message.sender != currentUserId) {
      return const SizedBox.shrink();
    }

    if (message.readBy.isNotEmpty) {
      return Icon(
        LucideIcons.checkCheck,
        size: 16,
        color: context.theme.colorScheme.primary,
      );
    } else {
      return Icon(
        LucideIcons.check,
        size: 16,
        color: context.theme.colorScheme.onPrimaryContainer.withValues(
          alpha: 0.6,
        ),
      );
    }
  }

  Widget _buildMessageInput(BuildContext context) {
    final textController = TextEditingController();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: context.theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: textController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: context.theme.colorScheme.outline.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: context.theme.colorScheme.outline.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: context.theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: context.theme.colorScheme.surfaceContainerHigh,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    controller.sendTextMessage(value.trim());
                    textController.clear();
                  }
                },
              ),
            ),
            AppSpacing.sm.gap,
            FloatingActionButton.small(
              onPressed: () {
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  controller.sendTextMessage(text);
                  textController.clear();
                }
              },
              child: const Icon(LucideIcons.send),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inHours > 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }
}
