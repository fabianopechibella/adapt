import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'delivery_screen.dart';
import 'providers.dart';

/// Rotas disponíveis: o entregador escolhe a corrida (modelo híbrido push + lista).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _accept(BuildContext context, WidgetRef ref, Delivery d) async {
    try {
      final accepted = await ref.read(backendProvider).deliveries.accept(d.id);
      ref.invalidate(availableProvider);
      ref.invalidate(currentProvider);
      if (context.mounted) await _open(context, ref, accepted.id);
    } on AppException catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _open(BuildContext context, WidgetRef ref, String id) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DeliveryScreen(deliveryId: id)));
    ref.invalidate(availableProvider);
    ref.invalidate(currentProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final current = ref.watch(currentProvider).value;
    final available = ref.watch(availableProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Olá, ${session?.displayName ?? ''}'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: () => ref.read(sessionProvider.notifier).set(null),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(availableProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(Tokens.space4),
          children: [
            if (current != null) ...[
              Card(
                color: theme.colorScheme.primaryContainer,
                child: ListTile(
                  key: const Key('current'),
                  leading: const Icon(Icons.navigation),
                  title: Text('Corrida em andamento · ${current.status.label}'),
                  subtitle: Text(current.workshopName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(context, ref, current.id),
                ),
              ),
              const SizedBox(height: Tokens.space4),
            ],
            Text('Rotas disponíveis', style: theme.textTheme.titleMedium),
            const SizedBox(height: Tokens.space2),
            available.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(Tokens.space5),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(availableProvider)),
              data: (list) => list.isEmpty
                  ? const EmptyState(icon: Icons.hourglass_empty, title: 'Nenhuma corrida perto de você agora')
                  : Column(
                      children: [
                        for (final d in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Tokens.space2),
                            child: _DeliveryCard(
                              delivery: d,
                              onAccept: current == null ? () => _accept(context, ref, d) : null,
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.delivery, this.onAccept});

  final Delivery delivery;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = delivery;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: Tokens.space2,
                    runSpacing: Tokens.space1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Pill(d.vehicleType.label, icon: Icons.local_shipping_outlined),
                      Text('${d.distanceKm.toStringAsFixed(1)} km'),
                    ],
                  ),
                ),
                Text(d.fee.format(), style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: Tokens.space3),
            _Stop(icon: Icons.store, title: d.distributorName, subtitle: d.pickupAddress),
            const SizedBox(height: Tokens.space2),
            _Stop(icon: Icons.build, title: d.workshopName, subtitle: d.dropoffAddress),
            const SizedBox(height: Tokens.space2),
            Text(d.itemsSummary, style: theme.textTheme.bodySmall),
            const SizedBox(height: Tokens.space3),
            FilledButton(onPressed: onAccept, child: const Text('Aceitar corrida')),
          ],
        ),
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: Tokens.space2),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ],
  );
}
