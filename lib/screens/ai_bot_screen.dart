import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/candidate.dart';
import '../theme/app_theme.dart';

class AiBotScreen extends StatefulWidget {
  final Candidate? candidate; // null = general HR bot
  const AiBotScreen({super.key, this.candidate});

  @override
  State<AiBotScreen> createState() => _AiBotScreenState();
}

class _AiBotScreenState extends State<AiBotScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  static final _apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.3-70b-versatile';

  @override
  void initState() {
    super.initState();
    // Welcome message
    _messages.add(_ChatMessage(
      text: widget.candidate != null
          ? 'Hi! I\'m your AI assistant. Ask me anything about ${widget.candidate!.name}\'s profile, skills, fit for the role, or interview questions.'
          : 'Hi! I\'m your HR AI assistant. Ask me about candidates, hiring decisions, skill requirements, or interview tips.',
      isBot: true,
    ));

    // Quick suggestion chips
    if (widget.candidate != null) {
      _messages.add(_ChatMessage(
        text: '',
        isBot: true,
        isSuggestions: true,
        suggestions: [
          'Is this candidate a good fit?',
          'What are the skill gaps?',
          'Suggest interview questions',
          'Compare score breakdown',
        ],
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;
    _controller.clear();

    setState(() {
      _messages.add(_ChatMessage(text: text, isBot: false));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final reply = await _askSarvam(text);
      setState(() {
        _messages.add(_ChatMessage(text: reply, isBot: true));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          text: 'Error: ${e.toString().replaceAll('Exception: ', '')}',
          isBot: true,
          isError: true,
        ));
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  Future<String> _askSarvam(String question) async {
    final context = widget.candidate != null ? _buildCandidateContext() : _buildGeneralContext();

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': context},
          {'role': 'user', 'content': question},
        ],
        'temperature': 0.7,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    var content = data['choices'][0]['message']['content'] as String;
    // Strip <think> blocks from reasoning model
    content = content.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '').trim();
    return content.isNotEmpty ? content : 'No response generated.';
  }

  String _buildCandidateContext() {
    final c = widget.candidate!;
    return '''
Candidate Profile:
Name: ${c.name}
Job Role: ${c.jobRole}
AI Score: ${c.aiScore}%
Confidence: ${c.confidenceScore}%
Status: ${c.status.label}
Experience: ${c.experienceYears} years
Education: ${c.education}
Skills: ${c.skills.join(', ')}
Certifications: ${c.certifications.join(', ')}
Skills Found: ${c.breakdown.skillsFound.join(', ')}
Skill Gaps: ${c.breakdown.skillGaps.join(', ')}
Skill Match: ${c.breakdown.skillMatch.toStringAsFixed(0)}%
Experience Match: ${c.breakdown.experienceMatch.toStringAsFixed(0)}%
Education Match: ${c.breakdown.educationMatch.toStringAsFixed(0)}%
AI Reasoning: ${c.breakdown.reasoning}
''';
  }

  String _buildGeneralContext() {
    return '''
You are an expert HR assistant helping recruiters make better hiring decisions.
You have deep knowledge of recruitment, talent acquisition, skill assessment,
interview techniques, and candidate evaluation. Provide professional, concise,
and actionable advice.
''';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.review,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI HR Assistant', style: TextStyle(fontSize: 16)),
                Text(
                  widget.candidate != null ? widget.candidate!.name : 'General Assistant',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) return const _TypingIndicator();
                final msg = _messages[index];
                if (msg.isSuggestions) {
                  return _SuggestionChips(
                    suggestions: msg.suggestions,
                    onTap: _sendMessage,
                  );
                }
                return _MessageBubble(message: msg);
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: _sendMessage,
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(
                  hintText: 'Ask about this candidate...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                    borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                    borderSide: BorderSide(color: AppTheme.primary, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _sendMessage(_controller.text),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isLoading ? AppTheme.textSecondary : AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isBot = message.isBot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isBot) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: message.isError ? AppTheme.danger : AppTheme.review,
                shape: BoxShape.circle,
              ),
              child: Icon(
                message.isError ? Icons.error_outline : Icons.smart_toy_outlined,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isBot
                    ? (message.isError
                        ? AppTheme.danger.withOpacity(0.08)
                        : Theme.of(context).cardTheme.color)
                    : AppTheme.primary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isBot ? 4 : 16),
                  bottomRight: Radius.circular(isBot ? 16 : 4),
                ),
                border: isBot
                    ? Border.all(color: Theme.of(context).dividerColor)
                    : null,
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isBot
                      ? (message.isError ? AppTheme.danger : null)
                      : Colors.white,
                ),
              ),
            ),
          ),
          if (!isBot) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Suggestion Chips ──────────────────────────────────────────────────────────

class _SuggestionChips extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onTap;
  const _SuggestionChips({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 30),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: suggestions
            .map((s) => GestureDetector(
                  onTap: () => onTap(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                    ),
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ── Typing Indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: AppTheme.review, shape: BoxShape.circle),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(
                        (i == 0 ? _ctrl.value : i == 1 ? (_ctrl.value + 0.3) % 1 : (_ctrl.value + 0.6) % 1),
                      ),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Model ─────────────────────────────────────────────────────────────────────

class _ChatMessage {
  final String text;
  final bool isBot;
  final bool isError;
  final bool isSuggestions;
  final List<String> suggestions;

  _ChatMessage({
    required this.text,
    required this.isBot,
    this.isError = false,
    this.isSuggestions = false,
    this.suggestions = const [],
  });
}
