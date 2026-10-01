import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oficina_app/app.dart';
import 'package:oficina_app/providers.dart';

void main() {
  late FakeWorkshopBackend backend;

  setUp(() => backend = FakeWorkshopBackend(latency: Duration.zero, tick: null));
  tearDown(() => backend.dispose());

  Future<void> pumpSignedIn(WidgetTester tester, Size logicalSize) async {
    tester.view
      ..physicalSize = logicalSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configProvider.overrideWithValue(const AppConfig(apiBaseUrl: '')),
          backendProvider.overrideWithValue(backend.asBackend()),
        ],
        child: const OficinaApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('cnpj')), '11.222.333/0001-81');
    await tester.enterText(find.byKey(const Key('phone')), '11999990000');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('code')), FakeWorkshopBackend.demoCode);
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('celular usa barra inferior', (tester) async {
    await pumpSignedIn(tester, const Size(400, 860));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('monitor do balcão usa menu lateral e conteúdo com largura máxima', (tester) async {
    await pumpSignedIn(tester, const Size(1440, 900));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).extended, isTrue);

    final plate = tester.getRect(find.byKey(const Key('plate')));
    expect(plate.width, lessThanOrEqualTo(kContentMaxWidth));

    // O menu lateral continua navegando entre as abas.
    await tester.tap(find.text('Pedidos'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum pedido ainda'), findsOneWidget);
  });

  testWidgets('rodapé do carrinho fica estreito e colado embaixo em tela larga', (tester) async {
    await pumpSignedIn(tester, const Size(1440, 900));
    await tester.enterText(find.byKey(const Key('plate')), 'ABC1D23');
    await tester.tap(find.byKey(const Key('lookup')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('query')), 'filtro de óleo');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filtro de óleo · Tecfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar ao carrinho').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver carrinho'));
    await tester.pumpAndSettle();

    final checkout = tester.getRect(find.byKey(const Key('checkout')));
    expect(checkout.width, lessThanOrEqualTo(kContentMaxWidth));
    expect(checkout.bottom, greaterThan(900 - 80));
  });
}
