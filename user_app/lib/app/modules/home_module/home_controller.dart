import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/backend_service.dart';
import '../../data/models/models.dart';
import '../../routes/app_pages.dart';
import './models/stats_model.dart';

class HomeController extends GetxController {
  // Services
  AuthService get _authService => AuthService.to;
  BackendService get _pbService => BackendService.to;

  // Observable state
  final RxBool isLoading = false.obs;
  final RxList<ReadingProgress> continueReadingItems = <ReadingProgress>[].obs;
  final RxList<Calculator> featuredCalculators = <Calculator>[].obs;
  final RxInt unreadMessagesCount = 300.obs;

  // Stats data
  final RxMap<String, int> stats = <String, int>{}.obs;
  final RxBool isLoadingStats = false.obs;
  DateTime? _lastStatsFetch;

  @override
  void onInit() {
    super.onInit();
    loadInitialData();
  }

  /// Load all initial data including stats
  Future<void> loadInitialData() async {
    await Future.wait([
      loadAllData(),
      fetchStats(), // This now includes unread messages count from the API
    ]);
  }

  /// Load data from backend
  Future<void> loadAllData() async {
    isLoading.value = true;

    try {
      // Load real featured calculators from backend
      await _loadFeaturedCalculators();

      // Load continue reading items from backend
      await _loadContinueReadingItems();

      // No additional collections to clear
    } catch (e) {
      debugPrint('Error loading data: $e');
      // Clear all collections on error
      featuredCalculators.clear();
      continueReadingItems.clear();
    } finally {
      isLoading.value = false;
    }
  }

  /// Refresh all data including stats
  Future<void> refreshData() async {
    await Future.wait([
      loadAllData(),
      fetchStats(
        forceRefresh: true,
      ), // This now includes unread messages count from the API
    ]);
  }

  /// Navigate to continue reading a guideline
  Future<void> navigateToContinueReading(ReadingProgress progress) async {
    try {
      final record = await _pbService.getRecord(
        collectionName: Guideline.collection,
        recordId: progress.guidelineId,
        expand: 'categories,tags',
      );
      if (record == null) return;
      final guideline = Guideline.fromRecord(record);
      Get.toNamed(AppRoutes.readGuideline, arguments: guideline);
    } catch (e) {
      debugPrint('Error loading guideline: $e');
    }
  }

  /// Load featured and most used calculators from backend
  Future<void> _loadFeaturedCalculators() async {
    try {
      // First get featured calculators
      final featuredCalculatorsList = await getCalculators(
        perPage: 6,
        filter: 'featured=true && status="active"',
        sort: '-usageCount,-created',
      );

      // If we have less than 6, fill with most used calculators
      if (featuredCalculatorsList.length < 6) {
        final remainingCount = 6 - featuredCalculatorsList.length;
        final mostUsedCalculators = await getCalculators(
          perPage: remainingCount,
          filter: 'featured!=true && status="active"',
          sort: '-usageCount,-created',
        );
        featuredCalculatorsList.addAll(mostUsedCalculators);
      }

      featuredCalculators.assignAll(featuredCalculatorsList.take(6).toList());
    } catch (e) {
      // Silently return empty list on error
      featuredCalculators.clear();
    }
  }

  /// Load continue reading items for current user
  Future<void> _loadContinueReadingItems() async {
    try {
      final currentUser = _authService.currentUser.value;
      if (currentUser == null) return;

      final records = await _pbService.getRecordList(
        collectionName: 'reading_progress',
        perPage: 5,
        filter:
            'user_id="${currentUser.id}" && progress_percentage>0 && progress_percentage<1',
        sort: '-last_read_at',
      );

      final progressItems = records.items
          .map((record) => ReadingProgress.fromRecord(record))
          .toList();

      continueReadingItems.assignAll(progressItems);
    } catch (e) {
      debugPrint('Error loading continue reading items: $e');
      continueReadingItems.clear();
    }
  }

  // ==================== CALCULATOR-SPECIFIC METHODS ====================

  /// Get calculators with optional filtering and pagination
  Future<List<Calculator>> getCalculators({
    int page = 1,
    int perPage = 30,
    String? filter,
    String? sort,
    String? expand,
  }) async {
    final result = await _pbService.getRecordList(
      collectionName: Calculator.collection,
      page: page,
      perPage: perPage,
      filter: filter,
      sort: sort,
      expand: expand,
    );
    return result.items.map((record) => Calculator.fromRecord(record)).toList();
  }

  /// Create a new calculator
  Future<Calculator> createCalculator(
    Map<String, dynamic> calculatorData,
  ) async {
    final record = await _pbService.createRecord(
      collectionName: Calculator.collection,
      data: calculatorData,
    );
    return Calculator.fromRecord(record);
  }

  /// Update an existing calculator
  Future<Calculator> updateCalculator(
    String calculatorId,
    Map<String, dynamic> calculatorData,
  ) async {
    final record = await _pbService.updateRecord(
      collectionName: Calculator.collection,
      recordId: calculatorId,
      data: calculatorData,
    );
    return Calculator.fromRecord(record);
  }

  // ==================== STATS METHODS ====================

  /// Fetch statistics from backend stats API endpoint
  Future<void> fetchStats({bool forceRefresh = false}) async {
    if (!forceRefresh && _shouldUseStatsCache()) return;

    try {
      isLoadingStats.value = true;

      // Get stats directly from backend API endpoint
      final response = await _pbService.getCustomEndpoint(
        path: '/api/stats',
        forceRefresh: forceRefresh,
      );

      if (response['success'] == true) {
        final Map<String, int> newStats = {};

        // Map API response to stats map
        newStats['drugs'] = response['drugs'] as int? ?? 0;
        newStats['medical_guidelines'] =
            response['medical_guidelines'] as int? ?? 0;
        newStats['calculators'] = response['calculators'] as int? ?? 0;
        newStats['abbreviations'] = response['abbreviations'] as int? ?? 0;
        newStats['health_facilities'] =
            response['health_facilities'] as int? ?? 0;
        newStats['consultants'] = response['consultants'] as int? ?? 0;
        newStats['ministry_directory'] =
            response['ministry_directory'] as int? ?? 0;
        newStats['faqs'] = response['faqs'] as int? ?? 0;
        newStats['user_conversations_count'] =
            response['user_conversations_count'] as int? ?? 0;

        stats.assignAll(newStats);

        // Update unread messages count from API response
        unreadMessagesCount.value =
            response['unread_messages_count'] as int? ?? 0;

        _lastStatsFetch = DateTime.now();
      } else {
        throw Exception('Stats API returned success: false');
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');

      // Set default values on error
      stats.assignAll({
        'drugs': 0,
        'medical_guidelines': 0,
        'calculators': 0,
        'abbreviations': 0,
        'health_facilities': 0,
        'consultants': 0,
        'ministry_directory': 0,
        'faqs': 0,
        'user_conversations_count': 0,
      });
      unreadMessagesCount.value = 0;

      // Only show toast in debug mode to avoid spamming users
      // Common.quickToast(title: 'Failed to load stats');
    } finally {
      isLoadingStats.value = false;
    }
  }

  /// Check if stats cache is still valid
  bool _shouldUseStatsCache() {
    if (_lastStatsFetch == null) return false;
    return DateTime.now().difference(_lastStatsFetch!).inMinutes < 5;
  }

  /// Convert stats map to StatsModel for the StatsWidget
  StatsModel get statsModel {
    return StatsModel(
      drugsCount: stats['drugs'] ?? 0,
      guidelinesCount: stats['medical_guidelines'] ?? 0,
      healthcareFacilitiesCount: stats['health_facilities'] ?? 0,
      consultantsCount: stats['consultants'] ?? 0,
      patientsServedCount:
          stats['calculators'] ??
          0, // Using calculators as tools/resources used
      emergencyContactsCount:
          stats['ministry_directory'] ?? 0, // Ministry directory contacts
      faqsCount: stats['faqs'] ?? 0,
      unreadMessagesCount: unreadMessagesCount.value,
      userConversationsCount: stats['user_conversations_count'] ?? 0,
      lastUpdated: _lastStatsFetch ?? DateTime.now(),
    );
  }
}
