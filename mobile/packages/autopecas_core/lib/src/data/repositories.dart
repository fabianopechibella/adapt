import '../domain/account.dart';
import '../domain/agent.dart';
import '../domain/cart.dart';
import '../domain/delivery.dart';
import '../domain/offer.dart';
import '../domain/order.dart';
import '../domain/part.dart';
import '../domain/vehicle.dart';

/// Erro de negócio ou de rede já traduzido para uma mensagem exibível.
class AppException implements Exception {
  const AppException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

abstract interface class AuthRepository {
  /// Envia o código de acesso por SMS/WhatsApp para o telefone cadastrado.
  Future<void> requestCode({required String login, required String phone});
  Future<Session> verifyCode({required String login, required String code});
}

abstract interface class AccountRepository {
  Future<WorkshopAccount> me();
}

abstract interface class CatalogRepository {
  Future<Vehicle> lookupPlate(String plate);
  Future<List<FitmentMatch>> searchCompatible({required String vehicleId, required String query});
}

abstract interface class OfferRepository {
  Future<List<Offer>> quote({required String partId, String? vehicleId});
}

class PlaceOrderRequest {
  const PlaceOrderRequest({required this.cart, required this.paymentMethod, required this.idempotencyKey});

  final Cart cart;
  final PaymentMethod paymentMethod;

  /// Mesma chave em retentativas = mesmo pedido (evita pedido duplicado em rede ruim).
  final String idempotencyKey;

  Map<String, dynamic> toJson() => {
    'paymentMethod': paymentMethod.name,
    'lines': [
      for (final l in cart.lines)
        {
          'offerId': l.offer.id,
          'partId': l.part.id,
          'quantity': l.quantity,
          if (l.vehicleId != null) 'vehicleId': l.vehicleId,
        },
    ],
  };
}

abstract interface class OrderRepository {
  Future<Order> placeOrder(PlaceOrderRequest request);
  Future<List<Order>> listOrders();
  Stream<Order> watchOrder(String orderId);
  Future<Order> requestReturn({required String subOrderId, required ReturnReason reason, String? note});
}

abstract interface class AgentRepository {
  Future<AgentReply> send({required String conversationId, required String text});
}

abstract interface class DeliveryRepository {
  Future<List<Delivery>> available();
  Future<Delivery?> current();
  Future<Delivery> accept(String deliveryId);
  Future<Delivery> advance(String deliveryId, {String? deliveryCode});
  Stream<Delivery> watch(String deliveryId);
}

/// Tudo de que o app da oficina precisa, injetado de uma vez.
class WorkshopBackend {
  const WorkshopBackend({
    required this.auth,
    required this.account,
    required this.catalog,
    required this.offers,
    required this.orders,
    required this.agent,
  });

  final AuthRepository auth;
  final AccountRepository account;
  final CatalogRepository catalog;
  final OfferRepository offers;
  final OrderRepository orders;
  final AgentRepository agent;
}

class CourierBackend {
  const CourierBackend({required this.auth, required this.deliveries});

  final AuthRepository auth;
  final DeliveryRepository deliveries;
}
