import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../screens/screens.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Observar el estado de autenticación para activar redirecciones si cambia la sesión
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: authState.isLoggedIn ? '/' : '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) {
          final tabStr = state.uri.queryParameters['tab'];
          final initialTab = int.tryParse(tabStr ?? '0') ?? 0;
          return HubScreen(initialTab: initialTab);
        },
      ),
      GoRoute(
        path: '/activity/create',
        builder: (context, state) {
          final existing = state.extra as Activity?;
          return CreateActivityScreen(existing: existing);
        },
      ),
      GoRoute(
        path: '/activity/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ActivityDetailScreen(activityId: id);
        },
      ),
      GoRoute(
        path: '/buy-tickets',
        builder: (context, state) => const BuyTicketsScreen(),
      ),
      GoRoute(
        path: '/polls',
        builder: (context, state) => const PollsScreen(),
      ),
    ],
  );
});
