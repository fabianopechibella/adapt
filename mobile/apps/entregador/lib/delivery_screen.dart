import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

class DeliveryScreen extends ConsumerStatefulWidget {
  const DeliveryScreen({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  var _busy = false;

  Future<void> _advance(Delivery d) async {
    String? code;
    if (d.status.next == DeliveryStatus.entregue) {
      code = await _askCode();
      if (code == null) return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(backendProvider).deliveries.advance(d.id, deliveryCode: code);
    } on AppException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askCode() => showDialog<String>(
    context: context,
    builder: (_) => _DeliveryCodeDialog(isDemo: ref.read(configProvider).isDemo),
  );

  @override
  Widget build(BuildContext context) {
    final delivery = ref.watch(deliveryProvider(widget.deliveryId));
    return Scaffold(
      appBar: AppBar(title: const Text('Corrida')),
      body: delivery.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(e),
        data: (d) => _Body(delivery: d, busy: _busy, onAdvance: () => _advance(d)),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.delivery, required this.busy, required this.onAdvance});

  final Delivery delivery;
  final bool busy;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = delivery;
    final waitingNfe = d.status == DeliveryStatus.noDistribuidor && !d.nfeAuthorized;
    final steps = DeliveryStatus.values.skip(1).toList();
    final current = steps.indexOf(d.status);

    return ListView(
      padding: const EdgeInsets.all(Tokens.space4),
      children: [
        Text(d.status.label, style: theme.textTheme.headlineSmall),
        const SizedBox(height: Tokens.space1),
        Text('${d.subOrderId} · ${d.itemsSummary}', style: theme.textTheme.bodySmall),
        const SizedBox(height: Tokens.space4),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.store),
                title: Text(d.distributorName),
                subtitle: Text(d.pickupAddress),
                trailing: d.nfeAuthorized
                    ? const Pill('NF-e ok', tone: Tone.success)
                    : const Pill('NF-e pendente', tone: Tone.warning),
              ),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.build), title: Text(d.workshopName), subtitle: Text(d.dropoffAddress)),
            ],
          ),
        ),
        const SizedBox(height: Tokens.space4),
        for (final (i, s) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.space1),
            child: Row(
              children: [
                Icon(
                  i <= current ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18,
                  color: i <= current ? Tokens.success : theme.colorScheme.outline,
                ),
                const SizedBox(width: Tokens.space2),
                Text(s.label),
              ],
            ),
          ),
        const SizedBox(height: Tokens.space4),
        if (waitingNfe)
          Card(
            color: Tokens.warning.withValues(alpha: 0.10),
            child: const ListTile(
              leading: Icon(Icons.receipt_long, color: Tokens.warning),
              title: Text('Aguardando NF-e autorizada'),
              subtitle: Text('A mercadoria só pode sair do distribuidor com nota fiscal. Esta tela atualiza sozinha.'),
            ),
          ),
        if (d.status == DeliveryStatus.entregue)
          const EmptyState(
            icon: Icons.task_alt,
            title: 'Entrega concluída',
            message: 'O valor da corrida entra no seu extrato.',
          )
        else ...[
          const SizedBox(height: Tokens.space2),
          FilledButton(
            key: const Key('advance'),
            onPressed: busy || waitingNfe ? null : onAdvance,
            child: Text(d.status.actionLabel!),
          ),
        ],
      ],
    );
  }
}

/// Dono do próprio controller para não descartá-lo durante a animação de saída.
class _DeliveryCodeDialog extends StatefulWidget {
  const _DeliveryCodeDialog({required this.isDemo});

  final bool isDemo;

  @override
  State<_DeliveryCodeDialog> createState() => _DeliveryCodeDialogState();
}

class _DeliveryCodeDialogState extends State<_DeliveryCodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Código de entrega'),
    content: TextField(
      key: const Key('delivery-code'),
      controller: _controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      maxLength: 4,
      decoration: InputDecoration(
        helperText: widget.isDemo ? 'Demonstração: ${FakeCourierBackend.demoDeliveryCode}' : 'Peça o código à oficina',
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: () => Navigator.pop(context, _controller.text), child: const Text('Confirmar')),
    ],
  );
}
