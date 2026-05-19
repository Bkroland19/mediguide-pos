import 'package:get/get.dart';

import '../../../app/modules/main_module/main_controller.dart';
import '../../controllers/global_search_controller.dart';

class MainBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MainController>(() => MainController());
    Get.lazyPut<GlobalSearchController>(() => GlobalSearchController());
  }
}
