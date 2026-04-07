import 'dart:convert';
import 'dart:io' show ZLibDecoder;
import 'package:syncfusion_flutter_pdf/pdf.dart';
/// Web-safe resume text extractor.
/// Always use [extractFromBytes] — works on web + mobile.
/// [extractText] is mobile-only (uses file path).
class FileParserService {
  FileParserService._();
  static final FileParserService instance = FileParserService._();

  /// Extract from bytes — works on ALL platforms including web.
  Future<String> extractFromBytes(List<int> bytes, String ext) async {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return _extractPdf(bytes);
      case 'docx':
        return _extractDocx(bytes);
      case 'txt':
        return utf8.decode(bytes, allowMalformed: true);
      default:
        throw FileParserException('Unsupported file type: .$ext');
    }
  }

  // ── PDF ─────────────────────────────────────────────────────────────────────

  String _extractPdf(List<int> bytes) {
    try {
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      document.dispose();
      return text.isEmpty ? 'PDF parsed but no text extracted.' : text;
    } catch (e) {
      throw FileParserException('Failed to parse PDF: $e');
    }
  }

  // ── DOCX ─────────────────────────────────────────────────────────────────────

  String _extractDocx(List<int> bytes) {
    try {
      final xml = _extractZipEntry(bytes, 'word/document.xml');
      if (xml == null) throw FileParserException('Invalid DOCX structure');
      return _stripXmlTags(xml);
    } catch (e) {
      if (e is FileParserException) rethrow;
      throw FileParserException('Failed to parse DOCX: $e');
    }
  }

  /// Pure Dart ZIP reader — no dart:io, works on web.
  /// Uses dart:convert ZLibDecoder for deflate decompression.
  String? _extractZipEntry(List<int> bytes, String entryName) {
    // Find End of Central Directory record
    int eocd = -1;
    for (int i = bytes.length - 22; i >= 0; i--) {
      if (bytes[i] == 0x50 && bytes[i + 1] == 0x4B &&
          bytes[i + 2] == 0x05 && bytes[i + 3] == 0x06) {
        eocd = i;
        break;
      }
    }
    if (eocd == -1) return null;

    final cdOffset = _i32(bytes, eocd + 16);
    final cdSize = _i32(bytes, eocd + 12);
    int pos = cdOffset;

    while (pos < cdOffset + cdSize) {
      if (_i32(bytes, pos) != 0x02014B50) break;
      final fnLen = _i16(bytes, pos + 28);
      final exLen = _i16(bytes, pos + 30);
      final cmLen = _i16(bytes, pos + 32);
      final lhOff = _i32(bytes, pos + 42);
      final fn = utf8.decode(bytes.sublist(pos + 46, pos + 46 + fnLen), allowMalformed: true);

      if (fn == entryName) {
        final lhFnLen = _i16(bytes, lhOff + 26);
        final lhExLen = _i16(bytes, lhOff + 28);
        final dataStart = lhOff + 30 + lhFnLen + lhExLen;
        final compSize = _i32(bytes, lhOff + 18);
        final method = _i16(bytes, lhOff + 8);
        final data = bytes.sublist(dataStart, dataStart + compSize);

        if (method == 0) {
          return utf8.decode(data, allowMalformed: true);
        } else if (method == 8) {
          // Deflate — use zlib codec from dart:convert (web-safe)
          final out = ZLibDecoder().convert(data);
          return utf8.decode(out, allowMalformed: true);
        }
        return null;
      }
      pos += 46 + fnLen + exLen + cmLen;
    }
    return null;
  }

  int _i16(List<int> b, int o) => b[o] | (b[o + 1] << 8);
  int _i32(List<int> b, int o) =>
      b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

  String _stripXmlTags(String xml) {
    final buf = StringBuffer();
    for (final m in RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true).allMatches(xml)) {
      buf.write('${m.group(1)} ');
    }
    final result = buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    // Fallback: strip all XML tags if no <w:t> found
    return result.isNotEmpty ? result : xml.replaceAll(RegExp(r'<[^>]+>'), ' ').trim();
  }
}

class FileParserException implements Exception {
  final String message;
  FileParserException(this.message);
  @override
  String toString() => 'FileParserException: $message';
}
