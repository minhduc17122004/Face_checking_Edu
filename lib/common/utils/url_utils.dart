import 'package:url_launcher/url_launcher_string.dart';

Future<void> launchURL(String? url) async {
  String link = url ?? '';
  if (link.isNotEmpty) {
    if (!((link.contains("http")) && (link.contains("https")))) {
      link = "https://$link";
    }
    await launchUrlString(link, mode: LaunchMode.externalApplication);
  }
}
