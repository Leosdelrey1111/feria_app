import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity.dart';

class ActivityService {
  static const String keyFavorites = 'favorite_activities';
  static const String keyCustomActivities = 'custom_activities_v1';
  // Ids de actividades OFICIALES que un administrador decidió eliminar.
  // No se puede borrar el generador de datos mock, así que en vez de eso
  // se guarda una lista de ids a excluir cada vez que se arma la agenda.
  static const String keyHiddenOfficialIds = 'hidden_official_activity_ids_v1';
  // Ediciones que un administrador hizo sobre actividades OFICIALES.
  // Se guardan aparte y se aplican encima del mock al construir la lista.
  static const String keyOfficialOverrides = 'official_activity_overrides_v1';

  // Genera actividades dinámicas para que siempre coincidan con el día de ejecución
  List<Activity> generateMockActivities() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dayAfter = today.add(const Duration(days: 2));

    return [
      Activity(
        id: 'act-01',
        title: 'Inauguración y Espectáculo de Luces',
        description: 'La gran ceremonia de apertura de la feria con pirotecnia fría, mapping tridimensional y música orquestal en vivo.',
        speaker: 'Patronato de la Feria',
        category: 'Música',
        startTime: now.subtract(const Duration(minutes: 15)), // En curso
        endTime: now.add(const Duration(minutes: 45)),
        locationName: 'Foro Principal (Escenario A)',
        isFeatured: true,
        isLive: true,
        mapX: 0.25,
        mapY: 0.35,
      ),
      Activity(
        id: 'act-02',
        title: 'Hackathon Juvenil de Robótica',
        description: 'Competencia donde jóvenes arman y programan robots para superar una pista de obstáculos con inteligencia artificial.',
        speaker: 'Dr. Alejandro Méndez (MIT)',
        category: 'Concursos',
        startTime: today.add(const Duration(hours: 15)), // 3:00 PM
        endTime: today.add(const Duration(hours: 18)),
        locationName: 'Pabellón Tecnológico',
        isFeatured: false,
        isLive: false,
        mapX: 0.75,
        mapY: 0.20,
      ),
      Activity(
        id: 'act-03',
        title: 'Taller de Escultura en Barro',
        description: 'Aprende las técnicas tradicionales de moldeado en barro con artesanos locales y llévate tu propia obra a casa.',
        speaker: 'Mtra. Elena Gómez',
        category: 'Arte',
        startTime: today.add(const Duration(hours: 16, minutes: 30)),
        endTime: today.add(const Duration(hours: 18, minutes: 0)),
        locationName: 'Zona Cultural y Talleres',
        isFeatured: false,
        isLive: false,
        mapX: 0.40,
        mapY: 0.75,
      ),
      Activity(
        id: 'act-04',
        title: 'Cata de Mezcal y Quesos Artesanales',
        description: 'Una experiencia gastronómica guiada para degustar los mejores mezcales del estado acompañados de quesos maduros.',
        speaker: 'Sommelier Roberto Ruiz',
        category: 'Gastronomía',
        startTime: today.add(const Duration(hours: 19, minutes: 0)),
        endTime: today.add(const Duration(hours: 21, minutes: 0)),
        locationName: 'Terraza Gourmet',
        isFeatured: false,
        isLive: false,
        mapX: 0.85,
        mapY: 0.65,
      ),
      Activity(
        id: 'act-05',
        title: 'Show de Títeres Gigantes',
        description: 'Espectáculo infantil con títeres gigantes y música interactiva que narra leyendas tradicionales de la región.',
        speaker: 'Compañía La Carpa Mágica',
        category: 'Infantil',
        startTime: today.add(const Duration(hours: 12, minutes: 0)),
        endTime: today.add(const Duration(hours: 13, minutes: 0)),
        locationName: 'Teatro del Pueblo (Foro B)',
        isFeatured: false,
        isLive: false,
        mapX: 0.20,
        mapY: 0.60,
      ),
      Activity(
        id: 'act-06',
        title: 'Concierto Estelar: Mariachi Sinfónico',
        description: 'Un ensamble espectacular que combina la música tradicional del mariachi con los arreglos de la orquesta sinfónica del estado.',
        speaker: 'Mariachi Imperial & Orquesta Sinfónica',
        category: 'Música',
        startTime: today.add(const Duration(hours: 21, minutes: 30)),
        endTime: today.add(const Duration(hours: 23, minutes: 30)),
        locationName: 'Foro Principal (Escenario A)',
        isFeatured: true,
        isLive: false,
        mapX: 0.25,
        mapY: 0.35,
      ),
      // Mañana (Día 2)
      Activity(
        id: 'act-07',
        title: 'Final Torneo de Videojuegos (Smash Bros)',
        description: 'La gran final presencial en pantalla gigante del torneo local. Ven a apoyar a los mejores jugadores de la ciudad.',
        speaker: 'E-Sports México',
        category: 'Concursos',
        startTime: tomorrow.add(const Duration(hours: 11, minutes: 0)),
        endTime: tomorrow.add(const Duration(hours: 14, minutes: 0)),
        locationName: 'Pabellón Tecnológico',
        isFeatured: false,
        isLive: false,
        mapX: 0.75,
        mapY: 0.20,
      ),
      Activity(
        id: 'act-08',
        title: 'Galería Abierta de Arte Urbano',
        description: 'Muestra colectiva de grafiti en vivo y muralismo urbano. Artistas locales pintarán lienzos gigantes en tiempo real.',
        speaker: 'Colectivo Graffiti-Arte',
        category: 'Arte',
        startTime: tomorrow.add(const Duration(hours: 14, minutes: 0)),
        endTime: tomorrow.add(const Duration(hours: 18, minutes: 0)),
        locationName: 'Zona Cultural y Talleres',
        isFeatured: false,
        isLive: false,
        mapX: 0.40,
        mapY: 0.75,
      ),
      // Pasado mañana (Día 3)
      Activity(
        id: 'act-09',
        title: 'Masterclass: Antojitos Mexicanos',
        description: 'Aprende los secretos para preparar las mejores salsas, tlacoyos y garnachas tradicionales de la mano de una cocinera tradicional.',
        speaker: 'Chef Juanita Domínguez',
        category: 'Gastronomía',
        startTime: dayAfter.add(const Duration(hours: 13, minutes: 0)),
        endTime: dayAfter.add(const Duration(hours: 14, minutes: 30)),
        locationName: 'Terraza Gourmet',
        isFeatured: false,
        isLive: false,
        mapX: 0.85,
        mapY: 0.65,
      ),
      Activity(
        id: 'act-10',
        title: 'Búsqueda del Tesoro Tecnológico',
        description: 'Una dinámica familiar donde, usando códigos QR escondidos en toda la feria, los niños descifrarán pistas mecánicas.',
        speaker: 'Staff de Mi Feria Inteligente',
        category: 'Infantil',
        startTime: dayAfter.add(const Duration(hours: 10, minutes: 0)),
        endTime: dayAfter.add(const Duration(hours: 12, minutes: 0)),
        locationName: 'Todo el Recinto (Salida de Teatro del Pueblo)',
        isFeatured: false,
        isLive: false,
        mapX: 0.50,
        mapY: 0.50,
      ),
    ];
  }

  // Obtener actividades: combina el programa oficial (mock, con las
  // ediciones de administrador ya aplicadas) con las actividades
  // personalizadas del usuario, excluyendo las oficiales que un
  // administrador haya eliminado, y ordena todo cronológicamente.
  Future<List<Activity>> getActivities() async {
    await Future.delayed(const Duration(milliseconds: 400));
    final prefs = await SharedPreferences.getInstance();

    final hiddenIds = (prefs.getStringList(keyHiddenOfficialIds) ?? []).toSet();
    final overrides = await _loadOfficialOverrides(prefs);

    final official = generateMockActivities()
        .where((a) => !hiddenIds.contains(a.id))
        .map((a) => overrides.containsKey(a.id) ? overrides[a.id]! : a)
        .toList();

    final custom = await getCustomActivities();
    final all = [...official, ...custom];
    all.sort((a, b) => a.startTime.compareTo(b.startTime));
    return all;
  }

  // Cargar favoritos
  Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(keyFavorites) ?? [];
  }

  // Toggle de favorito
  Future<List<String>> toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(keyFavorites) ?? [];
    if (favorites.contains(id)) {
      favorites.remove(id);
    } else {
      favorites.add(id);
    }
    await prefs.setStringList(keyFavorites, favorites);
    return favorites;
  }

  // ---------------------------------------------------------------------
  // Actividades personalizadas (tareas creadas por el usuario)
  // ---------------------------------------------------------------------
  //
  // Se guardan como una lista de objetos JSON en SharedPreferences, bajo
  // `keyCustomActivities`. El programa oficial (generateMockActivities)
  // nunca se toca ni se persiste: siempre se regenera en memoria. Así,
  // "reiniciar" el mock no borra lo que el usuario agregó por su cuenta.

  Future<List<Activity>> getCustomActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(keyCustomActivities) ?? [];
    return raw
        .map((jsonStr) => Activity.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveCustomActivities(List<Activity> activities) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = activities.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(keyCustomActivities, raw);
  }

  // Crear una nueva actividad/tarea personalizada
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
    final custom = await getCustomActivities();
    final now = DateTime.now();
    final newActivity = Activity(
      // Prefijo 'custom-' para nunca chocar con los ids del mock (act-XX)
      // y para poder identificar de forma segura qué se puede borrar.
      id: 'custom-${now.millisecondsSinceEpoch}',
      title: title,
      description: description,
      speaker: speaker.isEmpty ? 'Agregado por ti' : speaker,
      category: category,
      startTime: startTime,
      endTime: endTime,
      locationName: locationName,
      isFeatured: false,
      isLive: now.isAfter(startTime) && now.isBefore(endTime),
      mapX: mapX,
      mapY: mapY,
      isCustom: true,
    );
    custom.add(newActivity);
    await _saveCustomActivities(custom);
    return newActivity;
  }

  // Editar una actividad existente. Si es personalizada ('custom-'), se
  // actualiza en su propia lista. Si es del programa oficial ('act-XX'),
  // se guarda como un "override" que se aplica encima del mock.
  // Quién puede llamar esto se decide en la capa de arriba (solo admin).
  Future<void> updateActivity(Activity updated) async {
    if (updated.id.startsWith('custom-')) {
      final custom = await getCustomActivities();
      final index = custom.indexWhere((a) => a.id == updated.id);
      if (index != -1) {
        custom[index] = updated;
        await _saveCustomActivities(custom);
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final overrides = await _loadOfficialOverrides(prefs);
      overrides[updated.id] = updated;
      await _saveOfficialOverrides(prefs, overrides);
    }
  }

  // Eliminar una actividad. Si es personalizada, se quita de su lista.
  // Si es del programa oficial, se agrega a la lista de ocultas (no se
  // puede borrar el generador mock, así que se excluye al armar la agenda).
  // Quién puede llamar esto se decide en la capa de arriba (solo admin).
  Future<void> deleteActivity(String id) async {
    final prefs = await SharedPreferences.getInstance();

    if (id.startsWith('custom-')) {
      final custom = await getCustomActivities();
      custom.removeWhere((a) => a.id == id);
      await _saveCustomActivities(custom);
    } else {
      final hiddenIds = (prefs.getStringList(keyHiddenOfficialIds) ?? []).toList();
      if (!hiddenIds.contains(id)) {
        hiddenIds.add(id);
        await prefs.setStringList(keyHiddenOfficialIds, hiddenIds);
      }
    }

    // También se limpia de favoritos si estaba marcada
    final favorites = prefs.getStringList(keyFavorites) ?? [];
    if (favorites.remove(id)) {
      await prefs.setStringList(keyFavorites, favorites);
    }
  }

  Future<Map<String, Activity>> _loadOfficialOverrides(SharedPreferences prefs) async {
    final raw = prefs.getStringList(keyOfficialOverrides) ?? [];
    final map = <String, Activity>{};
    for (final jsonStr in raw) {
      final activity = Activity.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      map[activity.id] = activity;
    }
    return map;
  }

  Future<void> _saveOfficialOverrides(SharedPreferences prefs, Map<String, Activity> overrides) async {
    final raw = overrides.values.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(keyOfficialOverrides, raw);
  }
}
