import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import '../models/candidate.dart';

// Mobile-only imports loaded conditionally
import 'export_service_stub.dart'
    if (dart.library.io) 'export_service_mobile.dart';

class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  Future<void> exportAndShare(List<Candidate> candidates, String format) async {
    final content = format == 'csv' ? _buildCsv(candidates) : _buildJson(candidates);
    final fileName = 'candidates_export.$format';

    if (kIsWeb) {
      // On web: trigger browser download
      downloadFileWeb(content, fileName, format == 'csv' ? 'text/csv' : 'application/json');
    } else {
      // On mobile: save to documents and share
      await saveAndShareMobile(content, fileName);
    }
  }

  String _buildCsv(List<Candidate> candidates) {
    final rows = <List<String>>[
      Candidate.csvHeaders(),
      ...candidates.map((c) => c.toCsvRow()),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  String _buildJson(List<Candidate> candidates) {
    return const JsonEncoder.withIndent('  ').convert(
      candidates.map((c) => c.toMap()).toList(),
    );
  }
}
