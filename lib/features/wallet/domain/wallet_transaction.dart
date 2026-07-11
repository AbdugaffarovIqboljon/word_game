import 'package:equatable/equatable.dart';

enum Currency { coins, gems }

/// One append-only wallet ledger entry. [amount] is signed (credit > 0,
/// debit < 0).
class WalletTransaction extends Equatable {
  const WalletTransaction({
    required this.currency,
    required this.amount,
    required this.reason,
    required this.at,
    required this.balanceAfter,
  });

  final Currency currency;
  final int amount;
  final String reason;
  final DateTime at;
  final int balanceAfter;

  Map<String, dynamic> toJson() => {
    'currency': currency.name,
    'amount': amount,
    'reason': reason,
    'at': at.toIso8601String(),
    'balanceAfter': balanceAfter,
  };

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        currency: Currency.values.byName(json['currency'] as String),
        amount: json['amount'] as int,
        reason: json['reason'] as String,
        at: DateTime.parse(json['at'] as String),
        balanceAfter: json['balanceAfter'] as int,
      );

  @override
  List<Object?> get props => [currency, amount, reason, at, balanceAfter];
}
