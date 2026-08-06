class WalletTransaction {
  final int id;
  final String type;
  final double amount;
  final double balanceAfter;
  final String description;
  final String? referenceType;
  final int? referenceId;
  final String status;
  final DateTime? createdAt;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    this.referenceType,
    this.referenceId,
    required this.status,
    this.createdAt,
  });

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: _toInt(json['id']),
      type: json['type'] ?? '',
      amount: _toDouble(json['amount']),
      balanceAfter: _toDouble(json['balance_after']),
      description: json['description'] ?? '',
      referenceType: json['reference_type'],
      referenceId: _toInt(json['reference_id']),
      status: json['status'] ?? 'completed',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  bool get isCredit => type == 'credit';
  bool get isDebit => type == 'debit';
  bool get isRefund => type == 'refund';
}