/// Configurable job criteria used by the AI scoring engine.
class JobCriteria {
  final String jobTitle;
  final String jobDescription;
  final List<String> requiredSkills;
  final List<String> preferredSkills;
  final int minExperienceYears;
  final int maxExperienceYears;
  final String requiredEducation; // e.g. "Bachelor", "Master", "PhD"
  final List<String> preferredCertifications;

  // Scoring weights (must sum to 1.0)
  final double skillWeight;
  final double experienceWeight;
  final double educationWeight;
  final double certificationWeight;

  const JobCriteria({
    this.jobTitle = 'Software Engineer',
    this.jobDescription = '',
    this.requiredSkills = const ['Flutter', 'Dart', 'REST APIs'],
    this.preferredSkills = const ['Firebase', 'CI/CD', 'Git'],
    this.minExperienceYears = 2,
    this.maxExperienceYears = 8,
    this.requiredEducation = 'Bachelor',
    this.preferredCertifications = const [],
    this.skillWeight = 0.40,
    this.experienceWeight = 0.30,
    this.educationWeight = 0.20,
    this.certificationWeight = 0.10,
  });

  JobCriteria copyWith({
    String? jobTitle,
    String? jobDescription,
    List<String>? requiredSkills,
    List<String>? preferredSkills,
    int? minExperienceYears,
    int? maxExperienceYears,
    String? requiredEducation,
    List<String>? preferredCertifications,
    double? skillWeight,
    double? experienceWeight,
    double? educationWeight,
    double? certificationWeight,
  }) =>
      JobCriteria(
        jobTitle: jobTitle ?? this.jobTitle,
        jobDescription: jobDescription ?? this.jobDescription,
        requiredSkills: requiredSkills ?? this.requiredSkills,
        preferredSkills: preferredSkills ?? this.preferredSkills,
        minExperienceYears: minExperienceYears ?? this.minExperienceYears,
        maxExperienceYears: maxExperienceYears ?? this.maxExperienceYears,
        requiredEducation: requiredEducation ?? this.requiredEducation,
        preferredCertifications: preferredCertifications ?? this.preferredCertifications,
        skillWeight: skillWeight ?? this.skillWeight,
        experienceWeight: experienceWeight ?? this.experienceWeight,
        educationWeight: educationWeight ?? this.educationWeight,
        certificationWeight: certificationWeight ?? this.certificationWeight,
      );

  Map<String, dynamic> toJson() => {
        'jobTitle': jobTitle,
        'jobDescription': jobDescription,
        'requiredSkills': requiredSkills,
        'preferredSkills': preferredSkills,
        'minExperienceYears': minExperienceYears,
        'maxExperienceYears': maxExperienceYears,
        'requiredEducation': requiredEducation,
        'preferredCertifications': preferredCertifications,
        'skillWeight': skillWeight,
        'experienceWeight': experienceWeight,
        'educationWeight': educationWeight,
        'certificationWeight': certificationWeight,
      };

  factory JobCriteria.fromJson(Map<String, dynamic> json) => JobCriteria(
        jobTitle: json['jobTitle'] ?? 'Software Engineer',
        jobDescription: json['jobDescription'] ?? '',
        requiredSkills: List<String>.from(json['requiredSkills'] ?? []),
        preferredSkills: List<String>.from(json['preferredSkills'] ?? []),
        minExperienceYears: json['minExperienceYears'] ?? 2,
        maxExperienceYears: json['maxExperienceYears'] ?? 8,
        requiredEducation: json['requiredEducation'] ?? 'Bachelor',
        preferredCertifications: List<String>.from(json['preferredCertifications'] ?? []),
        skillWeight: (json['skillWeight'] ?? 0.40).toDouble(),
        experienceWeight: (json['experienceWeight'] ?? 0.30).toDouble(),
        educationWeight: (json['educationWeight'] ?? 0.20).toDouble(),
        certificationWeight: (json['certificationWeight'] ?? 0.10).toDouble(),
      );
}
