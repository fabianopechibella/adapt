import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter_test/flutter_test.dart';

Offer offer(String id, {required int price, required int eta, double reliability = 0.9, int stock = 5}) => Offer(
  id: id,
  partId: 'p1',
  distributorId: 'd-$id',
  distributorName: 'Dist $id',
  price: Money(price),
  stock: stock,
  etaMinutes: eta,
  reliability: reliability,
);

const part = Part(id: 'p1', name: 'Pastilha', brand: 'X', category: 'Freios', oemCode: '123');

void main() {
  group('rankOffers', () {
    test('ignora sem estoque e marca mais barato, mais rápido e recomendado', () {
      final ranked = rankOffers([
        offer('barata', price: 10000, eta: 90),
        offer('rapida', price: 12000, eta: 20),
        offer('equilibrada', price: 10500, eta: 30, reliability: 0.98),
        offer('sem-estoque', price: 1000, eta: 10, stock: 0),
      ]);

      expect(ranked.map((r) => r.offer.id), isNot(contains('sem-estoque')));
      expect(ranked.first.offer.id, 'equilibrada');
      expect(ranked.first.badges, contains(OfferBadge.recomendado));
      expect(ranked.firstWhere((r) => r.offer.id == 'barata').badges, contains(OfferBadge.maisBarato));
      expect(ranked.firstWhere((r) => r.offer.id == 'rapida').badges, contains(OfferBadge.maisRapido));
    });

    test('peso só em preço escolhe a mais barata', () {
      final ranked = rankOffers([
        offer('a', price: 9000, eta: 90),
        offer('b', price: 12000, eta: 10),
      ], weights: const RankingWeights(price: 1, eta: 0, reliability: 0));
      expect(ranked.first.offer.id, 'a');
    });

    test('lista vazia ou tudo sem estoque devolve vazio', () {
      expect(rankOffers([]), isEmpty);
      expect(rankOffers([offer('x', price: 1, eta: 1, stock: 0)]), isEmpty);
    });
  });

  group('Cart', () {
    test('soma quantidade da mesma oferta e respeita o estoque', () {
      final o = offer('a', price: 1000, eta: 30, stock: 3);
      final cart = const Cart().add(part, o).add(part, o, quantity: 5);
      expect(cart.lines.single.quantity, 3);
      expect(cart.total, const Money(3000));
    });

    test('agrupa por distribuidor e usa o prazo do subpedido mais lento', () {
      final cart = const Cart().add(part, offer('a', price: 1000, eta: 30)).add(part, offer('b', price: 2000, eta: 75));
      expect(cart.byDistributor.keys, ['Dist a', 'Dist b']);
      expect(cart.etaMinutes, 75);
    });

    test('quantidade zero remove a linha', () {
      final o = offer('a', price: 1000, eta: 30);
      expect(const Cart().add(part, o).setQuantity(o.id, 0).isEmpty, isTrue);
    });
  });
}
