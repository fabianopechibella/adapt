import 'dart:math';

import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeWorkshopBackend backend;

  setUp(() => backend = FakeWorkshopBackend(latency: Duration.zero, tick: null, random: Random(1)));
  tearDown(() => backend.dispose());

  Future<Cart> cartWithTwoDistributors() async {
    final vehicle = await backend.lookupPlate('ABC1D23');
    final match = (await backend.searchCompatible(vehicleId: vehicle.id, query: 'embreagem')).first;
    final offers = await backend.quote(partId: match.part.id);
    return const Cart()
        .add(match.part, offers.firstWhere((o) => o.distributorName.startsWith('Distribuidora')))
        .add(match.part, offers.firstWhere((o) => o.distributorName.startsWith('Auto Norte')));
  }

  test('login exige CNPJ válido e o código', () async {
    await expectLater(backend.requestCode(login: '123', phone: '11999990000'), throwsA(isA<AppException>()));
    await backend.requestCode(login: '11.222.333/0001-81', phone: '(11) 99999-0000');
    await expectLater(backend.verifyCode(login: '11222333000181', code: '000000'), throwsA(isA<AppException>()));
    final session = await backend.verifyCode(login: '11222333000181', code: FakeWorkshopBackend.demoCode);
    expect(session.token, isNotEmpty);
  });

  test('fitment: aplicação confirmada x inferida x confirmada por código', () async {
    final onix = await backend.lookupPlate('abc-1d23');
    final velas = await backend.searchCompatible(vehicleId: onix.id, query: 'vela');
    expect(velas.single.needsConfirmation, isTrue);

    final porCodigo = await backend.searchCompatible(vehicleId: onix.id, query: 'o código é 18846-11070');
    expect(porCodigo.single.needsConfirmation, isFalse);

    final embreagem = await backend.searchCompatible(vehicleId: onix.id, query: 'kit embreagem');
    expect(embreagem.single.part.id, 'p-emb-onix');
  });

  test('placa desconhecida gera erro de negócio', () async {
    await expectLater(backend.lookupPlate('ZZZ9Z99'), throwsA(isA<AppException>()));
  });

  test('pedido multifornecedor vira um subpedido por distribuidor e é idempotente', () async {
    final cart = await cartWithTwoDistributors();
    final request = PlaceOrderRequest(cart: cart, paymentMethod: PaymentMethod.pix, idempotencyKey: 'k1');
    final first = await backend.placeOrder(request);
    final retry = await backend.placeOrder(request);

    expect(first.subOrders, hasLength(2));
    expect(retry.id, first.id);
    expect(await backend.listOrders(), hasLength(1));
  });

  test('saga avança, compensa a NF-e rejeitada e só então entrega', () async {
    final order = await backend.placeOrder(
      PlaceOrderRequest(cart: await cartWithTwoDistributors(), paymentMethod: PaymentMethod.pix, idempotencyKey: 'k2'),
    );
    final updates = <Order>[];
    final sub = backend.watchOrder(order.id).listen(updates.add);

    for (var i = 0; i < 12; i++) {
      backend.advanceOrder(order.id);
    }
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    final last = updates.last;
    expect(last.subOrders.every((s) => s.status == OrderStatus.entregue), isTrue);
    final norte = last.subOrders.firstWhere((s) => s.distributorName.startsWith('Auto Norte'));
    final statuses = norte.history.map((e) => e.status).toList();
    expect(
      statuses,
      containsAllInOrder([
        OrderStatus.emSeparacao,
        OrderStatus.nfeRejeitada,
        OrderStatus.nfeAutorizada,
        OrderStatus.coletado,
      ]),
    );
    expect(norte.nfeKey, hasLength(44));
  });

  test('devolução só depois da entrega', () async {
    final order = await backend.placeOrder(
      PlaceOrderRequest(cart: await cartWithTwoDistributors(), paymentMethod: PaymentMethod.pix, idempotencyKey: 'k3'),
    );
    final subId = order.subOrders.first.id;
    await expectLater(
      backend.requestReturn(subOrderId: subId, reason: ReturnReason.pecaNaoServe),
      throwsA(isA<AppException>()),
    );

    for (var i = 0; i < 12; i++) {
      backend.advanceOrder(order.id);
    }
    final updated = await backend.requestReturn(
      subOrderId: subId,
      reason: ReturnReason.pecaNaoServe,
      note: 'motor diferente',
    );
    expect(updated.subOrders.first.status, OrderStatus.devolucaoSolicitada);
    backend.advanceOrder(order.id);
    expect((await backend.listOrders()).first.subOrders.first.status, OrderStatus.devolvido);
  });

  test('faturado respeita o limite de crédito', () async {
    final vehicle = await backend.lookupPlate('ABC1D23');
    final match = (await backend.searchCompatible(vehicleId: vehicle.id, query: 'embreagem')).first;
    final offer = (await backend.quote(partId: match.part.id)).last;
    final big = const Cart().add(match.part, offer, quantity: 10);
    expect(big.total > (await backend.me()).creditAvailable, isTrue);

    await expectLater(
      backend.placeOrder(PlaceOrderRequest(cart: big, paymentMethod: PaymentMethod.faturado, idempotencyKey: 'k4')),
      throwsA(isA<AppException>()),
    );
    final small = const Cart().add(match.part, offer);
    final before = (await backend.me()).creditAvailable;
    await backend.placeOrder(
      PlaceOrderRequest(cart: small, paymentMethod: PaymentMethod.faturado, idempotencyKey: 'k5'),
    );
    expect((await backend.me()).creditAvailable, before - small.total);
  });
}
