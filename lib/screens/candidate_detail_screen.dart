import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import '../models/candidate.dart';
import '../providers/candidate_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/score_chart.dart';
import 'ai_bot_screen.dart';

class CandidateDetailScreen extends StatelessWidget {
  final Candidate candidate;
  const CandidateDetailScreen({super.key, required this.candidate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Candidate Profile'),
        actions: [
          _StatusBadge(status: candidate.status),
          const SizedBox(width: 16),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AiBotScreen(candidate: candidate)),
        ),
        backgroundColor: AppTheme.review,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.smart_toy_outlined),
        label: const Text('Ask AI Bot'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHeader(candidate: candidate),
            const SizedBox(height: 20),
            _AIScoreCard(candidate: candidate),
            const SizedBox(height: 16),
            _ScoreBreakdownCard(candidate: candidate),
            const SizedBox(height: 16),
            // Skill Found & Gaps
            if (candidate.breakdown.skillsFound.isNotEmpty ||
                candidate.breakdown.skillGaps.isNotEmpty) ...[
              _SkillAnalysisCard(breakdown: candidate.breakdown),
              const SizedBox(height: 16),
            ],
            _SkillsCard(skills: candidate.skills),
            if (candidate.certifications.isNotEmpty) ...[
              const SizedBox(height: 16),
              _CertificationsCard(certifications: candidate.certifications),
            ],
            const SizedBox(height: 16),
            _ExperienceCard(candidate: candidate),
            const SizedBox(height: 16),
            _ReasoningCard(reasoning: candidate.breakdown.reasoning),
            const SizedBox(height: 24),
            _ActionButtons(candidate: candidate),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ── Profile Header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final Candidate candidate;
  const _ProfileHeader({required this.candidate});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppTheme.primaryLight,
              child: Text(
                candidate.name.isNotEmpty ? candidate.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  if (candidate.jobRole.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      candidate.jobRole,
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w500),
                    ),
                  ],
                  const SizedBox(height: 6),
                  if (candidate.email.isNotEmpty)
                    _InfoRow(icon: Icons.email_outlined, text: candidate.email),
                  if (candidate.phone.isNotEmpty)
                    _InfoRow(icon: Icons.phone_outlined, text: candidate.phone),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI Score Card ─────────────────────────────────────────────────────────────

class _AIScoreCard extends StatelessWidget {
  final Candidate candidate;
  const _AIScoreCard({required this.candidate});

  @override
  Widget build(BuildContext context) {
    final score = candidate.aiScore;
    final color = score >= 80
        ? AppTheme.success
        : score >= 60
            ? AppTheme.warning
            : AppTheme.danger;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircularPercentIndicator(
              radius: 52,
              lineWidth: 8,
              percent: score / 100,
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${score.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const Text('AI Score', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                ],
              ),
              progressColor: color,
              backgroundColor: color.withOpacity(0.1),
              circularStrokeCap: CircularStrokeCap.round,
              animation: true,
              animationDuration: 1000,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI Confidence', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: candidate.confidenceScore / 100,
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${candidate.confidenceScore.toStringAsFixed(0)}% confidence',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 12),
                  _ExperienceBadge(years: candidate.experienceYears),
                  const SizedBox(height: 6),
                  _EducationBadge(education: candidate.education),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExperienceBadge extends StatelessWidget {
  final int years;
  const _ExperienceBadge({required this.years});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.work_outline, size: 14, color: Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(
          '$years year${years != 1 ? 's' : ''} experience',
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

class _EducationBadge extends StatelessWidget {
  final String education;
  const _EducationBadge({required this.education});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.school_outlined, size: 14, color: Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(
          education,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

// ── Score Breakdown ───────────────────────────────────────────────────────────

class _ScoreBreakdownCard extends StatelessWidget {
  final Candidate candidate;
  const _ScoreBreakdownCard({required this.candidate});

  @override
  Widget build(BuildContext context) {
    final b = candidate.breakdown;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Score Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ScoreBar(label: 'Skill Match', value: b.skillMatch, color: AppTheme.primary),
            const SizedBox(height: 12),
            ScoreBar(label: 'Experience Match', value: b.experienceMatch, color: AppTheme.success),
            const SizedBox(height: 12),
            ScoreBar(label: 'Education Match', value: b.educationMatch, color: AppTheme.review),
            const SizedBox(height: 12),
            ScoreBar(label: 'Certifications', value: b.certificationMatch, color: AppTheme.warning),
          ],
        ),
      ),
    );
  }
}

// ── Skill Analysis (Found & Gaps) ─────────────────────────────────────────────

class _SkillAnalysisCard extends StatelessWidget {
  final ScoreBreakdown breakdown;
  const _SkillAnalysisCard({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics_outlined, size: 18, color: AppTheme.primary),
                SizedBox(width: 8),
                Text('Skill Analysis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            if (breakdown.skillsFound.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 15, color: AppTheme.success),
                  const SizedBox(width: 6),
                  Text(
                    'Skills Found (${breakdown.skillsFound.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: breakdown.skillsFound
                    .map((s) => _SkillChip(label: s, found: true))
                    .toList(),
              ),
              const SizedBox(height: 14),
            ],
            if (breakdown.skillGaps.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.cancel, size: 15, color: AppTheme.danger),
                  const SizedBox(width: 6),
                  Text(
                    'Skill Gaps (${breakdown.skillGaps.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: breakdown.skillGaps
                    .map((s) => _SkillChip(label: s, found: false))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String label;
  final bool found;
  const _SkillChip({required this.label, required this.found});

  @override
  Widget build(BuildContext context) {
    final color = found ? AppTheme.success : AppTheme.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(found ? Icons.check : Icons.close, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Skills ────────────────────────────────────────────────────────────────────

class _SkillsCard extends StatelessWidget {
  final List<String> skills;
  const _SkillsCard({required this.skills});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Skills', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${skills.length}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            skills.isEmpty
                ? const Text('No skills detected', style: TextStyle(color: Color(0xFF64748B)))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: skills.map((s) => Chip(label: Text(s))).toList(),
                  ),
          ],
        ),
      ),
    );
  }
}

// ── Certifications ────────────────────────────────────────────────────────────

class _CertificationsCard extends StatelessWidget {
  final List<String> certifications;
  const _CertificationsCard({required this.certifications});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Certifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: certifications
                  .map((c) => Chip(
                        label: Text(c),
                        avatar: const Icon(Icons.verified, size: 14, color: AppTheme.success),
                        backgroundColor: AppTheme.success.withOpacity(0.08),
                        labelStyle: const TextStyle(color: AppTheme.success, fontSize: 12),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Experience ────────────────────────────────────────────────────────────────

class _ExperienceCard extends StatelessWidget {
  final Candidate candidate;
  const _ExperienceCard({required this.candidate});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Experience & Education', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _DetailRow(icon: Icons.work_outline, label: 'Experience', value: '${candidate.experienceYears} years'),
            const SizedBox(height: 8),
            _DetailRow(icon: Icons.school_outlined, label: 'Education', value: candidate.education),
            if (candidate.resumeFilePath.isNotEmpty) ...[
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.attach_file,
                label: 'File',
                value: candidate.resumeFilePath.split('/').last,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
        ),
      ],
    );
  }
}

// ── Reasoning ─────────────────────────────────────────────────────────────────

class _ReasoningCard extends StatelessWidget {
  final String reasoning;
  const _ReasoningCard({required this.reasoning});

  @override
  Widget build(BuildContext context) {
    if (reasoning.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: AppTheme.primary),
                SizedBox(width: 8),
                Text('AI Reasoning', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            Text(reasoning, style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF475569))),
          ],
        ),
      ),
    );
  }
}

// ── Action Buttons ────────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final Candidate candidate;
  const _ActionButtons({required this.candidate});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CandidateProvider>();
    final isShortlisted = candidate.status == CandidateStatus.shortlisted;
    final isRejected = candidate.status == CandidateStatus.rejected;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isRejected
                ? null
                : () async {
                    await provider.updateStatus(candidate.id!, CandidateStatus.rejected);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Candidate rejected'),
                          backgroundColor: AppTheme.danger,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      Navigator.pop(context);
                    }
                  },
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.danger,
              side: const BorderSide(color: AppTheme.danger),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isShortlisted
                ? null
                : () async {
                    await provider.updateStatus(candidate.id!, CandidateStatus.shortlisted);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Candidate shortlisted'),
                          backgroundColor: AppTheme.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      Navigator.pop(context);
                    }
                  },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Shortlist'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final CandidateStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == CandidateStatus.shortlisted
        ? AppTheme.success
        : status == CandidateStatus.rejected
            ? AppTheme.danger
            : status == CandidateStatus.reviewed
                ? AppTheme.primary
                : AppTheme.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
