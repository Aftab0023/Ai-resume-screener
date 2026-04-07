import 'dart:convert';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/candidate.dart';
import '../models/job_criteria.dart';

/// AI Scoring Service — powered by Sarvam AI /v1/chat/completions (sarvam-m)
class AIScoringService {
  AIScoringService._();
  static final AIScoringService instance = AIScoringService._();

  static String get apiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  static const String _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  // ── Public API ──────────────────────────────────────────────────────────────

  Future<Candidate> scoreCandidate({
    required String resumeText,
    required String filePath,
    required JobCriteria criteria,
  }) async {
    try {
      return await _scoreWithSarvam(resumeText, filePath, criteria);
    } catch (e) {
      return _scoreLocally(resumeText, filePath, criteria);
    }
  }

  // ── Sarvam AI chat completions ──────────────────────────────────────────────

  Future<Candidate> _scoreWithSarvam(
    String resumeText,
    String filePath,
    JobCriteria criteria,
  ) async {
    final text = resumeText.length > 3000 ? resumeText.substring(0, 3000) : resumeText;

    final prompt = '''
You are an expert HR AI. Analyze this resume and return ONLY a valid JSON object.

RESUME:
$text

JOB CRITERIA:
- Job Title: ${criteria.jobTitle}
- Required Skills: ${criteria.requiredSkills.join(', ')}
- Preferred Skills: ${criteria.preferredSkills.join(', ')}
- Min Experience: ${criteria.minExperienceYears} years
- Max Experience: ${criteria.maxExperienceYears} years
- Required Education: ${criteria.requiredEducation}

IMPORTANT: Extract the candidate's FULL NAME carefully. It is usually at the very top of the resume, often the largest text or first line. Do NOT return "Unknown" - look carefully through the entire text for a person's name.

Return ONLY this JSON (no markdown, no explanation, no ```json blocks):
{
  "name": "First Last (full name of the person, REQUIRED)",
  "email": "email or empty string",
  "phone": "phone or empty string",
  "skills": ["skill1", "skill2"],
  "experience_years": 0,
  "education": "Bachelor",
  "certifications": ["cert1"],
  "skills_found": ["required skills present in resume"],
  "skill_gaps": ["required skills missing from resume"],
  "skill_match": 85,
  "experience_match": 90,
  "education_match": 80,
  "certification_match": 60,
  "reasoning": "2-3 sentence assessment of candidate fit"
}
''';

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': 'You are an expert HR AI assistant. Always respond with valid JSON only.'},
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.1,
      }),
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw Exception('Sarvam API error ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['choices'][0]['message']['content'] as String;

    // Extract JSON from response (strip any <think> tags if present)
    final jsonStr = _extractJson(content);
    final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

    return _buildFromParsed(parsed, resumeText, filePath, criteria);
  }

  String _extractJson(String content) {
    // Remove <think>...</think> blocks
    var clean = content.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '').trim();
    // Find JSON object
    final start = clean.indexOf('{');
    final end = clean.lastIndexOf('}');
    if (start != -1 && end != -1) return clean.substring(start, end + 1);
    return clean;
  }

  Candidate _buildFromParsed(
    Map<String, dynamic> p,
    String resumeText,
    String filePath,
    JobCriteria criteria,
  ) {
    final name = (p['name'] ?? '').toString().trim();
    final email = (p['email'] ?? '').toString().trim();
    final phone = (p['phone'] ?? '').toString().trim();
    final skills = _toStringList(p['skills']);
    final expYears = (p['experience_years'] ?? 0) is int
        ? p['experience_years'] as int
        : int.tryParse(p['experience_years'].toString()) ?? 0;
    final education = (p['education'] ?? 'Not Specified').toString();
    final certifications = _toStringList(p['certifications']);
    final skillsFound = _toStringList(p['skills_found']);
    final skillGaps = _toStringList(p['skill_gaps']);
    final skillMatch = _clamp((p['skill_match'] ?? 0).toDouble());
    final expMatch = _clamp((p['experience_match'] ?? 0).toDouble());
    final eduMatch = _clamp((p['education_match'] ?? 0).toDouble());
    final certMatch = _clamp((p['certification_match'] ?? 0).toDouble());
    final reasoning = (p['reasoning'] ?? 'AI analysis complete.').toString();

    final breakdown = ScoreBreakdown(
      skillMatch: skillMatch,
      experienceMatch: expMatch,
      educationMatch: eduMatch,
      certificationMatch: certMatch,
      reasoning: reasoning,
      skillsFound: skillsFound,
      skillGaps: skillGaps,
    );

    final aiScore = _weightedScore(breakdown, criteria);
    final confidence = _calculateConfidence(resumeText, name, email, skills, expYears, education);

    return Candidate(
      name: (name.isNotEmpty && !name.toLowerCase().contains('unknown'))
          ? name
          : _extractNameFallback(resumeText),
      email: email.isNotEmpty ? email : _extractEmailFallback(resumeText),
      phone: phone,
      skills: skills,
      experienceYears: expYears,
      education: education,
      certifications: certifications,
      aiScore: aiScore,
      confidenceScore: confidence,
      breakdown: breakdown,
      resumeFilePath: filePath,
      resumeText: resumeText,
      uploadDate: DateTime.now(),
      status: _autoStatus(aiScore),
      jobRole: criteria.jobTitle,
    );
  }

  // ── Local fallback ──────────────────────────────────────────────────────────

  Candidate _scoreLocally(String resumeText, String filePath, JobCriteria criteria) {
    final lower = resumeText.toLowerCase();
    final name = _extractNameFallback(resumeText);
    final email = _extractEmailFallback(resumeText);
    final phone = _extractPhoneFallback(resumeText);
    final skills = _extractSkillsLocal(lower);
    final expYears = _extractExpYearsLocal(lower);
    final education = _extractEducationLocal(lower);
    final certifications = _extractCertsLocal(lower);

    final lowerSkills = skills.map((s) => s.toLowerCase()).toSet();
    final skillsFound = criteria.requiredSkills
        .where((s) => lowerSkills.contains(s.toLowerCase())).toList();
    final skillGaps = criteria.requiredSkills
        .where((s) => !lowerSkills.contains(s.toLowerCase())).toList();

    final skillMatch = _scoreSkillsLocal(skills, criteria);
    final expMatch = _scoreExpLocal(expYears, criteria);
    final eduMatch = _scoreEduLocal(education, criteria);
    final certMatch = _scoreCertificationsLocal(certifications, criteria);

    final reasons = <String>[];
    if (skillMatch >= 80) reasons.add('Strong skill alignment.');
    if (skillMatch < 50) reasons.add('Missing key required skills.');
    if (expMatch >= 80) reasons.add('Experience level matches requirements.');
    if (expMatch < 50) reasons.add('Experience below minimum threshold.');
    if (eduMatch >= 80) reasons.add('Education meets or exceeds requirements.');

    final breakdown = ScoreBreakdown(
      skillMatch: skillMatch,
      experienceMatch: expMatch,
      educationMatch: eduMatch,
      certificationMatch: certMatch,
      reasoning: reasons.isEmpty
          ? 'Profile partially matches job requirements. (Offline scoring)'
          : '${reasons.join(' ')} (Offline scoring)',
      skillsFound: skillsFound,
      skillGaps: skillGaps,
    );

    final aiScore = _weightedScore(breakdown, criteria);
    final confidence = _calculateConfidence(resumeText, name, email, skills, expYears, education);

    return Candidate(
      name: name, email: email, phone: phone,
      skills: skills, experienceYears: expYears,
      education: education, certifications: certifications,
      aiScore: aiScore, confidenceScore: confidence,
      breakdown: breakdown, resumeFilePath: filePath,
      resumeText: resumeText, uploadDate: DateTime.now(),
      status: _autoStatus(aiScore), jobRole: criteria.jobTitle,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  List<String> _toStringList(dynamic val) {
    if (val == null) return [];
    if (val is List) return val.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    if (val is String) return val.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return [];
  }

  double _clamp(double v) => v.clamp(0.0, 100.0);

  double _weightedScore(ScoreBreakdown b, JobCriteria c) {
    final raw = b.skillMatch * c.skillWeight +
        b.experienceMatch * c.experienceWeight +
        b.educationMatch * c.educationWeight +
        b.certificationMatch * c.certificationWeight;
    return double.parse(raw.toStringAsFixed(1));
  }

  double _calculateConfidence(String text, String name, String email,
      List<String> skills, int expYears, String education) {
    double score = 0;
    if (text.length > 200) score += 20;
    if (text.length > 500) score += 10;
    if (name != 'Unknown Candidate') score += 15;
    if (email.isNotEmpty) score += 15;
    if (skills.isNotEmpty) score += 20;
    if (expYears > 0) score += 10;
    if (education != 'Not Specified') score += 10;
    return min(100, score);
  }

  CandidateStatus _autoStatus(double score) {
    if (score >= 80) return CandidateStatus.shortlisted;
    if (score >= 50) return CandidateStatus.pending;
    return CandidateStatus.rejected;
  }

  String _extractNameFallback(String text) {
    // Strategy 1: Look for "Name:" label pattern
    final labelMatch = RegExp(
      r'(?:name|full\s*name|candidate\s*name)\s*[:\-]\s*([A-Za-z][A-Za-z\s]{2,40})',
      caseSensitive: false,
    ).firstMatch(text);
    if (labelMatch != null) {
      final name = labelMatch.group(1)?.trim() ?? '';
      if (name.isNotEmpty && name.split(' ').length >= 2) return _toTitleCase(name);
    }

    // Strategy 2: First line that looks like a name (2-4 words, mostly letters)
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
    for (final line in lines.take(15)) {
      // Skip lines that look like headers, emails, phones, addresses
      if (line.contains('@') || line.contains('http') || line.contains('|') ||
          line.contains('/') || RegExp(r'\d{4,}').hasMatch(line) ||
          line.length > 60 || line.length < 4) continue;

      final words = line.split(RegExp(r'\s+'));
      if (words.length >= 2 && words.length <= 5) {
        // Check if words look like name parts (letters only, reasonable length)
        final looksLikeName = words.every((w) =>
            w.length >= 2 &&
            w.length <= 20 &&
            RegExp(r'^[A-Za-z][A-Za-z\-\.]*$').hasMatch(w));
        if (looksLikeName) return _toTitleCase(line);
      }
    }

    // Strategy 3: Find capitalized word pairs anywhere in first 500 chars
    final snippet = text.length > 500 ? text.substring(0, 500) : text;
    final namePattern = RegExp(r'\b([A-Z][a-z]{1,15})\s+([A-Z][a-z]{1,15})(?:\s+([A-Z][a-z]{1,15}))?\b');
    final match = namePattern.firstMatch(snippet);
    if (match != null) {
      final parts = [match.group(1), match.group(2), match.group(3)]
          .where((p) => p != null)
          .join(' ');
      // Exclude common non-name capitalized phrases
      const exclude = ['Summary', 'Experience', 'Education', 'Skills', 'Profile',
        'Objective', 'Contact', 'Address', 'Phone', 'Email', 'Resume', 'Curriculum'];
      if (!exclude.any((e) => parts.contains(e))) return parts;
    }

    return 'Unknown Candidate';
  }

  String _toTitleCase(String s) {
    return s.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  String _extractEmailFallback(String text) {
    final m = RegExp(r'[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}').firstMatch(text);
    return m?.group(0) ?? '';
  }

  String _extractPhoneFallback(String text) {
    final m = RegExp(r'(\+?\d[\d\s\-().]{7,}\d)').firstMatch(text);
    return m?.group(0)?.trim() ?? '';
  }

  List<String> _extractSkillsLocal(String lower) {
    const known = [
      'flutter', 'dart', 'react', 'angular', 'vue', 'javascript', 'typescript',
      'python', 'java', 'kotlin', 'swift', 'c++', 'c#', 'go', 'rust', 'ruby',
      'node.js', 'express', 'django', 'flask', 'spring', 'fastapi', 'firebase',
      'aws', 'azure', 'gcp', 'docker', 'kubernetes', 'terraform', 'postgresql',
      'mysql', 'mongodb', 'redis', 'git', 'ci/cd', 'rest apis', 'graphql',
      'tensorflow', 'pytorch', 'machine learning', 'nlp', 'figma', 'agile', 'sql',
    ];
    return known.where((s) => lower.contains(s)).toList();
  }

  int _extractExpYearsLocal(String lower) {
    final patterns = [
      RegExp(r'(\d+)\+?\s*years?\s+of\s+experience'),
      RegExp(r'(\d+)\+?\s*years?\s+experience'),
      RegExp(r'(\d+)\+?\s*yrs?\s+experience'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(lower);
      if (m != null) return int.tryParse(m.group(1) ?? '0') ?? 0;
    }
    return RegExp(r'20\d\d\s*[-–]\s*(20\d\d|present)').allMatches(lower).length;
  }

  String _extractEducationLocal(String lower) {
    if (lower.contains('phd') || lower.contains('doctorate')) return 'PhD';
    if (lower.contains('master') || lower.contains('m.sc') || lower.contains('mba')) return 'Master';
    if (lower.contains('bachelor') || lower.contains('b.sc') || lower.contains('b.eng') ||
        lower.contains('b.tech')) return 'Bachelor';
    if (lower.contains('associate') || lower.contains('diploma')) return 'Associate';
    if (lower.contains('high school')) return 'High School';
    return 'Not Specified';
  }

  List<String> _extractCertsLocal(String lower) {
    const certs = ['aws certified', 'google cloud', 'azure certified', 'pmp',
      'cissp', 'cka', 'ckad', 'scrum master', 'csm', 'oracle certified'];
    return certs.where((c) => lower.contains(c)).toList();
  }

  double _scoreSkillsLocal(List<String> skills, JobCriteria c) {
    if (c.requiredSkills.isEmpty) return 50.0;
    final lower = skills.map((s) => s.toLowerCase()).toSet();
    final req = c.requiredSkills.map((s) => s.toLowerCase()).toList();
    final pref = c.preferredSkills.map((s) => s.toLowerCase()).toList();
    final reqScore = req.isEmpty ? 100.0 : (req.where(lower.contains).length / req.length) * 100;
    final prefBonus = pref.isEmpty ? 0.0 : (pref.where(lower.contains).length / pref.length) * 20;
    return min(100, reqScore * 0.85 + prefBonus);
  }

  double _scoreExpLocal(int years, JobCriteria c) {
    if (years >= c.minExperienceYears && years <= c.maxExperienceYears) return 100.0;
    if (years < c.minExperienceYears) return max(0, 100 - ((c.minExperienceYears - years) * 20.0));
    return max(60, 100 - ((years - c.maxExperienceYears) * 5.0));
  }

  double _scoreEduLocal(String edu, JobCriteria c) {
    const levels = {'High School': 1, 'Associate': 2, 'Bachelor': 3, 'Master': 4, 'PhD': 5};
    final cl = levels[edu] ?? 0;
    final rl = levels[c.requiredEducation] ?? 3;
    if (cl >= rl) return 100.0;
    if (cl == rl - 1) return 70.0;
    if (cl == rl - 2) return 40.0;
    return 20.0;
  }

  double _scoreCertificationsLocal(List<String> certs, JobCriteria c) {
    if (c.preferredCertifications.isEmpty) return certs.isNotEmpty ? 60.0 : 0.0;
    final matches = certs.where((cert) => c.preferredCertifications
        .any((p) => cert.toLowerCase().contains(p.toLowerCase()))).length;
    return min(100, (matches / c.preferredCertifications.length) * 100);
  }
}
