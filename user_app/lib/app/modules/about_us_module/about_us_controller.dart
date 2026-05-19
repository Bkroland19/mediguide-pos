import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutUsController extends GetxController {
  static AboutUsController get to => Get.find();

  /// Launch external URL
  Future<void> launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Launch email client
  Future<void> launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
