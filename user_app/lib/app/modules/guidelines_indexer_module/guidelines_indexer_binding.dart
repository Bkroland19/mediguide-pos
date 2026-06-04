import 'package:get/get.dart';
import 'guidelines_indexer_controller.dart';

class GuidelinesIndexerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<GuidelinesIndexerController>(
      () => GuidelinesIndexerController(),
    );
  }
}