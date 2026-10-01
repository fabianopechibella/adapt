import 'dart:async';

import '../../domain/account.dart';
import '../../domain/delivery.dart';
import '../../domain/money.dart';
import '../repositories.dart';

/// Backend em memória do app do entregador.
///
/// Uma das corridas começa com a NF-e pendente e é autorizada depois de
/// [nfeDelay], para exercitar a regra "nada sai sem nota".
class FakeCourierBackend implements AuthRepository, DeliveryRepository {
  FakeCourierBackend({this.latency = const Duration(milliseconds: 300), this.nfeDelay = const Duration(seconds: 8)});

  static const demoCode = '123456';

  /// Código que a oficina informa na entrega (no app real vem do pedido da oficina).
  static const demoDeliveryCode = '2468';

  final Duration latency;
  final Duration? nfeDelay;
  final _controllers = <String, StreamController<Delivery>>{};
  final _timers = <Timer>[];
  String? _currentId;

  final _deliveries = <String, Delivery>{
    for (final d in const [
      Delivery(
        id: 'c-101',
        subOrderId: 'PED-0981-1',
        distributorName: 'Distribuidora Centro Peças',
        pickupAddress: 'Av. do Estado, 4500 · Cambuci',
        workshopName: 'Oficina Boa Vista',
        dropoffAddress: 'Rua das Oficinas, 120 · Vila Mariana',
        distanceKm: 4.2,
        fee: Money(1890),
        vehicleType: VehicleType.moto,
        itemsSummary: '1 kit de embreagem',
        status: DeliveryStatus.disponivel,
        nfeAuthorized: false,
      ),
      Delivery(
        id: 'c-102',
        subOrderId: 'PED-0982-1',
        distributorName: 'Express Autopeças',
        pickupAddress: 'Rua Vergueiro, 2100 · Paraíso',
        workshopName: 'Mecânica Irmãos Silva',
        dropoffAddress: 'Rua Domingos de Morais, 870 · Vila Mariana',
        distanceKm: 2.1,
        fee: Money(1290),
        vehicleType: VehicleType.moto,
        itemsSummary: '2 pastilhas de freio, 1 filtro de óleo',
        status: DeliveryStatus.disponivel,
        nfeAuthorized: true,
      ),
      Delivery(
        id: 'c-103',
        subOrderId: 'PED-0983-2',
        distributorName: 'Auto Norte Atacado',
        pickupAddress: 'Av. Cruzeiro do Sul, 1800 · Santana',
        workshopName: 'Auto Center Zona Sul',
        dropoffAddress: 'Av. Interlagos, 3200 · Interlagos',
        distanceKm: 23.5,
        fee: Money(5490),
        vehicleType: VehicleType.utilitario,
        itemsSummary: '2 amortecedores, 1 bateria 60Ah',
        status: DeliveryStatus.disponivel,
        nfeAuthorized: true,
      ),
    ])
      d.id: d,
  };

  CourierBackend asBackend() => CourierBackend(auth: this, deliveries: this);

  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    for (final c in _controllers.values) {
      c.close();
    }
  }

  Future<void> _wait() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  @override
  Future<void> requestCode({required String login, required String phone}) async {
    await _wait();
    if (login.replaceAll(RegExp(r'\D'), '').length != 11) {
      throw const AppException('Informe o CPF com 11 dígitos.');
    }
  }

  @override
  Future<Session> verifyCode({required String login, required String code}) async {
    await _wait();
    if (code != demoCode) throw const AppException('Código incorreto ou expirado.');
    return const Session(token: 'demo-courier', subjectId: 'e-7', displayName: 'Carlos');
  }

  @override
  Future<List<Delivery>> available() async {
    await _wait();
    return _deliveries.values.where((d) => d.status == DeliveryStatus.disponivel).toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  }

  @override
  Future<Delivery?> current() async {
    await _wait();
    final id = _currentId;
    if (id == null) return null;
    final d = _deliveries[id]!;
    return d.status == DeliveryStatus.entregue ? null : d;
  }

  @override
  Future<Delivery> accept(String deliveryId) async {
    await _wait();
    if (_currentId != null && _deliveries[_currentId]!.status != DeliveryStatus.entregue) {
      throw const AppException('Finalize a corrida atual antes de aceitar outra.');
    }
    final d = _get(deliveryId);
    if (d.status != DeliveryStatus.disponivel) throw const AppException('Esta corrida já foi aceita.');
    _currentId = deliveryId;
    final accepted = _save(d.advance());
    final delay = nfeDelay;
    if (!accepted.nfeAuthorized && delay != null) {
      _timers.add(Timer(delay, () => authorizeNfe(deliveryId)));
    }
    return accepted;
  }

  @override
  Future<Delivery> advance(String deliveryId, {String? deliveryCode}) async {
    await _wait();
    try {
      return _save(_get(deliveryId).advance(deliveryCode: deliveryCode, expectedCode: demoDeliveryCode));
    } on DeliveryRuleViolation catch (e) {
      throw AppException(e.message);
    }
  }

  @override
  Stream<Delivery> watch(String deliveryId) async* {
    yield _get(deliveryId);
    yield* _controllerFor(deliveryId).stream;
  }

  /// Simula o evento `NotaFiscalAutorizada` vindo da saga.
  void authorizeNfe(String deliveryId) => _save(_get(deliveryId).copyWith(nfeAuthorized: true));

  Delivery _get(String id) => _deliveries[id] ?? (throw const AppException('Corrida não encontrada.'));

  Delivery _save(Delivery d) {
    _deliveries[d.id] = d;
    _controllerFor(d.id).add(d);
    return d;
  }

  StreamController<Delivery> _controllerFor(String id) =>
      _controllers.putIfAbsent(id, StreamController<Delivery>.broadcast);
}
