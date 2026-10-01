/// Veículo normalizado a partir da placa (marca, modelo, ano, motorização, código FIPE).
class Vehicle {
  const Vehicle({
    required this.id,
    required this.plate,
    required this.brand,
    required this.model,
    required this.year,
    required this.engine,
    this.fipeCode,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
    id: json['id'] as String,
    plate: json['plate'] as String,
    brand: json['brand'] as String,
    model: json['model'] as String,
    year: json['year'] as int,
    engine: json['engine'] as String,
    fipeCode: json['fipeCode'] as String?,
  );

  final String id;
  final String plate;
  final String brand;
  final String model;
  final int year;
  final String engine;
  final String? fipeCode;

  String get title => '$brand $model $engine';
  String get subtitle => '$year · placa $plate';

  Map<String, dynamic> toJson() => {
    'id': id,
    'plate': plate,
    'brand': brand,
    'model': model,
    'year': year,
    'engine': engine,
    if (fipeCode != null) 'fipeCode': fipeCode,
  };
}
