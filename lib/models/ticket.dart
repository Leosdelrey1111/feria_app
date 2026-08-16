class Ticket {
  final String id;
  final String type; // General, VIP, Familiar
  final int quantity;
  final double totalPrice;
  final DateTime visitDate;
  final String qrCodeData;
  final String status; // Válido, Usado, Reservado, Cancelado

  Ticket({
    required this.id,
    required this.type,
    required this.quantity,
    required this.totalPrice,
    required this.visitDate,
    required this.qrCodeData,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'visitDate': visitDate.toIso8601String(),
      'qrCodeData': qrCodeData,
      'status': status,
    };
  }

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'],
      type: json['type'],
      quantity: (json['quantity'] as num).toInt(),
      totalPrice: (json['totalPrice'] as num).toDouble(),
      visitDate: DateTime.parse(json['visitDate']),
      qrCodeData: json['qrCodeData'],
      status: json['status'],
    );
  }
}
