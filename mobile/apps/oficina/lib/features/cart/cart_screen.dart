import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  var _payment = PaymentMethod.pix;
  var _busy = false;

  /// Mantida entre tentativas: se a rede cair depois de o servidor criar o
  /// pedido, a nova tentativa devolve o mesmo pedido em vez de duplicar.
  String? _idempotencyKey;

  Future<void> _checkout(Cart cart) async {
    setState(() => _busy = true);
    _idempotencyKey ??= newIdempotencyKey();
    try {
      final order = await ref
          .read(backendProvider)
          .orders
          .placeOrder(PlaceOrderRequest(cart: cart, paymentMethod: _payment, idempotencyKey: _idempotencyKey!));
      _idempotencyKey = null;
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(ordersProvider);
      ref.invalidate(accountProvider);
      if (mounted) context.go('/pedidos/${order.id}');
    } on AppException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = ref.watch(cartProvider);
    final account = ref.watch(accountProvider).value;
    final canInvoice = account?.canInvoice(cart.total) ?? false;
    if (!canInvoice && _payment == PaymentMethod.faturado) _payment = PaymentMethod.pix;

    return Scaffold(
      appBar: AppBar(title: const Text('Carrinho')),
      body: cart.isEmpty
          ? const EmptyState(icon: Icons.shopping_cart_outlined, title: 'Seu carrinho está vazio')
          : ResponsiveListView(
              children: [
                for (final entry in cart.byDistributor.entries) ...[
                  Text(entry.key, style: theme.textTheme.titleSmall),
                  Text(
                    'Entrega separada · chega em ~${entry.value.map((l) => l.offer.etaMinutes).reduce((a, b) => a > b ? a : b)} min',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: Tokens.space2),
                  for (final line in entry.value) _LineTile(line: line),
                  const SizedBox(height: Tokens.space4),
                ],
                Text('Pagamento', style: theme.textTheme.titleSmall),
                const SizedBox(height: Tokens.space2),
                Wrap(
                  spacing: Tokens.space2,
                  children: [
                    for (final m in PaymentMethod.values)
                      ChoiceChip(
                        label: Text(m.label),
                        selected: _payment == m,
                        onSelected: m == PaymentMethod.faturado && !canInvoice
                            ? null
                            : (_) => setState(() => _payment = m),
                      ),
                  ],
                ),
                if (account != null) ...[
                  const SizedBox(height: Tokens.space2),
                  Text(
                    'Crédito disponível para faturar: ${account.creditAvailable.format()}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: MaxContentWidth(
                child: Padding(
                  padding: const EdgeInsets.all(Tokens.space4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'itens'} · até ~${cart.etaMinutes} min',
                            ),
                          ),
                          Text(cart.total.format(), style: theme.textTheme.titleLarge),
                        ],
                      ),
                      const SizedBox(height: Tokens.space3),
                      FilledButton(
                        key: const Key('checkout'),
                        onPressed: _busy ? null : () => _checkout(cart),
                        child: _busy
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text('Confirmar pedido · ${_payment.label}'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _LineTile extends ConsumerWidget {
  const _LineTile({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.read(cartProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.space4, vertical: Tokens.space2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${line.part.name} · ${line.part.brand}'),
                  Text('${line.offer.price.format()} cada', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Diminuir',
              onPressed: () => cart.setQuantity(line.offer.id, line.quantity - 1),
              icon: Icon(line.quantity == 1 ? Icons.delete_outline : Icons.remove),
            ),
            Text('${line.quantity}'),
            IconButton(
              tooltip: 'Aumentar',
              onPressed: line.quantity >= line.offer.stock
                  ? null
                  : () => cart.setQuantity(line.offer.id, line.quantity + 1),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
