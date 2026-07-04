import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/hub/hub_screen.dart';
import '../screens/activity/activity_detail_screen.dart';
import '../screens/tickets/buy_tickets_screen.dart';
import '../screens/polls/polls_screen.dart';

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
