import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../router.dart';
import 'assistant_controller.dart';

/// Mesmo agente do canal WhatsApp, dentro do app.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final value = text ?? _input.text;
    _input.clear();
    await ref.read(assistantProvider.notifier).send(value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantProvider);
    final last = state.messages.last.reply;
    return Scaffold(
      appBar: AppBar(title: const Text('Assistente de peças'), actions: const [CartAction()]),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(Tokens.space4),
              itemCount: state.messages.length + (state.sending ? 1 : 0),
              itemBuilder: (context, i) =>
                  i == state.messages.length ? const _Typing() : _Bubble(message: state.messages[i]),
            ),
          ),
          if (last != null && last.quickReplies.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
                children: [
                  for (final q in last.quickReplies)
                    Padding(
                      padding: const EdgeInsets.only(right: Tokens.space2),
                      child: ActionChip(label: Text(q), onPressed: state.sending ? null : () => _send(q)),
                    ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(Tokens.space3),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('agent-input'),
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(hintText: 'Ex.: pastilha de freio do HB20 BRA2E19'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: Tokens.space2),
                  IconButton.filled(
                    key: const Key('agent-send'),
                    tooltip: 'Enviar',
                    onPressed: state.sending ? null : _send,
                    icon: const Icon(Icons.send),
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

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: EdgeInsets.all(Tokens.space2),
      child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
    ),
  );
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.message});

  final AgentMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mine = message.author == AgentAuthor.mecanico;
    final reply = message.reply;
    final color = switch (message.author) {
      AgentAuthor.mecanico => theme.colorScheme.primaryContainer,
      AgentAuthor.agente => theme.colorScheme.surfaceContainerHigh,
      AgentAuthor.sistema => Tokens.critical.withValues(alpha: 0.12),
    };

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.85),
        child: Container(
          margin: const EdgeInsets.only(bottom: Tokens.space2),
          padding: const EdgeInsets.all(Tokens.space3),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Tokens.radius)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.text),
              if (reply?.handoffToHuman ?? false) ...[
                const SizedBox(height: Tokens.space2),
                const Pill('Transferido para atendente', tone: Tone.warning, icon: Icons.support_agent),
              ],
              if (reply != null && reply.offers.isEmpty)
                for (final m in reply.matches) ...[
                  const SizedBox(height: Tokens.space2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${m.part.name} · ${m.part.brand} · cód. ${m.part.oemCode}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      FitmentBadge(m),
                    ],
                  ),
                ],
              if (reply != null && reply.offers.isNotEmpty && reply.matches.isNotEmpty)
                for (final o in reply.offers) ...[
                  const SizedBox(height: Tokens.space2),
                  _OfferRow(part: reply.matches.first.part, offer: o, vehicleId: reply.vehicle?.id),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferRow extends ConsumerWidget {
  const _OfferRow({required this.part, required this.offer, this.vehicleId});

  final Part part;
  final Offer offer;
  final String? vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    color: Theme.of(context).colorScheme.surface,
    child: ListTile(
      dense: true,
      title: Text('${offer.price.format()} · ~${offer.etaMinutes} min'),
      subtitle: Text(offer.distributorName),
      trailing: IconButton(
        tooltip: 'Adicionar ao carrinho',
        icon: const Icon(Icons.add_shopping_cart),
        onPressed: () {
          ref.read(cartProvider.notifier).add(part, offer, vehicleId: vehicleId);
          showError(context, 'Adicionado ao carrinho.');
        },
      ),
    ),
  );
}
