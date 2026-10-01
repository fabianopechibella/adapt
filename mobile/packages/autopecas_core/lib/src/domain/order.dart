import 'money.dart';

/// Estados da saga do subpedido: caminho feliz + compensações.
/// Espelha o diagrama "Saga do pedido" do documento de arquitetura.
enum OrderStatus {
  criado,
  pagamentoAutorizado,
  estoqueReservado,
  aceitoPeloDistribuidor,
  emSeparacao,
  nfeAutorizada,
  coletado,
  emRota,
  entregue,
  // Compensações
  reofertando,
  nfeRejeitada,
  redespacho,
  devolucaoSolicitada,
  devolvido,
  cancelado,
}

const happyPath = [
  OrderStatus.criado,
  OrderStatus.pagamentoAutorizado,
  OrderStatus.estoqueReservado,
  OrderStatus.aceitoPeloDistribuidor,
  OrderStatus.emSeparacao,
  OrderStatus.nfeAutorizada,
  OrderStatus.coletado,
  OrderStatus.emRota,
  OrderStatus.entregue,
];

const _transitions = <OrderStatus, Set<OrderStatus>>{
  OrderStatus.criado: {OrderStatus.pagamentoAutorizado, OrderStatus.cancelado},
  OrderStatus.pagamentoAutorizado: {OrderStatus.estoqueReservado, OrderStatus.reofertando, OrderStatus.cancelado},
  OrderStatus.estoqueReservado: {OrderStatus.aceitoPeloDistribuidor, OrderStatus.reofertando},
  OrderStatus.aceitoPeloDistribuidor: {OrderStatus.emSeparacao, OrderStatus.reofertando},
  OrderStatus.reofertando: {OrderStatus.estoqueReservado, OrderStatus.cancelado},
  OrderStatus.emSeparacao: {OrderStatus.nfeAutorizada, OrderStatus.nfeRejeitada},
  OrderStatus.nfeRejeitada: {OrderStatus.nfeAutorizada, OrderStatus.cancelado},
  OrderStatus.nfeAutorizada: {OrderStatus.coletado, OrderStatus.redespacho},
  OrderStatus.redespacho: {OrderStatus.coletado},
  OrderStatus.coletado: {OrderStatus.emRota},
  OrderStatus.emRota: {OrderStatus.entregue, OrderStatus.redespacho},
  OrderStatus.entregue: {OrderStatus.devolucaoSolicitada},
  OrderStatus.devolucaoSolicitada: {OrderStatus.devolvido},
  OrderStatus.devolvido: {},
  OrderStatus.cancelado: {},
};

extension OrderStatusRules on OrderStatus {
  String get label => switch (this) {
    OrderStatus.criado => 'Pedido criado',
    OrderStatus.pagamentoAutorizado => 'Pagamento autorizado',
    OrderStatus.estoqueReservado => 'Estoque reservado',
    OrderStatus.aceitoPeloDistribuidor => 'Aceito pelo distribuidor',
    OrderStatus.emSeparacao => 'Em separação',
    OrderStatus.nfeAutorizada => 'NF-e autorizada',
    OrderStatus.coletado => 'Coletado',
    OrderStatus.emRota => 'Em rota',
    OrderStatus.entregue => 'Entregue',
    OrderStatus.reofertando => 'Buscando outro distribuidor',
    OrderStatus.nfeRejeitada => 'NF-e em correção',
    OrderStatus.redespacho => 'Trocando entregador',
    OrderStatus.devolucaoSolicitada => 'Devolução solicitada',
    OrderStatus.devolvido => 'Devolvido',
    OrderStatus.cancelado => 'Cancelado',
  };

  Set<OrderStatus> get next => _transitions[this]!;

  bool canTransitionTo(OrderStatus target) => next.contains(target);

  bool get isTerminal => next.isEmpty;

  bool get isCompensation => !happyPath.contains(this);

  bool get canRequestReturn => this == OrderStatus.entregue;

  /// Próximo passo do caminho feliz, se houver.
  OrderStatus? get nextHappy {
    final i = happyPath.indexOf(this);
    if (i >= 0 && i < happyPath.length - 1) return happyPath[i + 1];
    return switch (this) {
      OrderStatus.reofertando => OrderStatus.estoqueReservado,
      OrderStatus.nfeRejeitada => OrderStatus.nfeAutorizada,
      OrderStatus.redespacho => OrderStatus.coletado,
      OrderStatus.devolucaoSolicitada => OrderStatus.devolvido,
      _ => null,
    };
  }

  /// Posição na linha do tempo do caminho feliz (compensações herdam a etapa onde ocorrem).
  int get timelineIndex => switch (this) {
    OrderStatus.reofertando => happyPath.indexOf(OrderStatus.estoqueReservado),
    OrderStatus.nfeRejeitada => happyPath.indexOf(OrderStatus.nfeAutorizada),
    OrderStatus.redespacho => happyPath.indexOf(OrderStatus.coletado),
    OrderStatus.devolucaoSolicitada || OrderStatus.devolvido => happyPath.length - 1,
    OrderStatus.cancelado => -1,
    _ => happyPath.indexOf(this),
  };
}

class InvalidTransition implements Exception {
  InvalidTransition(this.from, this.to);
  final OrderStatus from;
  final OrderStatus to;
  @override
  String toString() => 'Transição inválida: ${from.name} → ${to.name}';
}

enum PaymentMethod { pix, cartao, faturado }

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
    PaymentMethod.pix => 'Pix',
    PaymentMethod.cartao => 'Cartão',
    PaymentMethod.faturado => 'Faturado (boleto 28 dias)',
  };
}

enum ReturnReason { pecaNaoServe, avaria, defeito, pedidoErrado }

extension ReturnReasonLabel on ReturnReason {
  String get label => switch (this) {
    ReturnReason.pecaNaoServe => 'A peça não serve no veículo',
    ReturnReason.avaria => 'Chegou avariada',
    ReturnReason.defeito => 'Defeito (garantia)',
    ReturnReason.pedidoErrado => 'Pedi errado',
  };
}

class StatusEvent {
  const StatusEvent(this.status, this.at, {this.note});

  factory StatusEvent.fromJson(Map<String, dynamic> json) => StatusEvent(
    OrderStatus.values.byName(json['status'] as String),
    DateTime.parse(json['at'] as String),
    note: json['note'] as String?,
  );

  final OrderStatus status;
  final DateTime at;
  final String? note;

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'at': at.toUtc().toIso8601String(),
    if (note != null) 'note': note,
  };
}

class OrderLine {
  const OrderLine({required this.partId, required this.partName, required this.quantity, required this.unitPrice});

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
    partId: json['partId'] as String,
    partName: json['partName'] as String,
    quantity: json['quantity'] as int,
    unitPrice: Money.fromJson(json['unitPriceCents']),
  );

  final String partId;
  final String partName;
  final int quantity;
  final Money unitPrice;

  Money get total => unitPrice * quantity;

  Map<String, dynamic> toJson() => {
    'partId': partId,
    'partName': partName,
    'quantity': quantity,
    'unitPriceCents': unitPrice.cents,
  };
}

/// Um subpedido por distribuidor, cada um com sua saga.
class SubOrder {
  const SubOrder({
    required this.id,
    required this.distributorName,
    required this.lines,
    required this.history,
    required this.promisedAt,
    required this.deliveryCode,
    this.nfeKey,
    this.courierName,
  });

  factory SubOrder.fromJson(Map<String, dynamic> json) => SubOrder(
    id: json['id'] as String,
    distributorName: json['distributorName'] as String,
    lines: (json['lines'] as List).map((e) => OrderLine.fromJson(e as Map<String, dynamic>)).toList(),
    history: (json['history'] as List).map((e) => StatusEvent.fromJson(e as Map<String, dynamic>)).toList(),
    promisedAt: DateTime.parse(json['promisedAt'] as String),
    deliveryCode: json['deliveryCode'] as String,
    nfeKey: json['nfeKey'] as String?,
    courierName: json['courierName'] as String?,
  );

  final String id;
  final String distributorName;
  final List<OrderLine> lines;
  final List<StatusEvent> history;
  final DateTime promisedAt;

  /// Código que a oficina informa ao entregador para confirmar a entrega.
  final String deliveryCode;

  /// Chave de acesso da NF-e (44 dígitos) depois de autorizada.
  final String? nfeKey;
  final String? courierName;

  OrderStatus get status => history.last.status;
  Money get total => lines.fold(Money.zero, (sum, l) => sum + l.total);

  /// Valida a transição pela máquina de estados antes de registrar.
  SubOrder transition(OrderStatus to, DateTime at, {String? note, String? nfeKey, String? courierName}) {
    if (!status.canTransitionTo(to)) throw InvalidTransition(status, to);
    return SubOrder(
      id: id,
      distributorName: distributorName,
      lines: lines,
      history: [
        ...history,
        StatusEvent(to, at, note: note),
      ],
      promisedAt: promisedAt,
      deliveryCode: deliveryCode,
      nfeKey: nfeKey ?? this.nfeKey,
      courierName: courierName ?? this.courierName,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'distributorName': distributorName,
    'lines': lines.map((l) => l.toJson()).toList(),
    'history': history.map((h) => h.toJson()).toList(),
    'promisedAt': promisedAt.toUtc().toIso8601String(),
    'deliveryCode': deliveryCode,
    if (nfeKey != null) 'nfeKey': nfeKey,
    if (courierName != null) 'courierName': courierName,
  };
}

class Order {
  const Order({required this.id, required this.createdAt, required this.paymentMethod, required this.subOrders});

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    paymentMethod: PaymentMethod.values.byName(json['paymentMethod'] as String),
    subOrders: (json['subOrders'] as List).map((e) => SubOrder.fromJson(e as Map<String, dynamic>)).toList(),
  );

  final String id;
  final DateTime createdAt;
  final PaymentMethod paymentMethod;
  final List<SubOrder> subOrders;

  Money get total => subOrders.fold(Money.zero, (sum, s) => sum + s.total);

  bool get isFinished => subOrders.every((s) => s.status.isTerminal || s.status == OrderStatus.entregue);

  /// Status de manchete: o subpedido mais atrasado na saga.
  OrderStatus get headline =>
      subOrders.map((s) => s.status).reduce((a, b) => a.timelineIndex <= b.timelineIndex ? a : b);

  Order copyWithSubOrder(SubOrder updated) => Order(
    id: id,
    createdAt: createdAt,
    paymentMethod: paymentMethod,
    subOrders: [for (final s in subOrders) s.id == updated.id ? updated : s],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'paymentMethod': paymentMethod.name,
    'subOrders': subOrders.map((s) => s.toJson()).toList(),
  };
}
