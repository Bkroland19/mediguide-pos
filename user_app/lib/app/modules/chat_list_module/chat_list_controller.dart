import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../data/models/models.dart';
import '../../data/models/filter_models.dart';
import '../../data/services/backend_service.dart';
import '../../data/services/auth_service.dart';
import '../../routes/app_pages.dart';
import '../../utils/constants.dart';
import '../../utils/common.dart';
import '../../widgets/generic_filter_bottom_sheet.dart';

class ChatListController extends GetxController {
  // Pagination controller
  late final PagingController<int, Conversation> pagingController;

  // Search and filter state
  final RxString searchQuery = ''.obs;
  final RxBool hasActiveFilters = false.obs;
  final RxBool showRecentOnly = false.obs;
  final RxBool showVerifiedOnly = false.obs;

  @override
  void onInit() {
    super.onInit();

    // Ensure model registrations are triggered
    User.ensureRegistration();
    Conversation.ensureRegistration();
    Message.ensureRegistration();

    pagingController = PagingController<int, Conversation>(
      getNextPageKey: (state) =>
          state.lastPageIsEmpty ? null : state.nextIntPageKey,
      fetchPage: _loadPage,
    );
  }

  @override
  void onClose() {
    pagingController.dispose();
    super.onClose();
  }

  /// Load a page of conversations
  Future<List<Conversation>> _loadPage(int pageKey) async {
    try {
      final currentUserId = AuthService.to.currentUser.value?.id;
      if (currentUserId == null) return [];

      // Build filter for conversations where current user is a participant
      final filters = <String>[];
      filters.add(
        '(participant1 = "$currentUserId") || (participant2 = "$currentUserId")',
      );

      // Apply recent only filter (conversations from last 7 days)
      if (showRecentOnly.value) {
        final weekAgo = DateTime.now().subtract(Duration(days: 7));
        filters.add('last_activity >= "${weekAgo.toIso8601String()}"');
      }

      final filter = filters.join(' && ');

      final result = await BackendService.to.getRecordList(
        collectionName: Conversation.collection,
        page: pageKey,
        perPage: pageSize,
        filter: filter,
        sort: '-last_activity', // Most recent conversations first
        expand: 'participant1,participant2,messages_via_conversation',
      );

      final conversations = result.items
          .map((record) => Conversation.fromRecord(record))
          .toList();

      // Apply local filters
      var filteredConversations = conversations;

      // Apply search filter locally if needed
      if (searchQuery.value.isNotEmpty) {
        filteredConversations = filteredConversations.where((conversation) {
          final otherParticipant = conversation.getOtherParticipant(
            currentUserId,
          );
          final name = otherParticipant?.name ?? '';
          final email = otherParticipant?.email ?? '';
          final query = searchQuery.value.toLowerCase();
          return name.toLowerCase().contains(query) ||
              email.toLowerCase().contains(query);
        }).toList();
      }

      // Apply verified only filter
      if (showVerifiedOnly.value) {
        filteredConversations = filteredConversations.where((conversation) {
          final otherParticipant = conversation.getOtherParticipant(
            currentUserId,
          );
          return otherParticipant?.emailVisibility ==
              true; // Use emailVisibility as verification indicator
        }).toList();
      }

      return filteredConversations;
    } catch (e) {
      Common.quickToast(
        title: 'Failed to load conversations',
        description: e.toString(),
      );
      rethrow;
    }
  }

  /// Search conversations
  void searchConversations(String query) {
    searchQuery.value = query;
    _updateHasActiveFilters();
    pagingController.refresh();
  }

  /// Clear all filters
  void clearAllFilters() {
    searchQuery.value = '';
    showRecentOnly.value = false;
    showVerifiedOnly.value = false;
    hasActiveFilters.value = false;
    pagingController.refresh();
  }

  /// Clear search
  void clearSearch() {
    searchQuery.value = '';
    _updateHasActiveFilters();
    pagingController.refresh();
  }

  /// Update hasActiveFilters based on current filter state
  void _updateHasActiveFilters() {
    hasActiveFilters.value =
        searchQuery.value.isNotEmpty ||
        showRecentOnly.value ||
        showVerifiedOnly.value;
  }

  /// Refresh conversations
  void refreshConversations() {
    pagingController.refresh();
  }

  /// Navigate to chat interface with specific user
  void openChatWith(User otherUser) {
    Get.toNamed(AppRoutes.chatInterface, arguments: otherUser);
  }

  /// Get other participant from conversation
  User? getOtherParticipant(Conversation conversation) {
    final currentUserId = AuthService.to.currentUser.value?.id;
    if (currentUserId == null) return null;
    return conversation.getOtherParticipant(currentUserId);
  }

  /// Get conversation display name
  String getConversationName(Conversation conversation) {
    final currentUserId = AuthService.to.currentUser.value?.id;
    if (currentUserId == null) return 'Unknown';
    return conversation.getDisplayName(currentUserId);
  }

  /// Get relative time for last activity
  String getRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  /// Show filter modal using generic filter bottom sheet
  Future<void> showFilterModal(BuildContext context) async {
    final fields = <FilterField>[
      FilterField.text('search', 'search'.tr, hint: 'searchConversations'.tr),
      FilterField.boolean('showRecentOnly', 'Recent Conversations Only'),
      FilterField.boolean('showVerifiedOnly', 'Verified Users Only'),
    ];

    // Get initial values
    final values = <String, dynamic>{};
    if (searchQuery.value.isNotEmpty) values['search'] = searchQuery.value;
    if (showRecentOnly.value) values['showRecentOnly'] = true;
    if (showVerifiedOnly.value) values['showVerifiedOnly'] = true;

    if (!context.mounted) return;

    final result = await GenericFilterBottomSheet.show(
      context: context,
      title: 'conversations'.tr,
      fields: fields,
      initialValues: values,
    );

    if (result != null && result.isNotEmpty) {
      _applyFilters(result);
    }
  }

  /// Apply filters from the generic filter result
  void _applyFilters(FilterResult result) {
    // Clear existing filters first
    searchQuery.value = '';
    showRecentOnly.value = false;
    showVerifiedOnly.value = false;

    // Apply new filters
    final search = result.getValue<String>('search');
    if (search != null && search.isNotEmpty) {
      searchQuery.value = search;
    }

    final recentOnly = result.getValue<bool>('showRecentOnly');
    if (recentOnly == true) {
      showRecentOnly.value = true;
    }

    final verifiedOnly = result.getValue<bool>('showVerifiedOnly');
    if (verifiedOnly == true) {
      showVerifiedOnly.value = true;
    }

    _updateHasActiveFilters();
    pagingController.refresh();
  }
}
