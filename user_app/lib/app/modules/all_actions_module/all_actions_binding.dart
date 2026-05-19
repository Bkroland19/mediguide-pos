import 'package:get/get.dart';
import 'all_actions_controller.dart';

class AllActionsBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AllActionsController>(() => AllActionsController());
  }
}
