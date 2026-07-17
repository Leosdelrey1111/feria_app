import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

/// Pantalla para agregar (o editar, si `existing` viene lleno) una
/// actividad de la agenda.
///
/// El programa oficial de la feria y las actividades personales de
/// cualquier usuario solo pueden crearse/editarse/eliminarse por un
/// administrador (ver gating en activity_detail_screen.dart y
/// home_screen.dart). Esta pantalla en sí no revalida el rol: confía en
/// que solo se llega aquí desde un botón ya protegido.
class CreateActivityScreen extends ConsumerStatefulWidget {
  final Activity? existing;
  const CreateActivityScreen({super.key, this.existing});

  @override
  ConsumerState<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends ConsumerState<CreateActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _speakerController = TextEditingController();
  final _locationController = TextEditingController();

  static const List<Map<String, dynamic>> _categories = [
    {'name': 'Música', 'icon': Icons.music_note},
    {'name': 'Concursos', 'icon': Icons.emoji_events},
    {'name': 'Arte', 'icon': Icons.palette},
    {'name': 'Gastronomía', 'icon': Icons.restaurant},
    {'name': 'Infantil', 'icon': Icons.child_care},
  ];

  String _selectedCategory = 'Música';
  int _selectedDayIndex = 0; // 0 = hoy, 1 = mañana, 2 = pasado mañana
  TimeOfDay _startTime = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 13, minute: 0);

  // Posición aproximada en el mapa esquemático (0.0 a 1.0). Se elige con
  // un mini-selector táctil para que la actividad también aparezca con
  // pin en el Mapa Interactivo (M-04), tal como las oficiales.
  double _mapX = 0.5;
  double _mapY = 0.5;

  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _descriptionController.text = existing.description;
      _speakerController.text = existing.speaker;
      _locationController.text = existing.locationName;
      _selectedCategory = existing.category;
      _startTime = TimeOfDay.fromDateTime(existing.startTime);
      _endTime = TimeOfDay.fromDateTime(existing.endTime);
      _mapX = existing.mapX;
      _mapY = existing.mapY;

      final today = DateTime.now();
      final startDay = DateTime(existing.startTime.year, existing.startTime.month, existing.startTime.day);
      final diff = startDay.difference(DateTime(today.year, today.month, today.day)).inDays;
      _selectedDayIndex = diff.clamp(0, 2);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _speakerController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  List<DateTime> get _availableDays {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [today, today.add(const Duration(days: 1)), today.add(const Duration(days: 2))];
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  DateTime _combine(DateTime day, TimeOfDay time) {
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final day = _availableDays[_selectedDayIndex];
    final start = _combine(day, _startTime);
    final end = _combine(day, _endTime);

    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La hora de fin debe ser después de la hora de inicio.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          speaker: _speakerController.text.trim(),
          category: _selectedCategory,
          startTime: start,
          endTime: end,
          locationName: _locationController.text.trim(),
          mapX: _mapX,
          mapY: _mapY,
          isLive: DateTime.now().isAfter(start) && DateTime.now().isBefore(end),
        );
        await ref.read(activityProvider.notifier).updateActivity(updated);
      } else {
        await ref.read(activityProvider.notifier).createActivity(
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              speaker: _speakerController.text.trim(),
              category: _selectedCategory,
              startTime: start,
              endTime: end,
              locationName: _locationController.text.trim(),
              mapX: _mapX,
              mapY: _mapY,
            );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? '¡Actividad actualizada!' : '¡Actividad agregada a la agenda!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayLabels = _availableDays
        .map((d) => DateFormat('EEE d MMM', 'es_MX').format(d))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Actividad' : 'Agregar Actividad'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Agrega tu propio plan a la agenda: un recordatorio, una '
              'reunión con amigos en algún stand, o cualquier actividad '
              'que quieras que aparezca junto al programa oficial.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            // Título
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Título',
                hintText: 'Ej. Encontrarme con Ana en el stand de artesanías',
                prefixIcon: const Icon(Icons.title),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un título' : null,
            ),
            const SizedBox(height: 16),

            // Descripción
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Descripción',
                hintText: 'Detalles de tu actividad (opcional)',
                prefixIcon: const Icon(Icons.notes),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Agrega una breve descripción' : null,
            ),
            const SizedBox(height: 16),

            // Encargado / con quién
            TextFormField(
              controller: _speakerController,
              decoration: InputDecoration(
                labelText: 'Con quién / responsable (opcional)',
                hintText: 'Ej. Ana y Luis',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),

            // Ubicación
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Ubicación en el recinto',
                hintText: 'Ej. Entrada Principal',
                prefixIcon: const Icon(Icons.place_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Indica una ubicación' : null,
            ),
            const SizedBox(height: 20),

            // Categoría
            Text('Categoría', style: theme.textTheme.titleLarge?.copyWith(fontSize: 15)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final selected = _selectedCategory == cat['name'];
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCategory = cat['name'] as String),
                  avatar: Icon(
                    cat['icon'] as IconData,
                    size: 18,
                    color: selected ? Colors.white : theme.colorScheme.primary,
                  ),
                  label: Text(cat['name'] as String),
                  selectedColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : null,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Día
            Text('Día', style: theme.textTheme.titleLarge?.copyWith(fontSize: 15)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(dayLabels.length, (i) {
                final selected = _selectedDayIndex == i;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedDayIndex = i),
                  label: Text(dayLabels[i]),
                  selectedColor: theme.colorScheme.secondary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : null,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // Horarios
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(true),
                    icon: const Icon(Icons.schedule),
                    label: Text('Inicio: ${_startTime.format(context)}'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(false),
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text('Fin: ${_endTime.format(context)}'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Ubicación aproximada en el mapa
            Text('Ubicación aproximada en el mapa', style: theme.textTheme.titleLarge?.copyWith(fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              'Toca dentro del recuadro para marcar dónde aparecerá el pin en el Mapa Interactivo.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 1.4,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onTapDown: (details) {
                      final box = context.findRenderObject() as RenderBox;
                      final local = box.globalToLocal(details.globalPosition);
                      setState(() {
                        _mapX = (local.dx / constraints.maxWidth).clamp(0.0, 1.0);
                        _mapY = (local.dy / constraints.maxHeight).clamp(0.0, 1.0);
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                        color: theme.colorScheme.primary.withOpacity(0.05),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Icon(Icons.map_outlined,
                                size: 48, color: theme.colorScheme.primary.withOpacity(0.15)),
                          ),
                          Positioned(
                            left: _mapX * constraints.maxWidth - 14,
                            top: _mapY * constraints.maxHeight - 28,
                            child: Icon(Icons.location_pin,
                                size: 28, color: theme.colorScheme.secondary),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: _isSaving ? null : _submit,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(_isEditing ? Icons.save : Icons.add_task),
              label: Text(_isSaving
                  ? 'Guardando...'
                  : (_isEditing ? 'Guardar cambios' : 'Agregar a mi agenda')),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
