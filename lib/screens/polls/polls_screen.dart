import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/poll.dart';
import '../../providers/poll_provider.dart';
import '../../theme/app_theme.dart';

class PollsScreen extends ConsumerStatefulWidget {
  const PollsScreen({super.key});

  @override
  ConsumerState<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends ConsumerState<PollsScreen> {
  // Mapa para guardar la opción seleccionada temporalmente en cada encuesta antes de enviar el voto
  final Map<String, String> _selectedOptions = {};

  void _submitVote(String pollId) {
    final option = _selectedOptions[pollId];
    if (option == null) return;

    ref.read(pollProvider.notifier).vote(pollId, option);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Voto emitido con éxito! Mira cómo cambian los resultados en vivo.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final polls = ref.watch(pollProvider);
    final pollService = ref.read(pollServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Encuestas y Votaciones'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/?tab=0'),
        ),
      ),
      body: polls.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banner Informativo de Ecosistema
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.tv, color: theme.colorScheme.primary, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Integración con Smart TV',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Los resultados acumulados se proyectan en tiempo real en las pantallas del recinto.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Encuestas Activas',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Lista de Encuestas
                  ...polls.map((poll) {
                    final hasVoted = poll.userVotedOption != null;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Encabezado de la tarjeta (pregunta y estado)
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.wifi_tethering, size: 12, color: Colors.green),
                                      SizedBox(width: 4),
                                      Text(
                                        'EN VIVO',
                                        style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                const Text(
                                  'Votos totales: ',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  '${poll.totalVotes}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              poll.question,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const Divider(height: 24),

                            // Si el usuario ya votó, mostrar los resultados con barras animadas
                            if (hasVoted) ...[
                              ...poll.options.map((option) {
                                final votesCount = poll.votes[option] ?? 0;
                                final percent = poll.totalVotes > 0 ? votesCount / poll.totalVotes : 0.0;
                                final isSelected = poll.userVotedOption == option;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              option,
                                              style: TextStyle(
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                color: isSelected ? theme.colorScheme.primary : null,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${(percent * 100).toStringAsFixed(1)}% ($votesCount)',
                                            style: TextStyle(
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              color: isSelected ? theme.colorScheme.primary : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Barra de porcentaje animada
                                      Stack(
                                        children: [
                                          Container(
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: theme.brightness == Brightness.dark
                                                  ? Colors.grey[800]
                                                  : Colors.grey[200],
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                          ),
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 500),
                                            height: 10,
                                            width: MediaQuery.of(context).size.width * 0.8 * percent,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  isSelected ? theme.colorScheme.primary : Colors.grey,
                                                  isSelected ? AppTheme.secondaryColor : Colors.grey.shade400,
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 12),
                              const Center(
                                child: Text(
                                  '✓ Has votado. Los porcentajes se actualizan en vivo.',
                                  style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ] else ...[
                              // Si el usuario no ha votado, mostrar radio buttons de votación rápida
                              ...poll.options.map((option) {
                                return RadioListTile<String>(
                                  title: Text(option),
                                  value: option,
                                  groupValue: _selectedOptions[poll.id],
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedOptions[poll.id] = val!;
                                    });
                                  },
                                );
                              }).toList(),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _selectedOptions[poll.id] != null
                                    ? () => _submitVote(poll.id)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Enviar Voto'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: 32),
                  // Historial de Votaciones Anteriores
                  Text(
                    'Historial de Encuestas',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...pollService.pastPolls.map((past) {
                    return Card(
                      elevation: 0.5,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.done_all, color: Colors.grey),
                        title: Text(
                          past['question'] as String,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Ganador: ${past['winner']} • Votos totales: ${past['totalVotes']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            past['date'] as String,
                            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }
}
