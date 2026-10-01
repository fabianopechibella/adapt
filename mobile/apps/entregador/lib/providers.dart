import 'package:autopecas_core/autopecas_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final configProvider = Provider<AppConfig>((ref) => throw UnimplementedError('override no main'));
final backendProvider = Provider<CourierBackend>((ref) => throw UnimplementedError('override no main'));

/// Gancho para o main repassar o token ao cliente HTTP.
final onSessionProvider = Provider<void Function(Session?)>((ref) => (_) {});

class SessionController extends Notifier<Session?> {
  @override
  Session? build() => null;

  void set(Session? session) {
    ref.read(onSessionProvider)(session);
    state = session;
  }
}

final sessionProvider = NotifierProvider<SessionController, Session?>(SessionController.new);

final availableProvider = FutureProvider.autoDispose<List<Delivery>>(
  (ref) => ref.watch(backendProvider).deliveries.available(),
);

final currentProvider = FutureProvider.autoDispose<Delivery?>((ref) => ref.watch(backendProvider).deliveries.current());

final deliveryProvider = StreamProvider.autoDispose.family<Delivery, String>(
  (ref, id) => ref.watch(backendProvider).deliveries.watch(id),
);
