import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../theme/theme.dart';

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

class _MapScreenState extends ConsumerState<MapScreen> with TickerProviderStateMixin {
  static const double mapSize = 900.0;

  final TransformationController _transformationController = TransformationController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  // Filtros activos
  final Set<String> _activeFilters = {
    'Escenarios', 'Baños', 'Comida', 'Primeros Auxilios', 'Salidas de emergencia'
  };

  // Estado de descarga mock
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  // Ubicación del usuario simulada/real
  bool _gettingLocation = false;
  double? _userMapX;
  double? _userMapY;

  // Tamaño real del viewport donde se dibuja el mapa (para centrar bien
  // sin importar el tamaño de pantalla del dispositivo).
  Size _viewportSize = const Size(360, 640);

  // Animación de "radar" para las actividades en vivo
  late final AnimationController _pulseController;

  // Animación suave de cámara (zoom/paneo) en vez de saltos instantáneos
  late final AnimationController _cameraController;
  late final CurvedAnimation _cameraCurve;
  Matrix4Tween? _cameraTween;

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

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _cameraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _cameraCurve = CurvedAnimation(parent: _cameraController, curve: Curves.easeInOutCubic);
    _cameraController.addListener(() {
      if (_cameraTween != null) {
        _transformationController.value = _cameraTween!.evaluate(_cameraCurve);
      }
    });

    _searchFocusNode.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _transformationController.value = Matrix4.identity()
        ..translate(-180.0, -180.0)
        ..scale(1.25);
      _checkSelectedActivityFocus();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cameraController.dispose();
    _transformationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Cámara: zoom y centrado animados (en vez de saltos instantáneos)
  // ---------------------------------------------------------------------

  void _animateToMatrix(Matrix4 target) {
    _cameraTween = Matrix4Tween(begin: _transformationController.value, end: target);
    _cameraController.forward(from: 0);
  }

  // Centra suavemente la cámara sobre un punto de la escena (coordenadas
  // 0.0–1.0 relativas al mapa) con un nivel de zoom dado.
  void _animateCameraToScenePoint(double relX, double relY, {double scale = 1.7}) {
    final targetX = relX * mapSize;
    final targetY = relY * mapSize;
    final viewportW = _viewportSize.width;
    final viewportH = _viewportSize.height;
    final transX = (viewportW / 2) - (targetX * scale);
    final transY = (viewportH / 2) - (targetY * scale);
    final target = Matrix4.identity()
      ..translate(transX, transY)
      ..scale(scale);
    _animateToMatrix(target);
  }

  // Zoom con botones +/-, manteniendo fijo el centro de la pantalla actual
  void _zoomBy(double factor) {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final newScale = (currentScale * factor).clamp(0.5, 3.5);
    final effectiveFactor = newScale / currentScale;
    final centerX = _viewportSize.width / 2;
    final centerY = _viewportSize.height / 2;
    final zoomMatrix = Matrix4.identity()
      ..translate(centerX, centerY)
      ..scale(effectiveFactor)
      ..translate(-centerX, -centerY);
    final target = zoomMatrix.multiplied(_transformationController.value);
    _animateToMatrix(target);
  }

  void _resetView() {
    _animateToMatrix(
      Matrix4.identity()
        ..translate(-180.0, -180.0)
        ..scale(1.25),
    );
  }

  // Si venimos de la pantalla de detalle, enfocar la actividad preseleccionada
  void _checkSelectedActivityFocus() {
    final selectedAct = ref.read(selectedMapActivityProvider);
    if (selectedAct != null) {
      setState(() {
        _activeFilters.add('Escenarios');
        _searchController.text = selectedAct.title;
      });
      _animateCameraToScenePoint(selectedAct.mapX, selectedAct.mapY, scale: 1.7);

      Future.delayed(const Duration(milliseconds: 500), () {
        ref.read(selectedMapActivityProvider.notifier).state = null;
      });
    }
  }

  // Obtener geolocalización real (o simular en mapa esquemático)
  Future<void> _getUserLocation() async {
    setState(() => _gettingLocation = true);

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

      await Geolocator.getCurrentPosition();
      setState(() {
        _userMapX = 0.52;
        _userMapY = 0.48;
        _gettingLocation = false;
      });
      _animateCameraToScenePoint(_userMapX!, _userMapY!, scale: 1.8);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ubicación GPS obtenida. Se ha posicionado tu pin en el recinto.')),
        );
      }
    } catch (e) {
      setState(() {
        _gettingLocation = false;
        _userMapX = 0.52;
        _userMapY = 0.48;
      });
      _animateCameraToScenePoint(_userMapX!, _userMapY!, scale: 1.8);
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

  // ---------------------------------------------------------------------
  // Hojas de detalle (reemplazan a los Tooltip, mucho más legibles)
  // ---------------------------------------------------------------------

  void _showPoiSheet(MapPOI poi) {
    final theme = Theme.of(context);
    final style = _styleForType(poi.type, theme);
    _showDetailSheet(
      icon: style.icon,
      color: style.color,
      title: poi.name,
      subtitle: poi.type,
      actions: [
        _sheetActionButton(
          label: 'Centrar aquí',
          icon: Icons.center_focus_strong,
          color: style.color,
          onTap: () {
            Navigator.pop(context);
            _animateCameraToScenePoint(poi.mapX, poi.mapY, scale: 2.0);
          },
        ),
      ],
    );
  }

  void _showActivitySheet(Activity act, {required bool isLive}) {
    final theme = Theme.of(context);
    final color = isLive ? Colors.redAccent : theme.colorScheme.secondary;
    final timeLabel =
        '${act.startTime.hour.toString().padLeft(2, '0')}:${act.startTime.minute.toString().padLeft(2, '0')}'
        ' - ${act.endTime.hour.toString().padLeft(2, '0')}:${act.endTime.minute.toString().padLeft(2, '0')}';
    _showDetailSheet(
      icon: isLive ? Icons.flash_on : Icons.schedule,
      color: color,
      title: act.title,
      subtitle: '${act.category} · $timeLabel${act.isCustom ? ' · Tu actividad' : ''}',
      badgeText: isLive ? 'EN VIVO' : null,
      actions: [
        _sheetActionButton(
          label: 'Ver detalle',
          icon: Icons.info_outline,
          color: color,
          onTap: () {
            Navigator.pop(context);
            context.push('/activity/${act.id}');
          },
        ),
        _sheetActionButton(
          label: 'Centrar aquí',
          icon: Icons.center_focus_strong,
          color: color,
          onTap: () {
            Navigator.pop(context);
            _animateCameraToScenePoint(act.mapX, act.mapY, scale: 2.0);
          },
        ),
      ],
    );
  }

  void _showDetailSheet({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    String? badgeText,
    required List<Widget> actions,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (badgeText != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                              child: Text(badgeText,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(children: actions.map((a) => Expanded(child: a)).toList()
                .expand((w) => [w, const SizedBox(width: 10)]).toList()..removeLast()),
          ],
        ),
      ),
    );
  }

  Widget _sheetActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _showLegendSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Leyenda del mapa', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _legendRow(Icons.festival_rounded, theme.colorScheme.primary, 'Escenario / punto oficial'),
            _legendRow(Icons.wc, Colors.blue, 'Baños'),
            _legendRow(Icons.restaurant, Colors.orange, 'Comida'),
            _legendRow(Icons.medical_services_rounded, Colors.red, 'Primeros auxilios'),
            _legendRow(Icons.exit_to_app_rounded, Colors.green, 'Salida de emergencia'),
            _legendRow(Icons.flash_on, Colors.redAccent, 'Actividad en vivo ahora'),
            _legendRow(Icons.schedule, theme.colorScheme.secondary, 'Próxima actividad de hoy'),
            _legendRow(Icons.person, Colors.amber, 'Actividad agregada por ti', isBadge: true),
            _legendRow(Icons.my_location, Colors.blueAccent, 'Tu ubicación'),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(IconData icon, Color color, String label, {bool isBadge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isBadge ? Colors.white : color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: isBadge ? Border.all(color: color, width: 1.4) : null,
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  _MarkerStyle _styleForType(String type, ThemeData theme) {
    switch (type) {
      case 'Baños':
        return _MarkerStyle(Icons.wc, Colors.blue);
      case 'Comida':
        return _MarkerStyle(Icons.restaurant, Colors.orange);
      case 'Primeros Auxilios':
        return _MarkerStyle(Icons.medical_services_rounded, Colors.red);
      case 'Salidas de emergencia':
        return _MarkerStyle(Icons.exit_to_app_rounded, Colors.green);
      case 'Escenarios':
      default:
        return _MarkerStyle(Icons.festival_rounded, theme.colorScheme.primary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activityState = ref.watch(activityProvider);

    final now = DateTime.now();
    final todayActivities = activityState.activities.where((act) {
      return act.startTime.year == now.year &&
          act.startTime.month == now.month &&
          act.startTime.day == now.day;
    }).toList();

    final liveActivities = todayActivities.where((act) => act.isLive).toList();
    final upcomingTodayActivities = todayActivities.where((act) => !act.isLive).toList();
    final favoriteActivities = activityState.activities.where((act) => activityState.favoriteIds.contains(act.id)).toList();

    final query = _searchController.text.toLowerCase().trim();

    final filteredPOIs = _pointsOfInterest.where((poi) {
      if (!_activeFilters.contains(poi.type)) return false;
      if (query.isNotEmpty && !poi.name.toLowerCase().contains(query)) return false;
      return true;
    }).toList();

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

    final filteredFavoriteActPines = favoriteActivities.where((act) {
      if (!_activeFilters.contains('Escenarios')) return false;
      if (query.isNotEmpty && !act.title.toLowerCase().contains(query)) return false;
      return true;
    }).toList();

    final List<Object> suggestions = [];
    if (query.isNotEmpty) {
      suggestions.addAll(filteredPOIs);
      suggestions.addAll([...filteredLiveActPines, ...filteredUpcomingActPines, ...filteredFavoriteActPines]);
    }
    final showSuggestions = _searchFocusNode.hasFocus && query.isNotEmpty && suggestions.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa del Recinto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Leyenda',
            onPressed: _showLegendSheet,
          ),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 6)),
                  ],
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.12), width: 1),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Buscar stand, escenario o servicios...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  setState(() => _searchController.clear());
                                  _searchFocusNode.unfocus();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: theme.brightness == Brightness.dark ? Colors.grey[900] : Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.4),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          'Escenarios', 'Baños', 'Comida', 'Primeros Auxilios', 'Salidas de emergencia'
                        ].map((filter) {
                          final isSelected = _activeFilters.contains(filter);
                          final style = _styleForType(filter, theme);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: FilterChip(
                              avatar: Icon(style.icon, size: 16, color: isSelected ? Colors.white : null),
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
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Canvas del Mapa
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _viewportSize = constraints.biggest;
                    return ClipRect(
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: 0.5,
                        maxScale: 3.5,
                        boundaryMargin: const EdgeInsets.all(300),
                        child: Stack(
                          children: [
                            CustomPaint(
                              size: const Size(mapSize, mapSize),
                              painter: FairMapPainter(
                                isDark: theme.brightness == Brightness.dark,
                                primaryColor: theme.colorScheme.primary,
                                secondaryColor: AppTheme.secondaryColor,
                              ),
                            ),

                            ...filteredPOIs.map((poi) {
                              final style = _styleForType(poi.type, theme);
                              return Positioned(
                                left: poi.mapX * mapSize - 16,
                                top: poi.mapY * mapSize - 32,
                                child: _popIn(_mapMarker(
                                  title: poi.name,
                                  icon: style.icon,
                                  color: style.color,
                                  onTap: () => _showPoiSheet(poi),
                                )),
                              );
                            }),

                            ...filteredUpcomingActPines.map((act) {
                              return Positioned(
                                left: act.mapX * mapSize - 16,
                                top: act.mapY * mapSize - 34,
                                child: _popIn(_upcomingActivityMarker(act: act, theme: theme)),
                              );
                            }),

                            ...filteredFavoriteActPines.map((act) {
                              return Positioned(
                                left: act.mapX * mapSize - 18,
                                top: act.mapY * mapSize - 38,
                                child: _popIn(_favoriteActivityMarker(act: act, theme: theme)),
                              );
                            }),

                            ...filteredLiveActPines.map((act) {
                              return Positioned(
                                left: act.mapX * mapSize - 20,
                                top: act.mapY * mapSize - 40,
                                child: _popIn(_liveActivityMarker(act: act)),
                              );
                            }),

                            if (_userMapX != null && _userMapY != null)
                              Positioned(
                                left: _userMapX! * mapSize - 12,
                                top: _userMapY! * mapSize - 12,
                                child: _userLocationPin(),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // Sugerencias de búsqueda (overlay flotante)
          if (showSuggestions)
            Positioned(
              left: 16,
              right: 16,
              top: 68,
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: suggestions.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = suggestions[index];
                      if (item is MapPOI) {
                        final style = _styleForType(item.type, theme);
                        return ListTile(
                          dense: true,
                          leading: Icon(style.icon, color: style.color),
                          title: Text(item.name),
                          subtitle: Text(item.type),
                          onTap: () {
                            _searchFocusNode.unfocus();
                            _animateCameraToScenePoint(item.mapX, item.mapY, scale: 2.0);
                          },
                        );
                      } else if (item is Activity) {
                        final isLive = item.isLive;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isLive ? Icons.flash_on : Icons.schedule,
                            color: isLive ? Colors.redAccent : theme.colorScheme.secondary,
                          ),
                          title: Text(item.title),
                          subtitle: Text(isLive ? 'En vivo ahora' : item.category),
                          onTap: () {
                            _searchFocusNode.unfocus();
                            _animateCameraToScenePoint(item.mapX, item.mapY, scale: 2.0);
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            ),

          // Controles de zoom estilo Google Maps
          Positioned(
            right: 16,
            bottom: _isDownloading ? 96 : 24,
            child: Column(
              children: [
                _mapControlButton(icon: Icons.add, onTap: () => _zoomBy(1.3)),
                const SizedBox(height: 8),
                _mapControlButton(icon: Icons.remove, onTap: () => _zoomBy(1 / 1.3)),
                const SizedBox(height: 8),
                _mapControlButton(icon: Icons.center_focus_weak, onTap: _resetView),
              ],
            ),
          ),

          if (filteredFavoriteActPines.isNotEmpty)
            Positioned(
              left: 16,
              bottom: _isDownloading ? 120 : 24,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 14, offset: const Offset(0, 6)),
                  ],
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      '${filteredFavoriteActPines.length} favorito${filteredFavoriteActPines.length == 1 ? '' : 's'} en el mapa',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),

          // Barra de descarga de mapa offline
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
                            const Text('Descargando mapa sin conexión...', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // Pequeña animación de "pop" al aparecer un marcador (entrada con rebote)
  Widget _popIn(Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.elasticOut,
      builder: (context, value, c) => Transform.scale(scale: value.clamp(0.0, 1.4), child: c),
      child: child,
    );
  }

  Widget _mapControlButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Theme.of(context).cardColor,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }

  Widget _customBadge() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.amber,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.3),
      ),
      child: const Icon(Icons.person, size: 8, color: Colors.black87),
    );
  }

  // Widget para marcador genérico de un POI
  Widget _mapMarker({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2))],
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(4)),
            child: Text(
              title.length > 12 ? '${title.substring(0, 10)}..' : title,
              style: const TextStyle(color: Colors.white, fontSize: 8),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para marcador de Actividades en curso (LIVE!) con animación de radar real
  Widget _liveActivityMarker({required Activity act}) {
    return GestureDetector(
      onTap: () => _showActivitySheet(act, isLive: true),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final t = _pulseController.value;
                    return Opacity(
                      opacity: (1 - t).clamp(0.0, 1.0) * 0.55,
                      child: Transform.scale(
                        scale: 0.6 + t * 1.0,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)],
                  ),
                  child: const Icon(Icons.flash_on, size: 18, color: Colors.white),
                ),
                if (act.isCustom)
                  Positioned(top: 0, right: 0, child: _customBadge()),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
            child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _favoriteActivityMarker({required Activity act, required ThemeData theme}) {
    return GestureDetector(
      onTap: () => _showActivitySheet(act, isLive: act.isLive),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.amber,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.35), blurRadius: 8, spreadRadius: 1)],
            ),
            child: const Icon(Icons.star_rounded, size: 16, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              act.title.length > 12 ? '${act.title.substring(0, 10)}..' : act.title,
              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para marcador de Actividades próximas de hoy (aún no en vivo)
  Widget _upcomingActivityMarker({required Activity act, required ThemeData theme}) {
    final timeLabel =
        '${act.startTime.hour.toString().padLeft(2, '0')}:${act.startTime.minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: () => _showActivitySheet(act, isLive: false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: const Icon(Icons.schedule, size: 14, color: Colors.white),
                ),
                if (act.isCustom)
                  Positioned(top: -2, right: -2, child: _customBadge()),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: theme.colorScheme.secondary, borderRadius: BorderRadius.circular(4)),
            child: Text(timeLabel, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Pin de ubicación del usuario, con un halo animado sutil
  Widget _userLocationPin() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final t = _pulseController.value;
        return SizedBox(
          width: 34,
          height: 34,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - t).clamp(0.0, 1.0) * 0.4,
                child: Transform.scale(
                  scale: 0.5 + t * 1.2,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                  ),
                ),
              ),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.6), blurRadius: 6, spreadRadius: 1)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MarkerStyle {
  final IconData icon;
  final Color color;
  _MarkerStyle(this.icon, this.color);
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
    final outerBorder = Paint()
      ..color = primaryColor.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final streetPaint = Paint()
      ..color = isDark ? const Color(0xFF2C2C3E) : const Color(0xFFFFFFFF)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final accentPaint = Paint()
      ..color = secondaryColor.withOpacity(isDark ? 0.28 : 0.22)
      ..style = PaintingStyle.fill;
    final areaPaint = Paint()..style = PaintingStyle.fill;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(28)),
      bgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(2, 2, size.width - 4, size.height - 4), const Radius.circular(26)),
      outerBorder,
    );

    canvas.drawRect(Rect.fromLTWH(40, 40, size.width - 80, size.height - 80), Paint()..color = Colors.black.withOpacity(0.02)..style = PaintingStyle.fill);
    canvas.drawRect(Rect.fromLTWH(60, 60, size.width - 120, size.height - 120), Paint()..color = Colors.white.withOpacity(0.25)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    areaPaint.color = Colors.green.withOpacity(isDark ? 0.16 : 0.12);
    canvas.drawOval(Rect.fromLTWH(110, 500, 300, 220), areaPaint);

    areaPaint.color = primaryColor.withOpacity(isDark ? 0.16 : 0.09);
    canvas.drawRect(Rect.fromLTWH(490, 90, 260, 190), areaPaint);

    areaPaint.color = Colors.orange.withOpacity(isDark ? 0.16 : 0.12);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(565, 455, 200, 180), const Radius.circular(18)), areaPaint);

    final path = Path()
      ..moveTo(80, 80)
      ..lineTo(740, 80)
      ..lineTo(740, 740)
      ..lineTo(80, 740)
      ..close()
      ..moveTo(80, 420)
      ..lineTo(740, 420)
      ..moveTo(410, 80)
      ..lineTo(410, 740);
    canvas.drawPath(path, streetPaint);

    final diagonalPath = Path()
      ..moveTo(120, 120)
      ..lineTo(320, 320)
      ..moveTo(520, 520)
      ..lineTo(700, 720);
    canvas.drawPath(diagonalPath, Paint()
      ..color = secondaryColor.withOpacity(isDark ? 0.40 : 0.32)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);

    final plaza = Path()
      ..addOval(Rect.fromCenter(center: const Offset(410, 420), width: 130, height: 130));
    canvas.drawPath(plaza, accentPaint);

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
