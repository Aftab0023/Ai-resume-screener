import 'package:flutter/material.dart';
import '../models/candidate.dart';
import '../services/database_service.dart';

enum LoadState { idle, loading, success, error }

class FilterOptions {
  final double minScore;
  final double maxScore;
  final CandidateStatus? status;
  final int? minExperience;
  final int? maxExperience;
  final DateTime? fromDate;
  final DateTime? toDate;

  const FilterOptions({
    this.minScore = 0,
    this.maxScore = 100,
    this.status,
    this.minExperience,
    this.maxExperience,
    this.fromDate,
    this.toDate,
  });

  bool get hasActiveFilters =>
      minScore > 0 ||
      maxScore < 100 ||
      status != null ||
      minExperience != null ||
      maxExperience != null ||
      fromDate != null ||
      toDate != null;

  FilterOptions copyWith({
    double? minScore,
    double? maxScore,
    CandidateStatus? status,
    bool clearStatus = false,
    int? minExperience,
    int? maxExperience,
    DateTime? fromDate,
    DateTime? toDate,
  }) =>
      FilterOptions(
        minScore: minScore ?? this.minScore,
        maxScore: maxScore ?? this.maxScore,
        status: clearStatus ? null : (status ?? this.status),
        minExperience: minExperience ?? this.minExperience,
        maxExperience: maxExperience ?? this.maxExperience,
        fromDate: fromDate ?? this.fromDate,
        toDate: toDate ?? this.toDate,
      );
}

class CandidateProvider extends ChangeNotifier {
  List<Candidate> _all = [];
  List<Candidate> _filtered = [];
  LoadState _state = LoadState.idle;
  String _error = '';
  String _searchQuery = '';
  FilterOptions _filters = const FilterOptions();

  List<Candidate> get candidates => _filtered;
  List<Candidate> get allCandidates => _all;
  LoadState get state => _state;
  String get error => _error;
  FilterOptions get filters => _filters;
  String get searchQuery => _searchQuery;

  int get totalCount => _all.length;
  int get shortlistedCount =>
      _all.where((c) => c.status == CandidateStatus.shortlisted).length;
  int get rejectedCount =>
      _all.where((c) => c.status == CandidateStatus.rejected).length;
  int get pendingCount =>
      _all.where((c) => c.status == CandidateStatus.pending).length;

  // ── Load ────────────────────────────────────────────────────────────────────

  Future<void> loadCandidates() async {
    _setState(LoadState.loading);
    try {
      _all = await DatabaseService.instance.getAllCandidates();
      _applyFilters();
      _setState(LoadState.success);
    } catch (e) {
      _error = e.toString();
      _setState(LoadState.error);
    }
  }

  // ── Add ─────────────────────────────────────────────────────────────────────

  Future<void> addCandidate(Candidate candidate) async {
    final id = await DatabaseService.instance.insertCandidate(candidate);
    final saved = candidate.copyWith(id: id);
    _all.insert(0, saved);
    _applyFilters();
    notifyListeners();
  }

  Future<void> addCandidates(List<Candidate> candidates) async {
    final ids = await DatabaseService.instance.insertCandidates(candidates);
    for (int i = 0; i < candidates.length; i++) {
      _all.insert(0, candidates[i].copyWith(id: ids[i]));
    }
    _applyFilters();
    notifyListeners();
  }

  // ── Update ──────────────────────────────────────────────────────────────────

  Future<void> updateStatus(int id, CandidateStatus status) async {
    await DatabaseService.instance.updateStatus(id, status);
    final idx = _all.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _all[idx] = _all[idx].copyWith(status: status);
      _applyFilters();
      notifyListeners();
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  Future<void> deleteCandidate(int id) async {
    await DatabaseService.instance.deleteCandidate(id);
    _all.removeWhere((c) => c.id == id);
    _applyFilters();
    notifyListeners();
  }

  Future<void> deleteAll() async {
    await DatabaseService.instance.deleteAll();
    _all.clear();
    _filtered.clear();
    notifyListeners();
  }

  // ── Search & Filter ─────────────────────────────────────────────────────────

  void search(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void applyFilters(FilterOptions filters) {
    _filters = filters;
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _filters = const FilterOptions();
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    var list = List<Candidate>.from(_all);

    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((c) =>
              c.name.toLowerCase().contains(q) ||
              c.email.toLowerCase().contains(q) ||
              c.skills.any((s) => s.toLowerCase().contains(q)))
          .toList();
    }

    // Score range
    list = list
        .where((c) => c.aiScore >= _filters.minScore && c.aiScore <= _filters.maxScore)
        .toList();

    // Status
    if (_filters.status != null) {
      list = list.where((c) => c.status == _filters.status).toList();
    }

    // Experience
    if (_filters.minExperience != null) {
      list = list.where((c) => c.experienceYears >= _filters.minExperience!).toList();
    }
    if (_filters.maxExperience != null) {
      list = list.where((c) => c.experienceYears <= _filters.maxExperience!).toList();
    }

    // Date range
    if (_filters.fromDate != null) {
      list = list.where((c) => c.uploadDate.isAfter(_filters.fromDate!)).toList();
    }
    if (_filters.toDate != null) {
      list = list.where((c) => c.uploadDate.isBefore(_filters.toDate!)).toList();
    }

    // Sort by score descending
    list.sort((a, b) => b.aiScore.compareTo(a.aiScore));
    _filtered = list;
  }

  // ── Export ──────────────────────────────────────────────────────────────────

  Future<List<Candidate>> getAllForExport() async {
    return DatabaseService.instance.getAllForExport();
  }

  void _setState(LoadState s) {
    _state = s;
    notifyListeners();
  }
}
