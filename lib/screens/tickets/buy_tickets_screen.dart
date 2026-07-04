import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ticket_provider.dart';
import '../../services/ticket_service.dart';
import '../../theme/app_theme.dart';

class BuyTicketsScreen extends ConsumerStatefulWidget {
  const BuyTicketsScreen({super.key});

  @override
  ConsumerState<BuyTicketsScreen> createState() => _BuyTicketsScreenState();
}

class _BuyTicketsScreenState extends ConsumerState<BuyTicketsScreen> {
  final TicketService _ticketService = TicketService();
  
  late String _selectedType;
  late double _selectedPrice;
  int _quantity = 1;
  DateTime _visitDate = DateTime.now().add(const Duration(days: 1)); // Default mañana
  String _paymentMethod = 'Tarjeta de Crédito/Débito';
  bool _freeReservation = false;

  @override
  void initState() {
    super.initState();
    // Iniciar con la primera opción del catálogo
    _selectedType = _ticketService.ticketTypes[0]['type'];
    _selectedPrice = _ticketService.ticketTypes[0]['price'];
  }

  void _selectTicket(String type, double price) {
    setState(() {
      _selectedType = type;
      _selectedPrice = price;
    });
  }

  void _confirmPurchase() async {
    final method = _freeReservation ? 'Reserva gratuita, pago en taquilla' : _paymentMethod;
    
    final success = await ref.read(ticketProvider.notifier).buyTicket(
          _selectedType,
          _quantity,
          _selectedPrice,
          _visitDate,
          method,
        );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_freeReservation 
                ? '¡Reserva completada! Paga en taquilla el día de tu visita.'
                : '¡Compra exitosa! Boletos generados en tu Wallet.'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/?tab=2'); // Navegar a la wallet (Tab 2)
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al procesar la compra.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _visitDate) {
      setState(() {
        _visitDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final ticketState = ref.watch(ticketProvider);

    // Cálculos de precios
    final subtotal = _selectedPrice * _quantity;
    final tax = subtotal * 0.16; // 16% IVA
    final total = _freeReservation ? 0.0 : (subtotal + tax);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprar Boletos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/?tab=0'),
        ),
      ),
      body: authState.isVisitor
          ? _visitorBlockOverlay(theme)
          : ticketState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Selección de Boletos
                      Text(
                        '1. Selecciona tu Tipo de Boleto',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._ticketService.ticketTypes.map((t) {
                        final type = t['type'] as String;
                        final price = t['price'] as double;
                        final desc = t['description'] as String;
                        final isSelected = _selectedType == type;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          elevation: isSelected ? 4 : 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: InkWell(
                            onTap: () => _selectTicket(type, price),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        type,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '\$${price.toInt()} MXN',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    desc,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),

                      // 2. Cantidad y Fecha
                      const SizedBox(height: 20),
                      Text(
                        '2. Opciones de Visita',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              // Stepper de Cantidad
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Cantidad de boletos',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: _quantity > 1
                                            ? () => setState(() => _quantity--)
                                            : null,
                                        icon: const Icon(Icons.remove_circle_outline),
                                      ),
                                      Text(
                                        '$_quantity',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => setState(() => _quantity++),
                                        icon: const Icon(Icons.add_circle_outline),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              // Selector de Fecha
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Fecha de visita',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _selectDate(context),
                                    icon: const Icon(Icons.calendar_today),
                                    label: Text(
                                      DateFormat('dd / MM / yyyy').format(_visitDate),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 3. Métodos de Pago Simulado
                      const SizedBox(height: 20),
                      Text(
                        '3. Método de Pago',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      // Checkbox para Reserva Taquilla
                      SwitchListTile(
                        title: const Text(
                          'Reserva gratuita (pagar en taquilla)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text('Aparta tus accesos y paga al llegar al recinto.'),
                        value: _freeReservation,
                        onChanged: (val) {
                          setState(() {
                            _freeReservation = val;
                          });
                        },
                      ),
                      if (!_freeReservation) ...[
                        const SizedBox(height: 8),
                        ...[
                          'Tarjeta de Crédito/Débito',
                          'Pago en Tienda OXXO',
                          'Transferencia SPEI',
                          'PayPal'
                        ].map((method) {
                          return RadioListTile<String>(
                            title: Text(method),
                            value: method,
                            groupValue: _paymentMethod,
                            onChanged: (val) {
                              setState(() {
                                _paymentMethod = val!;
                              });
                            },
                          );
                        }).toList(),
                      ],

                      // 4. Resumen y Desglose
                      const SizedBox(height: 24),
                      Text(
                        'Resumen del Pedido',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        color: theme.brightness == Brightness.dark
                            ? Colors.grey[900]
                            : Colors.grey[150],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              _priceRow('Boleto $_selectedType (x$_quantity)', '\$${subtotal.toInt()} MXN'),
                              const SizedBox(height: 6),
                              _priceRow('IVA (16%)', _freeReservation ? '\$0 MXN' : '\$${tax.toInt()} MXN'),
                              const Divider(height: 20),
                              _priceRow(
                                'Total a Pagar',
                                '\$${total.toInt()} MXN',
                                isBold: true,
                                color: theme.colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Botón Confirmar
                      ElevatedButton(
                        onPressed: _confirmPurchase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _freeReservation ? 'Reservar Boletos' : 'Proceder al Pago',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _priceRow(String label, String value, {bool isBold = false, Color? color}) {
    final style = TextStyle(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontSize: isBold ? 16 : 14,
      color: color,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
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
                  'Compra no disponible',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'El catálogo de boletos y la pasarela de reservas digitales está limitado a usuarios registrados.',
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
