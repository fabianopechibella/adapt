import 'money.dart';

enum VehicleType { moto, carro, utilitario }

extension VehicleTypeLabel on VehicleType {
  String get label => switch (this) {
    VehicleType.moto => 'Moto',
    VehicleType.carro => 'Carro',
    VehicleType.utilitario => 'Utilitário',
  };
}

/// Etapas da corrida do ponto de vista do entregador.
enum DeliveryStatus { disponivel, aceita, noDistribuidor, coletada, emRota, entregue }

extension DeliveryStatusRules on DeliveryStatus {
  String get label => switch (this) {
    DeliveryStatus.disponivel => 'Disponível',
    DeliveryStatus.aceita => 'A caminho do distribuidor',
    DeliveryStatus.noDistribuidor => 'No distribuidor',
    DeliveryStatus.coletada => 'Coletada',
    DeliveryStatus.emRota => 'A caminho da oficina',
    DeliveryStatus.entregue => 'Entregue',
  };

  DeliveryStatus? get next {
    final i = DeliveryStatus.values.indexOf(this);
    return i < DeliveryStatus.values.length - 1 ? DeliveryStatus.values[i + 1] : null;
  }

  /// Texto do botão de ação principal em cada etapa.
  String? get actionLabel => switch (this) {
    DeliveryStatus.disponivel => 'Aceitar corrida',
    DeliveryStatus.aceita => 'Cheguei no distribuidor',
    DeliveryStatus.noDistribuidor => 'Confirmar coleta',
    DeliveryStatus.coletada => 'Iniciar rota',
    DeliveryStatus.emRota => 'Confirmar entrega',
    DeliveryStatus.entregue => null,
  };
}

class DeliveryRuleViolation implements Exception {
  DeliveryRuleViolation(this.message);
  final String message;
  @override
  String toString() => message;
}

class Delivery {
  const Delivery({
    required this.id,
    required this.subOrderId,
    required this.distributorName,
    required this.pickupAddress,
    required this.workshopName,
    required this.dropoffAddress,
    required this.distanceKm,
    required this.fee,
    required this.vehicleType,
    required this.itemsSummary,
    required this.status,
    required this.nfeAuthorized,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) => Delivery(
    id: json['id'] as String,
    subOrderId: json['subOrderId'] as String,
    distributorName: json['distributorName'] as String,
    pickupAddress: json['pickupAddress'] as String,
    workshopName: json['workshopName'] as String,
    dropoffAddress: json['dropoffAddress'] as String,
    distanceKm: (json['distanceKm'] as num).toDouble(),
    fee: Money.fromJson(json['feeCents']),
    vehicleType: VehicleType.values.byName(json['vehicleType'] as String),
    itemsSummary: json['itemsSummary'] as String,
    status: DeliveryStatus.values.byName(json['status'] as String),
    nfeAuthorized: json['nfeAuthorized'] as bool,
  );

  final String id;
  final String subOrderId;
  final String distributorName;
  final String pickupAddress;
  final String workshopName;
  final String dropoffAddress;
  final double distanceKm;
  final Money fee;
  final VehicleType vehicleType;
  final String itemsSummary;
  final DeliveryStatus status;

  /// A mercadoria só pode sair do distribuidor com NF-e autorizada.
  final bool nfeAuthorized;

  /// Aplica as regras de negócio da próxima etapa e devolve a corrida atualizada.
  Delivery advance({String? deliveryCode, String? expectedCode}) {
    final target = status.next;
    if (target == null) throw DeliveryRuleViolation('A corrida já foi entregue.');
    if (target == DeliveryStatus.coletada && !nfeAuthorized) {
      throw DeliveryRuleViolation('Aguarde a NF-e ser autorizada antes de coletar.');
    }
    if (target == DeliveryStatus.entregue) {
      if (deliveryCode == null || deliveryCode.trim() != expectedCode) {
        throw DeliveryRuleViolation('Código de entrega inválido. Peça o código à oficina.');
      }
    }
    return copyWith(status: target);
  }

  Delivery copyWith({DeliveryStatus? status, bool? nfeAuthorized}) => Delivery(
    id: id,
    subOrderId: subOrderId,
    distributorName: distributorName,
    pickupAddress: pickupAddress,
    workshopName: workshopName,
    dropoffAddress: dropoffAddress,
    distanceKm: distanceKm,
    fee: fee,
    vehicleType: vehicleType,
    itemsSummary: itemsSummary,
    status: status ?? this.status,
    nfeAuthorized: nfeAuthorized ?? this.nfeAuthorized,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'subOrderId': subOrderId,
    'distributorName': distributorName,
    'pickupAddress': pickupAddress,
    'workshopName': workshopName,
    'dropoffAddress': dropoffAddress,
    'distanceKm': distanceKm,
    'feeCents': fee.cents,
    'vehicleType': vehicleType.name,
    'itemsSummary': itemsSummary,
    'status': status.name,
    'nfeAuthorized': nfeAuthorized,
  };
}
