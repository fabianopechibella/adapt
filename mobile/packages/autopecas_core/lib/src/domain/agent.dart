import 'offer.dart';
import 'part.dart';
import 'vehicle.dart';

enum AgentAuthor { mecanico, agente, sistema }

/// Resposta do agente de identificação de peça. O LLM roda no backend; o app
/// só renderiza o que veio, inclusive as peças que o grafo de fitment aprovou.
class AgentReply {
  const AgentReply({
    required this.text,
    this.vehicle,
    this.matches = const [],
    this.offers = const [],
    this.quickReplies = const [],
    this.handoffToHuman = false,
  });

  factory AgentReply.fromJson(Map<String, dynamic> json) => AgentReply(
    text: json['text'] as String,
    vehicle: json['vehicle'] == null ? null : Vehicle.fromJson(json['vehicle'] as Map<String, dynamic>),
    matches: (json['matches'] as List? ?? const [])
        .map((e) => FitmentMatch.fromJson(e as Map<String, dynamic>))
        .toList(),
    offers: (json['offers'] as List? ?? const []).map((e) => Offer.fromJson(e as Map<String, dynamic>)).toList(),
    quickReplies: (json['quickReplies'] as List? ?? const []).cast<String>(),
    handoffToHuman: json['handoffToHuman'] as bool? ?? false,
  );

  final String text;
  final Vehicle? vehicle;
  final List<FitmentMatch> matches;
  final List<Offer> offers;
  final List<String> quickReplies;

  /// Verdadeiro quando o agente transferiu a conversa para um atendente.
  final bool handoffToHuman;

  Map<String, dynamic> toJson() => {
    'text': text,
    if (vehicle != null) 'vehicle': vehicle!.toJson(),
    'matches': matches.map((m) => m.toJson()).toList(),
    'offers': offers.map((o) => o.toJson()).toList(),
    'quickReplies': quickReplies,
    'handoffToHuman': handoffToHuman,
  };
}

class AgentMessage {
  const AgentMessage({required this.author, required this.text, required this.at, this.reply});

  final AgentAuthor author;
  final String text;
  final DateTime at;

  /// Conteúdo estruturado quando a mensagem vem do agente.
  final AgentReply? reply;
}
