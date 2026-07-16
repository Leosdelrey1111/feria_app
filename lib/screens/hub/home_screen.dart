import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // Mostrar diálogo de funcionalidad no disponible para visitantes
  void _showVisitorCTA(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.lock, color: Colors.orange),
            SizedBox(width: 8),
            Text('Función Limitada'),
          ],
        ),
        content: const Text(
          'Para guardar actividades como favoritas o configurar recordatorios, es necesario registrarse.',
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

  void _showSmartTvDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.tv, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Ecosistema Smart TV'),
          ],
        ),
        content: const Text(
          'La función "Ver en TV" te permite proyectar el programa y las actividades en la pantalla del recinto. Disponible en el ecosistema completo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final activityState = ref.watch(activityProvider);
    final polls = ref.watch(pollProvider);

    // Fechas dinámicas para las tabs
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = [
      today,
      today.add(const Duration(days: 1)),
      today.add(const Duration(days: 2)),
    ];
    final dateFormats = DateFormat('EEE d, MMM', 'es_MX');

    // Filtrar actividades por día y categoría
    final selectedDate = dates[activityState.selectedDayIndex];
    final filteredActivities = activityState.activities.where((act) {
      final sameDay = act.startTime.year == selectedDate.year &&
          act.startTime.month == selectedDate.month &&
          act.startTime.day == selectedDate.day;
      
      if (!sameDay) return false;
      if (activityState.selectedCategory != null &&
          act.category != activityState.selectedCategory) {
        return false;
      }
      return true;
    }).toList();

    // Actividad destacada del día
    final featuredActivity = activityState.activities.firstWhere(
      (act) => act.isFeatured,
      orElse: () => activityState.activities.isNotEmpty ? activityState.activities.first : Activity(
        id: 'mock',
        title: 'Feria en curso',
        description: 'Disfruta de las múltiples exposiciones y actividades.',
        speaker: 'Staff',
        category: 'Música',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 2)),
        locationName: 'Foro Central',
        isFeatured: true,
        isLive: true,
        mapX: 0.5,
        mapY: 0.5,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Feria Inteligente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(activityProvider.notifier).loadActivities(),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => context.go('/?tab=3'),
          ),
        ],
      ),
      body: activityState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Banner de Evento en Vivo / Cuenta Regresiva
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [theme.colorScheme.primary, AppTheme.secondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '● EN VIVO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Smartwatch: ${authState.wearConnected ? "Conectado" : "Desconectado"}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Gran Feria de Innovación 2026',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '¡Puertas abiertas hoy hasta las 11:30 PM!',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Actividad Destacada ("Ver en TV")
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber),
                                const SizedBox(width: 8),
                                Text(
                                  'Actividad Destacada',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              featuredActivity.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ponente: ${featuredActivity.speaker} • ${featuredActivity.locationName}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _showSmartTvDialog(context),
                                  icon: const Icon(Icons.tv),
                                  label: const Text('Ver en TV'),
                                ),
                                ElevatedButton(
                                  onPressed: () => context.push('/activity/${featuredActivity.id}'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Ver Detalle'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. Acceso rápido "Mi Boleto QR"
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: InkWell(
                      onTap: () {
                        if (authState.isVisitor) {
                          _showVisitorCTA(context);
                        } else {
                          context.go('/?tab=2');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.qr_code, color: theme.colorScheme.primary, size: 28),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Mi Boleto QR de Acceso',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Ver boletos activos o reservas',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_forward_ios, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 4. Tabs de fechas y Filtros de categorías
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Programa de Actividades',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),

                  // Tabs de días
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    height: 48,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: dates.length,
                      itemBuilder: (context, index) {
                        final isSelected = activityState.selectedDayIndex == index;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(
                              index == 0 ? 'Hoy (Día 1)' : dateFormats.format(dates[index]),
                              style: TextStyle(
                                color: isSelected ? Colors.white : null,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: theme.colorScheme.primary,
                            onSelected: (val) {
                              if (val) {
                                ref.read(activityProvider.notifier).setDayIndex(index);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  // Chips de categorías
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        'Todos',
                        'Música',
                        'Concursos',
                        'Arte',
                        'Gastronomía',
                        'Infantil',
                      ].map((cat) {
                        final isSelected = (cat == 'Todos' && activityState.selectedCategory == null) ||
                            (activityState.selectedCategory == cat);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) {
                                ref.read(activityProvider.notifier).setCategoryFilter(
                                      cat == 'Todos' ? null : cat,
                                    );
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // 5. Lista de Actividades agrupadas por hora
                  const SizedBox(height: 8),
                  filteredActivities.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                            child: Text(
                              'No hay actividades que coincidan con los filtros.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: filteredActivities.length,
                          itemBuilder: (context, index) {
                            final act = filteredActivities[index];
                            final isFav = activityState.favoriteIds.contains(act.id);
                            final timeStr = DateFormat('hh:mm a').format(act.startTime);

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              elevation: 1.5,
                              child: ListTile(
                                leading: Container(
                                  width: 60,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        timeStr.split(' ')[0],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        timeStr.split(' ')[1],
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        act.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15),
                                      ),
                                    ),
                                    if (act.isLive)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'LIVE',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${act.category} • ${act.locationName}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    isFav ? Icons.star : Icons.star_border,
                                    color: isFav ? Colors.amber : null,
                                  ),
                                  onPressed: () {
                                    if (authState.isVisitor) {
                                      _showVisitorCTA(context);
                                    } else {
                                      ref
                                          .read(activityProvider.notifier)
                                          .toggleFavorite(act.id);
                                    }
                                  },
                                ),
                                onTap: () => context.push('/activity/${act.id}'),
                              ),
                            );
                          },
                        ),

                  // 6. Sección de encuestas y votaciones activas
                  const SizedBox(height: 24),
                  if (polls.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Votaciones del Recinto',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 32),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Material(
                          child: InkWell(
                            onTap: () => context.push('/polls'),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.how_to_vote,
                                          color: theme.colorScheme.secondary),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Encuesta Activa',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    polls.first.question,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Participa en tiempo real. Resultados visibles en la Smart TV del recinto.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: const [
                                      Text(
                                        'Votar Ahora',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(Icons.arrow_forward, size: 16),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-activity-fab',
        onPressed: () {
          if (authState.isVisitor) {
            _showVisitorCTA(context);
          } else {
            context.push('/activity/create');
          }
        },
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task),
        label: const Text('Agregar'),
      ),
    );
  }
}
