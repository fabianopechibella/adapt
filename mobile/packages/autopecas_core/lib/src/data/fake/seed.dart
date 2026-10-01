import '../../domain/money.dart';
import '../../domain/offer.dart';
import '../../domain/part.dart';
import '../../domain/vehicle.dart';

/// Dados de demonstração. Valores ilustrativos, não são preços reais de mercado.
const seedVehicles = <Vehicle>[
  Vehicle(
    id: 'v-onix-19',
    plate: 'ABC1D23',
    brand: 'Chevrolet',
    model: 'Onix',
    year: 2019,
    engine: '1.0 Flex',
    fipeCode: '004457-0',
  ),
  Vehicle(
    id: 'v-hb20-20',
    plate: 'BRA2E19',
    brand: 'Hyundai',
    model: 'HB20',
    year: 2020,
    engine: '1.6 Flex',
    fipeCode: '015170-8',
  ),
  Vehicle(
    id: 'v-strada-21',
    plate: 'QWE4R56',
    brand: 'Fiat',
    model: 'Strada',
    year: 2021,
    engine: '1.4 Flex',
    fipeCode: '001503-0',
  ),
  Vehicle(
    id: 'v-gol-15',
    plate: 'KJH5544',
    brand: 'Volkswagen',
    model: 'Gol',
    year: 2015,
    engine: '1.0 Flex',
    fipeCode: '005340-4',
  ),
];

class SeedPart {
  const SeedPart(this.part, this.keywords, this.fits, {this.partialFits = const {}});

  final Part part;
  final List<String> keywords;

  /// Aplicação confirmada pelo catálogo técnico.
  final Set<String> fits;

  /// Aplicação inferida pela família do motor: exige confirmação.
  final Set<String> partialFits;
}

const seedParts = <SeedPart>[
  SeedPart(
    Part(
      id: 'p-emb-onix',
      name: 'Kit de embreagem',
      brand: 'LuK',
      category: 'Transmissão',
      oemCode: '52061543',
      equivalentCodes: ['620319200', 'SK-2215'],
    ),
    ['embreagem', 'kit embreagem', 'platô', 'plato', 'disco'],
    {'v-onix-19'},
  ),
  SeedPart(
    Part(
      id: 'p-emb-gol',
      name: 'Kit de embreagem',
      brand: 'Sachs',
      category: 'Transmissão',
      oemCode: '5U0198141',
      equivalentCodes: ['6553'],
    ),
    ['embreagem', 'kit embreagem', 'platô', 'plato', 'disco'],
    {'v-gol-15'},
  ),
  SeedPart(
    Part(
      id: 'p-pastilha-onix',
      name: 'Pastilha de freio dianteira',
      brand: 'Cobreq',
      category: 'Freios',
      oemCode: '52098519',
      equivalentCodes: ['N-1430', 'HQJ-2290'],
    ),
    ['pastilha', 'freio', 'freio dianteiro'],
    {'v-onix-19'},
    partialFits: {'v-gol-15'},
  ),
  SeedPart(
    Part(
      id: 'p-pastilha-hb20',
      name: 'Pastilha de freio dianteira',
      brand: 'Fras-le',
      category: 'Freios',
      oemCode: '58101-1RA00',
      equivalentCodes: ['PD/1531'],
    ),
    ['pastilha', 'freio', 'freio dianteiro'],
    {'v-hb20-20'},
  ),
  SeedPart(
    Part(
      id: 'p-filtro-oleo',
      name: 'Filtro de óleo',
      brand: 'Tecfil',
      category: 'Filtros',
      oemCode: '93185674',
      equivalentCodes: ['PSL-55', 'W 712/95'],
    ),
    ['filtro de óleo', 'filtro de oleo', 'filtro óleo', 'filtro', 'troca de óleo'],
    {'v-onix-19', 'v-gol-15', 'v-strada-21'},
  ),
  SeedPart(
    Part(
      id: 'p-amort-strada',
      name: 'Amortecedor dianteiro',
      brand: 'Cofap',
      category: 'Suspensão',
      oemCode: '51929163',
      equivalentCodes: ['GP32968', 'HG33178'],
    ),
    ['amortecedor', 'suspensão', 'suspensao', 'barulho na suspensão'],
    {'v-strada-21'},
  ),
  SeedPart(
    Part(
      id: 'p-vela-hb20',
      name: 'Jogo de velas de ignição',
      brand: 'NGK',
      category: 'Ignição',
      oemCode: '18846-11070',
      equivalentCodes: ['BKR6E-11'],
    ),
    ['vela', 'velas', 'ignição', 'ignicao', 'falhando'],
    {'v-hb20-20'},
    partialFits: {'v-onix-19'},
  ),
  SeedPart(
    Part(
      id: 'p-bateria-60',
      name: 'Bateria 60Ah',
      brand: 'Moura',
      category: 'Elétrica',
      oemCode: 'M60GD',
      equivalentCodes: ['60GD'],
    ),
    ['bateria', 'não liga', 'nao liga'],
    {'v-onix-19', 'v-hb20-20', 'v-strada-21', 'v-gol-15'},
  ),
];

/// Distribuidores com perfis diferentes para o ranking ter o que comparar.
const _distributors = [
  ('d-centro', 'Distribuidora Centro Peças', 1.00, 35, 0.97),
  ('d-norte', 'Auto Norte Atacado', 0.91, 75, 0.88),
  ('d-express', 'Express Autopeças', 1.08, 25, 0.93),
];

const _basePrices = <String, int>{
  'p-emb-onix': 68990,
  'p-emb-gol': 61990,
  'p-pastilha-onix': 13490,
  'p-pastilha-hb20': 15990,
  'p-filtro-oleo': 2890,
  'p-amort-strada': 38990,
  'p-vela-hb20': 11990,
  'p-bateria-60': 52990,
};

List<Offer> seedOffersFor(String partId) {
  final base = _basePrices[partId];
  if (base == null) return const [];
  return [
    for (final (i, d) in _distributors.indexed)
      Offer(
        id: 'o-$partId-${d.$1}',
        partId: partId,
        distributorId: d.$1,
        distributorName: d.$2,
        price: Money((base * d.$3).round()),
        // Um distribuidor sem estoque de amortecedor para exercitar o filtro.
        stock: partId == 'p-amort-strada' && i == 2 ? 0 : 3 + i * 4,
        etaMinutes: d.$4,
        reliability: d.$5,
      ),
  ];
}
