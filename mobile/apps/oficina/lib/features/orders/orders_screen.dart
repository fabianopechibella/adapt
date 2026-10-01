import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers.dart';

final _date = DateFormat('dd/MM HH:mm');

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(ordersProvider.future),
        child: orders.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(ordersProvider)),
          data: (list) => list.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    EmptyState(icon: Icons.receipt_long_outlined, title: 'Nenhum pedido ainda'),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(Tokens.space4),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Tokens.space2),
                  itemBuilder: (context, i) {
                    final o = list[i];
                    return Card(
                      child: ListTile(
                        onTap: () => context.go('/pedidos/${o.id}'),
                        title: Text(o.id),
                        subtitle: Text(
                          '${_date.format(o.createdAt)} · ${o.subOrders.length} entrega(s) · ${o.total.format()}',
                        ),
                        trailing: StatusPill(o.headline),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
