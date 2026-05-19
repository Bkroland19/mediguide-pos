import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_app/app/data/services/backend_service.dart';
import 'package:user_app/app/utils/constants.dart';
import 'package:user_app/app/utils/preference_utils.dart';
import 'package:user_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    SharedPreferences.setMockInitialValues({
      SharedPreferencesKeys.notFirstTime: true,
    });
    await PreferenceUtils.init();
    Get.put<BackendService>(BackendService());
  });

  tearDown(Get.reset);

  testWidgets('app boots to login when unauthenticated', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Create Account'), findsOneWidget);
  });
}
