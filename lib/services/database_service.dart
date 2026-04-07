import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/candidate.dart';

/// Web-compatible storage using SharedPreferences (works on all platforms).
/// On mobile you can swap this for sqflite without changing the provider layer.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const _key = 'candidates_v1';

  Future<void> init() async {
    // No-op — SharedPreferences initializes lazily
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  Future<void> _writeAll(List<Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data));
  }

  // ── INSERT ───────────────────────────────────────────────────────────────────

  Future<int> insertCandidate(Candidate candidate) async {
    final all = await _readAll();
    final id = DateTime.now().millisecondsSinceEpoch;
    final map = candidate.toMap()..['id'] = id;
    all.insert(0, map);
    await _writeAll(all);
    return id;
  }

  Future<List<int>> insertCandidates(List<Candidate> candidates) async {
    final all = await _readAll();
    final ids = <int>[];
    for (final c in candidates) {
      final id = DateTime.now().millisecondsSinceEpoch + ids.length;
      final map = c.toMap()..['id'] = id;
      all.insert(0, map);
      ids.add(id);
    }
    await _writeAll(all);
    return ids;
  }

  // ── READ ─────────────────────────────────────────────────────────────────────

  Future<List<Candidate>> getAllCandidates({String orderBy = 'ai_score DESC'}) async {
    final all = await _readAll();
    final candidates = all.map(Candidate.fromMap).toList();
    candidates.sort((a, b) => b.aiScore.compareTo(a.aiScore));
    return candidates;
  }

  Future<Candidate?> getCandidateById(int id) async {
    final all = await _readAll();
    final map = all.cast<Map<String, dynamic>?>().firstWhere(
          (m) => m?['id'] == id,
          orElse: () => null,
        );
    return map != null ? Candidate.fromMap(map) : null;
  }

  Future<List<Candidate>> getAllForExport() => getAllCandidates();

  // ── UPDATE ───────────────────────────────────────────────────────────────────

  Future<void> updateStatus(int id, CandidateStatus status) async {
    final all = await _readAll();
    final idx = all.indexWhere((m) => m['id'] == id);
    if (idx != -1) {
      all[idx]['status'] = status.dbValue;
      await _writeAll(all);
    }
  }

  Future<void> updateCandidate(Candidate candidate) async {
    final all = await _readAll();
    final idx = all.indexWhere((m) => m['id'] == candidate.id);
    if (idx != -1) {
      all[idx] = candidate.toMap();
      await _writeAll(all);
    }
  }

  // ── DELETE ───────────────────────────────────────────────────────────────────

  Future<void> deleteCandidate(int id) async {
    final all = await _readAll();
    all.removeWhere((m) => m['id'] == id);
    await _writeAll(all);
  }

  Future<void> deleteAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
