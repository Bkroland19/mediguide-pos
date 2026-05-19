import 'package:get/get.dart';

class TermsAndConditionsController extends GetxController {
  final _text = 'TermsAndConditions'.obs;
  set text(String text) => _text.value = text;
  String get text => _text.value;
}
