import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';
import '../../router.dart';

class OffersScreen extends ConsumerStatefulWidget {
  const OffersScreen({super.key, required this.partId, this.match});

  final String partId;

  /// Vem da busca; sem ele (deep link) a tela mostra só as ofertas.
  final FitmentMatch? match;

  @override
  ConsumerState<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends ConsumerState<OffersScreen> {
  var _codeChecked = false;

  bool get _blocked => (widget.match?.needsConfirmation ?? true) && !_codeChecked;

  void _add(Offer offer) {
    final match = widget.match;
    if (match == null) return;
    ref.read(cartProvider.notifier).add(match.part, offer, vehicleId: ref.read(vehicleProvider)?.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Adicionado: ${match.part.name} · ${offer.distributorName}'),
          action: SnackBarAction(label: 'Ver carrinho', onPressed: () => context.push('/carrinho')),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final match = widget.match;
    final offers = ref.watch(offersProvider((partId: widget.partId, vehicleId: ref.watch(vehicleProvider)?.id)));

    return Scaffold(
      appBar: AppBar(title: const Text('Ofertas'), actions: const [CartAction()]),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.space4),
        children: [
          if (match != null) ...[
            Row(
              children: [
                Expanded(child: Text('${match.part.name} · ${match.part.brand}', style: theme.textTheme.titleLarge)),
                FitmentBadge(match),
              ],
            ),
            const SizedBox(height: Tokens.space1),
            Text(
              'Cód. OEM ${match.part.oemCode}'
              '${match.part.equivalentCodes.isEmpty ? '' : ' · equivalentes ${match.part.equivalentCodes.join(', ')}'}',
              style: theme.textTheme.bodySmall,
            ),
            if (match.needsConfirmation) ...[
              const SizedBox(height: Tokens.space3),
              Card(
                color: Tokens.warning.withValues(alpha: 0.10),
                child: CheckboxListTile(
                  key: const Key('confirm-code'),
                  value: _codeChecked,
                  onChanged: (v) => setState(() => _codeChecked = v ?? false),
                  title: const Text('Aplicação não confirmada no catálogo'),
                  subtitle: Text(
                    'Confira se a peça antiga tem o código ${match.part.oemCode} '
                    'ou um equivalente antes de comprar.',
                  ),
                ),
              ),
            ],
            const SizedBox(height: Tokens.space4),
          ],
          Text('Ordenado por preço, prazo e confiabilidade', style: theme.textTheme.labelLarge),
          const SizedBox(height: Tokens.space2),
          offers.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(Tokens.space5),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(offersProvider)),
            data: (ranked) => ranked.isEmpty
                ? const EmptyState(icon: Icons.inventory_2_outlined, title: 'Sem estoque na sua região agora')
                : Column(
                    children: [
                      for (final r in ranked)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Tokens.space2),
                          child: OfferCard(ranked: r, onAdd: match == null || _blocked ? null : () => _add(r.offer)),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class OfferCard extends StatelessWidget {
  const OfferCard({super.key, required this.ranked, this.onAdd});

  final RankedOffer ranked;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final o = ranked.offer;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ranked.badges.isNotEmpty) ...[
              Wrap(
                spacing: Tokens.space2,
                children: [
                  for (final b in OfferBadge.values.where(ranked.badges.contains))
                    Pill(b.label, tone: b == OfferBadge.recomendado ? Tone.info : Tone.neutral),
                ],
              ),
              const SizedBox(height: Tokens.space2),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.distributorName, style: theme.textTheme.titleSmall),
                      const SizedBox(height: Tokens.space1),
                      Text(
                        'Chega em ~${o.etaMinutes} min · confiabilidade ${(o.reliability * 100).round()}% · ${o.stock} em estoque',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(o.price.format(), style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: Tokens.space3),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Adicionar ao carrinho'),
            ),
          ],
        ),
      ),
    );
  }
}
