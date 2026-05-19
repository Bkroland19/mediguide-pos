import 'package:get/get.dart';

import '../../../app/modules/read_guideline_module/read_guideline_controller.dart';

class ReadGuidelineBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReadGuidelineController>(() => ReadGuidelineController());
  }
}
