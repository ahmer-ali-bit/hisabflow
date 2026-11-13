import 'package:flutter_test/flutter_test.dart';
import 'package:hisabflow/features/ledger/data/ledger_pdf_exporter.dart';
import 'package:hisabflow/features/ledger/domain/customer.dart';
import 'package:hisabflow/features/ledger/domain/ledger_entry.dart';

void main() {
  test('builds a printable customer statement PDF', () async {
    const customer = LedgerCustomer(
      id: 'customer-1',
      name: 'Sample customer',
      year: 2026,
      openingDebit: 50,
    );
    final entry = LedgerEntry(
      id: 'entry-1',
      customerId: customer.id,
      entryDate: DateTime.utc(2026, 1, 5),
      createdAt: DateTime.utc(2026, 1, 5, 9),
      description: 'Opening transaction',
      debit: 25,
    );

    final bytes = await LedgerPdfExporter().buildCustomerStatement(
      customer: customer,
      entries: [entry],
      companyName: 'Sample company',
    );

    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(bytes.length, greaterThan(500));
  });
}
