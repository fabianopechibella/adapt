import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DemoBanner fica acima do conteúdo e não sobre a AppBar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => DemoBanner(enabled: true, child: child!),
        home: Scaffold(
          appBar: AppBar(
            actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.shopping_cart))],
          ),
        ),
      ),
    );
    final strip = tester.getRect(find.text('MODO DEMONSTRAÇÃO · dados fictícios'));
    final cart = tester.getRect(find.byIcon(Icons.shopping_cart));
    expect(strip.overlaps(cart), isFalse);
    expect(cart.top, greaterThanOrEqualTo(strip.bottom));
  });

  testWidgets('DemoBanner desligado não altera a árvore', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DemoBanner(enabled: false, child: Text('app'))));
    expect(find.textContaining('DEMONSTRAÇÃO'), findsNothing);
    expect(find.text('app'), findsOneWidget);
  });
}
