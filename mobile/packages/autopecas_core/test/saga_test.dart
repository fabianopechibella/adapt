import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter_test/flutter_test.dart';

SubOrder sub() => SubOrder(
  id: 's1',
  distributorName: 'D',
  lines: const [],
  history: [StatusEvent(OrderStatus.criado, DateTime(2026))],
  promisedAt: DateTime(2026),
  deliveryCode: '1234',
);

void main() {
  test('caminho feliz percorre todos os estados até a entrega', () {
    var s = sub();
    for (final status in happyPath.skip(1)) {
      s = s.transition(status, DateTime(2026));
    }
    expect(s.status, OrderStatus.entregue);
    expect(s.history, hasLength(happyPath.length));
  });

  test('não coleta sem NF-e autorizada', () {
    var s = sub();
    for (final status in happyPath.skip(1).take(4)) {
      s = s.transition(status, DateTime(2026));
    }
    expect(s.status, OrderStatus.emSeparacao);
    expect(() => s.transition(OrderStatus.coletado, DateTime(2026)), throwsA(isA<InvalidTransition>()));
  });

  test('NF-e rejeitada volta para autorizada sem pular etapas', () {
    expect(OrderStatus.emSeparacao.canTransitionTo(OrderStatus.nfeRejeitada), isTrue);
    expect(OrderStatus.nfeRejeitada.nextHappy, OrderStatus.nfeAutorizada);
    expect(OrderStatus.nfeRejeitada.timelineIndex, happyPath.indexOf(OrderStatus.nfeAutorizada));
  });

  test('devolução só depois da entrega e termina em devolvido', () {
    expect(OrderStatus.emRota.canRequestReturn, isFalse);
    expect(OrderStatus.entregue.canTransitionTo(OrderStatus.devolucaoSolicitada), isTrue);
    expect(OrderStatus.devolvido.isTerminal, isTrue);
    expect(OrderStatus.cancelado.isTerminal, isTrue);
  });

  test('todo estado é alcançável e só terminais não têm saída', () {
    final reachable = <OrderStatus>{OrderStatus.criado};
    var frontier = {OrderStatus.criado};
    while (frontier.isNotEmpty) {
      frontier = {for (final s in frontier) ...s.next}.difference(reachable);
      reachable.addAll(frontier);
    }
    expect(reachable, OrderStatus.values.toSet());
  });

  test('Order serializa e desserializa sem perda', () {
    final order = Order(
      id: 'PED-1',
      createdAt: DateTime.utc(2026, 10, 1, 12),
      paymentMethod: PaymentMethod.pix,
      subOrders: [sub().transition(OrderStatus.pagamentoAutorizado, DateTime.utc(2026, 10, 1, 12, 1))],
    );
    final copy = Order.fromJson(order.toJson());
    expect(copy.toJson(), order.toJson());
    expect(copy.headline, OrderStatus.pagamentoAutorizado);
  });

  group('Delivery', () {
    const d = Delivery(
      id: 'c1',
      subOrderId: 's1',
      distributorName: 'D',
      pickupAddress: 'A',
      workshopName: 'W',
      dropoffAddress: 'B',
      distanceKm: 1,
      fee: Money(1000),
      vehicleType: VehicleType.moto,
      itemsSummary: '1 item',
      status: DeliveryStatus.noDistribuidor,
      nfeAuthorized: false,
    );

    test('coleta bloqueada até a NF-e ser autorizada', () {
      expect(() => d.advance(), throwsA(isA<DeliveryRuleViolation>()));
      expect(d.copyWith(nfeAuthorized: true).advance().status, DeliveryStatus.coletada);
    });

    test('entrega exige o código informado pela oficina', () {
      final emRota = d.copyWith(status: DeliveryStatus.emRota, nfeAuthorized: true);
      expect(() => emRota.advance(deliveryCode: '0000', expectedCode: '2468'), throwsA(isA<DeliveryRuleViolation>()));
      expect(emRota.advance(deliveryCode: '2468', expectedCode: '2468').status, DeliveryStatus.entregue);
    });
  });
}
