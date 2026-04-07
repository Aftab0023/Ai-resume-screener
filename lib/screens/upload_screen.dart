import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/candidate.dart';
import '../providers/candidate_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_scoring_service.dart';
import '../services/file_parser_service.dart';
import '../theme/app_theme.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> with SingleTickerProviderStateMixin {
  final List<_UploadItem> _items = [];
  bool _isProcessing = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt'],
      withData: true, // ensures bytes are available on all platforms
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      for (final file in result.files) {
        if (!_items.any((i) => i.name == file.name)) {
          _items.add(_UploadItem(
            name: file.name,
            path: file.path ?? '',
            size: file.size,
            bytes: file.bytes,
          ));
        }
      }
    });
  }

  Future<void> _analyzeAll() async {
    if (_items.isEmpty || _isProcessing) return;
    setState(() => _isProcessing = true);

    final criteria = context.read<SettingsProvider>().criteria;
    final provider = context.read<CandidateProvider>();
    final candidates = <Candidate>[];

    for (final item in _items) {
      setState(() => item.state = _ItemState.processing);
      try {
        String text;
        final ext = item.name.split('.').last.toLowerCase();
        if (item.bytes != null) {
          text = await FileParserService.instance.extractFromBytes(item.bytes!, ext);
        } else {
          throw Exception('No file data available. Please re-select the file.');
        }
        final candidate = await AIScoringService.instance.scoreCandidate(
          resumeText: text,
          filePath: item.path.isNotEmpty ? item.path : item.name,
          criteria: criteria,
        );
        candidates.add(candidate);
        setState(() {
          item.state = _ItemState.done;
          item.score = candidate.aiScore;
        });
      } catch (e) {
        setState(() {
          item.state = _ItemState.error;
          item.errorMsg = e.toString();
        });
      }
    }

    if (candidates.isNotEmpty) {
      await provider.addCandidates(candidates);
    }

    setState(() => _isProcessing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${candidates.length} resume(s) analyzed successfully'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (candidates.length == _items.length) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Resumes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDropZone(),
                  if (_items.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildFileList(),
                  ],
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildDropZone() {
    return GestureDetector(
      onTap: _isProcessing ? null : _pickFiles,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) => Transform.scale(
          scale: _items.isEmpty ? _pulseAnim.value : 1.0,
          child: child,
        ),
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primary.withOpacity(0.4),
              width: 2,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_upload_outlined, size: 48, color: AppTheme.primary),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tap to browse files',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Supports PDF, DOCX, TXT • Multiple files allowed',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.primary.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_items.length} file(s) selected',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            TextButton.icon(
              onPressed: _isProcessing ? null : () => setState(() => _items.clear()),
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Clear all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_items.length, (i) => _FileItemTile(
          item: _items[i],
          onRemove: _isProcessing ? null : () => setState(() => _items.removeAt(i)),
        )),
      ],
    );
  }

  Widget _buildBottomBar() {
    final doneCount = _items.where((i) => i.state == _ItemState.done).length;
    final allDone = _items.isNotEmpty && doneCount == _items.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isProcessing) ...[
              LinearProgressIndicator(
                backgroundColor: AppTheme.primaryLight,
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 12),
              Text(
                'Analyzing ${_items.where((i) => i.state == _ItemState.processing).map((i) => i.name).firstOrNull ?? "resumes"}...',
                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _items.isEmpty || _isProcessing || allDone ? null : _analyzeAll,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(allDone ? Icons.check_circle : Icons.auto_awesome),
                label: Text(
                  _isProcessing
                      ? 'Analyzing...'
                      : allDone
                          ? 'All Analyzed'
                          : 'Analyze ${_items.length} Resume(s)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── File item tile ────────────────────────────────────────────────────────────

class _FileItemTile extends StatelessWidget {
  final _UploadItem item;
  final VoidCallback? onRemove;
  const _FileItemTile({required this.item, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _fileIcon(item.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        _formatSize(item.size),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      if (item.state == _ItemState.done) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Score: ${item.score?.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (item.state == _ItemState.error) ...[
                        const SizedBox(width: 8),
                        const Text(
                          'Parse error',
                          style: TextStyle(fontSize: 12, color: AppTheme.danger),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            _stateWidget(item.state),
            if (item.state == _ItemState.idle && onRemove != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }

  Widget _fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    final color = ext == 'pdf'
        ? AppTheme.danger
        : ext == 'docx'
            ? const Color(0xFF2563EB)
            : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.description_outlined, color: color, size: 22),
    );
  }

  Widget _stateWidget(_ItemState state) {
    switch (state) {
      case _ItemState.processing:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
        );
      case _ItemState.done:
        return const Icon(Icons.check_circle, color: AppTheme.success, size: 22);
      case _ItemState.error:
        return const Icon(Icons.error_outline, color: AppTheme.danger, size: 22);
      case _ItemState.idle:
        return const SizedBox.shrink();
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

enum _ItemState { idle, processing, done, error }

class _UploadItem {
  final String name;
  final String path;
  final int size;
  final List<int>? bytes;
  _ItemState state;
  double? score;
  String? errorMsg;

  _UploadItem({
    required this.name,
    required this.path,
    required this.size,
    this.bytes,
    this.state = _ItemState.idle,
  });
}
