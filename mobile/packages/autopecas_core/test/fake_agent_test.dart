import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeWorkshopBackend backend;
  late AgentRepository agent;

  setUp(() {
    backend = FakeWorkshopBackend(latency: Duration.zero, tick: null);
    agent = backend.asBackend().agent;
  });
  tearDown(() => backend.dispose());

  test('sem placa, pede a placa antes de buscar', () async {
    final reply = await agent.send(conversationId: 'c', text: 'preciso de pastilha de freio');
    expect(reply.text, contains('placa'));
    expect(reply.matches, isEmpty);
  });

  test('placa + peça compatível: responde com a peça e ofertas ranqueadas', () async {
    final reply = await agent.send(conversationId: 'c', text: 'kit de embreagem do onix placa ABC1D23');
    expect(reply.vehicle?.model, 'Onix');
    expect(reply.matches.single.part.id, 'p-emb-onix');
    expect(reply.offers, isNotEmpty);
    expect(reply.handoffToHuman, isFalse);
  });

  test('guardrail: aplicação não confirmada pede o código e não oferta', () async {
    await agent.send(conversationId: 'c', text: 'ABC1D23');
    final reply = await agent.send(conversationId: 'c', text: 'jogo de velas');
    expect(reply.matches.single.needsConfirmation, isTrue);
    expect(reply.offers, isEmpty);
    expect(reply.text, contains('código'));

    final confirmed = await agent.send(conversationId: 'c', text: '18846-11070');
    expect(confirmed.offers, isNotEmpty);
  });

  test('na segunda falha seguida transfere para humano', () async {
    await agent.send(conversationId: 'c', text: 'ABC1D23');
    final first = await agent.send(conversationId: 'c', text: 'turbina');
    expect(first.handoffToHuman, isFalse);
    final second = await agent.send(conversationId: 'c', text: 'intercooler');
    expect(second.handoffToHuman, isTrue);
  });
}
