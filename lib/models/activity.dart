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
  });

  // Helper para ver si la actividad ya pasó
  bool get hasEnded => DateTime.now().isAfter(endTime);

  // Formato para mostrar duración en minutos
  int get durationInMinutes => endTime.difference(startTime).inMinutes;
}
