import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation — triggers a browser file download.
void downloadFileWeb(String content, String fileName, String mimeType) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}

/// Stub for mobile — not used on web.
Future<void> saveAndShareMobile(String content, String fileName) async {
  throw UnsupportedError('saveAndShareMobile not available on web');
}
