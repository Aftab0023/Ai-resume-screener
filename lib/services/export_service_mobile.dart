import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile implementation — saves file and opens share sheet.
Future<void> saveAndShareMobile(String content, String fileName) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(content);
  await Share.shareXFiles([XFile(file.path)]);
}

/// Stub for web — not used on mobile.
void downloadFileWeb(String content, String fileName, String mimeType) {
  throw UnsupportedError('downloadFileWeb not available on mobile');
}
