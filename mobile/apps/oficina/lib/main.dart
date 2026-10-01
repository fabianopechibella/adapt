import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final tokens = TokenStore();
  runApp(
    ProviderScope(
      overrides: [
        configProvider.overrideWithValue(config),
        tokenStoreProvider.overrideWithValue(tokens),
        backendProvider.overrideWithValue(buildBackend(config, tokens)),
      ],
      child: const OficinaApp(),
    ),
  );
}

/// Sem `API_BASE_URL` o app usa o backend em memória (modo demonstração).
WorkshopBackend buildBackend(AppConfig config, TokenStore tokens) {
  if (config.isDemo) return FakeWorkshopBackend().asBackend();
  final api = ApiClient(baseUrl: Uri.parse(config.apiBaseUrl), tokenProvider: () => tokens.token);
  final repo = HttpWorkshopRepository(api);
  return WorkshopBackend(
    auth: HttpAuthRepository(api, audience: 'workshop'),
    account: repo,
    catalog: repo,
    offers: repo,
    orders: repo,
    agent: repo,
  );
}
