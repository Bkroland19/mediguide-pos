import 'package:get/get.dart';

import '../../../app/modules/ai_assistant_module/ai_assistant_controller.dart';

class AiAssistantBinding implements Bindings {
  @override
  void dependencies() {
    // OpenAI service is already initialized in main.dart
    // Just initialize the controller
    Get.lazyPut<AiAssistantController>(() => AiAssistantController());
  }
}
