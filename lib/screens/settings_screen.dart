import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/job_criteria.dart';
import '../providers/candidate_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _requiredSkillsCtrl;
  late TextEditingController _preferredSkillsCtrl;
  late TextEditingController _certsCtrl;
  late TextEditingController _minExpCtrl;
  late TextEditingController _maxExpCtrl;
  String _education = 'Bachelor';
  double _skillWeight = 0.40;
  double _expWeight = 0.30;
  double _eduWeight = 0.20;
  double _certWeight = 0.10;

  @override
  void initState() {
    super.initState();
    final c = context.read<SettingsProvider>().criteria;
    _titleCtrl = TextEditingController(text: c.jobTitle);
    _descCtrl = TextEditingController(text: c.jobDescription);
    _requiredSkillsCtrl = TextEditingController(text: c.requiredSkills.join(', '));
    _preferredSkillsCtrl = TextEditingController(text: c.preferredSkills.join(', '));
    _certsCtrl = TextEditingController(text: c.preferredCertifications.join(', '));
    _minExpCtrl = TextEditingController(text: c.minExperienceYears.toString());
    _maxExpCtrl = TextEditingController(text: c.maxExperienceYears.toString());
    _education = c.requiredEducation;
    _skillWeight = c.skillWeight;
    _expWeight = c.experienceWeight;
    _eduWeight = c.educationWeight;
    _certWeight = c.certificationWeight;
  }

  @override
  void dispose() {
    for (final c in [_titleCtrl, _descCtrl, _requiredSkillsCtrl, _preferredSkillsCtrl, _certsCtrl, _minExpCtrl, _maxExpCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _parseList(String s) =>
      s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _save() async {
    final total = _skillWeight + _expWeight + _eduWeight + _certWeight;
    if ((total - 1.0).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Weights must sum to 1.0'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final criteria = JobCriteria(
      jobTitle: _titleCtrl.text.trim(),
      jobDescription: _descCtrl.text.trim(),
      requiredSkills: _parseList(_requiredSkillsCtrl.text),
      preferredSkills: _parseList(_preferredSkillsCtrl.text),
      minExperienceYears: int.tryParse(_minExpCtrl.text) ?? 2,
      maxExperienceYears: int.tryParse(_maxExpCtrl.text) ?? 8,
      requiredEducation: _education,
      preferredCertifications: _parseList(_certsCtrl.text),
      skillWeight: _skillWeight,
      experienceWeight: _expWeight,
      educationWeight: _eduWeight,
      certificationWeight: _certWeight,
    );

    await context.read<SettingsProvider>().updateCriteria(criteria);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionHeader(title: 'Appearance'),
          _ThemeTile(),
          const SizedBox(height: 20),
          _SectionHeader(title: 'Job Criteria'),
          _buildTextField('Job Title', _titleCtrl, Icons.work_outline),
          const SizedBox(height: 12),
          _buildTextField('Job Description', _descCtrl, Icons.description_outlined, maxLines: 3),
          const SizedBox(height: 12),
          _buildTextField('Required Skills (comma-separated)', _requiredSkillsCtrl, Icons.star_outline),
          const SizedBox(height: 12),
          _buildTextField('Preferred Skills (comma-separated)', _preferredSkillsCtrl, Icons.thumb_up_outlined),
          const SizedBox(height: 12),
          _buildTextField('Preferred Certifications (comma-separated)', _certsCtrl, Icons.verified_outlined),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField('Min Experience (yrs)', _minExpCtrl, Icons.trending_up, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('Max Experience (yrs)', _maxExpCtrl, Icons.trending_down, keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 12),
          _buildEducationDropdown(),
          const SizedBox(height: 20),
          _SectionHeader(title: 'Scoring Weights (must sum to 1.0)'),
          _WeightSlider(
            label: 'Skill Match',
            value: _skillWeight,
            color: AppTheme.primary,
            onChanged: (v) => setState(() => _skillWeight = v),
          ),
          _WeightSlider(
            label: 'Experience Match',
            value: _expWeight,
            color: AppTheme.success,
            onChanged: (v) => setState(() => _expWeight = v),
          ),
          _WeightSlider(
            label: 'Education Match',
            value: _eduWeight,
            color: AppTheme.review,
            onChanged: (v) => setState(() => _eduWeight = v),
          ),
          _WeightSlider(
            label: 'Certifications',
            value: _certWeight,
            color: AppTheme.warning,
            onChanged: (v) => setState(() => _certWeight = v),
          ),
          _WeightTotal(total: _skillWeight + _expWeight + _eduWeight + _certWeight),
          const SizedBox(height: 20),
          _SectionHeader(title: 'Data Management'),
          _ExportTile(),
          const SizedBox(height: 8),
          _DangerTile(),
          const SizedBox(height: 40),
          const _CopyrightFooter(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
      ),
    );
  }

  Widget _buildEducationDropdown() {
    const levels = ['High School', 'Associate', 'Bachelor', 'Master', 'PhD'];
    return DropdownButtonFormField<String>(
      value: _education,
      decoration: const InputDecoration(
        labelText: 'Required Education Level',
        prefixIcon: Icon(Icons.school_outlined, size: 18),
      ),
      items: levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
      onChanged: (v) => setState(() => _education = v ?? 'Bachelor'),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return Card(
      child: SwitchListTile(
        title: const Text('Dark Mode'),
        subtitle: const Text('Switch between light and dark theme'),
        secondary: Icon(themeProvider.isDark ? Icons.dark_mode : Icons.light_mode),
        value: themeProvider.isDark,
        onChanged: (_) => themeProvider.toggle(),
        activeColor: AppTheme.primary,
      ),
    );
  }
}

class _WeightSlider extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;
  const _WeightSlider({required this.label, required this.value, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(value * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
            Slider(
              value: value,
              min: 0,
              max: 1,
              divisions: 20,
              activeColor: color,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightTotal extends StatelessWidget {
  final double total;
  const _WeightTotal({required this.total});

  @override
  Widget build(BuildContext context) {
    final isValid = (total - 1.0).abs() <= 0.01;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isValid ? AppTheme.success.withOpacity(0.08) : AppTheme.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isValid ? AppTheme.success.withOpacity(0.3) : AppTheme.danger.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(isValid ? Icons.check_circle_outline : Icons.warning_outlined,
              color: isValid ? AppTheme.success : AppTheme.danger, size: 18),
          const SizedBox(width: 8),
          Text(
            'Total: ${(total * 100).toStringAsFixed(0)}% ${isValid ? "(valid)" : "(must equal 100%)"}',
            style: TextStyle(
              color: isValid ? AppTheme.success : AppTheme.danger,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.download_outlined, color: AppTheme.primary),
        title: const Text('Export Data'),
        subtitle: const Text('Export candidates as CSV or JSON'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ExportButton(label: 'CSV', onTap: () => _export(context, 'csv')),
            const SizedBox(width: 8),
            _ExportButton(label: 'JSON', onTap: () => _export(context, 'json')),
          ],
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context, String format) async {
    try {
      final provider = context.read<CandidateProvider>();
      final candidates = await provider.getAllForExport();
      await ExportService.instance.exportAndShare(candidates, format);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported as $format'), backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.danger, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}

class _ExportButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ExportButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: const BorderSide(color: AppTheme.primary),
        foregroundColor: AppTheme.primary,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _DangerTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.delete_forever_outlined, color: AppTheme.danger),
        title: const Text('Clear All Data', style: TextStyle(color: AppTheme.danger)),
        subtitle: const Text('Permanently delete all candidate records'),
        onTap: () => _confirmClear(context),
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('This will permanently delete all candidate records. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<CandidateProvider>().deleteAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data cleared'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: const Text('Delete All', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }
}

class _CopyrightFooter extends StatelessWidget {
  const _CopyrightFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 12),
        Icon(Icons.psychology, color: AppTheme.primary.withOpacity(0.6), size: 28),
        const SizedBox(height: 8),
        const Text(
          'AI Resume Screener',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          '© ${DateTime.now().year} Developed by Aftab Tamboli',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        const Text(
          'All rights reserved.',
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
