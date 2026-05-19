import 'package:get/get.dart';

import '../../../app/modules/ai_assistant_module/ai_assistant_controller.dart';

class AiAssistantBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AiAssistantController>(() => AiAssistantController());
  }
}
