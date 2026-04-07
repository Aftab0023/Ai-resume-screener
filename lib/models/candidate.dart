import 'dart:convert';

enum CandidateStatus { pending, reviewed, shortlisted, rejected }

extension CandidateStatusExt on CandidateStatus {
  String get label {
    switch (this) {
      case CandidateStatus.pending:
        return 'Pending';
      case CandidateStatus.reviewed:
        return 'Reviewed';
      case CandidateStatus.shortlisted:
        return 'Shortlisted';
      case CandidateStatus.rejected:
        return 'Rejected';
    }
  }

  String get dbValue => name;

  static CandidateStatus fromString(String s) {
    return CandidateStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => CandidateStatus.pending,
    );
  }
}

class ScoreBreakdown {
  final double skillMatch;
  final double experienceMatch;
  final double educationMatch;
  final double certificationMatch;
  final String reasoning;
  final List<String> skillsFound;
  final List<String> skillGaps;

  const ScoreBreakdown({
    required this.skillMatch,
    required this.experienceMatch,
    required this.educationMatch,
    required this.certificationMatch,
    required this.reasoning,
    this.skillsFound = const [],
    this.skillGaps = const [],
  });

  Map<String, dynamic> toJson() => {
        'skillMatch': skillMatch,
        'experienceMatch': experienceMatch,
        'educationMatch': educationMatch,
        'certificationMatch': certificationMatch,
        'reasoning': reasoning,
        'skillsFound': skillsFound,
        'skillGaps': skillGaps,
      };

  factory ScoreBreakdown.fromJson(Map<String, dynamic> json) => ScoreBreakdown(
        skillMatch: (json['skillMatch'] ?? 0).toDouble(),
        experienceMatch: (json['experienceMatch'] ?? 0).toDouble(),
        educationMatch: (json['educationMatch'] ?? 0).toDouble(),
        certificationMatch: (json['certificationMatch'] ?? 0).toDouble(),
        reasoning: json['reasoning'] ?? '',
        skillsFound: List<String>.from(json['skillsFound'] ?? []),
        skillGaps: List<String>.from(json['skillGaps'] ?? []),
      );
}

class Candidate {
  final int? id;
  final String name;
  final String email;
  final String phone;
  final List<String> skills;
  final int experienceYears;
  final String education;
  final List<String> certifications;
  final double aiScore;
  final double confidenceScore;
  final ScoreBreakdown breakdown;
  final String resumeFilePath;
  final String resumeText;
  final DateTime uploadDate;
  CandidateStatus status;
  final String jobRole;

  Candidate({
    this.id,
    required this.name,
    required this.email,
    this.phone = '',
    required this.skills,
    required this.experienceYears,
    required this.education,
    this.certifications = const [],
    required this.aiScore,
    required this.confidenceScore,
    required this.breakdown,
    required this.resumeFilePath,
    this.resumeText = '',
    required this.uploadDate,
    this.status = CandidateStatus.pending,
    this.jobRole = '',
  });

  Candidate copyWith({
    int? id,
    CandidateStatus? status,
    double? aiScore,
    double? confidenceScore,
    ScoreBreakdown? breakdown,
  }) =>
      Candidate(
        id: id ?? this.id,
        name: name,
        email: email,
        phone: phone,
        skills: skills,
        experienceYears: experienceYears,
        education: education,
        certifications: certifications,
        aiScore: aiScore ?? this.aiScore,
        confidenceScore: confidenceScore ?? this.confidenceScore,
        breakdown: breakdown ?? this.breakdown,
        resumeFilePath: resumeFilePath,
        resumeText: resumeText,
        uploadDate: uploadDate,
        status: status ?? this.status,
        jobRole: jobRole,
      );

  // SQLite serialization
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'skills': jsonEncode(skills),
        'experience_years': experienceYears,
        'education': education,
        'certifications': jsonEncode(certifications),
        'ai_score': aiScore,
        'confidence_score': confidenceScore,
        'breakdown': jsonEncode(breakdown.toJson()),
        'resume_file_path': resumeFilePath,
        'resume_text': resumeText,
        'upload_date': uploadDate.toIso8601String(),
        'status': status.dbValue,
        'job_role': jobRole,
      };

  factory Candidate.fromMap(Map<String, dynamic> map) => Candidate(
        id: map['id'],
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        phone: map['phone'] ?? '',
        skills: List<String>.from(jsonDecode(map['skills'] ?? '[]')),
        experienceYears: map['experience_years'] ?? 0,
        education: map['education'] ?? '',
        certifications: List<String>.from(jsonDecode(map['certifications'] ?? '[]')),
        aiScore: (map['ai_score'] ?? 0).toDouble(),
        confidenceScore: (map['confidence_score'] ?? 0).toDouble(),
        breakdown: ScoreBreakdown.fromJson(jsonDecode(map['breakdown'] ?? '{}')),
        resumeFilePath: map['resume_file_path'] ?? '',
        resumeText: map['resume_text'] ?? '',
        uploadDate: DateTime.parse(map['upload_date'] ?? DateTime.now().toIso8601String()),
        status: CandidateStatusExt.fromString(map['status'] ?? 'pending'),
        jobRole: map['job_role'] ?? '',
      );

  // CSV row
  List<String> toCsvRow() => [
        id?.toString() ?? '',
        name,
        email,
        phone,
        skills.join('; '),
        experienceYears.toString(),
        education,
        aiScore.toStringAsFixed(1),
        confidenceScore.toStringAsFixed(1),
        status.label,
        uploadDate.toIso8601String(),
      ];

  static List<String> csvHeaders() => [
        'ID', 'Name', 'Email', 'Phone', 'Skills',
        'Experience (Years)', 'Education', 'AI Score',
        'Confidence Score', 'Status', 'Upload Date',
      ];
}
