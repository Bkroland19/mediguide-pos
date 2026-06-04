import 'package:get/get.dart';
import '../../../app/modules/guidelines_module/guidelines_controller.dart';

class GuidelinesBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<GuidelinesController>(
      () => GuidelinesController(),
    );
  }
}
