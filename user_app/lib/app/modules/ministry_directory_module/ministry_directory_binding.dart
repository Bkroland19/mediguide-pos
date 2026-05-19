import 'package:get/get.dart';

import '../../../app/modules/ministry_directory_module/ministry_directory_controller.dart';

class MinistryDirectoryBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MinistryDirectoryController>(
      () => MinistryDirectoryController(),
    );
  }
}
