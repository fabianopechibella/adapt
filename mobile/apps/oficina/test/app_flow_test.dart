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

  Future<void> pumpApp(WidgetTester tester) async {
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
        child: const OficinaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('cnpj')), '11.222.333/0001-81');
    await tester.enterText(find.byKey(const Key('phone')), '11999990000');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('code')), FakeWorkshopBackend.demoCode);
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
  }

  Future<void> identify(WidgetTester tester, String plate) async {
    await tester.enterText(find.byKey(const Key('plate')), plate);
    await tester.tap(find.byKey(const Key('lookup')));
    await tester.pumpAndSettle();
  }

  Future<void> searchPart(WidgetTester tester, String query) async {
    await tester.enterText(find.byKey(const Key('query')), query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  testWidgets('CNPJ inválido não avança no login', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byKey(const Key('cnpj')), '11.222.333/0001-00');
    await tester.enterText(find.byKey(const Key('phone')), '11999990000');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(find.text('CNPJ inválido. Confira os dígitos.'), findsOneWidget);
    expect(find.byKey(const Key('code')), findsNothing);
  });

  testWidgets('da placa ao pedido entregue, com a saga visível', (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    expect(find.text('Qual é o veículo?'), findsOneWidget);

    await identify(tester, 'abc1d23');
    expect(find.text('Chevrolet Onix 1.0 Flex'), findsOneWidget);

    await searchPart(tester, 'embreagem');
    expect(find.text('Kit de embreagem · LuK'), findsOneWidget);
    expect(find.text('Compatível'), findsOneWidget);

    await tester.tap(find.text('Kit de embreagem · LuK'));
    await tester.pumpAndSettle();
    expect(find.text('Recomendado'), findsOneWidget);

    await tester.tap(find.text('Adicionar ao carrinho').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver carrinho'));
    await tester.pumpAndSettle();

    expect(find.text('Carrinho'), findsOneWidget);
    await tester.tap(find.byKey(const Key('checkout')));
    await tester.pumpAndSettle();

    expect(find.text('PED-1000'), findsOneWidget);
    expect(find.text('Pedido criado'), findsWidgets);

    for (var i = 0; i < 6; i++) {
      backend.advanceOrder('PED-1000');
    }
    await tester.pumpAndSettle();
    expect(find.text('Código de entrega'), findsOneWidget);

    for (var i = 0; i < 4; i++) {
      backend.advanceOrder('PED-1000');
    }
    await tester.pumpAndSettle();
    expect(find.text('Solicitar devolução'), findsOneWidget);
  });

  testWidgets('aplicação não confirmada bloqueia a compra até conferir o código', (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    await identify(tester, 'ABC1D23');
    await searchPart(tester, 'velas');

    expect(find.text('Confirmar aplicação'), findsOneWidget);
    await tester.tap(find.text('Jogo de velas de ignição · NGK'));
    await tester.pumpAndSettle();

    final addButton = find.widgetWithText(OutlinedButton, 'Adicionar ao carrinho').first;
    expect(tester.widget<OutlinedButton>(addButton).onPressed, isNull);

    await tester.tap(find.byKey(const Key('confirm-code')));
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(addButton).onPressed, isNotNull);
  });

  testWidgets('assistente identifica a peça e permite adicionar ao carrinho', (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    await tester.tap(find.text('Assistente'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('agent-input')), 'pastilha de freio do HB20 placa BRA2E19');
    await tester.tap(find.byKey(const Key('agent-send')));
    await tester.pumpAndSettle();

    expect(find.textContaining('é compatível com o Hyundai HB20'), findsOneWidget);
    await tester.tap(find.byTooltip('Adicionar ao carrinho').first);
    await tester.pumpAndSettle();
    expect(find.text('1'), findsWidgets);
  });
}
