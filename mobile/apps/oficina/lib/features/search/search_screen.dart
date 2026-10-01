import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';
import '../../router.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(vehicleProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar peça'), actions: const [CartAction()]),
      body: vehicle == null ? const _PlateStep() : _PartStep(vehicle: vehicle),
    );
  }
}

/// Passo 1: placa → veículo normalizado. Sem veículo não há busca, porque
/// compatibilidade sempre é calculada para um veículo específico.
class _PlateStep extends ConsumerStatefulWidget {
  const _PlateStep();

  @override
  ConsumerState<_PlateStep> createState() => _PlateStepState();
}

class _PlateStepState extends ConsumerState<_PlateStep> {
  final _plate = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _plate.dispose();
    super.dispose();
  }

  Future<void> _lookup([String? value]) async {
    if (value != null) _plate.text = value;
    if (!Plate.isValid(_plate.text)) {
      showError(context, 'Placa inválida. Use ABC1D23 ou ABC-1234.');
      return;
    }
    setState(() => _busy = true);
    try {
      final vehicle = await ref.read(backendProvider).catalog.lookupPlate(Plate.normalize(_plate.text));
      ref.read(vehicleProvider.notifier).select(vehicle);
    } on AppException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDemo = ref.watch(configProvider).isDemo;
    return ListView(
      padding: const EdgeInsets.all(Tokens.space4),
      children: [
        Text('Qual é o veículo?', style: theme.textTheme.titleLarge),
        const SizedBox(height: Tokens.space2),
        Text('Pela placa buscamos só peças com aplicação confirmada.', style: theme.textTheme.bodyMedium),
        const SizedBox(height: Tokens.space4),
        TextField(
          key: const Key('plate'),
          controller: _plate,
          textCapitalization: TextCapitalization.characters,
          maxLength: 8,
          style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 4),
          decoration: const InputDecoration(labelText: 'Placa', hintText: 'ABC1D23', counterText: ''),
          onSubmitted: (_) => _lookup(),
        ),
        const SizedBox(height: Tokens.space3),
        FilledButton.icon(
          key: const Key('lookup'),
          onPressed: _busy ? null : _lookup,
          icon: _busy
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.directions_car),
          label: const Text('Identificar veículo'),
        ),
        if (isDemo) ...[
          const SizedBox(height: Tokens.space5),
          Text('Placas de demonstração', style: theme.textTheme.labelLarge),
          const SizedBox(height: Tokens.space2),
          Wrap(
            spacing: Tokens.space2,
            children: [
              for (final p in const ['ABC1D23', 'BRA2E19', 'QWE4R56', 'KJH5544'])
                ActionChip(label: Text(p), onPressed: _busy ? null : () => _lookup(p)),
            ],
          ),
        ],
      ],
    );
  }
}

class _PartStep extends ConsumerStatefulWidget {
  const _PartStep({required this.vehicle});

  final Vehicle vehicle;

  @override
  ConsumerState<_PartStep> createState() => _PartStepState();
}

class _PartStepState extends ConsumerState<_PartStep> {
  final _query = TextEditingController();
  var _submitted = '';

  static const _shortcuts = ['Pastilha de freio', 'Embreagem', 'Filtro de óleo', 'Amortecedor', 'Bateria', 'Velas'];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search([String? value]) {
    if (value != null) _query.text = value;
    setState(() => _submitted = _query.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = ref.watch(searchProvider((vehicleId: widget.vehicle.id, query: _submitted)));
    return ListView(
      padding: const EdgeInsets.all(Tokens.space4),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.directions_car),
            title: Text(widget.vehicle.title),
            subtitle: Text(widget.vehicle.subtitle),
            trailing: TextButton(
              onPressed: () => ref.read(vehicleProvider.notifier).clear(),
              child: const Text('Trocar'),
            ),
          ),
        ),
        const SizedBox(height: Tokens.space4),
        TextField(
          key: const Key('query'),
          controller: _query,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Peça, sintoma ou código',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _search),
          ),
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: Tokens.space2),
        Wrap(
          spacing: Tokens.space2,
          runSpacing: Tokens.space2,
          children: [for (final s in _shortcuts) ActionChip(label: Text(s), onPressed: () => _search(s))],
        ),
        const SizedBox(height: Tokens.space4),
        Text(
          _submitted.isEmpty ? 'Peças com aplicação para este veículo' : 'Resultados para "$_submitted"',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: Tokens.space2),
        results.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Tokens.space5),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ErrorView(e),
          data: (matches) => matches.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'Nenhuma peça compatível encontrada',
                  message: 'Tente outro nome, o código gravado na peça ou fale com o assistente.',
                )
              : Column(
                  children: [
                    for (final m in matches)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Tokens.space2),
                        child: _MatchTile(match: m),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match});

  final FitmentMatch match;

  @override
  Widget build(BuildContext context) {
    final part = match.part;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.radius),
        onTap: () => context.go('/buscar/peca/${part.id}', extra: match),
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('${part.name} · ${part.brand}', style: Theme.of(context).textTheme.titleSmall)),
                  FitmentBadge(match),
                ],
              ),
              const SizedBox(height: Tokens.space1),
              Text('${part.category} · cód. ${part.oemCode}', style: Theme.of(context).textTheme.bodySmall),
              if (match.note != null) ...[
                const SizedBox(height: Tokens.space2),
                Text(match.note!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Tokens.warning)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
