import 'package:flutter/material.dart';
import '../models/candidate.dart';
import '../providers/candidate_provider.dart';
import '../theme/app_theme.dart';

class FilterPanel extends StatefulWidget {
  final CandidateProvider provider;
  const FilterPanel({super.key, required this.provider});

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  late RangeValues _scoreRange;
  CandidateStatus? _status;
  late RangeValues _expRange;

  @override
  void initState() {
    super.initState();
    final f = widget.provider.filters;
    _scoreRange = RangeValues(f.minScore, f.maxScore);
    _status = f.status;
    _expRange = RangeValues(
      (f.minExperience ?? 0).toDouble(),
      (f.maxExperience ?? 20).toDouble(),
    );
  }

  void _apply() {
    widget.provider.applyFilters(FilterOptions(
      minScore: _scoreRange.start,
      maxScore: _scoreRange.end,
      status: _status,
      minExperience: _expRange.start.toInt(),
      maxExperience: _expRange.end.toInt(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Filters', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              TextButton(
                onPressed: () {
                  setState(() {
                    _scoreRange = const RangeValues(0, 100);
                    _status = null;
                    _expRange = const RangeValues(0, 20);
                  });
                  widget.provider.clearFilters();
                },
                child: const Text('Reset', style: TextStyle(color: AppTheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Score range
          _FilterLabel(
            label: 'AI Score',
            value: '${_scoreRange.start.toInt()}% – ${_scoreRange.end.toInt()}%',
          ),
          RangeSlider(
            values: _scoreRange,
            min: 0,
            max: 100,
            divisions: 20,
            activeColor: AppTheme.primary,
            onChanged: (v) {
              setState(() => _scoreRange = v);
              _apply();
            },
          ),

          // Experience range
          _FilterLabel(
            label: 'Experience',
            value: '${_expRange.start.toInt()} – ${_expRange.end.toInt()} years',
          ),
          RangeSlider(
            values: _expRange,
            min: 0,
            max: 20,
            divisions: 20,
            activeColor: AppTheme.success,
            onChanged: (v) {
              setState(() => _expRange = v);
              _apply();
            },
          ),

          // Status filter
          const Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _StatusFilterChip(
                label: 'All',
                selected: _status == null,
                onTap: () {
                  setState(() => _status = null);
                  _apply();
                },
              ),
              ...CandidateStatus.values.map((s) => _StatusFilterChip(
                    label: s.label,
                    selected: _status == s,
                    onTap: () {
                      setState(() => _status = _status == s ? null : s);
                      _apply();
                    },
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  final String label;
  final String value;
  const _FilterLabel({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Text(value, style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _StatusFilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.primaryLight,
      checkmarkColor: AppTheme.primary,
      labelStyle: TextStyle(
        color: selected ? AppTheme.primary : const Color(0xFF64748B),
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(color: selected ? AppTheme.primary : const Color(0xFFE2E8F0)),
      backgroundColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
