enum ChatRole { user, assistant }

/// One turn in an "ask a question about this document" conversation.
class AiChatMessage {
  final ChatRole role;
  final String content;

  const AiChatMessage({required this.role, required this.content});
}
