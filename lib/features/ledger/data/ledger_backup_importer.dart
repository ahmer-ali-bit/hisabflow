import 'dart:convert';

import '../domain/customer.dart';
import '../domain/ledger_entry.dart';

class ImportedLedger {
  const ImportedLedger({required this.year, required this.customers, required this.entries, required this.source});
  final int year;
  final List<LedgerCustomer> customers;
  final List<LedgerEntry> entries;
  final Map<String, dynamic> source;
}

/// Accepts HisabFlow backups and the legacy BalanceDesk schema without mutating source data.
class LedgerBackupImporter {
  const LedgerBackupImporter();

  ImportedLedger decode(String text) {
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) throw const FormatException('Backup root must be a JSON object.');
    final customerKey = _firstKey(decoded, const ['customers', 'clients']);
    final entryKey = _firstKey(decoded, const ['entries', 'transactions', 'ledgerEntries']);
    if (customerKey == null || entryKey == null || decoded[customerKey] is! List || decoded[entryKey] is! List) {
      throw const FormatException('This backup does not contain a recognized customer and entry list. No data was changed.');
    }
    final customerRows = _list(decoded, [customerKey]);
    final entryRows = _list(decoded, [entryKey]);
    final year = _int(decoded['activeYear'] ?? decoded['active_year'], DateTime.now().year);
    final customers = <LedgerCustomer>[];
    final idMap = <String, String>{};
    for (var i = 0; i < customerRows.length; i++) {
      final row = customerRows[i];
      if (row is! Map<String, dynamic>) throw FormatException('Customer record ${i + 1} is invalid.');
      final id = '${row['id'] ?? i}';
      final name = '${row['name'] ?? row['customerName'] ?? ''}'.trim();
      if (name.isEmpty) throw FormatException('Customer record ${i + 1} has no name.');
      idMap[id] = id;
      customers.add(LedgerCustomer(
        id: id,
        name: name,
        year: _int(row['ledgerYear'] ?? row['year'], year),
        phone: '${row['phone'] ?? ''}',
        address: '${row['address'] ?? ''}',
        isStockLedger: _bool(row['isStockLedger'] ?? row['is_stock_ledger']),
        useWeight: _bool(row['useWeight'] ?? row['use_weight']),
        openingDebit: _num(row['openingDebit'] ?? row['opening_debit'] ?? row['openingBalanceDebit']),
        openingCredit: _num(row['openingCredit'] ?? row['opening_credit'] ?? row['openingBalanceCredit']),
        openingBuyQuantity: _num(row['openingBuyQuantity'] ?? row['opening_buy_quantity'] ?? row['openingBuyWeight'] ?? row['opening_buy_weight']),
        openingSellQuantity: _num(row['openingSellQuantity'] ?? row['opening_sell_quantity'] ?? row['openingSellWeight'] ?? row['opening_sell_weight']),
      ));
    }
    final entries = <LedgerEntry>[];
    for (var i = 0; i < entryRows.length; i++) {
      final row = entryRows[i];
      if (row is! Map<String, dynamic>) throw FormatException('Entry record ${i + 1} is invalid.');
      final rawCustomer = '${row['customerId'] ?? row['customer_id'] ?? row['customer'] ?? ''}';
      if (rawCustomer.isEmpty || !idMap.containsKey(rawCustomer)) {
        throw FormatException('Entry record ${i + 1} has an unmatched customer reference. No data was changed.');
      }
      entries.add(LedgerEntry.fromJson({...row, 'id': row['id'] ?? 'import-$i', 'customerId': idMap[rawCustomer]}));
    }
    if (customers.isEmpty && entries.isEmpty) {
      throw const FormatException('No customer or ledger records were found in this backup.');
    }
    return ImportedLedger(year: year, customers: customers, entries: entries, source: decoded);
  }

  String? _firstKey(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key)) return key;
    }
    return null;
  }

  List<Object?> _list(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json[key] is List) return (json[key] as List).cast<Object?>();
    }
    return const [];
  }

  int _int(Object? value, int fallback) => int.tryParse('$value') ?? fallback;
  double _num(Object? value) => double.tryParse('$value') ?? 0;
  bool _bool(Object? value) => value == true || value == 1 || value == '1';
}
