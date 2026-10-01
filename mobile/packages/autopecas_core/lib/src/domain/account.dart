import 'money.dart';

class Session {
  const Session({required this.token, required this.subjectId, required this.displayName});

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    token: json['token'] as String,
    subjectId: json['subjectId'] as String,
    displayName: json['displayName'] as String,
  );

  final String token;
  final String subjectId;
  final String displayName;
}

/// Conta B2B da oficina: CNPJ, endereço de entrega e limite para compra faturada.
class WorkshopAccount {
  const WorkshopAccount({
    required this.id,
    required this.cnpj,
    required this.tradeName,
    required this.address,
    required this.creditLimit,
    required this.creditUsed,
  });

  factory WorkshopAccount.fromJson(Map<String, dynamic> json) => WorkshopAccount(
    id: json['id'] as String,
    cnpj: json['cnpj'] as String,
    tradeName: json['tradeName'] as String,
    address: json['address'] as String,
    creditLimit: Money.fromJson(json['creditLimitCents']),
    creditUsed: Money.fromJson(json['creditUsedCents']),
  );

  final String id;
  final String cnpj;
  final String tradeName;
  final String address;
  final Money creditLimit;
  final Money creditUsed;

  Money get creditAvailable => creditLimit - creditUsed;

  bool canInvoice(Money amount) => creditLimit.cents > 0 && amount <= creditAvailable;
}
