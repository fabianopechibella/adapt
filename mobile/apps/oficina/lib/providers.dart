import 'dart:math';

import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final configProvider = Provider<AppConfig>((ref) => throw UnimplementedError('override no main'));
final backendProvider = Provider<WorkshopBackend>((ref) => throw UnimplementedError('override no main'));
final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

/// Guarda o token em memória para o [ApiClient]. Persistir com armazenamento
/// seguro (Keychain/Keystore) é o próximo passo antes de ir para produção.
class TokenStore {
  String? token;
}

class SessionController extends Notifier<Session?> {
  @override
  Session? build() => null;

  void signIn(Session session) {
    ref.read(tokenStoreProvider).token = session.token;
    state = session;
  }

  void signOut() {
    ref.read(tokenStoreProvider).token = null;
    ref.read(cartProvider.notifier).clear();
    ref.read(vehicleProvider.notifier).clear();
    state = null;
  }
}

final sessionProvider = NotifierProvider<SessionController, Session?>(SessionController.new);

class VehicleController extends Notifier<Vehicle?> {
  @override
  Vehicle? build() => null;

  void select(Vehicle vehicle) => state = vehicle;
  void clear() => state = null;
}

final vehicleProvider = NotifierProvider<VehicleController, Vehicle?>(VehicleController.new);

class CartController extends Notifier<Cart> {
  @override
  Cart build() => const Cart();

  void add(Part part, Offer offer, {String? vehicleId}) => state = state.add(part, offer, vehicleId: vehicleId);
  void setQuantity(String offerId, int quantity) => state = state.setQuantity(offerId, quantity);
  void remove(String offerId) => state = state.remove(offerId);
  void clear() => state = const Cart();
}

final cartProvider = NotifierProvider<CartController, Cart>(CartController.new);

final accountProvider = FutureProvider.autoDispose<WorkshopAccount>((ref) => ref.watch(backendProvider).account.me());

typedef SearchQuery = ({String vehicleId, String query});

final searchProvider = FutureProvider.autoDispose.family<List<FitmentMatch>, SearchQuery>(
  (ref, q) => ref.watch(backendProvider).catalog.searchCompatible(vehicleId: q.vehicleId, query: q.query),
);

typedef OfferQuery = ({String partId, String? vehicleId});

final offersProvider = FutureProvider.autoDispose.family<List<RankedOffer>, OfferQuery>((ref, q) async {
  final offers = await ref.watch(backendProvider).offers.quote(partId: q.partId, vehicleId: q.vehicleId);
  return rankOffers(offers);
});

final ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) => ref.watch(backendProvider).orders.listOrders());

final orderProvider = StreamProvider.autoDispose.family<Order, String>(
  (ref, id) => ref.watch(backendProvider).orders.watchOrder(id),
);

String newIdempotencyKey() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}
