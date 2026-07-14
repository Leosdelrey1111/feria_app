import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WatchSyncService {
  HttpServer? _localServer;
  WebSocketChannel? _clientChannel;
  final List<WebSocket> _connectedSockets = [];
  bool _isServer = false;
  bool _isConnecting = false;
  
  // Callback para cuando recibimos comandos del reloj (como navegación de mapa)
  Function(Map<String, dynamic>)? onMessageReceived;

  // Estado temporal de datos para enviar a relojes nuevos que se conecten directamente
  Map<String, dynamic>? _lastAuthState;
  List<dynamic>? _lastTickets;
  List<dynamic>? _lastFavorites;

  Future<void> init() async {
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      try {
        // Intentamos arrancar nuestro propio servidor en puerto 8080 (útil si corre local nativo)
        _localServer = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
        _isServer = true;
        debugPrint('WatchSyncService: Servidor WebSocket iniciado localmente en puerto 8080');
        _localServer!.listen((HttpRequest request) async {
          if (WebSocketTransformer.isUpgradeRequest(request)) {
            final socket = await WebSocketTransformer.upgrade(request);
            _connectedSockets.add(socket);
            debugPrint('WatchSyncService: Reloj conectado directamente por WebSocket');
            
            // Enviar inmediatamente la última info cacheada al reloj recién conectado
            if (_lastAuthState != null) {
              socket.add(jsonEncode({'type': 'auth_state', ..._lastAuthState!}));
            }
            if (_lastTickets != null) {
              socket.add(jsonEncode({'type': 'tickets', 'tickets': _lastTickets}));
            }
            if (_lastFavorites != null) {
              socket.add(jsonEncode({'type': 'favorites', 'favorites': _lastFavorites}));
            }

            socket.listen(
              (data) => _handleIncomingData(data),
              onDone: () {
                _connectedSockets.remove(socket);
                debugPrint('WatchSyncService: Reloj desconectado');
              },
              onError: (e) {
                _connectedSockets.remove(socket);
                debugPrint('WatchSyncService: Error en socket de reloj: $e');
              },
            );
          }
        });
        return;
      } catch (e) {
        debugPrint('WatchSyncService: No se pudo arrancar el servidor local (posiblemente puerto ocupado o permiso denegado): $e');
      }
    }

    // Si no es servidor o falló, conectamos como cliente al bridge central
    _connectAsClient();
  }

  void _connectAsClient() {
    if (_isConnecting) return;
    _isConnecting = true;
    
    // En emulador Android, 10.0.2.2 apunta al host. En Windows/Desktop/Web, localhost es correcto.
    final host = kIsWeb
        ? 'localhost'
        : (defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost');
    final url = 'ws://$host:8080';
    debugPrint('WatchSyncService: Conectando al bridge central en $url');

    try {
      _clientChannel = WebSocketChannel.connect(Uri.parse(url));
      _clientChannel!.stream.listen(
        (data) {
          _isConnecting = false;
          _handleIncomingData(data);
        },
        onDone: () {
          _isConnecting = false;
          debugPrint('WatchSyncService: Conexión con bridge cerrada. Reintentando en 5 segundos...');
          Future.delayed(const Duration(seconds: 5), () => _connectAsClient());
        },
        onError: (e) {
          _isConnecting = false;
          debugPrint('WatchSyncService: Error al conectar con bridge: $e. Reintentando en 5 segundos...');
          Future.delayed(const Duration(seconds: 5), () => _connectAsClient());
        },
      );
    } catch (e) {
      _isConnecting = false;
      debugPrint('WatchSyncService: Excepción de conexión cliente: $e');
    }
  }

  void _handleIncomingData(dynamic data) {
    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      debugPrint('WatchSyncService: Mensaje recibido desde reloj/bridge: $msg');
      onMessageReceived?.call(msg);
    } catch (e) {
      debugPrint('WatchSyncService: Error interpretando JSON entrante: $e');
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    // Cachear internamente para re-conexiones directas
    final type = message['type'];
    if (type == 'auth_state') {
      _lastAuthState = Map<String, dynamic>.from(message)..remove('type');
    } else if (type == 'tickets') {
      _lastTickets = message['tickets'] as List<dynamic>?;
    } else if (type == 'favorites') {
      _lastFavorites = message['favorites'] as List<dynamic>?;
    }

    final raw = jsonEncode(message);
    
    // Si somos servidor local, enviar a todos los clientes directos
    if (_isServer) {
      for (final socket in _connectedSockets) {
        try {
          socket.add(raw);
        } catch (_) {}
      }
    }
    
    // Si estamos conectados como cliente al bridge, enviar allí
    if (_clientChannel != null) {
      try {
        _clientChannel!.sink.add(raw);
      } catch (_) {}
    }
  }
}
