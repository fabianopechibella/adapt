import 'package:intl/intl.dart';

/// Valor monetário em centavos de real. Evita erro de arredondamento de double.
class Money implements Comparable<Money> {
  const Money(this.cents);

  factory Money.fromJson(Object? json) => Money((json as num).toInt());

  static const zero = Money(0);

  final int cents;

  static final _format = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

  Money operator +(Money other) => Money(cents + other.cents);
  Money operator -(Money other) => Money(cents - other.cents);
  Money operator *(int factor) => Money(cents * factor);

  bool operator >(Money other) => cents > other.cents;
  bool operator <(Money other) => cents < other.cents;
  bool operator >=(Money other) => cents >= other.cents;
  bool operator <=(Money other) => cents <= other.cents;

  String format() => _format.format(cents / 100);

  int toJson() => cents;

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  @override
  bool operator ==(Object other) => other is Money && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  @override
  String toString() => format();
}
