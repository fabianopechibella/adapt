import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _cnpj = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  var _codeSent = false;
  var _busy = false;

  @override
  void dispose() {
    _cnpj.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = ref.read(backendProvider).auth;
    setState(() => _busy = true);
    try {
      if (!_codeSent) {
        await auth.requestCode(login: _cnpj.text, phone: _phone.text);
        setState(() => _codeSent = true);
      } else {
        final session = await auth.verifyCode(login: _cnpj.text, code: _code.text.trim());
        ref.read(sessionProvider.notifier).signIn(session);
      }
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Tokens.space5),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.build_circle, size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: Tokens.space3),
                  Text(
                    'Peça certa, na oficina, rápido.',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Tokens.space2),
                  Text('Entre com o CNPJ da oficina.', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                  const SizedBox(height: Tokens.space5),
                  TextField(
                    key: const Key('cnpj'),
                    controller: _cnpj,
                    enabled: !_codeSent,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'CNPJ', hintText: '00.000.000/0000-00'),
                  ),
                  const SizedBox(height: Tokens.space3),
                  TextField(
                    key: const Key('phone'),
                    controller: _phone,
                    enabled: !_codeSent,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Celular com DDD'),
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: Tokens.space3),
                    TextField(
                      key: const Key('code'),
                      controller: _code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Código recebido',
                        helperText: isDemo
                            ? 'Demonstração: use ${FakeWorkshopBackend.demoCode}'
                            : 'Enviado por SMS ou WhatsApp',
                      ),
                    ),
                  ],
                  const SizedBox(height: Tokens.space4),
                  FilledButton(
                    key: const Key('submit'),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_codeSent ? 'Entrar' : 'Receber código'),
                  ),
                  if (_codeSent)
                    TextButton(
                      onPressed: _busy ? null : () => setState(() => _codeSent = false),
                      child: const Text('Corrigir CNPJ ou celular'),
                    ),
                  if (isDemo) ...[
                    const SizedBox(height: Tokens.space4),
                    Text(
                      'Modo demonstração: CNPJ 11.222.333/0001-81 e qualquer celular.',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
