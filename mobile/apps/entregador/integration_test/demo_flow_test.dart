import 'dart:io';

import 'package:autopecas_core/autopecas_core.dart';
import 'package:entregador_app/app.dart';
import 'package:entregador_app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Percorre a corrida de demonstração no emulador Android / simulador iOS e
/// tira uma captura de cada etapa. Rodar com `flutter drive` (ver README).
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
    await binding.takeScreenshot('entregador-$name');
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('corrida de demonstração do entregador', (tester) async {
    final backend = FakeCourierBackend(latency: Duration.zero, nfeDelay: null);
    addTearDown(backend.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configProvider.overrideWithValue(const AppConfig(apiBaseUrl: '')),
          backendProvider.overrideWithValue(backend.asBackend()),
        ],
        child: const EntregadorApp(),
      ),
    );

    await tester.enterText(find.byKey(const Key('cpf')), '12345678909');
    await tester.enterText(find.byKey(const Key('phone')), '11988887777');
    await tapAndSettle(tester, find.byKey(const Key('submit')));
    await tester.enterText(find.byKey(const Key('code')), FakeCourierBackend.demoCode);
    await tapAndSettle(tester, find.byKey(const Key('submit')));
    await snap(tester, '01-rotas');

    final card = find.ancestor(of: find.text('Oficina Boa Vista'), matching: find.byType(Card));
    await tapAndSettle(tester, find.descendant(of: card, matching: find.text('Aceitar corrida')));
    await tapAndSettle(tester, find.byKey(const Key('advance')));
    expect(find.text('Aguardando NF-e autorizada'), findsOneWidget);
    await snap(tester, '02-aguardando-nfe');

    backend.authorizeNfe('c-101');
    await tester.pumpAndSettle();
    await snap(tester, '03-nfe-ok');

    await tapAndSettle(tester, find.byKey(const Key('advance')));
    await tapAndSettle(tester, find.byKey(const Key('advance')));
    await tapAndSettle(tester, find.byKey(const Key('advance')));
    await tester.enterText(find.byKey(const Key('delivery-code')), FakeCourierBackend.demoDeliveryCode);
    await snap(tester, '04-codigo');
    await tapAndSettle(tester, find.text('Confirmar'));
    expect(find.text('Entrega concluída'), findsOneWidget);
    await snap(tester, '05-entregue');
  });
}
