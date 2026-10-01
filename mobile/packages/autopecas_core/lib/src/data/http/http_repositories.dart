import 'dart:async';

import '../../domain/account.dart';
import '../../domain/agent.dart';
import '../../domain/delivery.dart';
import '../../domain/offer.dart';
import '../../domain/order.dart';
import '../../domain/part.dart';
import '../../domain/vehicle.dart';
import '../repositories.dart';
import 'api_client.dart';

typedef _Json = Map<String, dynamic>;

List<T> _list<T>(Object? json, T Function(_Json) parse) => (json as List).map((e) => parse(e as _Json)).toList();

/// Implementações contra o contrato `mobile/api/openapi.yaml`.
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._api, {required this.audience});

  final ApiClient _api;

  /// `workshop` ou `courier`: cada canal autentica num BFF próprio.
  final String audience;

  @override
  Future<void> requestCode({required String login, required String phone}) =>
      _api.post('/v1/auth/otp', body: {'audience': audience, 'login': login, 'phone': phone});

  @override
  Future<Session> verifyCode({required String login, required String code}) async => Session.fromJson(
    await _api.post('/v1/auth/verify', body: {'audience': audience, 'login': login, 'code': code}) as _Json,
  );
}

class HttpWorkshopRepository
    implements AccountRepository, CatalogRepository, OfferRepository, OrderRepository, AgentRepository {
  HttpWorkshopRepository(this._api, {this.pollInterval = const Duration(seconds: 5)});

  final ApiClient _api;
  final Duration pollInterval;

  @override
  Future<WorkshopAccount> me() async => WorkshopAccount.fromJson(await _api.get('/v1/me') as _Json);

  @override
  Future<Vehicle> lookupPlate(String plate) async =>
      Vehicle.fromJson(await _api.get('/v1/vehicles/by-plate/${Uri.encodeComponent(plate)}') as _Json);

  @override
  Future<List<FitmentMatch>> searchCompatible({required String vehicleId, required String query}) async =>
      _list(await _api.get('/v1/vehicles/$vehicleId/compatible-parts', query: {'q': query}), FitmentMatch.fromJson);

  @override
  Future<List<Offer>> quote({required String partId, String? vehicleId}) async =>
      _list(await _api.get('/v1/parts/$partId/offers', query: {'vehicleId': ?vehicleId}), Offer.fromJson);

  @override
  Future<Order> placeOrder(PlaceOrderRequest request) async => Order.fromJson(
    await _api.post('/v1/orders', body: request.toJson(), headers: {'Idempotency-Key': request.idempotencyKey})
        as _Json,
  );

  @override
  Future<List<Order>> listOrders() async => _list(await _api.get('/v1/orders'), Order.fromJson);

  /// Polling simples; trocar por SSE/WebSocket quando o BFF publicar o stream da saga.
  @override
  Stream<Order> watchOrder(String orderId) async* {
    while (true) {
      final order = Order.fromJson(await _api.get('/v1/orders/$orderId') as _Json);
      yield order;
      if (order.subOrders.every((s) => s.status.isTerminal)) return;
      await Future<void>.delayed(pollInterval);
    }
  }

  @override
  Future<Order> requestReturn({required String subOrderId, required ReturnReason reason, String? note}) async =>
      Order.fromJson(
        await _api.post('/v1/sub-orders/$subOrderId/returns', body: {'reason': reason.name, 'note': ?note}) as _Json,
      );

  @override
  Future<AgentReply> send({required String conversationId, required String text}) async => AgentReply.fromJson(
    await _api.post('/v1/agent/conversations/$conversationId/messages', body: {'text': text}) as _Json,
  );
}

class HttpDeliveryRepository implements DeliveryRepository {
  HttpDeliveryRepository(this._api, {this.pollInterval = const Duration(seconds: 5)});

  final ApiClient _api;
  final Duration pollInterval;

  @override
  Future<List<Delivery>> available() async =>
      _list(await _api.get('/v1/courier/deliveries/available'), Delivery.fromJson);

  @override
  Future<Delivery?> current() async {
    final json = await _api.get('/v1/courier/deliveries/current');
    return json == null ? null : Delivery.fromJson(json as _Json);
  }

  @override
  Future<Delivery> accept(String deliveryId) async =>
      Delivery.fromJson(await _api.post('/v1/courier/deliveries/$deliveryId/accept') as _Json);

  @override
  Future<Delivery> advance(String deliveryId, {String? deliveryCode}) async => Delivery.fromJson(
    await _api.post('/v1/courier/deliveries/$deliveryId/advance', body: {'deliveryCode': ?deliveryCode}) as _Json,
  );

  @override
  Stream<Delivery> watch(String deliveryId) async* {
    while (true) {
      final d = Delivery.fromJson(await _api.get('/v1/courier/deliveries/$deliveryId') as _Json);
      yield d;
      if (d.status == DeliveryStatus.entregue) return;
      await Future<void>.delayed(pollInterval);
    }
  }
}
