import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resultado de una operación de autenticación.
/// Se usa en vez de un simple `bool` para poder mostrarle al usuario
/// el motivo exacto por el que el login/registro falló.
class AuthResult {
  final bool success;
  final String? errorMessage;

  const AuthResult.ok()
      : success = true,
        errorMessage = null;
  const AuthResult.fail(this.errorMessage) : success = false;
}

/// Roles de la aplicación.
/// - admin: el organizador de la feria. Es el único que puede crear,
///   editar o eliminar actividades del programa (oficiales o propias).
/// - user: el visitante normal. Puede comprar boletos, votar, marcar
///   favoritos y navegar la app, pero no modificar el contenido del evento.
class AppRole {
  static const String admin = 'admin';
  static const String user = 'user';
}

/// Credenciales de la cuenta administradora sembrada automáticamente la
/// primera vez que corre la app en un dispositivo. Solo para la demo del
/// proyecto: en un backend real, el rol de administrador se asignaría desde
/// un panel seguro, nunca auto-registrable desde la pantalla de login.
class SeedAdmin {
  static const String email = 'admin@miferia.com';
  static const String password = 'Admin123!';
}

/// Snapshot de la sesión activa. A propósito se mantiene SOLO EN MEMORIA
/// (no se guarda en SharedPreferences): así, cuando la app se cierra por
/// completo y se vuelve a abrir (reinicio real, no hot reload), esta
/// información desaparece junto con el proceso y siempre hay que volver a
/// iniciar sesión. Las cuentas registradas (accounts_db) sí persisten en
/// disco, solo la sesión activa no.
class _Session {
  final String email;
  final String name;
  final String role;
  final bool isVisitor;

  _Session({
    required this.email,
    required this.name,
    required this.role,
    required this.isVisitor,
  });
}

class AuthService {
  static const String keyReminderMins = 'reminder_minutes';
  static const String keyDarkMode = 'dark_mode';
  static const String keyWearConnected = 'wear_connected';

  // "Base de datos" local de cuentas registradas.
  // Se guarda como JSON: { "correo@ejemplo.com": { "name": ..., "salt": ..., "hash": ..., "role": ... } }
  // IMPORTANTE: nunca se guarda la contraseña en texto plano, solo su hash SHA-256
  // combinado con un "salt" aleatorio único por usuario. Esto SÍ persiste en
  // disco entre reinicios: es la lista de cuentas, no la sesión activa.
  static const String keyAccountsDb = 'accounts_db_v1';

  // Sesión activa actual, solo en memoria (ver _Session arriba).
  _Session? _session;

  // ---------------------------------------------------------------------
  // Utilidades de seguridad
  // ---------------------------------------------------------------------

  String _generateSalt([int length = 16]) {
    final rand = Random.secure();
    final saltBytes = List<int>.generate(length, (_) => rand.nextInt(256));
    return base64UrlEncode(saltBytes);
  }

  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt::$password');
    return sha256.convert(bytes).toString();
  }

  String _generateSessionToken() {
    final rand = Random.secure();
    final tokenBytes = List<int>.generate(32, (_) => rand.nextInt(256));
    return base64UrlEncode(tokenBytes);
  }

  Future<Map<String, dynamic>> _loadAccounts(SharedPreferences prefs) async {
    final raw = prefs.getString(keyAccountsDb);
    if (raw == null || raw.isEmpty) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveAccounts(
      SharedPreferences prefs, Map<String, dynamic> accounts) async {
    await prefs.setString(keyAccountsDb, jsonEncode(accounts));
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  // Garantiza que la cuenta administradora exista. Se llama antes de
  // cualquier login/registro; si ya existe, no hace nada (operación barata
  // e idempotente).
  Future<Map<String, dynamic>> _ensureSeedAdmin(SharedPreferences prefs) async {
    final accounts = await _loadAccounts(prefs);
    if (!accounts.containsKey(SeedAdmin.email)) {
      final salt = _generateSalt();
      accounts[SeedAdmin.email] = {
        'name': 'Administrador de la Feria',
        'salt': salt,
        'hash': _hashPassword(SeedAdmin.password, salt),
        'role': AppRole.admin,
      };
      await _saveAccounts(prefs, accounts);
    }
    return accounts;
  }

  // ---------------------------------------------------------------------
  // Estado de sesión (en memoria)
  // ---------------------------------------------------------------------

  Future<bool> isLoggedIn() async => _session != null;

  Future<bool> isVisitor() async => _session?.isVisitor ?? false;

  Future<String?> getUserEmail() async => _session?.email;

  Future<String?> getUserName() async => _session?.name;

  Future<String?> getUserRole() async => _session?.role;

  Future<int> getReminderMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyReminderMins) ?? 10; // Default 10 min
  }

  Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyDarkMode) ?? false;
  }

  Future<bool> isWearConnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyWearConnected) ?? true;
  }

  // Guardar configuraciones
  Future<void> saveReminderMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyReminderMins, minutes);
  }

  Future<void> saveDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyDarkMode, isDark);
  }

  Future<void> saveWearConnected(bool connected) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyWearConnected, connected);
  }

  // ---------------------------------------------------------------------
  // Registro (siempre crea cuentas con rol "user": nadie se auto-asigna
  // administrador desde el formulario de registro)
  // ---------------------------------------------------------------------

  Future<AuthResult> register(
      String name, String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final prefs = await SharedPreferences.getInstance();
    final normalizedEmail = _normalizeEmail(email);

    final accounts = await _ensureSeedAdmin(prefs);
    if (accounts.containsKey(normalizedEmail)) {
      return const AuthResult.fail(
          'Ya existe una cuenta registrada con este correo.');
    }

    final salt = _generateSalt();
    final hash = _hashPassword(password, salt);

    accounts[normalizedEmail] = {
      'name': name.trim(),
      'salt': salt,
      'hash': hash,
      'role': AppRole.user,
    };
    await _saveAccounts(prefs, accounts);

    _startSession(
      email: normalizedEmail,
      name: name.trim(),
      role: AppRole.user,
      isVisitor: false,
    );
    return const AuthResult.ok();
  }

  // ---------------------------------------------------------------------
  // Login con correo y contraseña
  // ---------------------------------------------------------------------

  Future<AuthResult> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final prefs = await SharedPreferences.getInstance();
    final normalizedEmail = _normalizeEmail(email);

    final accounts = await _ensureSeedAdmin(prefs);
    final account = accounts[normalizedEmail] as Map<String, dynamic>?;

    if (account == null) {
      return const AuthResult.fail(
          'No existe una cuenta registrada con este correo.');
    }

    final salt = account['salt'] as String;
    final storedHash = account['hash'] as String;
    final attemptHash = _hashPassword(password, salt);

    if (attemptHash != storedHash) {
      return const AuthResult.fail('Correo o contraseña incorrectos.');
    }

    // Cuentas creadas antes de que existiera el sistema de roles no tienen
    // 'role' guardado: se asumen como 'user' por seguridad (nunca admin
    // por default).
    final role = account['role'] as String? ?? AppRole.user;

    _startSession(
      email: normalizedEmail,
      name: account['name'] as String,
      role: role,
      isVisitor: false,
    );
    return const AuthResult.ok();
  }

  // ---------------------------------------------------------------------
  // Login con Google (simulado localmente, sin backend real)
  // ---------------------------------------------------------------------
  //
  // NOTA IMPORTANTE PARA PRODUCCIÓN:
  // Esta app no tiene backend, así que no existe un OAuth real de Google.
  // Para integrar el inicio de sesión real habría que:
  //   1. Agregar el paquete `google_sign_in` al pubspec.yaml
  //   2. Configurar un proyecto de Firebase y su `google-services.json`
  //   3. Reemplazar este método por una llamada a `GoogleSignIn().signIn()`
  //      y usar el `displayName`, `email` y `photoUrl` reales que retorna.
  //
  // Mientras tanto, para no mostrar SIEMPRE la misma cuenta falsa
  // ("google.user@gmail.com"), se le pide al usuario el nombre con el que
  // quiere simular su cuenta de Google, y se crea/reutiliza esa cuenta
  // igual que el registro normal (con su propia entrada hasheada, rol "user").
  Future<AuthResult> loginWithGoogle(String displayName) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final prefs = await SharedPreferences.getInstance();

    final cleanName =
        displayName.trim().isEmpty ? 'Usuario de Google' : displayName.trim();
    // Se genera un correo determinístico a partir del nombre para que la
    // misma persona conserve su misma "cuenta simulada" entre sesiones.
    final slug = cleanName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '.')
        .replaceAll(RegExp(r'\.+'), '.')
        .replaceAll(RegExp(r'^\.|\.$'), '');
    final normalizedEmail = '$slug@gmail.com';

    final accounts = await _ensureSeedAdmin(prefs);
    if (!accounts.containsKey(normalizedEmail)) {
      // Cuenta "social" nueva: se le asigna una contraseña aleatoria interna
      // (el usuario nunca la necesita porque siempre entra por Google).
      final salt = _generateSalt();
      final randomPassword = _generateSessionToken();
      accounts[normalizedEmail] = {
        'name': cleanName,
        'salt': salt,
        'hash': _hashPassword(randomPassword, salt),
        'provider': 'google',
        'role': AppRole.user,
      };
      await _saveAccounts(prefs, accounts);
    }

    final role = (accounts[normalizedEmail]
            as Map<String, dynamic>)['role'] as String? ??
        AppRole.user;

    _startSession(
      email: normalizedEmail,
      name: cleanName,
      role: role,
      isVisitor: false,
    );
    return const AuthResult.ok();
  }

  // ---------------------------------------------------------------------
  // Modo visitante
  // ---------------------------------------------------------------------

  Future<void> enterAsVisitor() async {
    _startSession(
      email: 'visitante@miferia.com',
      name: 'Visitante de la Feria',
      role: AppRole.user,
      isVisitor: true,
    );
  }

  void _startSession({
    required String email,
    required String name,
    required String role,
    required bool isVisitor,
  }) {
    // El token no se usa fuera de esta clase, pero generarlo deja abierta
    // la puerta a validarlo contra un backend real más adelante.
    _generateSessionToken();
    _session = _Session(email: email, name: name, role: role, isVisitor: isVisitor);
  }

  // ---------------------------------------------------------------------
  // Cierre y eliminación de cuenta
  // ---------------------------------------------------------------------

  Future<void> logout() async {
    // Solo se limpia la sesión en memoria. Las cuentas registradas
    // (accounts_db) NO se tocan: siguen disponibles para volver a iniciar
    // sesión más tarde.
    _session = null;
  }

  Future<void> deleteAccount() async {
    final email = _session?.email;
    if (email != null) {
      final prefs = await SharedPreferences.getInstance();
      final accounts = await _loadAccounts(prefs);
      accounts.remove(_normalizeEmail(email));
      await _saveAccounts(prefs, accounts);
    }
    await logout();
  }
}
