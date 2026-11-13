import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisabflow/core/security/vault_store.dart';
import 'package:hisabflow/features/ledger/data/local_ledger_repository.dart';
import 'package:hisabflow/features/ledger/domain/ledger_entry.dart';

void main() {
  group('LocalLedgerRepository', () {
    test('carries forward general and stock balances into a new year', () async {
      final repository = LocalLedgerRepository(vault: _MemoryVault());
      final year = DateTime.now().year;
      await repository.addCustomer(name: 'General account', year: year);
      await repository.addCustomer(name: 'Stock account', year: year, isStock: true);
      final customers = await repository.customers();
      final general = customers.firstWhere((item) => item.name == 'General account');
      final stock = customers.firstWhere((item) => item.name == 'Stock account');
      await repository.addEntry(_entry('general-entry', general.id, debit: 100, credit: 20), stockLedger: false);
      await repository.addEntry(_entry('stock-entry', stock.id, debit: 60, credit: 20, buy: 3, sell: 1), stockLedger: true);

      await repository.createYear(year + 1);

      final nextYearCustomers = (await repository.customers()).where((item) => item.year == year + 1).toList();
      final nextGeneral = nextYearCustomers.singleWhere((item) => item.name == 'General account');
      final nextStock = nextYearCustomers.singleWhere((item) => item.name == 'Stock account');
      expect(nextGeneral.openingDebit, 80);
      expect(nextGeneral.openingCredit, 0);
      expect(nextStock.openingDebit, 0);
      expect(nextStock.openingCredit, 40);
      expect(nextStock.openingBuyQuantity, 2);
      expect(nextStock.openingSellQuantity, 0);
      expect((await repository.entries()).length, 2);
    });

    test('saves incremental snapshots and recalculates after hiding an entry', () async {
      final repository = LocalLedgerRepository(vault: _MemoryVault());
      final year = DateTime.now().year;
      await repository.addCustomer(name: 'Daily account', year: year);
      final customer = (await repository.customers()).single;
      final firstTime = DateTime.utc(year, 3, 2, 10);
      final secondTime = DateTime.utc(year, 3, 2, 11);
      await repository.addEntry(_entry('first', customer.id, debit: 40, createdAt: firstTime), stockLedger: false);
      final firstSnapshot = await repository.saveSnapshot(
        year: year,
        pageNumber: 'A1',
        savedAt: DateTime.utc(year, 3, 2, 10, 30),
      );
      await repository.addEntry(_entry('second', customer.id, credit: 5, createdAt: secondTime), stockLedger: false);
      final secondSnapshot = await repository.saveSnapshot(
        year: year,
        pageNumber: 'A2',
        savedAt: DateTime.utc(year, 3, 2, 11, 30),
      );

      expect(firstSnapshot.finalBalance, 40);
      expect(secondSnapshot.debit, 40);
      expect(secondSnapshot.credit, 5);
      expect(secondSnapshot.finalBalance, 35);

      await repository.setEntryDailyLogVisibility('first', false);
      await repository.recalculateSnapshots(year);

      final recalculated = await repository.dailySnapshots(year);
      expect(recalculated.first.finalBalance, 0);
      expect(recalculated.last.credit, 5);
      expect(recalculated.last.finalBalance, -5);
    });

    test('workspaces retain independent customer data', () async {
      final repository = LocalLedgerRepository(vault: _MemoryVault());
      final initial = await repository.workspaceState();
      await repository.addCustomer(name: 'First workspace customer', year: DateTime.now().year);
      await repository.createWorkspace('Second business');
      await repository.addCustomer(name: 'Second workspace customer', year: DateTime.now().year);

      expect((await repository.customers()).map((item) => item.name), ['Second workspace customer']);
      await repository.switchWorkspace('${initial.active['id']}');
      expect((await repository.customers()).map((item) => item.name), ['First workspace customer']);
    });

    test('CSV export quotes spreadsheet fields and includes opening rows', () async {
      final repository = LocalLedgerRepository(vault: _MemoryVault());
      final year = DateTime.now().year;
      await repository.addCustomer(name: 'Client, Co', year: year);
      await repository.addCustomer(name: '=SUM(1,2)', year: year);
      final customer = (await repository.customers()).firstWhere((item) => item.name == 'Client, Co');
      final entry = LedgerEntry(
        id: 'csv-entry',
        customerId: customer.id,
        entryDate: DateTime.utc(year, 2, 3),
        createdAt: DateTime.utc(year, 2, 3, 9),
        description: 'Rice, "Grade A"',
        debit: 12.5,
      );
      await repository.addEntry(entry, stockLedger: false);

      final csv = await repository.exportCsv(year: year);

      expect(csv, startsWith('record_type,year,customer_id'));
      expect(csv, contains('"Client, Co"'));
      expect(csv, contains("'=SUM(1,2)"));
      expect(csv, contains('"Rice, ""Grade A"""'));
      expect(csv, contains('opening,$year'));
      expect(csv, contains('entry,$year'));
    });
  });
}

LedgerEntry _entry(
  String id,
  String customerId, {
  double debit = 0,
  double credit = 0,
  double buy = 0,
  double sell = 0,
  DateTime? createdAt,
}) => LedgerEntry(
      id: id,
      customerId: customerId,
      entryDate: createdAt ?? DateTime.now(),
      createdAt: createdAt ?? DateTime.now(),
      debit: debit,
      credit: credit,
      buyQuantity: buy,
      sellQuantity: sell,
    );

class _MemoryVault implements VaultStore {
  Map<String, dynamic>? _document;

  @override
  Future<Map<String, dynamic>?> read() async {
    if (_document == null) return null;
    return jsonDecode(jsonEncode(_document)) as Map<String, dynamic>;
  }

  @override
  Future<void> write(Map<String, Object?> document) async {
    _document = jsonDecode(jsonEncode(document)) as Map<String, dynamic>;
  }
}
