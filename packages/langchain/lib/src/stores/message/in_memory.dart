import '../../chat_models/models/models.dart';
import 'history.dart';

/// {@template chat_message_history}
/// A simple in-memory implementation of a chat message history.
/// {@endtemplate}
final class ChatMessageHistory extends BaseChatMessageHistory {
  /// {@macro chat_message_history}
  ChatMessageHistory({final List<ChatMessage>? messages})
      : _messages = messages ?? [];

  final List<ChatMessage> _messages;

  @override
  Future<List<ChatMessage>> getMessages() {
    return Future.value(_messages);
  }

  @override
  Future<void> addMessage(final ChatMessage message) async {
    _messages.add(message);
  }

  @override
  Future<void> clear() async {
    _messages.clear();
  }
}