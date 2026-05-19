import 'package:get/get.dart';

import '../../../app/modules/generic_viewer_module/generic_viewer_controller.dart';

class GenericViewerBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<GenericViewerController>(() => GenericViewerController());
  }
}
