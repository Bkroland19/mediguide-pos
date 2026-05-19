import 'package:get/get.dart';

import '../../../app/modules/health_infrastructure_module/health_infrastructure_controller.dart';

class HealthInfrastructureBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HealthInfrastructureController>(
      () => HealthInfrastructureController(),
    );
  }
}
