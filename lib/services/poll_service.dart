import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/poll.dart';

class PollService {
  static const String keyVotedPrefix = 'voted_poll_';
  final _random = Random();

  // Lista base de encuestas activas
  final List<Poll> _initialPolls = [
    Poll(
      id: 'poll-01',
      question: '¿Cuál ha sido tu pabellón favorito hasta ahora?',
      options: ['Pabellón Tecnológico', 'Terraza Gourmet', 'Zona Cultural', 'Teatro del Pueblo'],
      votes: {
        'Pabellón Tecnológico': 420,
        'Terraza Gourmet': 350,
        'Zona Cultural': 210,
        'Teatro del Pueblo': 180,
      },
      totalVotes: 1160,
      endDate: DateTime.now().add(const Duration(hours: 12)),
    ),
    Poll(
      id: 'poll-02',
      question: '¿Qué artista te gustaría ver en la clausura?',
      options: ['Mariachi Imperial', 'Banda de Rock Alternativo', 'Orquesta Filarmónica', 'Show Pop Dance'],
      votes: {
        'Mariachi Imperial': 120,
        'Banda de Rock Alternativo': 280,
        'Orquesta Filarmónica': 90,
        'Show Pop Dance': 210,
      },
      totalVotes: 700,
      endDate: DateTime.now().add(const Duration(hours: 24)),
    ),
  ];

  // Historial de votaciones anteriores
  final List<Map<String, dynamic>> pastPolls = [
    {
      'question': '¿Qué calificación le das a la logística del estacionamiento?',
      'winner': 'Excelente (45%)',
      'totalVotes': 1850,
      'date': 'Ayer'
    },
    {
      'question': '¿Asistirás a las conferencias matutinas del Día 2?',
      'winner': 'Sí (72%)',
      'totalVotes': 1420,
      'date': 'Hace 2 días'
    }
  ];

  // Obtener encuestas actuales cruzando con SharedPreferences para ver si ya votó
  Future<List<Poll>> getActivePolls() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Poll> polls = [];

    for (var rawPoll in _initialPolls) {
      final votedOption = prefs.getString('$keyVotedPrefix${rawPoll.id}');
      polls.add(rawPoll.copyWith(userVotedOption: votedOption));
    }
    return polls;
  }

  // Registrar un voto
  Future<Poll> vote(String pollId, String option) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$keyVotedPrefix$pollId', option);

    // Encontrar la encuesta y añadir el voto
    final pollIndex = _initialPolls.indexWhere((p) => p.id == pollId);
    if (pollIndex != -1) {
      final poll = _initialPolls[pollIndex];
      final currentVotes = Map<String, int>.from(poll.votes);
      currentVotes[option] = (currentVotes[option] ?? 0) + 1;
      
      final updated = poll.copyWith(
        votes: currentVotes,
        totalVotes: poll.totalVotes + 1,
        userVotedOption: option,
      );
      _initialPolls[pollIndex] = updated;
      return updated;
    }
    throw Exception('Encuesta no encontrada');
  }

  // Simular conexión "WebSocket" mediante un Stream periódico
  // Cada 3 segundos, este Stream actualiza aleatoriamente los votos totales de las encuestas
  // para dar dinamismo a la interfaz.
  Stream<List<Poll>> getPollsStream() {
    return Stream.periodic(const Duration(seconds: 3), (_) async {
      final prefs = await SharedPreferences.getInstance();
      
      for (int i = 0; i < _initialPolls.length; i++) {
        final poll = _initialPolls[i];
        final currentVotes = Map<String, int>.from(poll.votes);
        
        // Simular que llegan entre 2 y 8 votos nuevos repartidos aleatoriamente
        int newVotesCount = _random.nextInt(7) + 2;
        for (int j = 0; j < newVotesCount; j++) {
          final randomOption = poll.options[_random.nextInt(poll.options.length)];
          currentVotes[randomOption] = (currentVotes[randomOption] ?? 0) + 1;
        }

        final votedOption = prefs.getString('$keyVotedPrefix${poll.id}');
        _initialPolls[i] = poll.copyWith(
          votes: currentVotes,
          totalVotes: poll.totalVotes + newVotesCount,
          userVotedOption: votedOption,
        );
      }
      return _initialPolls;
    }).asyncMap((event) => event);
  }
}
