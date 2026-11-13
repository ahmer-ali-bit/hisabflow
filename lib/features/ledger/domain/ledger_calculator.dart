import 'customer.dart';
import 'ledger_entry.dart';

class LedgerTotals {
  const LedgerTotals({
    required this.debit,
    required this.credit,
    required this.balance,
    required this.summaryBalance,
    required this.buyQuantity,
    required this.sellQuantity,
    required this.remainingQuantity,
  });

  final double debit;
  final double credit;
  final double balance;
  final double summaryBalance;
  final double buyQuantity;
  final double sellQuantity;
  final double remainingQuantity;

  String get balanceLabel => balance == 0
      ? '0'
      : '${balance.abs().toStringAsFixed(2)} ${balance > 0 ? 'D' : 'C'}';
}

class LedgerCalculator {
  const LedgerCalculator._();

  static LedgerTotals totals(LedgerCustomer customer, Iterable<LedgerEntry> entries) {
    var debit = customer.openingDebit;
    var credit = customer.openingCredit;
    var bought = customer.openingBuyQuantity;
    var sold = customer.openingSellQuantity;
    for (final entry in entries) {
      debit += entry.debit;
      credit += entry.credit;
      bought += entry.buyQuantity;
      sold += entry.sellQuantity;
    }
    // Ledger balance follows debit-credit; stock ledger display intentionally reverses it.
    final balance = customer.isStockLedger ? credit - debit : debit - credit;
    return LedgerTotals(
      debit: debit,
      credit: credit,
      balance: balance,
      summaryBalance: debit - credit,
      buyQuantity: bought,
      sellQuantity: sold,
      remainingQuantity: bought - sold,
    );
  }

  static List<double> runningBalances(LedgerCustomer customer, List<LedgerEntry> entries) {
    final ordered = [...entries]..sort((a, b) {
        final byDate = a.entryDate.compareTo(b.entryDate);
        return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
      });
    var balance = customer.isStockLedger
        ? customer.openingCredit - customer.openingDebit
        : customer.openingDebit - customer.openingCredit;
    return ordered.map((entry) {
      balance += customer.isStockLedger
          ? entry.credit - entry.debit
          : entry.debit - entry.credit;
      return balance;
    }).toList(growable: false);
  }

  static double quantityToKg(double quantity) => quantity;

  static double parseWeightKg(String value) {
    final parts = value.trim().split('-');
    if (parts.length == 2) {
      final mund = double.parse(parts[0].trim());
      final kilograms = double.parse(parts[1].trim());
      if (mund < 0 || kilograms < 0 || kilograms >= 40) {
        throw const FormatException('Weight must use Mund-KG format, with the KG part below 40.');
      }
      return mund * 40 + kilograms;
    }
    return double.parse(value.trim());
  }

  static String formatWeightKg(double kilograms) {
    final mund = kilograms ~/ 40;
    final remainder = kilograms - mund * 40;
    if (kilograms < 40) return kilograms.toStringAsFixed(0);
    return remainder == 0 ? '$mund' : '$mund-${remainder.toStringAsFixed(0)}';
  }

  static String? validateEntry({
    required double debit,
    required double credit,
    required bool stock,
    double buyQuantity = 0,
    double sellQuantity = 0,
  }) {
    if (!debit.isFinite || !credit.isFinite || !buyQuantity.isFinite || !sellQuantity.isFinite) {
      return 'Enter valid numeric amounts and quantities.';
    }
    if (debit < 0 || credit < 0 || buyQuantity < 0 || sellQuantity < 0) {
      return 'Amounts and quantities cannot be negative.';
    }
    if (stock) {
      if (debit == 0 && credit == 0 && buyQuantity == 0 && sellQuantity == 0) {
        return 'Enter at least one quantity or amount.';
      }
      if ((debit > 0) != (buyQuantity > 0) || (credit > 0) != (sellQuantity > 0)) {
        return 'Each stock amount requires its matching quantity.';
      }
    } else if (debit == 0 && credit == 0) {
      return 'Debit or credit must be greater than zero.';
    }
    return null;
  }
}
