import 'package:flutter_test/flutter_test.dart';
import 'package:hisabflow/features/ledger/data/ledger_backup_importer.dart';

void main() {
  const importer = LedgerBackupImporter();

  test('maps a legacy ledger backup without changing balances or stock flags', () {
    final result = importer.decode('''{
      "backupType": "balancedesk-manual-backup",
      "schemaVersion": 2,
      "activeYear": 2026,
      "customers": [{"id": 14, "name": "  Ayesha  ", "ledgerYear": 2026, "isStockLedger": 1, "useWeight": 1}],
      "entries": [{"id": 80, "customerId": 14, "entry_date": "2026-02-01", "created_at": "2026-02-01T10:00:00", "buy_amount": 100, "buy_weight": 420}]
    }''');

    expect(result.year, 2026);
    expect(result.customers.single.name, 'Ayesha');
    expect(result.customers.single.isStockLedger, isTrue);
    expect(result.customers.single.useWeight, isTrue);
    expect(result.entries.single.customerId, '14');
    expect(result.entries.single.debit, 100);
    expect(result.entries.single.buyQuantity, 420);
  });

  test('rejects an unknown/incomplete backup rather than silently restoring zero records', () {
    expect(() => importer.decode('{"customers": []}'), throwsFormatException);
  });

  test('rejects orphan entries before replacing stored data', () {
    expect(
      () => importer.decode('{"customers": [{"id": 1, "name": "A"}], "entries": [{"customerId": 9}]}'),
      throwsFormatException,
    );
  });
}
