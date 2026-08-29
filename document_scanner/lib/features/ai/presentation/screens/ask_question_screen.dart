import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../documents/domain/entities/document.dart';
import '../../data/ai_service.dart';
import '../../domain/entities/ai_chat_message.dart';

/// "Ask a question about this document" — a small chat over the
/// document's OCR text. Each turn sends the full document text plus
/// prior turns so follow-up questions ("and the due date?") work.
class AskQuestionScreen extends StatefulWidget {
  final ScannedDocument document;
  const AskQuestionScreen({super.key, required this.document});

  @override
  State<AskQuestionScreen> createState() => _AskQuestionScreenState();
}

class _AskQuestionScreenState extends State<AskQuestionScreen> {
  final _aiService = AiService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<AiChatMessage> _messages = [];
  bool _sending = false;

  bool get _hasText => (widget.document.extractedText ?? '').trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _sending || !_hasText) return;

    final priorHistory = List<AiChatMessage>.of(_messages);
    setState(() {
      _messages.add(AiChatMessage(role: ChatRole.user, content: question));
      _sending = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final answer = await _aiService.ask(widget.document.extractedText!, priorHistory, question);
      if (!mounted) return;
      setState(() {
        _messages.add(AiChatMessage(role: ChatRole.assistant, content: answer));
        _sending = false;
      });
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(AiChatMessage(role: ChatRole.assistant, content: e.message));
        _sending = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).extension<AppSemanticColors>()?.textSecondary;

    return Scaffold(
      appBar: AppBar(title: const Text('Ask About This Document')),
      body: !_hasText
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Extract text from this document first, then come back to ask questions about it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondary),
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Text('Ask anything about "${widget.document.name}"', style: TextStyle(color: secondary)),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) => _ChatBubble(message: _messages[index]),
                        ),
                ),
                if (_sending)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: const InputDecoration(hintText: 'Ask a question…'),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton.filled(
                          onPressed: _sending ? null : _send,
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final AiChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final theme = Theme.of(context);
    final bubbleColor = isUser ? theme.colorScheme.primary : theme.extension<AppSemanticColors>()?.surfaceAlt;
    final textColor = isUser ? Colors.white : null;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        child: Text(message.content, style: TextStyle(color: textColor)),
      ),
    );
  }
}
