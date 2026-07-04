import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String keyLoggedIn = 'is_logged_in';
  static const String keyEmail = 'user_email';
  static const String keyName = 'user_name';
  static const String keyIsVisitor = 'is_visitor';
  static const String keyReminderMins = 'reminder_minutes';
  static const String keyDarkMode = 'dark_mode';
  static const String keyWearConnected = 'wear_connected';

  // Obtener estado de sesión
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyLoggedIn) ?? false;
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
    return prefs.getBool(keyDarkMode) ?? false; // Default light mode
  }

  Future<bool> isWearConnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyWearConnected) ?? true; // Default conectado en mock
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

  // Simular Login
  Future<bool> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800)); // Simular retraso
    final prefs = await SharedPreferences.getInstance();
    
    // Asignar un nombre por defecto a partir del correo si no hay
    String name = email.split('@')[0];
    name = name[0].toUpperCase() + name.substring(1);

    await prefs.setBool(keyLoggedIn, true);
    await prefs.setString(keyEmail, email);
    await prefs.setString(keyName, name);
    await prefs.setBool(keyIsVisitor, false);
    return true;
  }

  // Simular Registro
  Future<bool> register(String name, String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800)); // Simular retraso
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyLoggedIn, true);
    await prefs.setString(keyEmail, email);
    await prefs.setString(keyName, name);
    await prefs.setBool(keyIsVisitor, false);
    return true;
  }

  // Simular Login de Google
  Future<bool> loginWithGoogle() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyLoggedIn, true);
    await prefs.setString(keyEmail, 'google.user@gmail.com');
    await prefs.setString(keyName, 'Google User');
    await prefs.setBool(keyIsVisitor, false);
    return true;
  }

  // Entrar en Modo Visitante
  Future<void> enterAsVisitor() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyLoggedIn, true);
    await prefs.setString(keyEmail, 'visitante@miferia.com');
    await prefs.setString(keyName, 'Visitante de la Feria');
    await prefs.setBool(keyIsVisitor, true);
  }

  // Cerrar Sesión
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyLoggedIn);
    await prefs.remove(keyEmail);
    await prefs.remove(keyName);
    await prefs.remove(keyIsVisitor);
  }

  // Eliminar Cuenta
  Future<void> deleteAccount() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    await logout();
  }
}
