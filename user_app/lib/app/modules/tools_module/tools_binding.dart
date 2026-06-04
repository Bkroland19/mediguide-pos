import 'package:get/get.dart';
import '../../../app/modules/tools_module/tools_controller.dart';

class ToolsBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ToolsController>(
      () => ToolsController(),
    );
  }
}
