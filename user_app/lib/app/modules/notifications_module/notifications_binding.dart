import 'package:get/get.dart';

import '../../../app/modules/notifications_module/notifications_controller.dart';

class NotificationsBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NotificationsController>(() => NotificationsController());
  }
}
