/// Placa de veículo brasileira: padrão antigo (ABC1234) ou Mercosul (ABC1D23).
class Plate {
  Plate._(this.value);

  static final _pattern = RegExp(r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$');

  /// Placa em texto livre, aceitando hífen ou espaço e minúsculas.
  static final loosePattern = RegExp(r'\b[A-Za-z]{3}[- ]?[0-9][A-Za-z0-9][0-9]{2}\b');

  /// Valor normalizado: maiúsculo, sem hífen nem espaços.
  final String value;

  static String normalize(String raw) => raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static bool isValid(String raw) => _pattern.hasMatch(normalize(raw));

  /// Retorna a placa normalizada ou `null` se o formato for inválido.
  static Plate? tryParse(String raw) {
    final normalized = normalize(raw);
    return _pattern.hasMatch(normalized) ? Plate._(normalized) : null;
  }

  /// Procura a primeira placa válida dentro de um texto livre.
  static Plate? findIn(String text) {
    final candidates = loosePattern.allMatches(text).map((m) => tryParse(m.group(0)!));
    return candidates.firstWhere((p) => p != null, orElse: () => null);
  }

  bool get isMercosul => RegExp(r'[A-Z]').hasMatch(value[4]);

  /// Formato de exibição: Mercosul sem hífen, antigo com hífen.
  String get display => isMercosul ? value : '${value.substring(0, 3)}-${value.substring(3)}';

  @override
  bool operator ==(Object other) => other is Plate && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => display;
}

/// CNPJ numérico e alfanumérico (IN RFB 2.229/2024, vigente a partir de julho de 2026).
///
/// Os 12 primeiros caracteres podem ser letras ou dígitos; os 2 últimos são
/// dígitos verificadores calculados com valor = código ASCII - 48.
class Cnpj {
  Cnpj._(this.value);

  final String value;

  static const _w1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  static const _w2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  static final _shape = RegExp(r'^[A-Z0-9]{12}[0-9]{2}$');

  static String normalize(String raw) => raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static int _digit(String base, List<int> weights) {
    var sum = 0;
    for (var i = 0; i < weights.length; i++) {
      sum += (base.codeUnitAt(i) - 48) * weights[i];
    }
    final rest = sum % 11;
    return rest < 2 ? 0 : 11 - rest;
  }

  static bool isValid(String raw) {
    final v = normalize(raw);
    if (!_shape.hasMatch(v)) return false;
    if (RegExp(r'^(\d)\1{13}$').hasMatch(v)) return false;
    final base = v.substring(0, 12);
    final d1 = _digit(base, _w1);
    final d2 = _digit('$base$d1', _w2);
    return v.substring(12) == '$d1$d2';
  }

  static Cnpj? tryParse(String raw) => isValid(raw) ? Cnpj._(normalize(raw)) : null;

  String get display =>
      '${value.substring(0, 2)}.${value.substring(2, 5)}.${value.substring(5, 8)}/'
      '${value.substring(8, 12)}-${value.substring(12)}';

  @override
  String toString() => display;
}
