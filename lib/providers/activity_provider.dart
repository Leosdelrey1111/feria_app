import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity.dart';
import '../services/activity_service.dart';
import '../services/watch_sync_service.dart';
import 'watch_sync_provider.dart';

class ActivityState {
  final List<Activity> activities;
  final List<String> favoriteIds;
  final bool isLoading;
  final String? selectedCategory; // null = Todos
  final int selectedDayIndex; // 0 = DÃ­a 1, 1 = DÃ­a 2, 2 = DÃ­a 3

  ActivityState({
    this.activities = const [],
    this.favoriteIds = const [],
    this.isLoading = false,
    this.selectedCategory,
    this.selectedDayIndex = 0,
  });

  ActivityState copyWith({
    List<Activity>? activities,
    List<String>? favoriteIds,
    bool? isLoading,
    String? selectedCategory,
    bool clearCategory = false,
    int? selectedDayIndex,
  }) {
    return ActivityState(
      activities: activities ?? this.activities,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      isLoading: isLoading ?? this.isLoading,
      selectedCategory: clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      selectedDayIndex: selectedDayIndex ?? this.selectedDayIndex,
    );
  }
}

class ActivityNotifier extends StateNotifier<ActivityState> {
  final ActivityService _service;
  final WatchSyncService _watchSyncService;

  ActivityNotifier(this._service, this._watchSyncService) : super(ActivityState()) {
    loadActivities();
  }

  // Sincronizar favoritos con el reloj
  void syncFavoritesToWatch() {
    final favList = state.activities.where((act) => state.favoriteIds.contains(act.id)).map((act) {
      String icon = 'ðŸ“…';
      switch (act.category) {
        case 'MÃºsica': icon = 'ðŸŽµ'; break;
        case 'Concursos': icon = 'ðŸ†'; break;
        case 'Arte': icon = 'ðŸŽ­'; break;
        case 'GastronomÃ­a': icon = 'ðŸ²'; break;
        case 'Infantil': icon = 'ðŸŽˆ'; break;
      }
      
      final now = DateTime.now();
      String statusStr = 'upcoming';
      if (now.isAfter(act.endTime)) {
        statusStr = 'finished';
      } else if (now.isAfter(act.startTime) && now.isBefore(act.endTime)) {
        statusStr = 'ongoing';
      }

      String pad(int value) => value.toString().padLeft(2, '0');
      final timeStr = '${pad(act.startTime.hour)}:${pad(act.startTime.minute)}';
      final endTimeStr = '${pad(act.endTime.hour)}:${pad(act.endTime.minute)}';

      return {
        'id': act.id,
        'name': act.title,
        'shortName': act.title,
        'location': act.locationName,
        'time': timeStr,
        'endTime': endTimeStr,
        'duration': '${act.durationInMinutes} min',
        'status': statusStr,
        'icon': icon,
          'mapX': act.mapX,
          'mapY': act.mapY,
        };
    }).toList();

    _watchSyncService.sendMessage({
      'type': 'favorites',
      'favorites': favList,
    });
  }

  // Cargar actividades y favoritos
  Future<void> loadActivities() async {
    state = state.copyWith(isLoading: true);
    try {
      final list = await _service.getActivities();
      final favs = await _service.getFavorites();
      state = state.copyWith(
        activities: list,
        favoriteIds: favs,
        isLoading: false,
      );
      syncFavoritesToWatch();
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  // Filtrar por categorÃ­a
  void setCategoryFilter(String? category) {
    if (category == null) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategory: category);
    }
  }

  // Cambiar dÃ­a seleccionado
  void setDayIndex(int index) {
    state = state.copyWith(selectedDayIndex: index);
  }

  // Toggle de favorito
  Future<void> toggleFavorite(String id) async {
    final updatedFavs = await _service.toggleFavorite(id);
    state = state.copyWith(favoriteIds: updatedFavs);
    syncFavoritesToWatch();
  }

  // Crear una actividad/tarea personalizada y recargar la lista
  Future<Activity> createActivity({
    required String title,
    required String description,
    required String speaker,
    required String category,
    required DateTime startTime,
    required DateTime endTime,
    required String locationName,
    double mapX = 0.5,
    double mapY = 0.5,
  }) async {
    final created = await _service.createActivity(
      title: title,
      description: description,
      speaker: speaker,
      category: category,
      startTime: startTime,
      endTime: endTime,
      locationName: locationName,
      mapX: mapX,
      mapY: mapY,
    );
    await loadActivities();
    return created;
  }

  // Editar una actividad (personalizada u oficial) y recargar la lista.
  // El control de quiÃ©n puede llamar esto (solo admin) vive en la UI.
  Future<void> updateActivity(Activity updated) async {
    await _service.updateActivity(updated);
    await loadActivities();
  }

  // Eliminar una actividad/tarea personalizada y recargar la lista
  Future<void> deleteActivity(String id) async {
    await _service.deleteActivity(id);
    await loadActivities();
  }
}

// Provider de ActivityService
final activityServiceProvider = Provider<ActivityService>((ref) {
  return ActivityService();
});

// Provider del estado de actividades
final activityProvider = StateNotifierProvider<ActivityNotifier, ActivityState>((ref) {
  final service = ref.watch(activityServiceProvider);
  final syncService = ref.watch(watchSyncServiceProvider);
  return ActivityNotifier(service, syncService);
});

// Provider para destacar una actividad en el mapa
final selectedMapActivityProvider = StateProvider<Activity?>((ref) => null);


