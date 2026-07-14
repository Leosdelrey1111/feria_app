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

class AuthService {
  static const String keyLoggedIn = 'is_logged_in';
  static const String keySessionToken = 'session_token';
  static const String keyEmail = 'user_email';
  static const String keyName = 'user_name';
  static const String keyIsVisitor = 'is_visitor';
  static const String keyReminderMins = 'reminder_minutes';
  static const String keyDarkMode = 'dark_mode';
  static const String keyWearConnected = 'wear_connected';

  // "Base de datos" local de cuentas registradas.
  // Se guarda como JSON: { "correo@ejemplo.com": { "name": ..., "salt": ..., "hash": ... } }
  // IMPORTANTE: nunca se guarda la contraseña en texto plano, solo su hash SHA-256
  // combinado con un "salt" aleatorio único por usuario.
  static const String keyAccountsDb = 'accounts_db_v1';

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

  // ---------------------------------------------------------------------
  // Estado de sesión
  // ---------------------------------------------------------------------

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    // Una sesión solo es válida si además del flag existe un token de sesión.
    final loggedIn = prefs.getBool(keyLoggedIn) ?? false;
    final token = prefs.getString(keySessionToken);
    return loggedIn && token != null && token.isNotEmpty;
  }

  Future<bool> isVisitor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyIsVisitor) ?? false;
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyEmail);
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyName);
  }

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
  // Registro
  // ---------------------------------------------------------------------

  Future<AuthResult> register(
      String name, String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final prefs = await SharedPreferences.getInstance();
    final normalizedEmail = _normalizeEmail(email);

    final accounts = await _loadAccounts(prefs);
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
    };
    await _saveAccounts(prefs, accounts);

    await _startSession(prefs,
        email: normalizedEmail, name: name.trim(), isVisitor: false);
    return const AuthResult.ok();
  }

  // ---------------------------------------------------------------------
  // Login con correo y contraseña
  // ---------------------------------------------------------------------

  Future<AuthResult> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final prefs = await SharedPreferences.getInstance();
    final normalizedEmail = _normalizeEmail(email);

    final accounts = await _loadAccounts(prefs);
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

    await _startSession(prefs,
        email: normalizedEmail,
        name: account['name'] as String,
        isVisitor: false);
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
  // igual que el registro normal (con su propia entrada hasheada).
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

    final accounts = await _loadAccounts(prefs);
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
      };
      await _saveAccounts(prefs, accounts);
    }

    await _startSession(prefs,
        email: normalizedEmail, name: cleanName, isVisitor: false);
    return const AuthResult.ok();
  }

  // ---------------------------------------------------------------------
  // Modo visitante
  // ---------------------------------------------------------------------

  Future<void> enterAsVisitor() async {
    final prefs = await SharedPreferences.getInstance();
    await _startSession(prefs,
        email: 'visitante@miferia.com',
        name: 'Visitante de la Feria',
        isVisitor: true);
  }

  Future<void> _startSession(
    SharedPreferences prefs, {
    required String email,
    required String name,
    required bool isVisitor,
  }) async {
    final token = _generateSessionToken();
    await prefs.setBool(keyLoggedIn, true);
    await prefs.setString(keySessionToken, token);
    await prefs.setString(keyEmail, email);
    await prefs.setString(keyName, name);
    await prefs.setBool(keyIsVisitor, isVisitor);
  }

  // ---------------------------------------------------------------------
  // Cierre y eliminación de cuenta
  // ---------------------------------------------------------------------

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    // Se elimina el token de sesión y los datos de sesión activa.
    // Las cuentas registradas (accounts_db) NO se borran: es la "base de
    // datos" local y debe seguir existiendo para futuros logins.
    await prefs.remove(keyLoggedIn);
    await prefs.remove(keySessionToken);
    await prefs.remove(keyEmail);
    await prefs.remove(keyName);
    await prefs.remove(keyIsVisitor);
  }

  Future<void> deleteAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(keyEmail);
    if (email != null) {
      final accounts = await _loadAccounts(prefs);
      accounts.remove(_normalizeEmail(email));
      await _saveAccounts(prefs, accounts);
    }
    await logout();
  }
}
