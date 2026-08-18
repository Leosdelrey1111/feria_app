import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/poll.dart';
import '../services/poll_service.dart';
import '../services/watch_sync_service.dart';
import 'watch_sync_provider.dart';

class PollNotifier extends StateNotifier<List<Poll>> {
  final PollService _service;
  final WatchSyncService _watchSyncService;
  StreamSubscription<List<Poll>>? _subscription;

  PollNotifier(this._service, this._watchSyncService) : super([]) {
    _init();
  }

  Future<void> _init() async {
    try {
      // Cargar encuestas iniciales
      final initial = await _service.getActivePolls();
      state = initial;
      broadcastPolls(initial);
    } catch (_) {}
    
    // Conectar al Stream "WebSocket" para actualizaciones en tiempo real
    _subscription = _service.getPollsStream().listen((updatedList) {
      state = updatedList;
      broadcastPolls(updatedList);
    });
  }

  void broadcastPolls(List<Poll> pollsList) {
    _watchSyncService.sendMessage({
      'type': 'polls',
      'polls': pollsList.map((p) => {
        'id': p.id,
        'question': p.question,
        'options': p.options,
        'votes': p.votes,
        'totalVotes': p.totalVotes,
      }).toList(),
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
      broadcastPolls(state);
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
  final syncService = ref.watch(watchSyncServiceProvider);
  return PollNotifier(service, syncService);
});
