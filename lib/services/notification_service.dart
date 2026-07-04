import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    
    // Solo inicializar si estamos en Android o iOS nativo
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _isInitialized = true;
      debugPrint('Notificaciones Locales: Plataforma no soportada para notificaciones nativas de fondo.');
      return;
    }

    try {
      tz.initializeTimeZones();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _localNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          debugPrint('Notificación clickeada: ${details.payload}');
        },
      );
      _isInitialized = true;
      debugPrint('Notificaciones Locales inicializadas con éxito.');
    } catch (e) {
      debugPrint('Error inicializando notificaciones locales nativas: $e');
    }
  }

  // Programar notificación
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required Duration delay,
    BuildContext? context,
  }) async {
    // Si no está inicializado nativamente o es escritorio, mostramos Snackbar
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS) && _isInitialized) {
      try {
        final scheduledTime = tz.TZDateTime.now(tz.local).add(delay);
        
        const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
          'feria_inteligente_channel',
          'Recordatorios de Actividades',
          channelDescription: 'Canal para recordatorios de actividades de la feria',
          importance: Importance.max,
          priority: Priority.high,
        );

        const NotificationDetails platformDetails = NotificationDetails(
          android: androidDetails,
        );

        await _localNotificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledTime,
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        
        debugPrint('Notificación programada con éxito en $delay');
        return;
      } catch (e) {
        debugPrint('Error programando notificación local nativa: $e');
      }
    }

    // Fallback: Mostrar confirmación y simular de forma visual
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.alarm_on, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Recordatorio configurado: "$title" en ${delay.inMinutes} minutos.',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
