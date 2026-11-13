import 'package:flutter_test/flutter_test.dart';
import 'package:hisabflow/features/ledger/domain/customer.dart';
import 'package:hisabflow/features/ledger/domain/ledger_calculator.dart';
import 'package:hisabflow/features/ledger/domain/ledger_entry.dart';

void main() {
  group('LedgerCalculator', () {
    test('normal totals include opening balance and entries', () {
      const customer = LedgerCustomer(id: 'c', name: 'Customer', year: 2026, openingDebit: 100);
      final entries = [
        LedgerEntry(id: '1', customerId: 'c', entryDate: DateTime(2026), createdAt: DateTime(2026), debit: 500),
        LedgerEntry(id: '2', customerId: 'c', entryDate: DateTime(2026, 1, 2), createdAt: DateTime(2026, 1, 2), credit: 200),
      ];
      final totals = LedgerCalculator.totals(customer, entries);
      expect(totals.debit, 600);
      expect(totals.credit, 200);
      expect(totals.balance, 400);
      expect(totals.balanceLabel, '400.00 D');
    });

    test('stock display balance is credit less debit and quantities remain buy less sell', () {
      const customer = LedgerCustomer(id: 'c', name: 'Stock', year: 2026, isStockLedger: true, openingBuyQuantity: 40);
      final entries = [LedgerEntry(id: '1', customerId: 'c', entryDate: DateTime(2026), createdAt: DateTime(2026), debit: 100, credit: 40, buyQuantity: 10, sellQuantity: 6)];
      final totals = LedgerCalculator.totals(customer, entries);
      expect(totals.balance, -60);
      expect(totals.summaryBalance, 60);
      expect(totals.remainingQuantity, 44);
    });

    test('weight formatting uses 40 kg mund', () {
      expect(LedgerCalculator.formatWeightKg(420), '10-20');
      expect(LedgerCalculator.formatWeightKg(25), '25');
      expect(LedgerCalculator.parseWeightKg('10-20'), 420);
      expect(LedgerCalculator.parseWeightKg('25'), 25);
    });

    test('normal entries require at least one amount', () {
      expect(LedgerCalculator.validateEntry(debit: 0, credit: 0, stock: false), isNotNull);
      expect(LedgerCalculator.validateEntry(debit: 10, credit: 20, stock: false), isNull);
    });

    test('stock amount and matching quantity are validated as pairs', () {
      expect(LedgerCalculator.validateEntry(debit: 10, credit: 0, stock: true, buyQuantity: 0), isNotNull);
      expect(LedgerCalculator.validateEntry(debit: 10, credit: 0, stock: true, buyQuantity: 2), isNull);
    });
  });
}
