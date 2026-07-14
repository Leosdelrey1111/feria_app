import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/watch_sync_service.dart';
import 'watch_sync_provider.dart';

class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final bool isVisitor;
  final String? name;
  final String? email;
  final int reminderMinutes;
  final bool wearConnected;
  // Último error de autenticación, para que el login_screen lo muestre.
  final String? lastError;

  AuthState({
    this.isLoading = false,
    this.isLoggedIn = false,
    this.isVisitor = false,
    this.name,
    this.email,
    this.reminderMinutes = 10,
    this.wearConnected = true,
    this.lastError,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    bool? isVisitor,
    String? name,
    String? email,
    int? reminderMinutes,
    bool? wearConnected,
    String? lastError,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isVisitor: isVisitor ?? this.isVisitor,
      name: name ?? this.name,
      email: email ?? this.email,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      wearConnected: wearConnected ?? this.wearConnected,
      lastError: lastError,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final WatchSyncService _watchSyncService;

  AuthNotifier(this._authService, this._watchSyncService) : super(AuthState()) {
    _loadSession();
  }

  void _syncAuthStateToWatch() {
    _watchSyncService.sendMessage({
      'type': 'auth_state',
      'isLoggedIn': state.isLoggedIn,
      'isVisitor': state.isVisitor,
      'name': state.name,
      'email': state.email,
      'wearConnected': state.wearConnected,
      'reminderMinutes': state.reminderMinutes,
    });
  }

  void syncAuthStateToWatch() => _syncAuthStateToWatch();

  // Cargar sesión inicial al abrir la app
  Future<void> _loadSession() async {
    state = state.copyWith(isLoading: true);
    final loggedIn = await _authService.isLoggedIn();
    if (loggedIn) {
      final name = await _authService.getUserName();
      final email = await _authService.getUserEmail();
      final visitor = await _authService.isVisitor();
      final mins = await _authService.getReminderMinutes();
      final wear = await _authService.isWearConnected();
      state = AuthState(
        isLoggedIn: true,
        isVisitor: visitor,
        name: name,
        email: email,
        reminderMinutes: mins,
        wearConnected: wear,
        isLoading: false,
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
    _syncAuthStateToWatch();
  }

  // Iniciar sesión normal (valida contra el hash guardado localmente)
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, lastError: null);
    try {
      final result = await _authService.login(email, password);
      if (result.success) {
        final name = await _authService.getUserName();
        final userEmail = await _authService.getUserEmail();
        state = AuthState(
          isLoggedIn: true,
          isVisitor: false,
          name: name,
          email: userEmail,
          reminderMinutes: 10,
          wearConnected: true,
          isLoading: false,
        );
        _syncAuthStateToWatch();
        _watchSyncService.sendMessage({'type': 'request_sync'});
        return true;
      } else {
        state = state.copyWith(isLoading: false, lastError: result.errorMessage);
        return false;
      }
    } catch (_) {
      state = state.copyWith(isLoading: false, lastError: 'Error al iniciar sesión.');
      return false;
    }
  }

  // Registrar cuenta (falla si el correo ya existe)
  Future<bool> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, lastError: null);
    try {
      final result = await _authService.register(name, email, password);
      if (result.success) {
        state = AuthState(
          isLoggedIn: true,
          isVisitor: false,
          name: name,
          email: email,
          reminderMinutes: 10,
          wearConnected: true,
          isLoading: false,
        );
        _syncAuthStateToWatch();
        _watchSyncService.sendMessage({'type': 'request_sync'});
        return true;
      } else {
        state = state.copyWith(isLoading: false, lastError: result.errorMessage);
        return false;
      }
    } catch (_) {
      state = state.copyWith(isLoading: false, lastError: 'Error al registrar la cuenta.');
      return false;
    }
  }

  // Google Login
  Future<bool> loginWithGoogle(String displayName) async {
    state = state.copyWith(isLoading: true, lastError: null);
    try {
      final result = await _authService.loginWithGoogle(displayName);
      if (result.success) {
        final name = await _authService.getUserName();
        final email = await _authService.getUserEmail();
        state = AuthState(
          isLoggedIn: true,
          isVisitor: false,
          name: name,
          email: email,
          reminderMinutes: 10,
          wearConnected: true,
          isLoading: false,
        );
        _syncAuthStateToWatch();
        _watchSyncService.sendMessage({'type': 'request_sync'});
        return true;
      } else {
        state = state.copyWith(isLoading: false, lastError: result.errorMessage);
        return false;
      }
    } catch (_) {
      state = state.copyWith(isLoading: false, lastError: 'Error al iniciar sesión con Google.');
      return false;
    }
  }

  // Explorar como visitante
  Future<void> loginAsVisitor() async {
    state = state.copyWith(isLoading: true);
    await _authService.enterAsVisitor();
    final name = await _authService.getUserName();
    final email = await _authService.getUserEmail();
    state = AuthState(
      isLoggedIn: true,
      isVisitor: true,
      name: name,
      email: email,
      reminderMinutes: 10,
      wearConnected: true,
      isLoading: false,
    );
    _syncAuthStateToWatch();
  }

  // Limpiar el error mostrado (por ejemplo, al cambiar entre login/registro)
  void clearError() {
    if (state.lastError != null) {
      state = state.copyWith(lastError: null);
    }
  }

  // Cambiar configuración de minutos de recordatorio
  Future<void> updateReminderMinutes(int minutes) async {
    await _authService.saveReminderMinutes(minutes);
    state = state.copyWith(reminderMinutes: minutes);
    _syncAuthStateToWatch();
  }

  // Sincronizar Smartwatch (Mock)
  Future<void> syncSmartwatch() async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 1500));
    await _authService.saveWearConnected(true);
    state = state.copyWith(wearConnected: true, isLoading: false);
    _syncAuthStateToWatch();
    _watchSyncService.sendMessage({'type': 'request_sync'});
  }

  // Desvincular Smartwatch (Mock)
  Future<void> disconnectSmartwatch() async {
    await _authService.saveWearConnected(false);
    state = state.copyWith(wearConnected: false);
    _syncAuthStateToWatch();
  }

  // Cerrar sesión
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _authService.logout();
    state = AuthState();
    _syncAuthStateToWatch();
  }

  // Eliminar cuenta
  Future<bool> deleteAccount() async {
    state = state.copyWith(isLoading: true);
    try {
      await _authService.deleteAccount();
      state = AuthState();
      _syncAuthStateToWatch();
      return true;
    } catch (_) {}
    state = state.copyWith(isLoading: false);
    return false;
  }
}

// Provider de AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Provider de estado AuthState
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final service = ref.watch(authServiceProvider);
  final syncService = ref.watch(watchSyncServiceProvider);
  return AuthNotifier(service, syncService);
});

