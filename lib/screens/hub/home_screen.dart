import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _heroController;
  late final AnimationController _cardsController;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _cardsController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  }

  @override
  void dispose() {
    _heroController.dispose();
    _cardsController.dispose();
    super.dispose();
  }

  void _showVisitorCTA(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.orange),
            SizedBox(width: 8),
            Text('Función Limitada'),
          ],
        ),
        content: const Text(
          'Para guardar actividades como favoritas o configurar recordatorios, es necesario registrarse.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Seguir explorando')),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final activityState = ref.watch(activityProvider);
    final polls = ref.watch(pollProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = [today, today.add(const Duration(days: 1)), today.add(const Duration(days: 2))];
    final dateFormats = DateFormat('EEE d, MMM', 'es_MX');

    final selectedDate = dates[activityState.selectedDayIndex];
    final filteredActivities = activityState.activities.where((act) {
      final sameDay = act.startTime.year == selectedDate.year &&
          act.startTime.month == selectedDate.month &&
          act.startTime.day == selectedDate.day;

      if (!sameDay) return false;
      if (activityState.selectedCategory != null && act.category != activityState.selectedCategory) {
        return false;
      }
      return true;
    }).toList();

    final featuredActivity = activityState.activities.firstWhere(
      (act) => act.isFeatured,
      orElse: () => activityState.activities.isNotEmpty
          ? activityState.activities.first
          : Activity(
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
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(activityProvider.notifier).loadActivities(),
          ),
          IconButton(
            icon: const Icon(Icons.person_rounded),
            onPressed: () => context.go('/?tab=3'),
          ),
        ],
      ),
      body: activityState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: AnimatedBuilder(
                      animation: _heroController,
                      builder: (context, child) {
                        final offset = 6 * (0.5 - _heroController.value);
                        return Transform.translate(offset: Offset(0, offset), child: child);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            colors: [theme.colorScheme.primary, AppTheme.secondaryColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.24),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              right: -10,
                              top: -10,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.14),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withOpacity(0.95),
                                        borderRadius: BorderRadius.circular(999),
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
                                      'Smartwatch: ${authState.wearConnected ? 'Conectado' : 'Desconectado'}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Tu feria, en movimiento',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Explora actividades, sigue tus favoritos y llega al punto ideal del recinto en segundos.',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.92),
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _pill(label: 'Mapa interactivo', icon: Icons.map_outlined),
                                    _pill(label: 'Favoritos en tiempo real', icon: Icons.star_rounded),
                                    _pill(label: 'Programación de hoy', icon: Icons.schedule_rounded),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: AnimatedBuilder(
                            animation: _cardsController,
                            builder: (context, child) {
                              final value = Curves.easeOutCubic.transform(_cardsController.value);
                              return Transform.scale(scale: 0.95 + (0.05 * value), child: child);
                            },
                            child: _quickActionCard(
                              context,
                              icon: Icons.map_rounded,
                              title: 'Mapa del recinto',
                              subtitle: 'Descubre puntos clave y tus actividades',
                              onTap: () => context.go('/?tab=1'),
                              accent: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AnimatedBuilder(
                            animation: _cardsController,
                            builder: (context, child) {
                              final value = Curves.easeOutCubic.transform(_cardsController.value);
                              return Transform.scale(scale: 0.95 + (0.05 * value), child: child);
                            },
                            child: _quickActionCard(
                              context,
                              icon: Icons.qr_code_rounded,
                              title: 'Mi boleto',
                              subtitle: 'Accede a tus entradas y reservas',
                              onTap: () {
                                if (authState.isVisitor) {
                                  _showVisitorCTA(context);
                                } else {
                                  context.go('/?tab=2');
                                }
                              },
                              accent: theme.colorScheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.16), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.16),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.star_rounded, color: Colors.amber),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Actividad destacada',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            featuredActivity.title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ponente: ${featuredActivity.speaker} • ${featuredActivity.locationName}',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showSmartTvDialog(context),
                                  icon: const Icon(Icons.tv_rounded),
                                  label: const Text('Ver en TV'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => context.push('/activity/${featuredActivity.id}'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: const Text('Ver detalle'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available_rounded, color: Colors.deepPurpleAccent),
                        const SizedBox(width: 8),
                        Text(
                          'Programa del día',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    height: 54,
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

                  SizedBox(
                    height: 46,
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
                            selectedColor: theme.colorScheme.primary.withOpacity(0.18),
                            onSelected: (val) {
                              if (val) {
                                ref.read(activityProvider.notifier).setCategoryFilter(cat == 'Todos' ? null : cat);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

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

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: isFav ? Colors.amber.withOpacity(0.35) : theme.dividerColor),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  leading: Container(
                                    width: 60,
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(14),
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
                                            fontWeight: FontWeight.w600,
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
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                      ),
                                      if (act.isLive)
                                        Container(
                                          margin: const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'LIVE',
                                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${act.category} • ${act.locationName}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: AnimatedScale(
                                    scale: isFav ? 1.08 : 1.0,
                                    duration: const Duration(milliseconds: 220),
                                    child: IconButton(
                                      icon: Icon(
                                        isFav ? Icons.star_rounded : Icons.star_border_rounded,
                                        color: isFav ? Colors.amber : null,
                                      ),
                                      onPressed: () {
                                        if (authState.isVisitor) {
                                          _showVisitorCTA(context);
                                        } else {
                                          ref.read(activityProvider.notifier).toggleFavorite(act.id);
                                        }
                                      },
                                    ),
                                  ),
                                  onTap: () => context.push('/activity/${act.id}'),
                                ),
                              ),
                            );
                          },
                        ),

                  const SizedBox(height: 24),
                  if (polls.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Votaciones del recinto',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 32),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.16)),
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
                                      Icon(Icons.how_to_vote_rounded, color: theme.colorScheme.secondary),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Encuesta activa',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    polls.first.question,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Participa en tiempo real y visualiza los resultados desde el ecosistema del recinto.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: const [
                                      Text('Votar ahora', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      SizedBox(width: 4),
                                      Icon(Icons.arrow_forward_rounded, size: 16),
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
      floatingActionButton: authState.isAdmin
          ? FloatingActionButton.extended(
              heroTag: 'add-activity-fab',
              onPressed: () => context.push('/activity/create'),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Agregar'),
            )
          : null,
    );
  }

  Widget _quickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color accent,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withOpacity(0.18), width: 1.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: accent.withOpacity(0.16), shape: BoxShape.circle),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill({required String label, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
