import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../theme/theme.dart';
import 'qr_fullscreen_screen.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final PageController _pageController = PageController();
  int _activePage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showTransferDialog(Ticket ticket) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Transferir Boleto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ingresa el correo electrónico del destinatario para transferir este boleto de forma permanente.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Correo electrónico',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final email = emailController.text.trim();
              if (email.isNotEmpty && email.contains('@')) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Boleto transferido con éxito a $email.'),
                    backgroundColor: Colors.green,
                  ),
                );
                // En una app real, actualizaríamos el estado local
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ingresa un correo válido.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Transferir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final ticketState = ref.watch(ticketProvider);

    // Dividir tickets activos e históricos
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final activeTickets = ticketState.tickets
        .where((t) => t.status != 'Usado' && t.status != 'Cancelado' && !t.visitDate.isBefore(today))
        .toList();

    final historyTickets = ticketState.tickets
        .where((t) => t.status == 'Usado' || t.status == 'Cancelado' || t.visitDate.isBefore(today))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Boletos'),
      ),
      body: authState.isVisitor
          ? _visitorBlockOverlay(theme)
          : ticketState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => ref.read(ticketProvider.notifier).loadTickets(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Slider de boletos activos
                        if (activeTickets.isEmpty)
                          _emptyTicketsView(theme)
                        else ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Text(
                              'Boletos Activos / Reservas',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(
                            height: 410,
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: activeTickets.length,
                              onPageChanged: (index) {
                                setState(() {
                                  _activePage = index;
                                });
                              },
                              itemBuilder: (context, index) {
                                final ticket = activeTickets[index];
                                return _ticketPassCard(context, ticket);
                              },
                            ),
                          ),
                          // Indicador de páginas
                          if (activeTickets.length > 1) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                activeTickets.length,
                                (index) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: _activePage == index ? 16 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _activePage == index
                                        ? theme.colorScheme.primary
                                        : Colors.grey.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],

                        // 2. Historial de boletos usados
                        const SizedBox(height: 24),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Text(
                            'Historial de Boletos',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        historyTickets.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Center(
                                  child: Text(
                                    'No tienes boletos usados o cancelados.',
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: historyTickets.length,
                                itemBuilder: (context, index) {
                                  final ticket = historyTickets[index];
                                  final dateStr = DateFormat('dd MMM yyyy').format(ticket.visitDate);
                                  return Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                    elevation: 0.5,
                                    child: ListTile(
                                      leading: const Icon(Icons.history, color: Colors.grey),
                                      title: Text('${ticket.type} (${ticket.quantity} boletos)'),
                                      subtitle: Text('Visita: $dateStr • ${ticket.status}'),
                                      trailing: Text(
                                        '\$${ticket.totalPrice.toInt()} MXN',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  );
                                },
                              ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: authState.isVisitor
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/buy-tickets'),
              icon: const Icon(Icons.add),
              label: const Text('Comprar Boletos'),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
    );
  }

  Widget _ticketPassCard(BuildContext context, Ticket ticket) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('EEEE d \'de\' MMMM, yyyy', 'es_MX').format(ticket.visitDate);
    Color statusColor = Colors.green;
    if (ticket.status == 'Reservado') statusColor = Colors.orange;
    if (ticket.status == 'Cancelado') statusColor = Colors.red;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Encabezado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: theme.colorScheme.primary.withOpacity(0.08),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BOLETO DIGITAL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        'Pase ${ticket.type}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ticket.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Contenido QR (tocar para verlo a pantalla completa)
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => QrFullscreenScreen(ticket: ticket),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      QrImageView(
                        data: ticket.qrCodeData,
                        version: QrVersions.auto,
                        size: 130.0,
                        gapless: false,
                        foregroundColor: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Código: ${ticket.id}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fullscreen, size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Toca para ver en pantalla completa',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Línea punteada de boleto
            Row(
              children: List.generate(
                30,
                (i) => Expanded(
                  child: Container(
                    color: i % 2 == 0 ? Colors.transparent : Colors.grey.withOpacity(0.5),
                    height: 1,
                  ),
                ),
              ),
            ),

            // Pie del boleto
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ACCESOS', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(
                            '${ticket.quantity} Personas',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('FECHA VISITA', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(
                            DateFormat('dd/MM/yyyy').format(ticket.visitDate),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showTransferDialog(ticket),
                          icon: const Icon(Icons.send, size: 16),
                          label: const Text('Transferir', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Boleto sincronizado con Google Wallet (Simulado).'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.wallet, size: 16, color: Colors.white),
                          label: const Text('Google Wallet', style: TextStyle(fontSize: 12, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyTicketsView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.confirmation_num_outlined, size: 80, color: Colors.grey.withOpacity(0.4)),
            const SizedBox(height: 16),
            const Text(
              'Aún no tienes boletos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Compra accesos o realiza una reserva gratuita para ver tus pases QR en esta sección.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/buy-tickets'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Comprar accesos ahora'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _visitorBlockOverlay(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock, size: 48, color: Colors.orange),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Wallet no disponible',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tu cartera digital (Wallet) requiere una cuenta para almacenar y sincronizar boletos de forma segura.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Crear cuenta o Iniciar Sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
