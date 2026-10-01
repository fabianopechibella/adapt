import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final account = ref.watch(accountProvider);
    final isDemo = ref.watch(configProvider).isDemo;
    return Scaffold(
      appBar: AppBar(title: const Text('Conta')),
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(accountProvider)),
        data: (a) {
          final used = a.creditLimit.cents == 0 ? 0.0 : a.creditUsed.cents / a.creditLimit.cents;
          return ResponsiveListView(
            children: [
              Text(a.tradeName, style: theme.textTheme.titleLarge),
              Text('CNPJ ${a.cnpj}', style: theme.textTheme.bodyMedium),
              const SizedBox(height: Tokens.space1),
              Text(a.address, style: theme.textTheme.bodySmall),
              const SizedBox(height: Tokens.space5),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Tokens.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Crédito para compra faturada', style: theme.textTheme.titleSmall),
                      const SizedBox(height: Tokens.space3),
                      LinearProgressIndicator(
                        value: used.clamp(0, 1),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: Tokens.space2),
                      Text('Disponível ${a.creditAvailable.format()} de ${a.creditLimit.format()}'),
                    ],
                  ),
                ),
              ),
              if (isDemo) ...[
                const SizedBox(height: Tokens.space4),
                const Pill('Modo demonstração: dados em memória', tone: Tone.warning, icon: Icons.science_outlined),
              ],
              const SizedBox(height: Tokens.space5),
              OutlinedButton.icon(
                onPressed: () => ref.read(sessionProvider.notifier).signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
              ),
            ],
          );
        },
      ),
    );
  }
}
