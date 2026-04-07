import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/candidate_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/candidate_card.dart';
import '../widgets/filter_panel.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/stat_card.dart';
import 'upload_screen.dart';
import 'settings_screen.dart';
import 'ai_bot_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _searchController = TextEditingController();
  bool _showFilters = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.psychology, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('AI Resume Screener'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => context.read<ThemeProvider>().toggle(),
            tooltip: 'Toggle theme',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            tooltip: 'Settings',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<CandidateProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              _buildStatsBar(provider),
              _buildSearchBar(provider),
              if (_showFilters) FilterPanel(provider: provider),
              Expanded(child: _buildList(provider)),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'bot',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiBotScreen()),
            ),
            backgroundColor: AppTheme.review,
            foregroundColor: Colors.white,
            mini: true,
            child: const Icon(Icons.smart_toy_outlined),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'upload',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UploadScreen()),
            ).then((_) => context.read<CandidateProvider>().loadCandidates()),
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload Resume'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(CandidateProvider provider) {
    return Container(
      color: Theme.of(context).appBarTheme.backgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              label: 'Total',
              value: provider.totalCount.toString(),
              color: AppTheme.primary,
              icon: Icons.people_outline,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatCard(
              label: 'Shortlisted',
              value: provider.shortlistedCount.toString(),
              color: AppTheme.success,
              icon: Icons.check_circle_outline,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatCard(
              label: 'Pending',
              value: provider.pendingCount.toString(),
              color: AppTheme.warning,
              icon: Icons.hourglass_empty,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatCard(
              label: 'Rejected',
              value: provider.rejectedCount.toString(),
              color: AppTheme.danger,
              icon: Icons.cancel_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(CandidateProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: provider.search,
              decoration: InputDecoration(
                hintText: 'Search by name, email, skills...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          provider.search('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _FilterButton(
            active: _showFilters || provider.filters.hasActiveFilters,
            onTap: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
    );
  }

  Widget _buildList(CandidateProvider provider) {
    if (provider.state == LoadState.loading) {
      return const SkeletonLoader();
    }

    if (provider.state == LoadState.error) {
      return _ErrorState(message: provider.error, onRetry: provider.loadCandidates);
    }

    if (provider.candidates.isEmpty) {
      return _EmptyState(hasFilters: provider.filters.hasActiveFilters || provider.searchQuery.isNotEmpty);
    }

    return RefreshIndicator(
      onRefresh: provider.loadCandidates,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        itemCount: provider.candidates.length,
        itemBuilder: (context, index) {
          final candidate = provider.candidates[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CandidateCard(
              candidate: candidate,
              rank: index + 1,
              onStatusChanged: (status) =>
                  provider.updateStatus(candidate.id!, status),
              onDelete: () => _confirmDelete(context, provider, candidate.id!),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, CandidateProvider provider, int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Candidate'),
        content: const Text('This will permanently remove the candidate record.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              provider.deleteCandidate(id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Candidate deleted'), behavior: SnackBarBehavior.floating),
              );
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _FilterButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppTheme.primary : const Color(0xFFE2E8F0),
          ),
        ),
        child: Icon(
          Icons.tune,
          color: active ? Colors.white : AppTheme.textSecondary,
          size: 20,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  const _EmptyState({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters ? Icons.search_off : Icons.inbox_outlined,
            size: 72,
            color: AppTheme.textSecondary.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No candidates match your filters' : 'No candidates yet',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Try adjusting your search or filters'
                : 'Upload resumes to get started',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppTheme.danger),
          const SizedBox(height: 16),
          const Text('Something went wrong', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: AppTheme.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

