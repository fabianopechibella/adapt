import 'package:autopecas_core/autopecas_core.dart';
import 'package:entregador_app/app.dart';
import 'package:entregador_app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeCourierBackend backend;

  setUp(() => backend = FakeCourierBackend(latency: Duration.zero, nfeDelay: null));
  tearDown(() => backend.dispose());

  Future<void> pumpSignedIn(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configProvider.overrideWithValue(const AppConfig(apiBaseUrl: '')),
          backendProvider.overrideWithValue(backend.asBackend()),
        ],
        child: const EntregadorApp(),
      ),
    );
    await tester.enterText(find.byKey(const Key('cpf')), '123.456.789-09');
    await tester.enterText(find.byKey(const Key('phone')), '11988887777');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('code')), FakeCourierBackend.demoCode);
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
  }

  FilledButton advanceButton(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(const Key('advance')));

  Future<void> advance(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('advance')));
    await tester.pumpAndSettle();
  }

  testWidgets('coleta bloqueada até a NF-e e entrega com código da oficina', (tester) async {
    await pumpSignedIn(tester);
    expect(find.text('Rotas disponíveis'), findsOneWidget);
    expect(find.text('Oficina Boa Vista'), findsOneWidget);

    // c-102 é a mais próxima; aceita a c-101 (NF-e pendente) pelo endereço.
    final card = find.ancestor(of: find.text('Oficina Boa Vista'), matching: find.byType(Card));
    await tester.tap(find.descendant(of: card, matching: find.text('Aceitar corrida')));
    await tester.pumpAndSettle();

    expect(find.text('A caminho do distribuidor'), findsWidgets);
    await advance(tester);
    expect(find.text('Aguardando NF-e autorizada'), findsOneWidget);
    expect(advanceButton(tester).onPressed, isNull);

    backend.authorizeNfe('c-101');
    await tester.pumpAndSettle();
    expect(find.text('NF-e ok'), findsOneWidget);

    await advance(tester); // coleta
    await advance(tester); // inicia rota
    await tester.tap(find.byKey(const Key('advance'))); // confirmar entrega
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('delivery-code')), '0000');
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(find.text('Código de entrega inválido. Peça o código à oficina.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('advance')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('delivery-code')), FakeCourierBackend.demoDeliveryCode);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(find.text('Entrega concluída'), findsOneWidget);
  });
}
