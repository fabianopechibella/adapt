import 'dart:async';
import 'dart:math';

import '../../domain/account.dart';
import '../../domain/money.dart';
import '../../domain/offer.dart';
import '../../domain/order.dart';
import '../../domain/part.dart';
import '../../domain/validators.dart';
import '../../domain/vehicle.dart';
import '../repositories.dart';
import 'fake_agent.dart';
import 'seed.dart';

/// Backend em memória para desenvolvimento, demonstração e testes.
///
/// Simula a saga do pedido avançando os subpedidos a cada [tick]. Com
/// `tick: null` o avanço é manual via [advanceOrder] (útil em testes).
class FakeWorkshopBackend
    implements AuthRepository, AccountRepository, CatalogRepository, OfferRepository, OrderRepository {
  FakeWorkshopBackend({
    this.latency = const Duration(milliseconds: 350),
    Duration? tick = const Duration(seconds: 4),
    Random? random,
    DateTime Function()? clock,
  }) : _random = random ?? Random(),
       _clock = clock ?? DateTime.now {
    if (tick != null) _timer = Timer.periodic(tick, (_) => _advanceAll());
  }

  static const demoCode = '123456';

  final Duration latency;
  final Random _random;
  final DateTime Function() _clock;
  Timer? _timer;

  final _orders = <String, Order>{};
  final _idempotency = <String, String>{};
  final _controllers = <String, StreamController<Order>>{};
  var _sequence = 1000;
  var _creditUsed = const Money(125000);
  String? _pendingLogin;

  WorkshopBackend asBackend() => WorkshopBackend(
    auth: this,
    account: this,
    catalog: this,
    offers: this,
    orders: this,
    agent: FakeAgent(catalog: this, offers: this, latency: latency),
  );

  void dispose() {
    _timer?.cancel();
    for (final c in _controllers.values) {
      c.close();
    }
  }

  Future<void> _wait() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  // ---------------------------------------------------------------- Auth

  @override
  Future<void> requestCode({required String login, required String phone}) async {
    await _wait();
    if (!Cnpj.isValid(login)) throw const AppException('CNPJ inválido. Confira os dígitos.', code: 'invalid_cnpj');
    if (phone.replaceAll(RegExp(r'\D'), '').length < 10) {
      throw const AppException('Informe o celular com DDD.', code: 'invalid_phone');
    }
    _pendingLogin = Cnpj.normalize(login);
  }

  @override
  Future<Session> verifyCode({required String login, required String code}) async {
    await _wait();
    if (_pendingLogin != Cnpj.normalize(login) || code != demoCode) {
      throw const AppException('Código incorreto ou expirado.', code: 'invalid_code');
    }
    return const Session(token: 'demo-token', subjectId: 'w-1', displayName: 'Oficina Boa Vista');
  }

  // ---------------------------------------------------------------- Conta

  @override
  Future<WorkshopAccount> me() async {
    await _wait();
    return WorkshopAccount(
      id: 'w-1',
      cnpj: '11.222.333/0001-81',
      tradeName: 'Oficina Boa Vista',
      address: 'Rua das Oficinas, 120 · São Paulo/SP',
      creditLimit: const Money(500000),
      creditUsed: _creditUsed,
    );
  }

  // ---------------------------------------------------------------- Catálogo

  @override
  Future<Vehicle> lookupPlate(String plate) async {
    await _wait();
    final parsed = Plate.tryParse(plate);
    if (parsed == null) throw const AppException('Placa em formato inválido.', code: 'invalid_plate');
    return seedVehicles.firstWhere(
      (v) => v.plate == parsed.value,
      orElse: () => throw const AppException(
        'Não encontramos essa placa. Confira ou selecione o veículo manualmente.',
        code: 'plate_not_found',
      ),
    );
  }

  @override
  Future<List<FitmentMatch>> searchCompatible({required String vehicleId, required String query}) async {
    await _wait();
    final q = query.trim().toLowerCase();
    String code(String raw) => raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final tokens = {code(q), ...q.split(RegExp(r'\s+')).map(code)}..removeWhere((t) => t.length < 4);
    final results = <FitmentMatch>[];

    for (final seed in seedParts) {
      final fits = seed.fits.contains(vehicleId);
      final partial = seed.partialFits.contains(vehicleId);
      if (!fits && !partial) continue;

      final codes = [seed.part.oemCode, ...seed.part.equivalentCodes].map(code).toSet();
      final byCode = tokens.any(codes.contains);
      final byText = q.isEmpty || seed.keywords.any((k) => q.contains(k) || (q.length >= 4 && k.contains(q)));
      if (!byCode && !byText) continue;

      if (byCode) {
        results.add(FitmentMatch(part: seed.part, confidence: 0.99, note: 'Confirmado pelo código da peça.'));
      } else if (fits) {
        results.add(FitmentMatch(part: seed.part, confidence: 0.97));
      } else {
        results.add(
          FitmentMatch(
            part: seed.part,
            confidence: 0.62,
            note: 'Aplicação inferida pela família do motor. Confirme o código da peça antiga.',
          ),
        );
      }
    }
    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results;
  }

  @override
  Future<List<Offer>> quote({required String partId, String? vehicleId}) async {
    await _wait();
    return seedOffersFor(partId);
  }

  // ---------------------------------------------------------------- Pedidos

  @override
  Future<Order> placeOrder(PlaceOrderRequest request) async {
    await _wait();
    final existing = _idempotency[request.idempotencyKey];
    if (existing != null) return _orders[existing]!;
    if (request.cart.isEmpty) throw const AppException('O carrinho está vazio.');

    if (request.paymentMethod == PaymentMethod.faturado) {
      final account = await me();
      if (!account.canInvoice(request.cart.total)) {
        throw const AppException('Limite de crédito insuficiente para faturar este pedido.', code: 'credit_denied');
      }
      _creditUsed += request.cart.total;
    }

    final now = _clock();
    final id = 'PED-${_sequence++}';
    final subOrders = <SubOrder>[];
    var index = 1;
    for (final entry in request.cart.byDistributor.entries) {
      final lines = entry.value;
      final eta = lines.map((l) => l.offer.etaMinutes).reduce(max);
      subOrders.add(
        SubOrder(
          id: '$id-${index++}',
          distributorName: entry.key,
          lines: [
            for (final l in lines)
              OrderLine(
                partId: l.part.id,
                partName: '${l.part.name} ${l.part.brand}',
                quantity: l.quantity,
                unitPrice: l.offer.price,
              ),
          ],
          history: [StatusEvent(OrderStatus.criado, now)],
          promisedAt: now.add(Duration(minutes: eta)),
          deliveryCode: (1000 + _random.nextInt(9000)).toString(),
        ),
      );
    }
    final order = Order(id: id, createdAt: now, paymentMethod: request.paymentMethod, subOrders: subOrders);
    _orders[id] = order;
    _idempotency[request.idempotencyKey] = id;
    return order;
  }

  @override
  Future<List<Order>> listOrders() async {
    await _wait();
    return _orders.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Stream<Order> watchOrder(String orderId) async* {
    final order = _orders[orderId];
    if (order == null) throw const AppException('Pedido não encontrado.');
    yield order;
    yield* _controllerFor(orderId).stream;
  }

  @override
  Future<Order> requestReturn({required String subOrderId, required ReturnReason reason, String? note}) async {
    await _wait();
    final order = _orders.values.firstWhere(
      (o) => o.subOrders.any((s) => s.id == subOrderId),
      orElse: () => throw const AppException('Subpedido não encontrado.'),
    );
    final sub = order.subOrders.firstWhere((s) => s.id == subOrderId);
    if (!sub.status.canRequestReturn) {
      throw const AppException('A devolução só pode ser aberta depois da entrega.');
    }
    final text = note == null || note.isEmpty ? reason.label : '${reason.label}: $note';
    return _save(order.copyWithSubOrder(sub.transition(OrderStatus.devolucaoSolicitada, _clock(), note: text)));
  }

  /// Avança cada subpedido não terminal um passo na saga.
  void advanceOrder(String orderId) {
    final order = _orders[orderId];
    if (order == null) return;
    var updated = order;
    for (final sub in order.subOrders) {
      final next = _nextFor(sub);
      if (next == null) continue;
      updated = updated.copyWithSubOrder(
        sub.transition(
          next,
          _clock(),
          nfeKey: next == OrderStatus.nfeAutorizada ? _nfeKey() : null,
          courierName: next == OrderStatus.coletado ? 'Carlos (moto)' : null,
          note: switch (next) {
            OrderStatus.nfeRejeitada => 'SEFAZ rejeitou: corrigindo NCM e reemitindo.',
            OrderStatus.devolvido => 'Crédito gerado para a oficina.',
            _ => null,
          },
        ),
      );
    }
    if (!identical(updated, order)) _save(updated);
  }

  /// Caminho feliz, com uma compensação determinística para demonstrar a saga:
  /// a primeira NF-e do distribuidor "Auto Norte" é rejeitada e reemitida.
  OrderStatus? _nextFor(SubOrder sub) {
    final status = sub.status;
    if (status == OrderStatus.entregue) return null;
    if (status == OrderStatus.emSeparacao &&
        sub.distributorName.startsWith('Auto Norte') &&
        !sub.history.any((e) => e.status == OrderStatus.nfeRejeitada)) {
      return OrderStatus.nfeRejeitada;
    }
    return status.nextHappy;
  }

  void _advanceAll() {
    for (final id in _orders.keys.toList()) {
      advanceOrder(id);
    }
  }

  Order _save(Order order) {
    _orders[order.id] = order;
    _controllerFor(order.id).add(order);
    return order;
  }

  StreamController<Order> _controllerFor(String id) => _controllers.putIfAbsent(id, StreamController<Order>.broadcast);

  String _nfeKey() => List.generate(44, (_) => _random.nextInt(10)).join();
}
