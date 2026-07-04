import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Estado local para notificaciones e idioma
  String _notificationSetting = 'Todas'; // Todas, Solo urgentes, Ninguna
  String _language = 'Español'; // Español, Inglés

  void _showDeleteAccountConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('¿Eliminar Cuenta?'),
          ],
        ),
        content: const Text(
          'Esta acción es definitiva. Se borrarán de forma permanente todos tus datos de registro, favoritos, recordatorios y boletos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Cerrar diálogo
              final success = await ref.read(authProvider.notifier).deleteAccount();
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cuenta eliminada definitivamente.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                context.go('/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar de todas formas'),
          ),
        ],
      ),
    );
  }

  void _syncWatch() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Buscando smartwatch Wear OS compatible...'),
        duration: Duration(seconds: 1),
      ),
    );
    await ref.read(authProvider.notifier).syncSmartwatch();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Smartwatch Wear OS vinculado con éxito!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _disconnectWatch() async {
    await ref.read(authProvider.notifier).disconnectSmartwatch();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Smartwatch Wear OS desvinculado.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      body: authState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Cabecera de perfil elegante
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withOpacity(0.08),
                          theme.colorScheme.secondary.withOpacity(0.04),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Avatar placeholder
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                              child: Text(
                                authState.name != null && authState.name!.isNotEmpty
                                    ? authState.name![0].toUpperCase()
                                    : 'V',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            if (!authState.isVisitor)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                                  ),
                                  child: const Icon(Icons.check, size: 16, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          authState.name ?? 'Visitante de la Feria',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          authState.email ?? 'visitante@miferia.com',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        if (authState.isVisitor) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning, size: 14, color: Colors.orange),
                                SizedBox(width: 6),
                                Text(
                                  'Modo Visitante Limitado',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Lista de Configuraciones
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // --- SECCIÓN: CONFIGURACIÓN DE FERIA ---
                      _sectionTitle('Preferencias de la Feria'),
                      
                      // Configuración de minutos de recordatorio
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.alarm),
                              title: const Text('Anticipación de recordatorios'),
                              subtitle: const Text('Minutos antes de iniciar la actividad'),
                              trailing: DropdownButton<int>(
                                value: authState.reminderMinutes,
                                items: const [
                                  DropdownMenuItem(value: 5, child: Text('5 minutos')),
                                  DropdownMenuItem(value: 10, child: Text('10 minutos')),
                                  DropdownMenuItem(value: 15, child: Text('15 minutos')),
                                ],
                                onChanged: authState.isVisitor
                                    ? null
                                    : (val) {
                                        if (val != null) {
                                          ref.read(authProvider.notifier).updateReminderMinutes(val);
                                        }
                                      },
                              ),
                            ),
                            const Divider(height: 1),
                            // Configuración de nivel de notificaciones push
                            ListTile(
                              leading: const Icon(Icons.notifications_active_outlined),
                              title: const Text('Nivel de notificaciones push'),
                              subtitle: Text('Estado: $_notificationSetting'),
                              trailing: PopupMenuButton<String>(
                                initialValue: _notificationSetting,
                                onSelected: (val) {
                                  setState(() {
                                    _notificationSetting = val;
                                  });
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(value: 'Todas', child: Text('Todas')),
                                  PopupMenuItem(value: 'Solo urgentes', child: Text('Solo urgentes')),
                                  PopupMenuItem(value: 'Ninguna', child: Text('Ninguna')),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            // Selector de idioma (Mock)
                            ListTile(
                              leading: const Icon(Icons.language),
                              title: const Text('Idioma de interfaz'),
                              subtitle: Text('Activo: $_language'),
                              trailing: PopupMenuButton<String>(
                                initialValue: _language,
                                onSelected: (val) {
                                  setState(() {
                                    _language = val;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Idioma cambiado a: $val (Mock UI)')),
                                  );
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(value: 'Español', child: Text('Español (ES)')),
                                  PopupMenuItem(value: 'Inglés', child: Text('Inglés (EN) (Mock)')),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- SECCIÓN: DISPOSITIVOS VINCULADOS ---
                      _sectionTitle('Dispositivos Vinculados (Ecosistema)'),
                      Card(
                        child: Column(
                          children: [
                            // Wear OS Smartwatch
                            ListTile(
                              leading: Icon(
                                Icons.watch,
                                color: authState.wearConnected ? theme.colorScheme.primary : Colors.grey,
                              ),
                              title: const Text('Smartwatch (Wear OS)'),
                              subtitle: Text(
                                authState.wearConnected
                                    ? 'Estado: Conectado'
                                    : 'Estado: Sin reloj detectado',
                                style: TextStyle(
                                  color: authState.wearConnected ? Colors.green : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: TextButton(
                                onPressed: authState.isVisitor
                                    ? null
                                    : (authState.wearConnected ? _disconnectWatch : _syncWatch),
                                child: Text(authState.wearConnected ? 'Desvincular' : 'Sincronizar'),
                              ),
                            ),
                            const Divider(height: 1),
                            // Smart TV
                            ListTile(
                              leading: const Icon(Icons.tv),
                              title: const Text('Smart TV del Recinto'),
                              subtitle: const Text('Código de vinculación del evento'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SelectableText(
                                    'TV-FERIA-9921',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 16),
                                    onPressed: () {
                                      Clipboard.setData(const ClipboardData(text: 'TV-FERIA-9921'));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Código de TV copiado.')),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- SECCIÓN: INTERFAZ Y TEMA ---
                      _sectionTitle('Configuración Visual'),
                      Card(
                        child: SwitchListTile(
                          title: const Text('Modo Oscuro'),
                          subtitle: const Text('Cambia el aspecto visual de la aplicación'),
                          secondary: const Icon(Icons.dark_mode_outlined),
                          value: isDark,
                          onChanged: (val) {
                            ref.read(themeProvider.notifier).toggleTheme(val);
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // --- BOTONES DE CUENTA ---
                      ElevatedButton.icon(
                        onPressed: () async {
                          await ref.read(authProvider.notifier).logout();
                          if (mounted) {
                            context.go('/login');
                          }
                        },
                        icon: const Icon(Icons.logout),
                        label: Text(
                          authState.isVisitor ? 'Salir del Modo Visitante' : 'Cerrar Sesión',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (!authState.isVisitor) ...[
                        OutlinedButton.icon(
                          onPressed: _showDeleteAccountConfirmDialog,
                          icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                          label: const Text('Eliminar mi Cuenta', style: TextStyle(color: Colors.redAccent)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 48),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
