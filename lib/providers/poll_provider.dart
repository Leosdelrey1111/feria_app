import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/poll.dart';
import '../services/poll_service.dart';

class PollNotifier extends StateNotifier<List<Poll>> {
  final PollService _service;
  StreamSubscription<List<Poll>>? _subscription;

  PollNotifier(this._service) : super([]) {
    _init();
  }

  Future<void> _init() async {
    try {
      // Cargar encuestas iniciales
      final initial = await _service.getActivePolls();
      state = initial;
    } catch (_) {}
    
    // Conectar al Stream "WebSocket" para actualizaciones en tiempo real
    _subscription = _service.getPollsStream().listen((updatedList) {
      state = updatedList;
    });
  }

  // Registrar un voto
  Future<void> vote(String pollId, String option) async {
    try {
      final updatedPoll = await _service.vote(pollId, option);
      
      // Actualizar el estado local inmediatamente
      state = [
        for (final poll in state)
          if (poll.id == pollId) updatedPoll else poll
      ];
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// Provider de PollService
final pollServiceProvider = Provider<PollService>((ref) {
  return PollService();
});

// Provider del listado de encuestas vivas
final pollProvider = StateNotifierProvider<PollNotifier, List<Poll>>((ref) {
  final service = ref.watch(pollServiceProvider);
  return PollNotifier(service);
});
