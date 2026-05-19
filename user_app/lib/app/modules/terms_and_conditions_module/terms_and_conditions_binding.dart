import 'package:get/get.dart';

import '../../../app/modules/terms_and_conditions_module/terms_and_conditions_controller.dart';

class TermsAndConditionsBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TermsAndConditionsController>(
      () => TermsAndConditionsController(),
    );
  }
}
