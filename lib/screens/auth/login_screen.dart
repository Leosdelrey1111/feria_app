import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authNotifier = ref.read(authProvider.notifier);
    bool success = false;

    if (_isSignUp) {
      success = await authNotifier.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } else {
      success = await authNotifier.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    }

    if (mounted) {
      if (success) {
        _showLoginSuccessAndNavigate();
      } else {
        final error = ref.read(authProvider).lastError ?? 'Credenciales incorrectas o error en el servidor.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _googleLogin() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Selecciona tu cuenta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta app aún no tiene un backend real, así que el acceso con Google se simula localmente. Escribe tu nombre para continuar con una cuenta identificable.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nombre completo',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final success = await ref.read(authProvider.notifier).loginWithGoogle(name);
    if (mounted && success) {
      _showLoginSuccessAndNavigate();
    } else if (mounted) {
      final error = ref.read(authProvider).lastError ?? 'No se pudo iniciar sesión con Google.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showLoginSuccessAndNavigate() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.watch, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '¡Sesión iniciada! Sincronizando con Smartwatch Wear OS...',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 3),
      ),
    );
    context.go('/');
  }

  void _exploreAsVisitor() async {
    await ref.read(authProvider.notifier).loginAsVisitor();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrando en Modo Visitante. Algunas funciones estarán limitadas.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: authState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.18),
                        theme.colorScheme.secondary.withOpacity(0.08),
                        Colors.white.withOpacity(0.96),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Positioned(
                  top: -50,
                  left: -60,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final angle = _controller.value * 2 * pi;
                      return Transform.translate(
                        offset: Offset(24 * sin(angle), -18 * cos(angle)),
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.16),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  bottom: -30,
                  right: -30,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final angle = _controller.value * 2 * pi + pi / 3;
                      return Transform.translate(
                        offset: Offset(-18 * cos(angle), 22 * sin(angle)),
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withOpacity(0.14),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _fadeAnimation.value,
                          child: Transform.translate(
                            offset: _slideAnimation.value * 32,
                            child: child,
                          ),
                        );
                      },
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.75),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 8)),
                                ],
                              ),
                              child: Icon(Icons.festival_rounded, size: 64, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Mi Feria Inteligente',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.brightness == Brightness.dark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isSignUp ? 'Crea una cuenta para disfrutar la feria' : 'Bienvenido. Accede a tu agenda y boletos.',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                                child: Container(
                                  padding: const EdgeInsets.all(24.0),
                                  decoration: BoxDecoration(
                                    color: theme.brightness == Brightness.dark
                                        ? Colors.black.withOpacity(0.35)
                                        : Colors.white.withOpacity(0.72),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(color: Colors.white.withOpacity(0.45), width: 1.2),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 16)),
                                    ],
                                  ),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        if (_isSignUp) ...[
                                          TextFormField(
                                            controller: _nameController,
                                            decoration: InputDecoration(
                                              filled: true,
                                              fillColor: Colors.white.withOpacity(0.86),
                                              labelText: 'Nombre completo',
                                              prefixIcon: const Icon(Icons.person_outline),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(16),
                                                borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(16),
                                                borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.6),
                                              ),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.trim().isEmpty) {
                                                return 'Ingresa tu nombre';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                        TextFormField(
                                          controller: _emailController,
                                          keyboardType: TextInputType.emailAddress,
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: Colors.white.withOpacity(0.86),
                                            labelText: 'Correo electrónico',
                                            prefixIcon: const Icon(Icons.email_outlined),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(16),
                                              borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(16),
                                              borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.6),
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Ingresa tu correo';
                                            }
                                            if (!value.contains('@') || !value.contains('.')) {
                                              return 'Ingresa un correo válido';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        TextFormField(
                                          controller: _passwordController,
                                          obscureText: _obscurePassword,
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: Colors.white.withOpacity(0.86),
                                            labelText: 'Contraseña',
                                            prefixIcon: const Icon(Icons.lock_outlined),
                                            suffixIcon: IconButton(
                                              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                              onPressed: () {
                                                setState(() {
                                                  _obscurePassword = !_obscurePassword;
                                                });
                                              },
                                            ),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(16),
                                              borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(16),
                                              borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.6),
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Ingresa tu contraseña';
                                            }
                                            if (value.length < 6) {
                                              return 'Mínimo 6 caracteres';
                                            }
                                            return null;
                                          },
                                        ),
                                        if (_isSignUp) ...[
                                          const SizedBox(height: 16),
                                          TextFormField(
                                            controller: _confirmPasswordController,
                                            obscureText: _obscureConfirmPassword,
                                            decoration: InputDecoration(
                                              filled: true,
                                              fillColor: Colors.white.withOpacity(0.86),
                                              labelText: 'Confirmar contraseña',
                                              prefixIcon: const Icon(Icons.lock_outlined),
                                              suffixIcon: IconButton(
                                                icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                                onPressed: () {
                                                  setState(() {
                                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                                  });
                                                },
                                              ),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(16),
                                                borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(16),
                                                borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.6),
                                              ),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Confirma tu contraseña';
                                              }
                                              if (value != _passwordController.text) {
                                                return 'Las contraseñas no coinciden';
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        if (!_isSignUp)
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton(
                                              onPressed: () {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Mock: Enlace de recuperación enviado al correo.')),
                                                );
                                              },
                                              child: const Text('¿Olvidaste tu contraseña?'),
                                            ),
                                          ),
                                        if (authState.lastError != null) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.redAccent, width: 1),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    authState.lastError!,
                                                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 13),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed: _submit,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: theme.colorScheme.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            elevation: 2,
                                          ),
                                          child: Text(
                                            _isSignUp ? 'Registrarse' : 'Iniciar Sesión',
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _googleLogin,
                              icon: Image.network(
                                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                                height: 20,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 24),
                              ),
                              label: const Text('Acceder con Google'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextButton(
                              onPressed: _exploreAsVisitor,
                              child: Text(
                                'Explorar sin cuenta (Modo Visitante)',
                                style: TextStyle(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_isSignUp ? '¿Ya tienes una cuenta?' : '¿No tienes una cuenta?'),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isSignUp = !_isSignUp;
                                      _formKey.currentState?.reset();
                                    });
                                    ref.read(authProvider.notifier).clearError();
                                  },
                                  child: Text(
                                    _isSignUp ? 'Inicia Sesión' : 'Regístrate',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
