import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_screen.dart';
import 'login_screen.dart';
import 'providers.dart';

class EntregadorApp extends ConsumerWidget {
  const EntregadorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(sessionProvider) != null;
    final isDemo = ref.watch(configProvider).isDemo;
    return MaterialApp(
      title: 'Autopeças Entregador',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => DemoBanner(enabled: isDemo, child: child!),
      home: signedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
