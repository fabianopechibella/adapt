import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/account/account_screen.dart';
import 'features/assistant/assistant_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/cart/cart_screen.dart';
import 'features/orders/order_detail_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/search/offers_screen.dart';
import 'features/search/search_screen.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/buscar',
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = ref.read(sessionProvider) != null;
      final atLogin = state.matchedLocation == '/login';
      if (!signedIn) return atLogin ? null : '/login';
      return atLogin ? '/buscar' : null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/carrinho', builder: (_, _) => const CartScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/buscar',
                builder: (_, _) => const SearchScreen(),
                routes: [
                  GoRoute(
                    path: 'peca/:partId',
                    builder: (_, state) =>
                        OffersScreen(partId: state.pathParameters['partId']!, match: state.extra as FitmentMatch?),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/assistente', builder: (_, _) => const AssistantScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pedidos',
                builder: (_, _) => const OrdersScreen(),
                routes: [
                  GoRoute(
                    path: ':orderId',
                    builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters['orderId']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/conta', builder: (_, _) => const AccountScreen())],
          ),
        ],
      ),
    ],
  );
});

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _destinations = [
    (icon: Icons.search, selected: Icons.search, label: 'Buscar'),
    (icon: Icons.forum_outlined, selected: Icons.forum, label: 'Assistente'),
    (icon: Icons.receipt_long_outlined, selected: Icons.receipt_long, label: 'Pedidos'),
    (icon: Icons.store_outlined, selected: Icons.store, label: 'Conta'),
  ];

  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

  /// Celular: barra inferior. Tablet e web no computador: menu lateral,
  /// que libera altura útil e é o padrão esperado em telas largas.
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < kWideLayoutBreakpoint) {
      return Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _go,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: d.label),
          ],
        ),
      );
    }
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: _go,
            extended: width >= 1200,
            labelType: width >= 1200 ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: Tokens.space3),
              child: Icon(Icons.build_circle, size: 36, color: Theme.of(context).colorScheme.primary),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: shell),
        ],
      ),
    );
  }
}

/// Ícone do carrinho com contador, usado na AppBar das telas de compra.
class CartAction extends ConsumerWidget {
  const CartAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartProvider.select((c) => c.itemCount));
    return IconButton(
      tooltip: 'Carrinho',
      onPressed: () => context.push('/carrinho'),
      icon: Badge(isLabelVisible: count > 0, label: Text('$count'), child: const Icon(Icons.shopping_cart_outlined)),
    );
  }
}
