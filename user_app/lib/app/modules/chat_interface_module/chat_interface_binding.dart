import 'package:get/get.dart';

import '../../../app/modules/chat_interface_module/chat_interface_controller.dart';

class ChatInterfaceBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ChatInterfaceController>(() => ChatInterfaceController());
  }
}
