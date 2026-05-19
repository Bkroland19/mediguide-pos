import 'package:get/get.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import '../../data/models/models.dart';
import '../../data/services/backend_service.dart';
import '../../data/services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/common.dart';

class NotificationsController extends GetxController {
  // Pagination controller
  late final PagingController<int, MyNotification> pagingController;

  // Search and filter state
  final RxString searchQuery = ''.obs;
  final RxBool hasActiveFilters = false.obs;
  final RxString selectedType = ''.obs;
  final RxString selectedPriority = ''.obs;

  @override
  void onInit() {
    super.onInit();
    pagingController = PagingController<int, MyNotification>(
      getNextPageKey: (state) =>
          state.lastPageIsEmpty ? null : state.nextIntPageKey,
      fetchPage: _loadPage,
    );

    // Listen to search changes
    searchQuery.listen((_) => _refreshData());
    selectedType.listen((_) => _refreshData());
    selectedPriority.listen((_) => _refreshData());
  }

  @override
  void onClose() {
    pagingController.dispose();
    super.onClose();
  }

  /// Load page of notifications
  Future<List<MyNotification>> _loadPage(int pageKey) async {
    try {
      final currentUserId = AuthService.to.currentUser.value?.id;
      String filter = '';

      // Build filter for user-specific + general notifications
      if (currentUserId != null) {
        filter = 'user_id = "" || user_id = "$currentUserId"';
      } else {
        filter = 'user_id = ""';
      }

      // Add search filter
      if (searchQuery.value.isNotEmpty) {
        filter +=
            ' && (title ~ "${searchQuery.value}" || message ~ "${searchQuery.value}")';
      }

      // Add type filter
      if (selectedType.value.isNotEmpty) {
        filter += ' && type = "${selectedType.value}"';
      }

      // Add priority filter
      if (selectedPriority.value.isNotEmpty) {
        filter += ' && priority = "${selectedPriority.value}"';
      }

      final result = await BackendService.to.getRecordList(
        collectionName: 'notifications',
        page: pageKey,
        perPage: pageSize,
        filter: filter,
        sort: '-created',
      );

      final notifications = result.items
          .map((record) => MyNotification.fromRecord(record))
          .toList();
      return notifications;
    } catch (error) {
      Common.quickToast(title: 'Error loading notifications');
      rethrow;
    }
  }

  /// Refresh data
  void _refreshData() {
    _updateFilterState();
    pagingController.refresh();
  }

  /// Update filter state
  void _updateFilterState() {
    hasActiveFilters.value =
        searchQuery.value.isNotEmpty ||
        selectedType.value.isNotEmpty ||
        selectedPriority.value.isNotEmpty;
  }

  /// Clear all filters
  void clearAllFilters() {
    searchQuery.value = '';
    selectedType.value = '';
    selectedPriority.value = '';
  }

  /// Set type filter
  void setTypeFilter(String type) {
    selectedType.value = type;
  }

  /// Set priority filter
  void setPriorityFilter(String priority) {
    selectedPriority.value = priority;
  }
}
