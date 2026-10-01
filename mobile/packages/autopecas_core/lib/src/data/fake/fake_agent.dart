import '../../domain/agent.dart';
import '../../domain/offer.dart';
import '../../domain/part.dart';
import '../../domain/validators.dart';
import '../../domain/vehicle.dart';
import '../repositories.dart';

class _Conversation {
  Vehicle? vehicle;
  int clarifications = 0;
}

/// Agente de demonstração, determinístico e sem LLM.
///
/// Reproduz o contrato e os guardrails do agente real (que roda no backend):
/// 1. sem veículo identificado, pede a placa;
/// 2. quem decide compatibilidade é o catálogo, nunca o texto do agente;
/// 3. confiança abaixo do limiar pede o código da peça;
/// 4. na segunda falha seguida, transfere para um atendente humano.
class FakeAgent implements AgentRepository {
  FakeAgent({required this.catalog, required this.offers, this.latency = Duration.zero});

  final CatalogRepository catalog;
  final OfferRepository offers;
  final Duration latency;
  final _conversations = <String, _Conversation>{};

  static const _maxClarifications = 2;

  @override
  Future<AgentReply> send({required String conversationId, required String text}) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final convo = _conversations.putIfAbsent(conversationId, _Conversation.new);

    var request = text;
    final plate = Plate.findIn(text);
    if (plate != null) {
      try {
        convo.vehicle = await catalog.lookupPlate(plate.value);
        convo.clarifications = 0;
      } on AppException catch (e) {
        return AgentReply(text: '${e.message} Pode conferir a placa?');
      }
      request = text.replaceAll(Plate.loosePattern, ' ');
    }

    final vehicle = convo.vehicle;
    if (vehicle == null) {
      return const AgentReply(
        text: 'Para buscar só peças compatíveis, me passe a placa do veículo (ex.: ABC1D23).',
        quickReplies: ['ABC1D23', 'BRA2E19', 'QWE4R56'],
      );
    }

    final query = _clean(request);
    if (query.length < 3) {
      return AgentReply(
        text: 'Achei: ${vehicle.title} ${vehicle.year}. Qual peça você precisa?',
        vehicle: vehicle,
        quickReplies: const ['Kit de embreagem', 'Pastilha de freio', 'Filtro de óleo', 'Bateria'],
      );
    }

    final matches = await catalog.searchCompatible(vehicleId: vehicle.id, query: query);
    if (matches.isEmpty) {
      return _clarify(
        convo,
        vehicle,
        'Não encontrei "$query" com aplicação para o ${vehicle.title}. '
        'Pode descrever de outro jeito ou me mandar o código gravado na peça?',
      );
    }

    final best = matches.first;
    if (best.needsConfirmation) {
      return _clarify(
        convo,
        vehicle,
        'Encontrei uma peça provável, mas a aplicação não está confirmada no catálogo para este motor. '
        'Me envie o código gravado na peça antiga para eu confirmar antes de cotar.',
        matches: matches,
      );
    }

    convo.clarifications = 0;
    final ranked = rankOffers(await offers.quote(partId: best.part.id, vehicleId: vehicle.id));
    if (ranked.isEmpty) {
      return AgentReply(
        text:
            '${best.part.name} ${best.part.brand} é compatível, mas está sem estoque nos distribuidores da sua região agora.',
        vehicle: vehicle,
        matches: [best],
      );
    }
    final top = ranked.first.offer;
    return AgentReply(
      text:
          '${best.part.name} ${best.part.brand} (cód. ${best.part.oemCode}) é compatível com o '
          '${vehicle.title} ${vehicle.year}. Melhor opção: ${top.price.format()} com '
          '${top.distributorName}, entrega em cerca de ${top.etaMinutes} min. Quer adicionar ao carrinho?',
      vehicle: vehicle,
      matches: [best],
      offers: ranked.take(3).map((r) => r.offer).toList(),
    );
  }

  AgentReply _clarify(_Conversation convo, Vehicle vehicle, String text, {List<FitmentMatch> matches = const []}) {
    convo.clarifications++;
    if (convo.clarifications >= _maxClarifications) {
      convo.clarifications = 0;
      return AgentReply(
        text: 'Para não arriscar a peça errada, vou chamar um atendente. Ele continua por aqui em instantes.',
        vehicle: vehicle,
        handoffToHuman: true,
      );
    }
    return AgentReply(text: text, vehicle: vehicle, matches: matches);
  }

  static final _filler = RegExp(
    r'\b(preciso|precisa|quero|queria|do|da|de|dos|das|para|pra|pro|o|a|os|as|um|uma|placa|carro|por favor|favor|oi|olá|ola|bom dia|boa tarde|me|manda|tem)\b',
    caseSensitive: false,
  );

  String _clean(String text) =>
      text.replaceAll(_filler, ' ').replaceAll(RegExp(r'[^\wÀ-ú\-/ ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}
