import 'package:get/get.dart';
import 'package:toastification/toastification.dart';
import '../../data/services/backend_service.dart';
import '../../models/generic_page.dart';
import '../../routes/app_pages.dart';
import '../../translations/app_translations.dart';
import '../../utils/common.dart';

class AllActionsController extends GetxController {
  // Tab management
  final RxInt currentTabIndex = 0.obs;

  // Generic pages state
  final RxList<GenericPage> genericPages = <GenericPage>[].obs;
  final RxBool isLoadingPages = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadGenericPages();
  }

  /// Switch to a specific tab
  void switchTab(int index) {
    currentTabIndex.value = index;
  }

  /// Load generic pages from backend
  Future<void> loadGenericPages() async {
    try {
      isLoadingPages.value = true;

      final records = await BackendService.to.getRecordList(
        collectionName: 'generic_pages',
        perPage: 50, // Load all pages
      );

      final pages = records.items
          .map((record) => GenericPage.fromJson(record.toJson()))
          .toList();

      genericPages.assignAll(pages);
    } catch (e) {
      Common.quickToast(
        title: 'Failed to load pages',
        description: 'Could not fetch additional pages.',
        type: ToastificationType.error,
      );
    } finally {
      isLoadingPages.value = false;
    }
  }

  /// Navigate to generic page viewer with actual model
  void navigateToGenericPage(GenericPage page) {
    Get.toNamed(AppRoutes.genericViewer, arguments: page);
  }

  // Navigation methods for essential medical resources
  void navigateToEssentialMedicines() {
    Get.toNamed(AppRoutes.drugIndex);
  }

  void navigateToLabTestMenu() {
    Get.snackbar(
      'Laboratory Test Menu',
      'Opening laboratory testing guidelines...',
      snackPosition: SnackPosition.BOTTOM,
    );
    // TODO: Navigate to lab test menu page
  }

  void navigateToClinicalAlgorithms() {
    // Navigate to Tools page with Decision Tool tab selected (tab index 2)
    Get.toNamed(AppRoutes.tools, arguments: {'initialTab': 2});
  }

  void navigateToInfectionPrevention() {
    Get.snackbar(
      'Infection Prevention',
      'Opening infection control guidelines...',
      snackPosition: SnackPosition.BOTTOM,
    );
    // TODO: Navigate to infection prevention page
  }

  // Navigation methods for core health services
  void navigateToConsultants() {
    Get.snackbar(
      AppTranslationKey.chatWithConsultant,
      'Opening consultant list...',
      snackPosition: SnackPosition.BOTTOM,
    );
    // TODO: Navigate to consultants page
  }

  void navigateToHealthInfrastructure() {
    Get.snackbar(
      AppTranslationKey.healthInfrastructure,
      'Opening health facility map...',
      snackPosition: SnackPosition.BOTTOM,
    );
    // TODO: Navigate to map page
  }

  void navigateToEmergencyContacts() {
    Get.snackbar(
      AppTranslationKey.emergencyContacts,
      'Opening emergency directory...',
      snackPosition: SnackPosition.BOTTOM,
    );
    // TODO: Navigate to emergency contacts page
  }

  void navigateToDrugIndex() {
    Get.toNamed(AppRoutes.drugIndex);
  }

  void navigateToAIChat() {
    Get.toNamed(AppRoutes.aiAssistant);
  }

  void navigateToMedicalCalculators() {
    Get.snackbar(
      AppTranslationKey.medicalCalculators,
      'Opening medical calculators...',
      snackPosition: SnackPosition.BOTTOM,
    );
    // TODO: Navigate to calculators page
  }

  void navigateToGuidelines() {
    Get.toNamed(AppRoutes.guidelines);
  }

  void navigateToTools() {
    Get.toNamed(AppRoutes.tools);
  }

  void navigateToAbbreviations() {
    Get.snackbar(
      AppTranslationKey.medicalAbbreviations,
      'Opening medical abbreviations dictionary...',
      snackPosition: SnackPosition.BOTTOM,
    );
    // TODO: Navigate to abbreviations page
  }
}
