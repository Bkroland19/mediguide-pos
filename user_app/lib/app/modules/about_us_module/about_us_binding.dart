import 'package:get/get.dart';

import '../../../app/modules/about_us_module/about_us_controller.dart';

class AboutUsBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AboutUsController>(() => AboutUsController());
  }
}
