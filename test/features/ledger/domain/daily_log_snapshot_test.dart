import 'package:flutter_test/flutter_test.dart';
import 'package:hisabflow/features/ledger/domain/daily_log_snapshot.dart';

void main() {
  group('DailyLogSnapshot', () {
    test('round trips the snapshot fields', () {
      final createdAt = DateTime.utc(2026, 4, 12, 9, 30);
      final original = DailyLogSnapshot(
        id: 'snapshot-1',
        year: 2026,
        createdAt: createdAt,
        debit: 150,
        credit: 25,
        finalBalance: 125,
        customerCount: 2,
        pageNumber: '18A',
        entryIds: ['entry-1', 'entry-2'],
      );

      final restored = DailyLogSnapshot.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.year, original.year);
      expect(restored.createdAt, createdAt);
      expect(restored.debit, original.debit);
      expect(restored.credit, original.credit);
      expect(restored.finalBalance, original.finalBalance);
      expect(restored.customerCount, original.customerCount);
      expect(restored.pageNumber, original.pageNumber);
      expect(restored.entryIds, original.entryIds);
    });

    test('tolerates older snapshot fields and missing optional values', () {
      final restored = DailyLogSnapshot.fromJson({
        'id': 'legacy',
        'year': '2025',
        'savedAt': '2025-12-31T23:59:00.000Z',
        'debit': '100',
        'credit': 40,
        'balance': 60,
        'entryIds': ['entry-a'],
      });

      expect(restored.year, 2025);
      expect(restored.finalBalance, 60);
      expect(restored.pageNumber, isNull);
      expect(restored.entryIds, ['entry-a']);
    });
  });
}
