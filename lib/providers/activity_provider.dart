import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity.dart';
import '../services/activity_service.dart';

class ActivityState {
  final List<Activity> activities;
  final List<String> favoriteIds;
  final bool isLoading;
  final String? selectedCategory; // null = Todos
  final int selectedDayIndex; // 0 = Día 1, 1 = Día 2, 2 = Día 3

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

  ActivityNotifier(this._service) : super(ActivityState()) {
    loadActivities();
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
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  // Filtrar por categoría
  void setCategoryFilter(String? category) {
    if (category == null) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategory: category);
    }
  }

  // Cambiar día seleccionado
  void setDayIndex(int index) {
    state = state.copyWith(selectedDayIndex: index);
  }

  // Toggle de favorito
  Future<void> toggleFavorite(String id) async {
    final updatedFavs = await _service.toggleFavorite(id);
    state = state.copyWith(favoriteIds: updatedFavs);
  }
}

// Provider de ActivityService
final activityServiceProvider = Provider<ActivityService>((ref) {
  return ActivityService();
});

// Provider del estado de actividades
final activityProvider = StateNotifierProvider<ActivityNotifier, ActivityState>((ref) {
  final service = ref.watch(activityServiceProvider);
  return ActivityNotifier(service);
});

// Provider para destacar una actividad en el mapa
final selectedMapActivityProvider = StateProvider<Activity?>((ref) => null);
