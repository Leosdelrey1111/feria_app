import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../models/activity.dart';
import '../../providers/activity_provider.dart';
import '../../theme/app_theme.dart';

// Modelo para puntos fijos del mapa (Servicios)
class MapPOI {
  final String id;
  final String name;
  final String type; // Baños, Comida, Primeros Auxilios, Salidas de emergencia, Escenarios
  final double mapX;
  final double mapY;

  MapPOI({
    required this.id,
    required this.name,
    required this.type,
    required this.mapX,
    required this.mapY,
  });
}

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final TransformationController _transformationController = TransformationController();
  final _searchController = TextEditingController();
  
  // Filtros activos
  final Set<String> _activeFilters = {
    'Escenarios', 'Baños', 'Comida', 'Primeros Auxilios', 'Salidas de emergencia'
  };

  // Estado de descarga mock
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  // Ubicación del usuario simulada/real
  Position? _userPosition;
  bool _gettingLocation = false;
  double? _userMapX;
  double? _userMapY;

  // Lista de POIs del recinto
  final List<MapPOI> _pointsOfInterest = [
    MapPOI(id: 'poi-b1', name: 'Sanitarios Zona Norte', type: 'Baños', mapX: 0.15, mapY: 0.15),
    MapPOI(id: 'poi-b2', name: 'Sanitarios Zona Central', type: 'Baños', mapX: 0.90, mapY: 0.40),
    MapPOI(id: 'poi-e1', name: 'Foro Principal (Escenario A)', type: 'Escenarios', mapX: 0.25, mapY: 0.35),
    MapPOI(id: 'poi-e2', name: 'Teatro del Pueblo (Foro B)', type: 'Escenarios', mapX: 0.20, mapY: 0.60),
    MapPOI(id: 'poi-e3', name: 'Pabellón Tecnológico', type: 'Escenarios', mapX: 0.75, mapY: 0.20),
    MapPOI(id: 'poi-e4', name: 'Zona Cultural y Talleres', type: 'Escenarios', mapX: 0.40, mapY: 0.75),
    MapPOI(id: 'poi-c1', name: 'Terraza Gourmet', type: 'Comida', mapX: 0.85, mapY: 0.65),
    MapPOI(id: 'poi-pa1', name: 'Puesto de Auxilio 1', type: 'Primeros Auxilios', mapX: 0.50, mapY: 0.85),
    MapPOI(id: 'poi-se1', name: 'Salida de Emergencia A', type: 'Salidas de emergencia', mapX: 0.10, mapY: 0.85),
    MapPOI(id: 'poi-se2', name: 'Salida de Emergencia B', type: 'Salidas de emergencia', mapX: 0.90, mapY: 0.15),
  ];

  @override
  void initState() {
    super.initState();
    // Inicializar zoom centrado en el medio del mapa
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _transformationController.value = Matrix4.identity()
        ..translate(-120.0, -120.0)
        ..scale(1.3);
      _checkSelectedActivityFocus();
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Si venimos de la pantalla de detalle, enfocar la actividad preseleccionada
  void _checkSelectedActivityFocus() {
    final selectedAct = ref.read(selectedMapActivityProvider);
    if (selectedAct != null) {
      setState(() {
        // Asegurarse de que el filtro de escenarios/actividades esté activo
        _activeFilters.add('Escenarios');
        _searchController.text = selectedAct.title;
      });

      // Mover el mapa para centrarlo en la actividad (coordenadas relativas a un mapa de 800x800)
      final targetX = selectedAct.mapX * 800;
      final targetY = selectedAct.mapY * 800;

      // Calcular translación para centrar en pantalla (asumiendo viewport promedio de 360x500)
      const viewportW = 360.0;
      const viewportH = 500.0;
      const scale = 1.6;

      final transX = (viewportW / 2) - (targetX * scale);
      final transY = (viewportH / 2) - (targetY * scale);

      _transformationController.value = Matrix4.identity()
        ..translate(transX, transY)
        ..scale(scale);

      // Limpiar para que no re-centre al cambiar de pantalla
      Future.delayed(const Duration(milliseconds: 500), () {
        ref.read(selectedMapActivityProvider.notifier).state = null;
      });
    }
  }

  // Obtener geolocalización real (o simular en mapa esquemático)
  Future<void> _getUserLocation() async {
    setState(() {
      _gettingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Los servicios de ubicación están deshabilitados.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Permiso de ubicación denegado.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Los permisos de ubicación están denegados permanentemente.';
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _userPosition = position;
        // Asignar una ubicación de prueba fija dentro del recinto de la feria
        _userMapX = 0.52;
        _userMapY = 0.48;
        _gettingLocation = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ubicación GPS obtenida. Se ha posicionado tu pin en el recinto.')),
        );
      }
    } catch (e) {
      setState(() {
        _gettingLocation = false;
        // Simulamos ubicación del usuario por seguridad de compilación/demo
        _userMapX = 0.52;
        _userMapY = 0.48;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Simulando ubicación en el recinto (GPS desactivado/error): $e'),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        );
      }
    }
  }

  // Simular descarga de mapa offline
  void _downloadMapOffline() {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _downloadProgress += 0.1;
        if (_downloadProgress >= 1.0) {
          _downloadProgress = 1.0;
          _isDownloading = false;
          timer.cancel();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Mapa descargado con éxito! Disponible sin conexión.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activityState = ref.watch(activityProvider);
    const double mapSize = 800.0;

    // Antes solo se marcaban en el mapa las actividades EN VIVO (isLive),
    // así que casi siempre solo aparecía la Inauguración. Ahora se muestran
    // TODAS las actividades programadas para el día de hoy: las que están
    // en curso con el pin "LIVE" animado, y las próximas del día con un pin
    // "Próximo" que incluye su hora de inicio.
    final now = DateTime.now();
    final todayActivities = activityState.activities.where((act) {
      return act.startTime.year == now.year &&
          act.startTime.month == now.month &&
          act.startTime.day == now.day;
    }).toList();

    final liveActivities = todayActivities.where((act) => act.isLive).toList();
    final upcomingTodayActivities =
        todayActivities.where((act) => !act.isLive).toList();

    // Filtrar puntos del mapa a renderizar basados en filtros seleccionados y búsqueda
    final query = _searchController.text.toLowerCase();
    
    final filteredPOIs = _pointsOfInterest.where((poi) {
      if (!_activeFilters.contains(poi.type)) return false;
      if (query.isNotEmpty && !poi.name.toLowerCase().contains(query)) return false;
      return true;
    }).toList();

    // Actividades asociadas a escenarios si se filtran escenarios
    final filteredLiveActPines = liveActivities.where((act) {
      if (!_activeFilters.contains('Escenarios')) return false;
      if (query.isNotEmpty && !act.title.toLowerCase().contains(query)) return false;
      return true;
    }).toList();

    final filteredUpcomingActPines = upcomingTodayActivities.where((act) {
      if (!_activeFilters.contains('Escenarios')) return false;
      if (query.isNotEmpty && !act.title.toLowerCase().contains(query)) return false;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa del Recinto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_for_offline_outlined),
            onPressed: _isDownloading ? null : _downloadMapOffline,
          ),
          IconButton(
            icon: _gettingLocation 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
            onPressed: _gettingLocation ? null : _getUserLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Buscador y Chips de filtros
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Buscador
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar stand, escenario o servicios...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: theme.brightness == Brightness.dark
                        ? Colors.grey[900]
                        : Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (val) => setState(() {}),
                ),
              ),

              // Chips de filtros
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    'Escenarios', 'Baños', 'Comida', 'Primeros Auxilios', 'Salidas de emergencia'
                  ].map((filter) {
                    final isSelected = _activeFilters.contains(filter);
                    IconData icon = Icons.info_outline;
                    switch (filter) {
                      case 'Escenarios': icon = Icons.festival_rounded; break;
                      case 'Baños': icon = Icons.wc; break;
                      case 'Comida': icon = Icons.restaurant; break;
                      case 'Primeros Auxilios': icon = Icons.medical_services_rounded; break;
                      case 'Salidas de emergencia': icon = Icons.exit_to_app_rounded; break;
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : null),
                        label: Text(filter),
                        selected: isSelected,
                        selectedColor: theme.colorScheme.primary,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : null,
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _activeFilters.add(filter);
                            } else {
                              _activeFilters.remove(filter);
                            }
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),

              // Canvas del Mapa en un espacio expandido
              Expanded(
                child: ClipRect(
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.5,
                    maxScale: 3.5,
                    boundaryMargin: const EdgeInsets.all(300),
                    child: Stack(
                      children: [
                        // Capa base: El plano esquemático dibujado
                        CustomPaint(
                          size: const Size(mapSize, mapSize),
                          painter: FairMapPainter(
                            isDark: theme.brightness == Brightness.dark,
                            primaryColor: theme.colorScheme.primary,
                            secondaryColor: AppTheme.secondaryColor,
                          ),
                        ),

                        // Pines de Puntos de Interés
                        ...filteredPOIs.map((poi) {
                          IconData pinIcon = Icons.location_on;
                          Color pinColor = theme.colorScheme.primary;

                          switch (poi.type) {
                            case 'Baños':
                              pinIcon = Icons.wc;
                              pinColor = Colors.blue;
                              break;
                            case 'Comida':
                              pinIcon = Icons.restaurant;
                              pinColor = Colors.orange;
                              break;
                            case 'Primeros Auxilios':
                              pinIcon = Icons.medical_services_rounded;
                              pinColor = Colors.red;
                              break;
                            case 'Salidas de emergencia':
                              pinIcon = Icons.exit_to_app_rounded;
                              pinColor = Colors.green;
                              break;
                            case 'Escenarios':
                              pinIcon = Icons.festival_rounded;
                              pinColor = theme.colorScheme.primary;
                              break;
                          }

                          return Positioned(
                            left: poi.mapX * mapSize - 16,
                            top: poi.mapY * mapSize - 32,
                            child: _mapMarker(
                              title: poi.name,
                              type: poi.type,
                              icon: pinIcon,
                              color: pinColor,
                            ),
                          );
                        }).toList(),

                        // Pines de Actividades próximas del día (no en vivo todavía)
                        ...filteredUpcomingActPines.map((act) {
                          return Positioned(
                            left: act.mapX * mapSize - 16,
                            top: act.mapY * mapSize - 34,
                            child: _upcomingActivityMarker(
                              act: act,
                              theme: theme,
                            ),
                          );
                        }).toList(),

                        // Pines de Actividades En Vivo (destacadas e intermitentes)
                        ...filteredLiveActPines.map((act) {
                          return Positioned(
                            left: act.mapX * mapSize - 18,
                            top: act.mapY * mapSize - 36,
                            child: _liveActivityMarker(
                              act: act,
                              theme: theme,
                            ),
                          );
                        }).toList(),

                        // Pin del usuario
                        if (_userMapX != null && _userMapY != null)
                          Positioned(
                            left: _userMapX! * mapSize - 12,
                            top: _userMapY! * mapSize - 12,
                            child: _userLocationPin(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 2. Barra de descarga de mapa offline overlay
          if (_isDownloading)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.downloading, color: Colors.blue, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Descargando mapa sin conexión...',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(value: _downloadProgress),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text('${(_downloadProgress * 100).toInt()}%'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Widget para marcador genérico
  Widget _mapMarker({
    required String title,
    required String type,
    required IconData icon,
    required Color color,
  }) {
    return Tooltip(
      message: '$title ($type)',
      triggerMode: TooltipTriggerMode.tap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              title.length > 12 ? '${title.substring(0, 10)}..' : title,
              style: const TextStyle(color: Colors.white, fontSize: 8),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para marcador de Actividades en curso (LIVE!)
  Widget _liveActivityMarker({
    required Activity act,
    required ThemeData theme,
  }) {
    return GestureDetector(
      onTap: () {
        context.push('/activity/${act.id}');
      },
      child: Tooltip(
        message: '¡En Vivo!: ${act.title}',
        triggerMode: TooltipTriggerMode.tap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animación estática de pulso rojo simulado
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 3,
                  ),
                ],
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.flash_on, size: 18, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget para marcador de Actividades próximas de hoy (aún no en vivo)
  Widget _upcomingActivityMarker({
    required Activity act,
    required ThemeData theme,
  }) {
    final timeLabel =
        '${act.startTime.hour.toString().padLeft(2, '0')}:${act.startTime.minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: () {
        context.push('/activity/${act.id}');
      },
      child: Tooltip(
        message: '${act.title} · $timeLabel',
        triggerMode: TooltipTriggerMode.tap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.schedule, size: 14, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                timeLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pin de ubicación del usuario
  Widget _userLocationPin() {
    return Tooltip(
      message: 'Tu Ubicación',
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.6),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Pintor personalizado para el plano esquemático
class FairMapPainter extends CustomPainter {
  final bool isDark;
  final Color primaryColor;
  final Color secondaryColor;

  FairMapPainter({
    required this.isDark,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = isDark ? const Color(0xFF1E1E2C) : const Color(0xFFEFEFEF);
    final streetPaint = Paint()
      ..color = isDark ? const Color(0xFF2C2C3E) : Colors.white
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final areaPaint = Paint()..style = PaintingStyle.fill;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // 1. Dibujar fondo de todo el recinto
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(24)),
      bgPaint,
    );

    // 2. Dibujar áreas verdes / zonas
    // Zona Cultural
    areaPaint.color = Colors.green.withOpacity(isDark ? 0.15 : 0.1);
    canvas.drawOval(Rect.fromLTWH(100, 450, 300, 250), areaPaint);

    // Pabellón Tecnológico
    areaPaint.color = primaryColor.withOpacity(isDark ? 0.15 : 0.08);
    canvas.drawRect(Rect.fromLTWH(500, 80, 240, 180), areaPaint);

    // Terraza Gourmet
    areaPaint.color = Colors.orange.withOpacity(isDark ? 0.15 : 0.1);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(550, 450, 200, 180), const Radius.circular(16)), areaPaint);

    // 3. Dibujar "Caminos" o Calles del recinto
    final path = Path()
      ..moveTo(80, 80)
      ..lineTo(720, 80)
      ..lineTo(720, 720)
      ..lineTo(80, 720)
      ..close()
      ..moveTo(80, 400)
      ..lineTo(720, 400)
      ..moveTo(400, 80)
      ..lineTo(400, 720);

    canvas.drawPath(path, streetPaint);

    // 4. Escribir nombres de zonas principales
    _drawLabel(canvas, textPainter, 'PABELLÓN TECNOLÓGICO', size.width * 0.75, size.height * 0.22, isDark);
    _drawLabel(canvas, textPainter, 'ZONA CULTURAL Y TALLERES', size.width * 0.40, size.height * 0.78, isDark);
    _drawLabel(canvas, textPainter, 'FORO PRINCIPAL A', size.width * 0.25, size.height * 0.38, isDark);
    _drawLabel(canvas, textPainter, 'TERRAZA GOURMET', size.width * 0.85, size.height * 0.68, isDark);
    _drawLabel(canvas, textPainter, 'CENTRO DEL RECINTO', size.width * 0.50, size.height * 0.48, isDark);
  }

  void _drawLabel(Canvas canvas, TextPainter tp, String text, double x, double y, bool isDark) {
    tp.text = TextSpan(
      text: text,
      style: TextStyle(
        color: isDark ? Colors.grey[600] : Colors.grey[500],
        fontWeight: FontWeight.bold,
        fontSize: 10,
        letterSpacing: 1.2,
      ),
    );
    tp.layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
