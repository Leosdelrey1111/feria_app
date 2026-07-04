import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ticket.dart';

class TicketService {
  static const String keyTickets = 'purchased_tickets';

  // Catálogo de boletos
  final List<Map<String, dynamic>> ticketTypes = [
    {
      'type': 'General',
      'price': 150.0,
      'description': 'Acceso general al recinto de la feria, pabellones de exposiciones y Teatro del Pueblo (Foro B).',
    },
    {
      'type': 'VIP',
      'price': 450.0,
      'description': 'Acceso preferente (sin filas), asientos reservados en Foro Principal (Foro A), y 1 bebida de cortesía.',
    },
    {
      'type': 'Familiar',
      'price': 400.0,
      'description': 'Paquete de acceso completo válido para 2 adultos y 2 niños menores de 12 años.',
    },
  ];

  // Obtener boletos del usuario
  Future<List<Ticket>> getPurchasedTickets() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(keyTickets) ?? [];
    
    // Si la lista está vacía, podemos crear un ticket por defecto de prueba para que la UI no se vea vacía al inicio (opcional)
    if (jsonList.isEmpty) {
      return [];
    }

    return jsonList.map((item) => Ticket.fromJson(json.decode(item))).toList();
  }

  // Comprar/Reservar boleto
  Future<void> purchaseTicket(Ticket ticket) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(keyTickets) ?? [];
    
    jsonList.add(json.encode(ticket.toJson()));
    await prefs.setStringList(keyTickets, jsonList);
  }

  // Limpiar boletos (al cerrar sesión o borrar cuenta)
  Future<void> clearTickets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyTickets);
  }
}
