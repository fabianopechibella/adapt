import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

class AssistantState {
  const AssistantState({required this.conversationId, this.messages = const [], this.sending = false});

  final String conversationId;
  final List<AgentMessage> messages;
  final bool sending;

  AssistantState copyWith({List<AgentMessage>? messages, bool? sending}) => AssistantState(
    conversationId: conversationId,
    messages: messages ?? this.messages,
    sending: sending ?? this.sending,
  );
}

class AssistantController extends Notifier<AssistantState> {
  @override
  AssistantState build() => AssistantState(
    conversationId: newIdempotencyKey(),
    messages: [
      AgentMessage(
        author: AgentAuthor.agente,
        at: DateTime.now(),
        text: 'Oi! Me diga a placa e a peça (ou o sintoma) que eu encontro a peça certa e cotamos juntos.',
      ),
    ],
  );

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;
    state = state.copyWith(
      sending: true,
      messages: [
        ...state.messages,
        AgentMessage(author: AgentAuthor.mecanico, text: trimmed, at: DateTime.now()),
      ],
    );
    try {
      final reply = await ref.read(backendProvider).agent.send(conversationId: state.conversationId, text: trimmed);
      if (reply.vehicle != null) ref.read(vehicleProvider.notifier).select(reply.vehicle!);
      state = state.copyWith(
        messages: [
          ...state.messages,
          AgentMessage(author: AgentAuthor.agente, text: reply.text, at: DateTime.now(), reply: reply),
        ],
      );
    } on AppException catch (e) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          AgentMessage(author: AgentAuthor.sistema, text: e.message, at: DateTime.now()),
        ],
      );
    } finally {
      state = state.copyWith(sending: false);
    }
  }
}

final assistantProvider = NotifierProvider<AssistantController, AssistantState>(AssistantController.new);
