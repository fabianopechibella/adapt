import 'dart:io';

import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oficina_app/app.dart';
import 'package:oficina_app/providers.dart';

/// Percorre o modo demonstração no emulador Android / simulador iOS e tira
/// uma captura de cada tela. Rodar com `flutter drive` (ver README).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var surfaceConverted = false;

  Future<void> snap(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    if (Platform.isAndroid && !surfaceConverted) {
      await binding.convertFlutterSurfaceToImage();
      surfaceConverted = true;
      await tester.pumpAndSettle();
    }
    await binding.takeScreenshot('oficina-$name');
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('fluxo de demonstração da oficina', (tester) async {
    final backend = FakeWorkshopBackend(latency: Duration.zero, tick: null);
    addTearDown(backend.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configProvider.overrideWithValue(const AppConfig(apiBaseUrl: '')),
          backendProvider.overrideWithValue(backend.asBackend()),
        ],
        child: const OficinaApp(),
      ),
    );
    await snap(tester, '01-login');

    await tester.enterText(find.byKey(const Key('cnpj')), '11.222.333/0001-81');
    await tester.enterText(find.byKey(const Key('phone')), '11999990000');
    await tapAndSettle(tester, find.byKey(const Key('submit')));
    await tester.enterText(find.byKey(const Key('code')), FakeWorkshopBackend.demoCode);
    await tapAndSettle(tester, find.byKey(const Key('submit')));
    await snap(tester, '02-placa');

    await tester.enterText(find.byKey(const Key('plate')), 'ABC1D23');
    await tapAndSettle(tester, find.byKey(const Key('lookup')));
    await tester.enterText(find.byKey(const Key('query')), 'embreagem');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Kit de embreagem · LuK'), findsOneWidget);
    await snap(tester, '03-busca');

    await tapAndSettle(tester, find.text('Kit de embreagem · LuK'));
    await snap(tester, '04-ofertas');

    await tapAndSettle(tester, find.text('Adicionar ao carrinho').first);
    await tapAndSettle(tester, find.text('Ver carrinho'));
    await snap(tester, '05-carrinho');

    await tapAndSettle(tester, find.byKey(const Key('checkout')));
    for (var i = 0; i < 6; i++) {
      backend.advanceOrder('PED-1000');
    }
    await tester.pumpAndSettle();
    expect(find.text('Código de entrega'), findsOneWidget);
    await snap(tester, '06-pedido');

    await tapAndSettle(tester, find.text('Assistente'));
    await tester.enterText(find.byKey(const Key('agent-input')), 'pastilha de freio do HB20 placa BRA2E19');
    await tapAndSettle(tester, find.byKey(const Key('agent-send')));
    expect(find.textContaining('é compatível com o Hyundai HB20'), findsOneWidget);
    await snap(tester, '07-assistente');
  });
}
