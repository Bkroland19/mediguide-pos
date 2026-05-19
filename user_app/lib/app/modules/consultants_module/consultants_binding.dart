import 'package:get/get.dart';

import '../../../app/modules/consultants_module/consultants_controller.dart';

class ConsultantsBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ConsultantsController>(() => ConsultantsController());
  }
}
