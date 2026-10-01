import 'money.dart';
import 'offer.dart';
import 'part.dart';

class CartLine {
  const CartLine({required this.part, required this.offer, required this.quantity, this.vehicleId});

  final Part part;
  final Offer offer;
  final int quantity;

  /// Veículo para o qual a peça foi buscada; vai no pedido para auditoria de fitment.
  final String? vehicleId;

  Money get total => offer.price * quantity;

  CartLine copyWith({int? quantity}) =>
      CartLine(part: part, offer: offer, quantity: quantity ?? this.quantity, vehicleId: vehicleId);
}

/// Carrinho multifornecedor. Cada distribuidor vira um subpedido com saga própria.
class Cart {
  const Cart([this.lines = const []]);

  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;
  int get itemCount => lines.fold(0, (sum, l) => sum + l.quantity);
  Money get total => lines.fold(Money.zero, (sum, l) => sum + l.total);

  /// Prazo do pedido = o subpedido mais lento.
  int get etaMinutes => lines.isEmpty ? 0 : lines.map((l) => l.offer.etaMinutes).reduce((a, b) => a > b ? a : b);

  Map<String, List<CartLine>> get byDistributor {
    final groups = <String, List<CartLine>>{};
    for (final line in lines) {
      groups.putIfAbsent(line.offer.distributorName, () => []).add(line);
    }
    return groups;
  }

  /// Adiciona respeitando o estoque da oferta; a mesma oferta soma quantidade.
  Cart add(Part part, Offer offer, {int quantity = 1, String? vehicleId}) {
    final index = lines.indexWhere((l) => l.offer.id == offer.id);
    if (index == -1) {
      final q = quantity.clamp(1, offer.stock);
      return Cart([...lines, CartLine(part: part, offer: offer, quantity: q, vehicleId: vehicleId)]);
    }
    return setQuantity(offer.id, lines[index].quantity + quantity);
  }

  /// Quantidade zero remove a linha; acima do estoque é limitada ao estoque.
  Cart setQuantity(String offerId, int quantity) {
    if (quantity <= 0) return remove(offerId);
    return Cart([
      for (final l in lines) l.offer.id == offerId ? l.copyWith(quantity: quantity.clamp(1, l.offer.stock)) : l,
    ]);
  }

  Cart remove(String offerId) => Cart(lines.where((l) => l.offer.id != offerId).toList());
}
