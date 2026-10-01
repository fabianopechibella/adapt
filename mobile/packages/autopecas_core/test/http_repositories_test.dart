import 'dart:convert';

import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const vehicle = Vehicle(id: 'v1', plate: 'ABC1D23', brand: 'Chevrolet', model: 'Onix', year: 2019, engine: '1.0');
  const part = Part(id: 'p1', name: 'Pastilha', brand: 'Cobreq', category: 'Freios', oemCode: 'N-1430');
  const offer = Offer(
    id: 'o1',
    partId: 'p1',
    distributorId: 'd1',
    distributorName: 'Centro',
    price: Money(13490),
    stock: 4,
    etaMinutes: 35,
    reliability: 0.97,
  );

  late List<http.Request> requests;

  HttpWorkshopRepository repo(http.Response Function(http.Request) handler) {
    requests = [];
    final client = MockClient((r) async {
      requests.add(r);
      return handler(r);
    });
    return HttpWorkshopRepository(
      ApiClient(baseUrl: Uri.parse('https://bff.test/api'), tokenProvider: () => 'tok', client: client),
    );
  }

  http.Response json(Object body, [int status = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

  test('envia token e monta a URL a partir da base', () async {
    final r = repo((_) => json(vehicle.toJson()));
    final v = await r.lookupPlate('ABC1D23');
    expect(v.model, 'Onix');
    expect(requests.single.url.toString(), 'https://bff.test/api/v1/vehicles/by-plate/ABC1D23');
    expect(requests.single.headers['Authorization'], 'Bearer tok');
  });

  test('pedido envia Idempotency-Key e as linhas do carrinho', () async {
    final order = Order(
      id: 'PED-1',
      createdAt: DateTime.utc(2026),
      paymentMethod: PaymentMethod.pix,
      subOrders: [
        SubOrder(
          id: 'PED-1-1',
          distributorName: 'Centro',
          lines: const [OrderLine(partId: 'p1', partName: 'Pastilha', quantity: 2, unitPrice: Money(13490))],
          history: [StatusEvent(OrderStatus.criado, DateTime.utc(2026))],
          promisedAt: DateTime.utc(2026),
          deliveryCode: '1234',
        ),
      ],
    );
    final r = repo((_) => json(order.toJson(), 201));
    final placed = await r.placeOrder(
      PlaceOrderRequest(
        cart: const Cart().add(part, offer, quantity: 2, vehicleId: vehicle.id),
        paymentMethod: PaymentMethod.pix,
        idempotencyKey: 'abc',
      ),
    );

    expect(placed.total, const Money(26980));
    final sent = requests.single;
    expect(sent.headers['Idempotency-Key'], 'abc');
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['paymentMethod'], 'pix');
    expect((body['lines'] as List).single, {'offerId': 'o1', 'partId': 'p1', 'quantity': 2, 'vehicleId': 'v1'});
  });

  test('erro do BFF vira AppException com a mensagem do servidor', () async {
    final r = repo((_) => json({'code': 'plate_not_found', 'message': 'Placa não encontrada'}, 404));
    await expectLater(
      r.lookupPlate('ZZZ9Z99'),
      throwsA(
        isA<AppException>()
            .having((e) => e.code, 'code', 'plate_not_found')
            .having((e) => e.message, 'message', 'Placa não encontrada'),
      ),
    );
  });

  test('falha de rede vira mensagem amigável', () async {
    final client = MockClient((_) async => throw const SocketLikeException());
    final r = HttpWorkshopRepository(
      ApiClient(baseUrl: Uri.parse('https://bff.test'), tokenProvider: () => null, client: client),
    );
    await expectLater(r.me(), throwsA(isA<AppException>().having((e) => e.code, 'code', 'network')));
  });
}

class SocketLikeException implements Exception {
  const SocketLikeException();
}
