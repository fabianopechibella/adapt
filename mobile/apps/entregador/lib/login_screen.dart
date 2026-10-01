import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _cpf = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  var _codeSent = false;
  var _busy = false;

  @override
  void dispose() {
    _cpf.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = ref.read(backendProvider).auth;
    setState(() => _busy = true);
    try {
      if (!_codeSent) {
        await auth.requestCode(login: _cpf.text, phone: _phone.text);
        setState(() => _codeSent = true);
      } else {
        ref.read(sessionProvider.notifier).set(await auth.verifyCode(login: _cpf.text, code: _code.text.trim()));
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.two_wheeler, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: Tokens.space3),
                Text('Entregas de autopeças', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: Tokens.space5),
                TextField(
                  key: const Key('cpf'),
                  controller: _cpf,
                  enabled: !_codeSent,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'CPF'),
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
                    decoration: InputDecoration(
                      labelText: 'Código recebido',
                      helperText: isDemo ? 'Demonstração: use ${FakeCourierBackend.demoCode}' : null,
                    ),
                  ),
                ],
                const SizedBox(height: Tokens.space4),
                FilledButton(
                  key: const Key('submit'),
                  onPressed: _busy ? null : _submit,
                  child: Text(_codeSent ? 'Entrar' : 'Receber código'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
