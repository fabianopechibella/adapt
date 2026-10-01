import 'package:flutter/material.dart';

import '../domain/order.dart';
import '../domain/part.dart';
import 'theme.dart';

enum Tone { neutral, info, success, warning, critical }

Color toneColor(BuildContext context, Tone tone) => switch (tone) {
  Tone.neutral => Theme.of(context).colorScheme.outline,
  Tone.info => Tokens.brand,
  Tone.success => Tokens.success,
  Tone.warning => Tokens.warning,
  Tone.critical => Tokens.critical,
};

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.tone = Tone.neutral, this.icon});

  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = toneColor(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.space2, vertical: Tokens.space1),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

Tone toneForStatus(OrderStatus status) => switch (status) {
  OrderStatus.entregue || OrderStatus.devolvido => Tone.success,
  OrderStatus.cancelado => Tone.critical,
  _ when status.isCompensation => Tone.warning,
  _ => Tone.info,
};

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) => Pill(status.label, tone: toneForStatus(status));
}

/// Exibe a confiança do fitment. Abaixo do limiar, alerta em vez de vender.
class FitmentBadge extends StatelessWidget {
  const FitmentBadge(this.match, {super.key});

  final FitmentMatch match;

  @override
  Widget build(BuildContext context) => match.needsConfirmation
      ? const Pill('Confirmar aplicação', tone: Tone.warning, icon: Icons.help_outline)
      : const Pill('Compatível', tone: Tone.success, icon: Icons.verified_outlined);
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: Tokens.space3),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: Tokens.space2),
              Text(message!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: Tokens.space4), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView(this.error, {super.key, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.cloud_off_outlined,
    title: 'Algo deu errado',
    message: error.toString(),
    action: onRetry == null ? null : OutlinedButton(onPressed: onRetry, child: const Text('Tentar de novo')),
  );
}

/// Faixa no topo que deixa claro quando o app roda com dados de demonstração.
/// Fica acima do conteúdo (e não sobre ele) para não cobrir ações da AppBar.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Column(
      children: [
        Material(
          color: Tokens.accent,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              width: double.infinity,
              height: 22,
              child: Center(
                child: Text(
                  'MODO DEMONSTRAÇÃO · dados fictícios',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, letterSpacing: 0.6),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
        ),
      ],
    );
  }
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(error.toString())));
}
