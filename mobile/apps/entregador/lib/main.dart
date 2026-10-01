import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  String? token;
  final CourierBackend backend;
  if (config.isDemo) {
    backend = FakeCourierBackend().asBackend();
  } else {
    final api = ApiClient(baseUrl: Uri.parse(config.apiBaseUrl), tokenProvider: () => token);
    backend = CourierBackend(
      auth: HttpAuthRepository(api, audience: 'courier'),
      deliveries: HttpDeliveryRepository(api),
    );
  }
  runApp(
    ProviderScope(
      overrides: [
        configProvider.overrideWithValue(config),
        backendProvider.overrideWithValue(backend),
        onSessionProvider.overrideWithValue((session) => token = session?.token),
      ],
      child: const EntregadorApp(),
    ),
  );
}
