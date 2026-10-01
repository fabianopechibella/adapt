/// Configuração por `--dart-define`, igual para iOS e Android.
///
/// `flutter run --dart-define=API_BASE_URL=https://bff-oficina.exemplo.com.br`
/// Sem `API_BASE_URL`, o app sobe em modo demonstração com backend em memória.
class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  factory AppConfig.fromEnvironment() => const AppConfig(apiBaseUrl: String.fromEnvironment('API_BASE_URL'));

  final String apiBaseUrl;

  bool get isDemo => apiBaseUrl.isEmpty;
}
