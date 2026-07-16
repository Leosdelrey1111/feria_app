class Activity {
  final String id;
  final String title;
  final String description;
  final String speaker;
  final String category; // Música, Concursos, Arte, Gastronomía, Infantil
  final DateTime startTime;
  final DateTime endTime;
  final String locationName;
  final bool isFeatured;
  final bool isLive;
  final double mapX; // Coordenada X relativa (0.0 a 1.0) para el mapa esquemático
  final double mapY; // Coordenada Y relativa (0.0 a 1.0) para el mapa esquemático

  // Actividades creadas por el propio usuario (no vienen del programa oficial
  // de la feria). Sirve para distinguirlas en la UI (ícono, opción de borrar)
  // y para que el servicio sepa cuáles puede eliminar con seguridad.
  final bool isCustom;

  Activity({
    required this.id,
    required this.title,
    required this.description,
    required this.speaker,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.locationName,
    required this.isFeatured,
    required this.isLive,
    required this.mapX,
    required this.mapY,
    this.isCustom = false,
  });

  // Helper para ver si la actividad ya pasó
  bool get hasEnded => DateTime.now().isAfter(endTime);

  // Formato para mostrar duración en minutos
  int get durationInMinutes => endTime.difference(startTime).inMinutes;

  Activity copyWith({
    String? id,
    String? title,
    String? description,
    String? speaker,
    String? category,
    DateTime? startTime,
    DateTime? endTime,
    String? locationName,
    bool? isFeatured,
    bool? isLive,
    double? mapX,
    double? mapY,
    bool? isCustom,
  }) {
    return Activity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      speaker: speaker ?? this.speaker,
      category: category ?? this.category,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      locationName: locationName ?? this.locationName,
      isFeatured: isFeatured ?? this.isFeatured,
      isLive: isLive ?? this.isLive,
      mapX: mapX ?? this.mapX,
      mapY: mapY ?? this.mapY,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  // ---------------------------------------------------------------------
  // Serialización (para guardar actividades personalizadas en
  // SharedPreferences como JSON, ya que el mock original solo vive en
  // memoria y se regenera en cada arranque).
  // ---------------------------------------------------------------------

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'speaker': speaker,
      'category': category,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'locationName': locationName,
      'isFeatured': isFeatured,
      'isLive': isLive,
      'mapX': mapX,
      'mapY': mapY,
      'isCustom': isCustom,
    };
  }

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      speaker: json['speaker'] as String,
      category: json['category'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      locationName: json['locationName'] as String,
      isFeatured: json['isFeatured'] as bool? ?? false,
      isLive: json['isLive'] as bool? ?? false,
      mapX: (json['mapX'] as num?)?.toDouble() ?? 0.5,
      mapY: (json['mapY'] as num?)?.toDouble() ?? 0.5,
      isCustom: json['isCustom'] as bool? ?? true,
    );
  }
}
