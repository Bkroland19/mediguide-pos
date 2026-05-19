import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../utils/loading.dart';
import '../../../utils/app_spacing.dart';
import '../../../data/models/models.dart';
import '../help_center_controller.dart';
import 'ticket_reply_card.dart';

/// Full screen dialog for viewing ticket details and conversation
class TicketDetailDialog extends StatelessWidget {
  final String ticketId;

  const TicketDetailDialog({super.key, required this.ticketId});

  static Future<void> show(String ticketId) {
    return showDialog<void>(
      context: Get.overlayContext!,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (context) => TicketDetailDialog(ticketId: ticketId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HelpCenterController>();
    final cs = context.theme.colorScheme;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadTicketDetails(ticketId);
    });

    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(
            controller.selectedTicket.value?.subject ?? 'Ticket Details',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value &&
            controller.selectedTicket.value == null) {
          return const CenteredLoading.large();
        }

        final ticket = controller.selectedTicket.value;
        if (ticket == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.circleAlert,
                  size: 48,
                  color: cs.onSurfaceVariant,
                ),
                AppSpacing.gapMd,
                Text('Ticket not found', style: context.textTheme.titleMedium),
                AppSpacing.gapSm,
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => controller.loadTicketDetails(ticketId),
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  children: [
                    // ── Ticket info header ──
                    // Status row
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ticket.status.color,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ticket.status.label,
                          style: context.textTheme.labelMedium?.copyWith(
                            color: ticket.status.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (ticket.isHighPriority) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '·',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ),
                          Icon(
                            LucideIcons.flag,
                            size: 14,
                            color: ticket.priority.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ticket.priority.label,
                            style: context.textTheme.labelMedium?.copyWith(
                              color: ticket.priority.color,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          ticket.timeAgo,
                          style: context.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),

                    AppSpacing.gapSm,

                    // Subject
                    Text(
                      ticket.subject,
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    if (ticket.category.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        ticket.category,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: cs.primary,
                        ),
                      ),
                    ],

                    AppSpacing.gapMd,

                    // Description
                    Text(
                      ticket.description,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        height: 1.5,
                      ),
                    ),

                    AppSpacing.gapLg,

                    // ── Conversation ──
                    Divider(color: cs.outlineVariant.withValues(alpha: 0.4)),
                    AppSpacing.gapSm,

                    Text(
                      'CONVERSATION',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),

                    AppSpacing.gapMd,

                    Obx(() {
                      final replies = controller.currentTicketReplies;

                      if (replies.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xl,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                LucideIcons.messageCircle,
                                size: 32,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              AppSpacing.gapSm,
                              Text(
                                'No replies yet',
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: replies
                            .map(
                              (reply) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: TicketReplyCard(reply: reply),
                              ),
                            )
                            .toList(),
                      );
                    }),

                    AppSpacing.gapLg,
                  ],
                ),
              ),
            ),

            // ── Reply input ──
            if (ticket.status != TicketStatus.closed)
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(
                    top: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: FormBuilder(
                    key: controller.replyFormKey,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: FormBuilderTextField(
                            name: 'reply',
                            decoration: const InputDecoration(
                              hintText: 'Type your reply...',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                            minLines: 1,
                            textInputAction: TextInputAction.newline,
                            validator: FormBuilderValidators.compose([
                              FormBuilderValidators.required(),
                              FormBuilderValidators.minLength(1),
                            ]),
                          ),
                        ),
                        AppSpacing.hGapSm,
                        Obx(
                          () => IconButton.filled(
                            onPressed: controller.isAddingReply.value
                                ? null
                                : () => _submitReply(controller),
                            icon: controller.isAddingReply.value
                                ? const Loading.small()
                                : const Icon(LucideIcons.send),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Future<void> _submitReply(HelpCenterController controller) async {
    if (controller.replyFormKey.currentState?.saveAndValidate() ?? false) {
      final message =
          controller.replyFormKey.currentState!.value['reply'] as String;
      await controller.addReplyToCurrentTicket(message);
      if (!controller.isAddingReply.value) {
        controller.replyFormKey.currentState?.reset();
      }
    }
  }
}
