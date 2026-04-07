import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../models/candidate.dart';
import '../screens/candidate_detail_screen.dart';
import '../theme/app_theme.dart';

class CandidateCard extends StatelessWidget {
  final Candidate candidate;
  final int rank;
  final ValueChanged<CandidateStatus> onStatusChanged;
  final VoidCallback onDelete;

  const CandidateCard({
    super.key,
    required this.candidate,
    required this.rank,
    required this.onStatusChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('candidate_${candidate.id}'),
      background: _SwipeBackground(direction: DismissDirection.startToEnd),
      secondaryBackground: _SwipeBackground(direction: DismissDirection.endToStart),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onStatusChanged(CandidateStatus.shortlisted);
        } else {
          onStatusChanged(CandidateStatus.rejected);
        }
        return false; // Don't actually dismiss — just update status
      },
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CandidateDetailScreen(candidate: candidate)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _RankBadge(rank: rank, score: candidate.aiScore),
                const SizedBox(width: 14),
                Expanded(child: _CandidateInfo(candidate: candidate)),
                const SizedBox(width: 12),
                _ScoreIndicator(score: candidate.aiScore),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  final double score;
  const _RankBadge({required this.rank, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? AppTheme.success
        : score >= 60
            ? AppTheme.warning
            : AppTheme.danger;

    return Column(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: color.withOpacity(0.12),
          child: Text(
            '#$rank',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _CandidateInfo extends StatelessWidget {
  final Candidate candidate;
  const _CandidateInfo({required this.candidate});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          candidate.name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          candidate.jobRole.isNotEmpty ? candidate.jobRole : candidate.email,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _StatusChip(status: candidate.status),
            const SizedBox(width: 8),
            if (candidate.experienceYears > 0)
              _InfoChip(
                icon: Icons.work_outline,
                label: '${candidate.experienceYears}y exp',
              ),
          ],
        ),
        if (candidate.skills.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            candidate.skills.take(3).join(' • '),
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _ScoreIndicator extends StatelessWidget {
  final double score;
  const _ScoreIndicator({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? AppTheme.success
        : score >= 60
            ? AppTheme.warning
            : AppTheme.danger;

    return CircularPercentIndicator(
      radius: 30,
      lineWidth: 5,
      percent: score / 100,
      center: Text(
        '${score.toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
      progressColor: color,
      backgroundColor: color.withOpacity(0.1),
      circularStrokeCap: CircularStrokeCap.round,
      animation: true,
      animationDuration: 800,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final CandidateStatus status;
  const _StatusChip({required this.status});

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      ],
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  final DismissDirection direction;
  const _SwipeBackground({required this.direction});

  @override
  Widget build(BuildContext context) {
    final isStart = direction == DismissDirection.startToEnd;
    return Container(
      decoration: BoxDecoration(
        color: isStart ? AppTheme.success.withOpacity(0.15) : AppTheme.danger.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: isStart ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isStart ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: isStart ? AppTheme.success : AppTheme.danger,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            isStart ? 'Shortlist' : 'Reject',
            style: TextStyle(
              color: isStart ? AppTheme.success : AppTheme.danger,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
