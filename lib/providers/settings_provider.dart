import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/job_criteria.dart';

class SettingsProvider extends ChangeNotifier {
  JobCriteria _criteria = const JobCriteria();
  JobCriteria get criteria => _criteria;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('job_criteria');
    if (json != null) {
      _criteria = JobCriteria.fromJson(jsonDecode(json));
      notifyListeners();
    }
  }

  Future<void> updateCriteria(JobCriteria criteria) async {
    _criteria = criteria;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('job_criteria', jsonEncode(criteria.toJson()));
    notifyListeners();
  }
}
