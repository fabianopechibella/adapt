import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers.dart';

final _time = DateFormat('HH:mm');

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId));
    return Scaffold(
      appBar: AppBar(title: Text(orderId)),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(orderProvider(orderId))),
        data: (o) => ListView(
          padding: const EdgeInsets.all(Tokens.space4),
          children: [
            Text('${o.paymentMethod.label} · total ${o.total.format()}', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: Tokens.space3),
            for (final s in o.subOrders) ...[_SubOrderCard(sub: s), const SizedBox(height: Tokens.space3)],
          ],
        ),
      ),
    );
  }
}

class _SubOrderCard extends ConsumerWidget {
  const _SubOrderCard({required this.sub});

  final SubOrder sub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final inTransit =
        sub.status.timelineIndex >= happyPath.indexOf(OrderStatus.nfeAutorizada) &&
        sub.status.timelineIndex < happyPath.indexOf(OrderStatus.entregue);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(sub.distributorName, style: theme.textTheme.titleMedium)),
                StatusPill(sub.status),
              ],
            ),
            const SizedBox(height: Tokens.space1),
            for (final l in sub.lines) Text('${l.quantity}× ${l.partName}', style: theme.textTheme.bodySmall),
            const SizedBox(height: Tokens.space2),
            Text(
              'Previsão: ${_time.format(sub.promisedAt)}${sub.courierName == null ? '' : ' · ${sub.courierName}'}',
              style: theme.textTheme.bodySmall,
            ),
            if (inTransit) ...[
              const SizedBox(height: Tokens.space3),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Tokens.space3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(Tokens.radius),
                ),
                child: Column(
                  children: [
                    Text('Código de entrega', style: theme.textTheme.labelMedium),
                    Text(sub.deliveryCode, style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 6)),
                    Text('Informe ao entregador para confirmar o recebimento.', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
            if (sub.nfeKey != null) ...[
              const SizedBox(height: Tokens.space2),
              Text(
                'NF-e ${sub.nfeKey!.substring(0, 4)}…${sub.nfeKey!.substring(40)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: Tokens.space3),
            SagaTimeline(sub: sub),
            if (sub.status.canRequestReturn) ...[
              const SizedBox(height: Tokens.space3),
              OutlinedButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ReturnSheet(sub: sub),
                ),
                icon: const Icon(Icons.assignment_return_outlined),
                label: const Text('Solicitar devolução'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Linha do tempo da saga: etapas do caminho feliz + eventos de compensação.
class SagaTimeline extends StatelessWidget {
  const SagaTimeline({super.key, required this.sub});

  final SubOrder sub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = sub.status.timelineIndex;
    final compensations = sub.history.where((e) => e.status.isCompensation).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, step) in happyPath.indexed)
          Row(
            children: [
              Icon(
                i < current || (i == current && !sub.status.isCompensation)
                    ? Icons.check_circle
                    : i == current
                    ? Icons.pending
                    : Icons.radio_button_unchecked,
                size: 18,
                color: i <= current
                    ? (i == current && sub.status.isCompensation ? Tokens.warning : Tokens.success)
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: Tokens.space2),
              Text(step.label, style: i <= current ? theme.textTheme.bodyMedium : theme.textTheme.bodySmall),
            ],
          ),
        for (final e in compensations) ...[
          const SizedBox(height: Tokens.space2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 18, color: Tokens.warning),
              const SizedBox(width: Tokens.space2),
              Expanded(
                child: Text(
                  '${_time.format(e.at)} · ${e.status.label}${e.note == null ? '' : ': ${e.note}'}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class ReturnSheet extends ConsumerStatefulWidget {
  const ReturnSheet({super.key, required this.sub});

  final SubOrder sub;

  @override
  ConsumerState<ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends ConsumerState<ReturnSheet> {
  var _reason = ReturnReason.pecaNaoServe;
  final _note = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(backendProvider)
          .orders
          .requestReturn(subOrderId: widget.sub.id, reason: _reason, note: _note.text.trim());
      if (mounted) Navigator.of(context).pop();
    } on AppException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      Tokens.space4,
      Tokens.space4,
      Tokens.space4,
      MediaQuery.viewInsetsOf(context).bottom + Tokens.space4,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Por que devolver?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: Tokens.space2),
        for (final r in ReturnReason.values)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(_reason == r ? Icons.radio_button_checked : Icons.radio_button_unchecked),
            title: Text(r.label),
            onTap: () => setState(() => _reason = r),
          ),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Detalhes (opcional)'),
        ),
        const SizedBox(height: Tokens.space3),
        Text(
          'A coleta reversa e a NF de devolução são geradas automaticamente.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: Tokens.space3),
        FilledButton(onPressed: _busy ? null : _submit, child: const Text('Abrir devolução')),
      ],
    ),
  );
}
