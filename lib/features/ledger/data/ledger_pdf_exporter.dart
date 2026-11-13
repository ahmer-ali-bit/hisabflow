import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/customer.dart';
import '../domain/ledger_calculator.dart';
import '../domain/ledger_entry.dart';

class LedgerPdfExporter {
  Future<Uint8List> buildCustomerStatement({
    required LedgerCustomer customer,
    required List<LedgerEntry> entries,
    String companyName = '',
  }) async {
    final ordered = [...entries]..sort((a, b) {
        final byDate = a.entryDate.compareTo(b.entryDate);
        return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
      });
    final balances = LedgerCalculator.runningBalances(customer, ordered);
    final balanceById = <String, double>{};
    for (var index = 0; index < ordered.length; index++) {
      balanceById[ordered[index].id] = balances[index];
    }
    final totals = LedgerCalculator.totals(customer, ordered);
    final isStock = customer.isStockLedger;
    final headers = <String>['Date', 'Details', 'Page', 'Debit', 'Credit'];
    if (isStock) headers.addAll(['Buy qty', 'Sell qty']);
    headers.add('Balance');
    final data = <List<String>>[
      for (final entry in ordered)
        [
          _date(entry.entryDate),
          entry.description.isEmpty ? 'Ledger entry' : entry.description,
          entry.pageNumber ?? '—',
          entry.debit.toStringAsFixed(2),
          entry.credit.toStringAsFixed(2),
          if (isStock) _quantity(entry.buyQuantity, customer.useWeight),
          if (isStock) _quantity(entry.sellQuantity, customer.useWeight),
          _balance(balanceById[entry.id] ?? 0),
        ],
    ];
    final document = pw.Document();
    document.addPage(pw.MultiPage(
      pageFormat: isStock ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 30, 28, 32),
      header: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(companyName.trim().isEmpty ? 'HisabFlow' : companyName.trim(), style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
          pw.Text('Customer statement · ${customer.year}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ]),
      ),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ),
      build: (context) => [
        pw.SizedBox(height: 12),
        pw.Text(customer.name, style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
        pw.SizedBox(height: 5),
        pw.Text('${isStock ? 'Stock' : 'General'} ledger${customer.phone.isEmpty ? '' : ' · ${customer.phone}'}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
        pw.Wrap(spacing: 16, runSpacing: 6, children: [
          _metric('Opening debit', customer.openingDebit),
          _metric('Opening credit', customer.openingCredit),
          _metric('Debit total', totals.debit),
          _metric('Credit total', totals.credit),
          pw.Text('Balance ${_balance(totals.balance)}', style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: data,
          headerStyle: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
          cellStyle: const pw.TextStyle(fontSize: 7),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          cellAlignment: pw.Alignment.centerLeft,
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
        ),
      ],
    ));
    return Uint8List.fromList(await document.save());
  }

  pw.Widget _metric(String label, double value) => pw.Text('$label  ${value.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9));

  String _date(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _balance(double value) => value == 0 ? '0.00' : '${value.abs().toStringAsFixed(2)} ${value > 0 ? 'D' : 'C'}';

  String _quantity(double value, bool useWeight) => useWeight ? LedgerCalculator.formatWeightKg(value) : value.toStringAsFixed(2);
}
