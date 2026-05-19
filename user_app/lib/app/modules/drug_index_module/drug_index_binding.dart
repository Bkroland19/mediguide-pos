import 'package:get/get.dart';

import '../../../app/modules/drug_index_module/drug_index_controller.dart';

class DrugIndexBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DrugIndexController>(() => DrugIndexController());
  }
}
