 import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'router/router.dart';
import 'theme/theme.dart';
import 'providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar localización para formateo de fechas en español
  await initializeDateFormatting('es_MX', null);
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Registrar el listener de comunicación del smartwatch después del renderizado inicial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final syncService = ref.read(watchSyncServiceProvider);
      syncService.onMessageReceived = (msg) {
        final type = msg['type'];
        debugPrint('MyApp: Comando recibido desde el reloj: $type');
        if (type == 'open_map') {
          // Navegar al tab del Mapa (tab index 1 en HubScreen)
          ref.read(routerProvider).go('/?tab=1');
        } else if (type == 'open_activity') {
          final activityId = msg['activityId'];
          ref.read(routerProvider).go('/activity/$activityId');
        } else if (type == 'open_notification' || type == 'open_alert') {
          // Navegar al tab de Perfil (tab index 3) donde se ve el estado de sincronización
          ref.read(routerProvider).go('/?tab=3');
        } else if (type == 'request_sync') {
          // El reloj solicita una sincronización forzada de todos los datos
          final authNotifier = ref.read(authProvider.notifier);
          if (!authNotifier.state.wearConnected && authNotifier.state.isLoggedIn) {
            authNotifier.syncSmartwatch();
          } else {
            authNotifier.syncAuthStateToWatch();
            ref.read(ticketProvider.notifier).syncTicketsToWatch();
            ref.read(activityProvider.notifier).syncFavoritesToWatch();
          }
        }
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Mi Feria Inteligente',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}

