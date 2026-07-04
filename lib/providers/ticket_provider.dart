import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ticket.dart';
import '../services/ticket_service.dart';

class TicketState {
  final List<Ticket> tickets;
  final bool isLoading;

  TicketState({
    this.tickets = const [],
    this.isLoading = false,
  });

  TicketState copyWith({
    List<Ticket>? tickets,
    bool? isLoading,
  }) {
    return TicketState(
      tickets: tickets ?? this.tickets,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class TicketNotifier extends StateNotifier<TicketState> {
  final TicketService _service;

  TicketNotifier(this._service) : super(TicketState()) {
    loadTickets();
  }

  // Cargar boletos guardados
  Future<void> loadTickets() async {
    state = state.copyWith(isLoading: true);
    try {
      final list = await _service.getPurchasedTickets();
      state = state.copyWith(tickets: list, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  // Reservar/Comprar boleto
  Future<bool> buyTicket(String type, int quantity, double pricePerItem, DateTime visitDate, String paymentMethod) async {
    state = state.copyWith(isLoading: true);
    try {
      final total = pricePerItem * quantity;
      final ticketId = 'tkt-${DateTime.now().millisecondsSinceEpoch}';
      
      // Simular generación de código QR con metadatos del ticket
      final qrData = 'FERIA2026|$ticketId|$type|$quantity|${visitDate.toIso8601String()}';

      final newTicket = Ticket(
        id: ticketId,
        type: type,
        quantity: quantity,
        totalPrice: total,
        visitDate: visitDate,
        qrCodeData: qrData,
        status: paymentMethod == 'Reserva gratuita, pago en taquilla' ? 'Reservado' : 'Válido',
      );

      await _service.purchaseTicket(newTicket);
      await loadTickets(); // Recargar de SharedPreferences
      return true;
    } catch (_) {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  // Limpiar boletos al cerrar sesión
  Future<void> clearAll() async {
    await _service.clearTickets();
    state = TicketState();
  }
}

// Provider del servicio de boletos
final ticketServiceProvider = Provider<TicketService>((ref) {
  return TicketService();
});

// Provider del estado del wallet de boletos
final ticketProvider = StateNotifierProvider<TicketNotifier, TicketState>((ref) {
  final service = ref.watch(ticketServiceProvider);
  return TicketNotifier(service);
});
