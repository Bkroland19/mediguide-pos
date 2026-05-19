import 'package:get/get.dart';

import '../../../app/modules/abbreviations_module/abbreviations_controller.dart';

class AbbreviationsBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AbbreviationsController>(() => AbbreviationsController());
  }
}
