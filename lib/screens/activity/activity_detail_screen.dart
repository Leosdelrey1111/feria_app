import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../theme/theme.dart';

class ActivityDetailScreen extends ConsumerStatefulWidget {
  final String activityId;
  const ActivityDetailScreen({super.key, required this.activityId});

  @override
  ConsumerState<ActivityDetailScreen> createState() =>
      _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen> {
  // Contadores locales de reacciones
  final Map<String, int> _reactions = {'👍': 12, '❤️': 24, '😲': 3, '😱': 1};

  // Solo se permite UNA reacción por usuario a la vez (como pide el PDF:
  // "Sección de reacciones rápidas del público en tiempo real"). Por eso,
  // en vez de un mapa de booleans independientes por emoji, se guarda
  // únicamente cuál fue la reacción elegida.
  String? _selectedReaction;

  void _handleReaction(String emoji) {
    setState(() {
      if (_selectedReaction == emoji) {
        // Tocar la misma reacción otra vez la quita (deseleccionar)
        _reactions[emoji] = (_reactions[emoji] ?? 1) - 1;
        _selectedReaction = null;
      } else {
        // Si había otra reacción seleccionada, se le resta su voto
        if (_selectedReaction != null) {
          _reactions[_selectedReaction!] =
              (_reactions[_selectedReaction!] ?? 1) - 1;
        }
        _reactions[emoji] = (_reactions[emoji] ?? 0) + 1;
        _selectedReaction = emoji;
      }
    });
  }

  void _showVisitorCTA() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.lock, color: Colors.orange),
            SizedBox(width: 8),
            Text('Función Registrada'),
          ],
        ),
        content: const Text(
          'Para programar recordatorios de esta actividad, necesitas registrarte en la aplicación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Seguir explorando'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Iniciar Sesión'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Activity activity) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.delete_outline, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Eliminar actividad'),
          ],
        ),
        content: Text(
          '¿Seguro que quieres eliminar "${activity.title}" de tu agenda? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(activityProvider.notifier).deleteActivity(activity.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Actividad eliminada.')),
                );
                context.pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _scheduleReminder(Activity activity, int minutesBefore) async {
    final notificationTime = activity.startTime.subtract(
      Duration(minutes: minutesBefore),
    );
    final delay = notificationTime.difference(DateTime.now());

    if (delay.isNegative) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Esta actividad ya ha comenzado o falta muy poco tiempo.',
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final notifService = NotificationService();
    await notifService.init();

    if (mounted) {
      await notifService.scheduleNotification(
        id: activity.id.hashCode,
        title: '¡Tu actividad comienza pronto!',
        body:
            '"${activity.title}" iniciará en $minutesBefore minutos en ${activity.locationName}.',
        delay: delay,
        context: context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final activityState = ref.watch(activityProvider);

    // Buscar actividad por ID
    final activity = activityState.activities.firstWhere(
      (act) => act.id == widget.activityId,
      orElse: () => Activity(
        id: 'error',
        title: 'Actividad no encontrada',
        description: 'La actividad seleccionada no existe.',
        speaker: 'N/A',
        category: 'Música',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        locationName: 'N/A',
        isFeatured: false,
        isLive: false,
        mapX: 0,
        mapY: 0,
      ),
    );

    if (activity.id == 'error') {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Actividad no encontrada')),
      );
    }

    final timeStr = DateFormat('hh:mm a').format(activity.startTime);
    final endTimeStr = DateFormat('hh:mm a').format(activity.endTime);
    final dateStr = DateFormat(
      'EEEE d \'de\' MMMM',
      'es_MX',
    ).format(activity.startTime);
    final isFav = activityState.favoriteIds.contains(activity.id);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Banner App Bar
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      AppTheme.secondaryColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    activity.category == 'Música'
                        ? Icons.music_note
                        : activity.category == 'Concursos'
                        ? Icons.emoji_events
                        : activity.category == 'Arte'
                        ? Icons.palette
                        : activity.category == 'Gastronomía'
                        ? Icons.restaurant_menu
                        : Icons.child_care,
                    size: 80,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  isFav ? Icons.star : Icons.star_border,
                  color: isFav ? Colors.amber : Colors.white,
                ),
                onPressed: () {
                  if (authState.isVisitor) {
                    _showVisitorCTA();
                  } else {
                    ref
                        .read(activityProvider.notifier)
                        .toggleFavorite(activity.id);
                  }
                },
              ),
              // Solo las actividades creadas por el propio usuario se
              // pueden borrar; el programa oficial de la feria está protegido.
              if (activity.isCustom)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  tooltip: 'Eliminar actividad',
                  onPressed: () => _confirmDelete(context, activity),
                ),
            ],
          ),

          // Contenido del detalle
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Categoría y badge de En Vivo
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          activity.category.toUpperCase(),
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (activity.isLive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'EN CURSO',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Título y Ponente
                  Text(
                    activity.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Presentado por: ${activity.speaker}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[700],
                    ),
                  ),
                  const Divider(height: 32),

                  // Info de Horario y Lugar
                  Row(
                    children: [
                      Expanded(
                        child: _infoCard(
                          context,
                          icon: Icons.calendar_today_outlined,
                          title: 'Fecha',
                          value:
                              dateStr[0].toUpperCase() + dateStr.substring(1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _infoCard(
                          context,
                          icon: Icons.access_time,
                          title: 'Horario',
                          value: '$timeStr - $endTimeStr',
                          subtitle:
                              '${activity.durationInMinutes} minutos de duración',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _infoCard(
                          context,
                          icon: Icons.location_on_outlined,
                          title: 'Ubicación',
                          value: activity.locationName,
                          trailing: TextButton.icon(
                            onPressed: () {
                              ref
                                      .read(
                                        selectedMapActivityProvider.notifier,
                                      )
                                      .state =
                                  activity;
                              context.go(
                                '/?tab=1',
                              ); // Navegar a la pestaña del Mapa
                            },
                            icon: const Icon(Icons.map, size: 16),
                            label: const Text('Ver en Mapa'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Descripción
                  const Text(
                    'Sobre esta actividad',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activity.description,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  // Botones de acción (Recordatorio y Compartir)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (authState.isVisitor) {
                              _showVisitorCTA();
                            } else {
                              _scheduleReminder(
                                activity,
                                authState.reminderMinutes,
                              );
                            }
                          },
                          icon: const Icon(Icons.alarm, color: Colors.white),
                          label: const Text('Recordatorio'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Share.share(
                              '¡No te pierdas la actividad "${activity.title}" en la Feria Inteligente 2026!\nHora: $timeStr - Lugar: ${activity.locationName}. Descarga la app para agendar tu visita.',
                            );
                          },
                          icon: const Icon(Icons.share),
                          label: const Text('Compartir'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Sección de reacciones rápidas
                  const Text(
                    '¿Qué te parece esta actividad?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _reactions.keys.map((emoji) {
                      final count = _reactions[emoji]!;
                      final voted = _selectedReaction == emoji;
                      return InkWell(
                        onTap: () => _handleReaction(emoji),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: voted
                                ? theme.colorScheme.secondary.withOpacity(0.15)
                                : theme.brightness == Brightness.dark
                                ? Colors.grey[850]
                                : Colors.grey[200],
                            border: Border.all(
                              color: voted
                                  ? theme.colorScheme.secondary
                                  : Colors.transparent,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 6),
                              Text(
                                '$count',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: voted
                                      ? theme.colorScheme.secondary
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.brightness == Brightness.dark
          ? Colors.grey[900]
          : Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}
