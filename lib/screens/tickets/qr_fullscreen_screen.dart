import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/models.dart';
/// Pantalla de pantalla completa para el código QR de un boleto.
///
/// El PDF pide que el QR se pueda ver "a pantalla completa, optimizado
/// para escaneo rápido", y que en pantallas pequeñas se vea completo
/// (sin recortarse). Por eso este widget:
///   - Usa fondo negro puro y el QR en blanco: máximo contraste posible
///     para que el lector del acceso lo escanee sin problema.
///   - Calcula el tamaño del QR a partir del lado más chico de la
///     pantalla (con márgenes), así siempre cabe completo sin importar
///     el tamaño físico del dispositivo.
///   - No depende de brillo automático de hardware (no todos los
///     dispositivos exponen esa API sin plugins nativos extra), pero deja
///     el fondo en negro puro con el QR en blanco puro, que es lo que
///     realmente ayuda a la cámara del escáner a leerlo bien.
class QrFullscreenScreen extends StatelessWidget {
  final Ticket ticket;
  const QrFullscreenScreen({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // El QR ocupa hasta el 85% del lado más pequeño de la pantalla,
    // con un máximo razonable para no verse gigante en tablets.
    final qrSize = (size.shortestSide * 0.85).clamp(200.0, 380.0);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        // Botón de regreso explícito: círculo blanco con flecha negra bien
        // marcada, para que se note claramente sobre el fondo negro (el
        // ícono automático del AppBar se veía apagado/poco visible).
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.arrow_back, color: Colors.black, size: 22),
              ),
            ),
          ),
        ),
        title: const Text(
          'Mi Boleto QR',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: QrImageView(
                    data: ticket.qrCodeData,
                    version: QrVersions.auto,
                    size: qrSize,
                    gapless: false,
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  ticket.type,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Código: ${ticket.id}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Visita: ${DateFormat('dd/MM/yyyy').format(ticket.visitDate)} · ${ticket.quantity} persona(s)',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ticket.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Muestra este código en el acceso del recinto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: const Text(
                      'Cerrar',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
