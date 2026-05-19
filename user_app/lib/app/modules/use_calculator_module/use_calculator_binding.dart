import 'package:get/get.dart';

import '../../../app/modules/use_calculator_module/use_calculator_controller.dart';

class UseCalculatorBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UseCalculatorController>(() => UseCalculatorController());
  }
}
