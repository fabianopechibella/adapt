/// Peça de catálogo com código OEM e equivalentes aftermarket.
class Part {
  const Part({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.oemCode,
    this.equivalentCodes = const [],
  });

  factory Part.fromJson(Map<String, dynamic> json) => Part(
    id: json['id'] as String,
    name: json['name'] as String,
    brand: json['brand'] as String,
    category: json['category'] as String,
    oemCode: json['oemCode'] as String,
    equivalentCodes: (json['equivalentCodes'] as List? ?? const []).cast<String>(),
  );

  final String id;
  final String name;
  final String brand;
  final String category;
  final String oemCode;
  final List<String> equivalentCodes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'category': category,
    'oemCode': oemCode,
    'equivalentCodes': equivalentCodes,
  };
}

/// Resultado do motor de fitment: a peça e o quanto o grafo de aplicação confia
/// que ela serve no veículo. O app nunca calcula compatibilidade; só exibe.
class FitmentMatch {
  const FitmentMatch({required this.part, required this.confidence, this.note});

  factory FitmentMatch.fromJson(Map<String, dynamic> json) => FitmentMatch(
    part: Part.fromJson(json['part'] as Map<String, dynamic>),
    confidence: (json['confidence'] as num).toDouble(),
    note: json['note'] as String?,
  );

  /// Abaixo deste valor o app pede confirmação extra antes de vender.
  static const confirmationThreshold = 0.85;

  final Part part;
  final double confidence;
  final String? note;

  bool get needsConfirmation => confidence < confirmationThreshold;

  Map<String, dynamic> toJson() => {'part': part.toJson(), 'confidence': confidence, if (note != null) 'note': note};
}
