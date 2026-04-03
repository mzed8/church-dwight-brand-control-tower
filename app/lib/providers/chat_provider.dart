import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import 'brands_provider.dart';

final chatMessagesProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier(ref);
});

final chatOpenProvider = StateProvider<bool>((ref) => false);

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref ref;

  ChatNotifier(this.ref) : super([]);

  Future<void> sendMessage(String content) async {
    // Add user message
    state = [...state, ChatMessage(role: 'user', content: content)];

    // Add loading placeholder
    state = [...state, ChatMessage(role: 'assistant', content: '', isLoading: true)];

    try {
      final api = ref.read(apiServiceProvider);
      final messages = state
          .where((m) => !m.isLoading)
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final response = await api.chat(messages);

      // Replace loading with actual response
      state = [
        ...state.where((m) => !m.isLoading),
        ChatMessage(role: 'assistant', content: response),
      ];
    } catch (e) {
      state = [
        ...state.where((m) => !m.isLoading),
        ChatMessage(role: 'assistant', content: 'Error: ${e.toString()}'),
      ];
    }
  }

  void clear() => state = [];
}
