import 'money.dart';

/// Oferta de um distribuidor para uma peça: preço por cliente, estoque e prazo prometido.
class Offer {
  const Offer({
    required this.id,
    required this.partId,
    required this.distributorId,
    required this.distributorName,
    required this.price,
    required this.stock,
    required this.etaMinutes,
    required this.reliability,
  });

  factory Offer.fromJson(Map<String, dynamic> json) => Offer(
    id: json['id'] as String,
    partId: json['partId'] as String,
    distributorId: json['distributorId'] as String,
    distributorName: json['distributorName'] as String,
    price: Money.fromJson(json['priceCents']),
    stock: json['stock'] as int,
    etaMinutes: json['etaMinutes'] as int,
    reliability: (json['reliability'] as num).toDouble(),
  );

  final String id;
  final String partId;
  final String distributorId;
  final String distributorName;
  final Money price;
  final int stock;

  /// Prazo prometido da reserva até a entrega na oficina.
  final int etaMinutes;

  /// Nota de 0 a 1: aceite, acerto de estoque e prazo cumprido do distribuidor.
  final double reliability;

  bool get available => stock > 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'partId': partId,
    'distributorId': distributorId,
    'distributorName': distributorName,
    'priceCents': price.cents,
    'stock': stock,
    'etaMinutes': etaMinutes,
    'reliability': reliability,
  };
}

enum OfferBadge { recomendado, maisBarato, maisRapido }

extension OfferBadgeLabel on OfferBadge {
  String get label => switch (this) {
    OfferBadge.recomendado => 'Recomendado',
    OfferBadge.maisBarato => 'Mais barato',
    OfferBadge.maisRapido => 'Mais rápido',
  };
}

class RankedOffer {
  const RankedOffer({required this.offer, required this.score, this.badges = const {}});

  final Offer offer;

  /// Menor é melhor.
  final double score;
  final Set<OfferBadge> badges;
}

/// Pesos do ranking preço × prazo × confiabilidade. Para a oficina, prazo
/// costuma valer tanto quanto preço: o carro parado no elevador custa dinheiro.
class RankingWeights {
  const RankingWeights({this.price = 0.4, this.eta = 0.4, this.reliability = 0.2});

  final double price;
  final double eta;
  final double reliability;
}

/// Ordena ofertas disponíveis por pontuação normalizada (min-max) e marca destaques.
List<RankedOffer> rankOffers(List<Offer> offers, {RankingWeights weights = const RankingWeights()}) {
  final available = offers.where((o) => o.available).toList();
  if (available.isEmpty) return const [];

  double norm(num value, num min, num max) => max == min ? 0 : (value - min) / (max - min);

  final prices = available.map((o) => o.price.cents);
  final etas = available.map((o) => o.etaMinutes);
  final minPrice = prices.reduce((a, b) => a < b ? a : b);
  final maxPrice = prices.reduce((a, b) => a > b ? a : b);
  final minEta = etas.reduce((a, b) => a < b ? a : b);
  final maxEta = etas.reduce((a, b) => a > b ? a : b);

  final ranked =
      available
          .map(
            (o) => (
              offer: o,
              score:
                  weights.price * norm(o.price.cents, minPrice, maxPrice) +
                  weights.eta * norm(o.etaMinutes, minEta, maxEta) +
                  weights.reliability * (1 - o.reliability.clamp(0.0, 1.0)),
            ),
          )
          .toList()
        ..sort((a, b) {
          final byScore = a.score.compareTo(b.score);
          return byScore != 0 ? byScore : a.offer.price.compareTo(b.offer.price);
        });

  final cheapest = available.reduce((a, b) => a.price <= b.price ? a : b);
  final fastest = available.reduce((a, b) => a.etaMinutes <= b.etaMinutes ? a : b);

  return [
    for (var i = 0; i < ranked.length; i++)
      RankedOffer(
        offer: ranked[i].offer,
        score: ranked[i].score,
        badges: {
          if (i == 0) OfferBadge.recomendado,
          if (identical(ranked[i].offer, cheapest)) OfferBadge.maisBarato,
          if (identical(ranked[i].offer, fastest)) OfferBadge.maisRapido,
        },
      ),
  ];
}
