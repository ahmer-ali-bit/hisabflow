import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/security/encrypted_vault.dart';
import '../../../core/security/vault_store.dart';
import '../domain/customer.dart';
import '../domain/ledger_entry.dart';
import '../domain/ledger_calculator.dart';
import '../domain/daily_log_snapshot.dart';
import 'ledger_backup_importer.dart';

class LocalLedgerRepository {
  LocalLedgerRepository({VaultStore? vault}) : _vault = vault ?? EncryptedVault();
  final VaultStore _vault;
  static const _uuid = Uuid();
  static const _workspaceId = 'default-workspace';

  Future<Map<String, dynamic>> load() async {
    final stored = await _vault.read();
    if (stored != null) return stored;
    final empty = <String, dynamic>{
      'formatVersion': 1,
      'activeWorkspaceId': _workspaceId,
      'workspaces': [
        {
          'id': _workspaceId,
          'name': 'My workspace',
          'activeYear': DateTime.now().year,
          'years': [DateTime.now().year],
          'customers': <Object?>[],
          'entries': <Object?>[],
          'snapshots': <Object?>[],
          'dailyLogOpeningDebit': 0,
          'dailyLogOpeningCredit': 0,
          'notes': '',
          'companyName': '',
          'companyLogo': null,
        }
      ],
    };
    await _vault.write(empty);
    return empty;
  }

  Future<Map<String, dynamic>> currentWorkspace() async => _activeWorkspace(await load());

  Future<({Map<String, dynamic> active, List<Map<String, dynamic>> all})> workspaceState() async {
    final data = await load();
    final all = (data['workspaces'] as List? ?? const []).whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
    return (active: _activeWorkspace(data), all: all);
  }

  Future<int> activeYear() async => int.tryParse('${_activeWorkspace(await load())['activeYear']}') ?? DateTime.now().year;

  Future<List<int>> years() async {
    final values = (_activeWorkspace(await load())['years'] as List? ?? const []).map((value) => int.tryParse('$value')).whereType<int>().toSet().toList()..sort();
    return values;
  }

  Future<void> selectYear(int year) async {
    final data = await load();
    final workspace = _activeWorkspace(data);
    final values = (workspace['years'] as List? ?? const []).map((value) => int.tryParse('$value')).whereType<int>().toSet();
    if (!values.contains(year)) throw StateError('Ledger year does not exist.');
    workspace['activeYear'] = year;
    await _vault.write(data);
  }

  Future<void> createYear(int year) async {
    if (year < 1900 || year > 9999) throw ArgumentError('Year must be from 1900 to 9999.');
    final data = await load();
    final workspace = _activeWorkspace(data);
    final years = (workspace['years'] as List? ?? const []).map((value) => int.tryParse('$value')).whereType<int>().toSet();
    if (years.contains(year)) throw StateError('This ledger year already exists.');
    final sourceYear = int.tryParse('${workspace['activeYear']}') ?? DateTime.now().year;
    final oldCustomers = (workspace['customers'] as List? ?? <Object?>[]).whereType<Map>().map((row) => LedgerCustomer.fromJson(Map<String, dynamic>.from(row))).where((customer) => customer.year == sourceYear).toList();
    final oldEntries = (workspace['entries'] as List? ?? <Object?>[]).whereType<Map>().map((row) => LedgerEntry.fromJson(Map<String, dynamic>.from(row))).toList();
    final customers = (workspace['customers'] as List? ?? <Object?>[]).toList();
    for (final customer in oldCustomers) {
      final entries = oldEntries.where((entry) => entry.customerId == customer.id).toList();
      final totals = LedgerCalculator.totals(customer, entries);
      final closing = totals.balance;
      final quantity = totals.remainingQuantity;
      customers.add(LedgerCustomer(
        id: _uuid.v4(), name: customer.name, year: year, phone: customer.phone, address: customer.address,
        isStockLedger: customer.isStockLedger, useWeight: customer.useWeight,
        openingDebit: closing > 0 ? closing : 0,
        openingCredit: closing < 0 ? -closing : 0,
        openingBuyQuantity: quantity > 0 ? quantity : 0,
        openingSellQuantity: quantity < 0 ? -quantity : 0,
      ).toJson());
    }
    workspace['customers'] = customers;
    years.add(year);
    workspace['years'] = years.toList()..sort();
    workspace['activeYear'] = year;
    final snapshots = (workspace['snapshots'] as List? ?? <Object?>[]).whereType<Map>().toList();
    final priorSnapshots = snapshots.where((row) => int.tryParse('${row['year'] ?? sourceYear}') == sourceYear).toList()..sort((a, b) => '${a['createdAt'] ?? a['savedAt']}'.compareTo('${b['createdAt'] ?? b['savedAt']}'));
    var dailyClosing = 0.0;
    if (priorSnapshots.isNotEmpty) {
      final latest = priorSnapshots.last;
      dailyClosing = double.tryParse('${latest['finalBalance'] ?? latest['balance'] ?? 0}') ?? 0;
    } else {
      dailyClosing = _dailyClosing(workspace, oldCustomers, oldEntries);
    }
    workspace['dailyLogOpeningDebit'] = dailyClosing > 0 ? dailyClosing : 0;
    workspace['dailyLogOpeningCredit'] = dailyClosing < 0 ? -dailyClosing : 0;
    await _vault.write(data);
  }

  double _dailyClosing(Map<String, dynamic> workspace, List<LedgerCustomer> customers, List<LedgerEntry> entries) {
    var debit = double.tryParse('${workspace['dailyLogOpeningDebit'] ?? 0}') ?? 0;
    var credit = double.tryParse('${workspace['dailyLogOpeningCredit'] ?? 0}') ?? 0;
    final customerById = {for (final customer in customers) customer.id: customer};
    for (final entry in entries) {
      if (!entry.dailyLogVisible) continue;
      final customer = customerById[entry.customerId];
      if (customer == null) continue;
      if (customer.isStockLedger) {
        debit += entry.credit;
        credit += entry.debit;
      } else {
        debit += entry.debit;
        credit += entry.credit;
      }
    }
    return debit - credit;
  }

  Future<void> deleteYear(int year) async {
    final data = await load();
    final workspace = _activeWorkspace(data);
    final years = (workspace['years'] as List? ?? const []).map((value) => int.tryParse('$value')).whereType<int>().toSet();
    if (years.length <= 1) throw StateError('The last ledger year cannot be deleted.');
    if (!years.remove(year)) throw StateError('Ledger year does not exist.');
    final customers = (workspace['customers'] as List? ?? <Object?>[]).whereType<Map>().toList();
    final ids = customers.where((row) => int.tryParse('${row['year'] ?? row['ledgerYear']}') == year).map((row) => '${row['id']}').toSet();
    workspace['customers'] = customers.where((row) => !ids.contains('${row['id']}')).toList();
    final entries = (workspace['entries'] as List? ?? <Object?>[]).whereType<Map>().toList();
    workspace['entries'] = entries.where((row) => !ids.contains('${row['customerId'] ?? row['customer_id']}')).toList();
    final snapshots = (workspace['snapshots'] as List? ?? <Object?>[]).whereType<Map>().toList();
    workspace['snapshots'] = snapshots.where((row) => int.tryParse('${row['year'] ?? 0}') != year).toList();
    workspace['years'] = years.toList()..sort();
    if (int.tryParse('${workspace['activeYear']}') == year) workspace['activeYear'] = years.reduce((a, b) => a > b ? a : b);
    await _vault.write(data);
  }

  Future<void> saveNotes(String notes) async {
    final data = await load();
    _activeWorkspace(data)['notes'] = notes;
    await _vault.write(data);
  }

  Future<void> saveCompanyProfile({required String name, String? logoData}) async {
    final data = await load();
    final workspace = _activeWorkspace(data);
    workspace['companyName'] = name.trim();
    workspace['companyLogo'] = logoData;
    await _vault.write(data);
  }

  Future<List<Map<String, dynamic>>> workspaces() async {
    final data = await load();
    return (data['workspaces'] as List? ?? const []).whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> createWorkspace(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) throw ArgumentError('Workspace name is required.');
    final data = await load();
    final existing = (data['workspaces'] as List? ?? const []).whereType<Map>().toList();
    final year = DateTime.now().year;
    final id = _uuid.v4();
    existing.add(_emptyWorkspace(id, normalized, year));
    data['workspaces'] = existing;
    data['activeWorkspaceId'] = id;
    await _vault.write(data);
  }

  Future<void> renameWorkspace(String workspaceId, String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) throw ArgumentError('Workspace name is required.');
    final data = await load();
    final rows = (data['workspaces'] as List? ?? const []).whereType<Map>().toList();
    final workspace = rows.firstWhere((row) => '${row['id']}' == workspaceId, orElse: () => throw StateError('Workspace not found.'));
    workspace['name'] = normalized;
    data['workspaces'] = rows;
    await _vault.write(data);
  }

  Future<void> switchWorkspace(String workspaceId) async {
    final data = await load();
    final rows = (data['workspaces'] as List? ?? const []).whereType<Map>().toList();
    if (!rows.any((row) => '${row['id']}' == workspaceId)) throw StateError('Workspace not found.');
    data['activeWorkspaceId'] = workspaceId;
    await _vault.write(data);
  }

  Future<void> deleteWorkspace(String workspaceId) async {
    final data = await load();
    final rows = (data['workspaces'] as List? ?? const []).whereType<Map>().toList();
    if (rows.length <= 1) throw StateError('The last workspace cannot be deleted.');
    final remaining = rows.where((row) => '${row['id']}' != workspaceId).toList();
    if (remaining.length == rows.length) throw StateError('Workspace not found.');
    data['workspaces'] = remaining;
    if ('${data['activeWorkspaceId']}' == workspaceId) data['activeWorkspaceId'] = remaining.first['id'];
    await _vault.write(data);
  }

  Map<String, Object?> _emptyWorkspace(String id, String name, int year) => {
        'id': id,
        'name': name,
        'activeYear': year,
        'years': [year],
        'customers': <Object?>[],
        'entries': <Object?>[],
        'snapshots': <Object?>[],
        'dailyLogOpeningDebit': 0,
        'dailyLogOpeningCredit': 0,
        'notes': '',
        'companyName': '',
        'companyLogo': null,
      };

  Future<String> exportCsv({int? year}) async {
    final workspace = _activeWorkspace(await load());
    final selectedYear = year ?? int.tryParse('${workspace['activeYear']}') ?? DateTime.now().year;
    final customers = (workspace['customers'] as List? ?? const []).whereType<Map>()
        .map((row) => LedgerCustomer.fromJson(Map<String, dynamic>.from(row)))
        .where((customer) => customer.year == selectedYear)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final customerById = {for (final customer in customers) customer.id: customer};
    final entries = (workspace['entries'] as List? ?? const []).whereType<Map>()
        .map((row) => LedgerEntry.fromJson(Map<String, dynamic>.from(row)))
        .where((entry) => customerById.containsKey(entry.customerId))
        .toList()
      ..sort((a, b) {
        final byDate = a.entryDate.compareTo(b.entryDate);
        return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
      });
    final rows = <List<Object?>>[
      ['record_type', 'year', 'customer_id', 'customer_name', 'phone', 'address', 'entry_id', 'entry_date', 'created_at', 'page', 'description', 'debit', 'credit', 'buy_quantity', 'sell_quantity', 'stock_ledger', 'weight_mode', 'daily_log_visible'],
    ];
    for (final customer in customers) {
      rows.add([
        'opening', selectedYear, customer.id, customer.name, customer.phone, customer.address,
        '', '', '', '', 'Opening balance', customer.openingDebit, customer.openingCredit,
        customer.openingBuyQuantity, customer.openingSellQuantity, customer.isStockLedger, customer.useWeight, '',
      ]);
      for (final entry in entries.where((item) => item.customerId == customer.id)) {
        rows.add([
          'entry', selectedYear, customer.id, customer.name, customer.phone, customer.address,
          entry.id, entry.entryDate.toIso8601String(), entry.createdAt.toIso8601String(), entry.pageNumber ?? '', entry.description,
          entry.debit, entry.credit, entry.buyQuantity, entry.sellQuantity, customer.isStockLedger, customer.useWeight, entry.dailyLogVisible,
        ]);
      }
    }
    return rows.map((row) => row.map(_csvField).join(',')).join('\r\n');
  }

  String _csvField(Object? value) {
    var text = '$value';
    // Prevent spreadsheet formula execution in untrusted text fields.
    if (value is String && RegExp(r'^\s*[=+@-]').hasMatch(text)) text = "'$text";
    if (!text.contains(',') && !text.contains('"') && !text.contains('\n') && !text.contains('\r')) return text;
    return '"${text.replaceAll('"', '""')}"';
  }

  Future<String> exportBackupJson() async {
    final workspace = _activeWorkspace(await load());
    return const JsonEncoder.withIndent('  ').convert({
      'backupType': 'hisabflow-manual-backup',
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'activeYear': workspace['activeYear'],
      'years': workspace['years'],
      'workspace': {'id': workspace['id'], 'name': workspace['name']},
      'customers': workspace['customers'] ?? [],
      'entries': workspace['entries'] ?? [],
      'snapshots': workspace['snapshots'] ?? [],
      'dailyLogOpeningDebit': workspace['dailyLogOpeningDebit'] ?? 0,
      'dailyLogOpeningCredit': workspace['dailyLogOpeningCredit'] ?? 0,
      'notes': workspace['notes'] ?? '',
      'companyName': workspace['companyName'] ?? '',
      'companyLogo': workspace['companyLogo'],
      'legacySourceBackup': workspace['legacySourceBackup'],
    });
  }

  Future<List<LedgerCustomer>> customers() async {
    final workspace = _activeWorkspace(await load());
    final rows = (workspace['customers'] as List? ?? const []).whereType<Map>().toList();
    return rows.map((row) => LedgerCustomer.fromJson(Map<String, dynamic>.from(row))).toList();
  }

  Future<List<LedgerEntry>> entries() async {
    final workspace = _activeWorkspace(await load());
    final rows = (workspace['entries'] as List? ?? const []).whereType<Map>().toList();
    return rows.map((row) => LedgerEntry.fromJson(Map<String, dynamic>.from(row))).toList();
  }

  Future<void> addCustomer({required String name, required int year, String phone = '', String address = '', bool isStock = false, bool useWeight = false}) async {
    final data = await load();
    final workspace = _activeWorkspace(data);
    final normalized = name.trim();
    if (normalized.isEmpty) throw ArgumentError('Customer name is required.');
    final customers = (workspace['customers'] as List).whereType<Map>().toList();
    if (customers.any((row) => '${row['year'] ?? row['ledgerYear']}' == '$year' && '${row['name']}'.trim().toLowerCase() == normalized.toLowerCase())) {
      throw StateError('A customer with this name already exists in this year.');
    }
    customers.add(LedgerCustomer(id: _uuid.v4(), name: normalized, year: year, phone: phone.trim(), address: address.trim(), isStockLedger: isStock, useWeight: useWeight).toJson());
    workspace['customers'] = customers;
    await _vault.write(data);
  }

  Future<void> updateCustomer(LedgerCustomer customer) async {
    final data = await load();
    final workspace = _activeWorkspace(data);
    final rows = (workspace['customers'] as List).whereType<Map>().toList();
    final normalized = customer.name.trim();
    if (normalized.isEmpty) throw ArgumentError('Customer name is required.');
    if (rows.any((row) => '${row['id']}' != customer.id && '${row['year'] ?? row['ledgerYear']}' == '${customer.year}' && '${row['name']}'.trim().toLowerCase() == normalized.toLowerCase())) {
      throw StateError('A customer with this name already exists in this year.');
    }
    final index = rows.indexWhere((row) => '${row['id']}' == customer.id);
    if (index < 0) throw StateError('Customer not found.');
    rows[index] = customer.toJson();
    workspace['customers'] = rows;
    await _vault.write(data);
  }

  Future<void> deleteCustomer(String customerId) async {
    final data = await load();
    final workspace = _activeWorkspace(data);
    final customers = (workspace['customers'] as List).whereType<Map>().toList();
    if (!customers.any((row) => '${row['id']}' == customerId)) throw StateError('Customer not found.');
    workspace['customers'] = customers.where((row) => '${row['id']}' != customerId).toList();
    final entries = (workspace['entries'] as List? ?? <Object?>[]).whereType<Map>().toList();
    workspace['entries'] = entries.where((row) => '${row['customerId'] ?? row['customer_id']}' != customerId).toList();
    await _vault.write(data);
  }

  Future<void> updateEntry(LedgerEntry entry, {required bool stockLedger}) async {
    final issue = LedgerCalculator.validateEntry(
      debit: entry.debit,
      credit: entry.credit,
      stock: stockLedger,
      buyQuantity: entry.buyQuantity,
      sellQuantity: entry.sellQuantity,
    );
    if (issue != null) throw ArgumentError(issue);
    final data = await load();
    final workspace = _activeWorkspace(data);
    final rows = (workspace['entries'] as List? ?? <Object?>[]).whereType<Map>().toList();
    final index = rows.indexWhere((row) => '${row['id']}' == entry.id);
    if (index < 0) throw StateError('Entry not found.');
    final stored = LedgerEntry.fromJson(Map<String, dynamic>.from(rows[index]));
    rows[index] = LedgerEntry(
      id: stored.id,
      customerId: entry.customerId,
      entryDate: entry.entryDate,
      createdAt: stored.createdAt,
      pageNumber: entry.pageNumber,
      description: entry.description,
      debit: entry.debit,
      credit: entry.credit,
      buyQuantity: entry.buyQuantity,
      sellQuantity: entry.sellQuantity,
      dailyLogVisible: stored.dailyLogVisible,
    ).toJson();
    workspace['entries'] = rows;
    await _vault.write(data);
  }

  Future<void> transferEntry(String entryId, String destinationCustomerId) async {
    final data = await load();
    final workspace = _activeWorkspace(data);
    final customers = (workspace['customers'] as List? ?? <Object?>[]).whereType<Map>().toList();
    if (!customers.any((row) => '${row['id']}' == destinationCustomerId)) throw StateError('Destination customer not found.');
    final rows = (workspace['entries'] as List? ?? <Object?>[]).whereType<Map>().toList();
    final index = rows.indexWhere((row) => '${row['id']}' == entryId);
    if (index < 0) throw StateError('Entry not found.');
    final stored = LedgerEntry.fromJson(Map<String, dynamic>.from(rows[index]));
    rows[index] = stored.copyWith(customerId: destinationCustomerId).toJson();
    workspace['entries'] = rows;
    await _vault.write(data);
  }

  Future<void> deleteEntry(String entryId) async {
    final data = await load();
    final workspace = _activeWorkspace(data);
    final rows = (workspace['entries'] as List? ?? <Object?>[]).whereType<Map>().toList();
    final remaining = rows.where((row) => '${row['id']}' != entryId).toList();
    if (remaining.length == rows.length) throw StateError('Entry not found.');
    workspace['entries'] = remaining;
    await _vault.write(data);
  }

  Future<void> addEntry(LedgerEntry entry, {required bool stockLedger}) async {
    final issue = LedgerCalculator.validateEntry(
      debit: entry.debit,
      credit: entry.credit,
      stock: stockLedger,
      buyQuantity: entry.buyQuantity,
      sellQuantity: entry.sellQuantity,
    );
    if (issue != null) throw ArgumentError(issue);
    final data = await load();
    final workspace = _activeWorkspace(data);
    final entries = (workspace['entries'] as List? ?? <Object?>[]).whereType<Map>().toList();
    entries.add(entry.toJson());
    workspace['entries'] = entries;
    workspace['lastEntryDate'] = entry.entryDate.toIso8601String();
    if ((entry.pageNumber ?? '').isNotEmpty) {
      final lastPages = Map<String, dynamic>.from(workspace['lastPageByCustomer'] as Map? ?? const {});
      lastPages[entry.customerId] = entry.pageNumber;
      workspace['lastPageByCustomer'] = lastPages;
    }
    await _vault.write(data);
  }

  Future<double> dailyLogOpeningDebit() async => double.tryParse('${_activeWorkspace(await load())['dailyLogOpeningDebit'] ?? 0}') ?? 0;
  Future<double> dailyLogOpeningCredit() async => double.tryParse('${_activeWorkspace(await load())['dailyLogOpeningCredit'] ?? 0}') ?? 0;

  Future<void> saveDailyLogOpening({required double debit, required double credit}) async {
    if (debit < 0 || credit < 0 || !debit.isFinite || !credit.isFinite) throw ArgumentError('Opening amounts must be non-negative numbers.');
    final data = await load();
    final workspace = _activeWorkspace(data);
    workspace['dailyLogOpeningDebit'] = debit;
    workspace['dailyLogOpeningCredit'] = credit;
    await _vault.write(data);
  }

  Future<List<DailyLogSnapshot>> dailySnapshots(int year) async {
    final rows = (_activeWorkspace(await load())['snapshots'] as List? ?? const []).whereType<Map>().toList();
    final snapshots = rows.map((row) => DailyLogSnapshot.fromJson(Map<String, dynamic>.from(row))).where((snapshot) => snapshot.year == year).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return snapshots;
  }

  Future<DailyLogSnapshot> saveSnapshot({required int year, required String? pageNumber, DateTime? savedAt}) async {
    final data = await load();
    final workspace = _activeWorkspace(data);
    final current = savedAt ?? DateTime.now();
    final rows = (workspace['snapshots'] as List? ?? <Object?>[]).whereType<Map>().toList();
    final snapshots = rows.map((row) => DailyLogSnapshot.fromJson(Map<String, dynamic>.from(row))).where((snapshot) => snapshot.year == year).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final previous = snapshots.isEmpty ? null : snapshots.last;
    final alreadySnapshotted = snapshots.expand((snapshot) => snapshot.entryIds).toSet();
    final customers = (workspace['customers'] as List? ?? <Object?>[]).whereType<Map>().map((row) => LedgerCustomer.fromJson(Map<String, dynamic>.from(row))).where((customer) => customer.year == year).toList();
    final customerById = {for (final customer in customers) customer.id: customer};
    final entryRows = (workspace['entries'] as List? ?? <Object?>[]).whereType<Map>().toList();
    final periodEntries = entryRows.map((row) => LedgerEntry.fromJson(Map<String, dynamic>.from(row))).where((entry) {
      return entry.dailyLogVisible && customerById.containsKey(entry.customerId) &&
          !alreadySnapshotted.contains(entry.id) && !entry.createdAt.isAfter(current);
    }).toList();
    var debit = previous == null ? (double.tryParse('${workspace['dailyLogOpeningDebit'] ?? 0}') ?? 0.0) : (previous.finalBalance > 0 ? previous.finalBalance : 0.0);
    var credit = previous == null ? (double.tryParse('${workspace['dailyLogOpeningCredit'] ?? 0}') ?? 0.0) : (previous.finalBalance < 0 ? -previous.finalBalance : 0.0);
    final customerIds = <String>{};
    for (final entry in periodEntries) {
      final customer = customerById[entry.customerId]!;
      debit += customer.isStockLedger ? entry.credit : entry.debit;
      credit += customer.isStockLedger ? entry.debit : entry.credit;
      customerIds.add(customer.id);
    }
    if (periodEntries.isEmpty && debit == 0 && credit == 0) throw StateError('No visible entries or opening balance to snapshot.');
    final id = _uuid.v4();
    final cleanPage = (pageNumber ?? '').trim();
    final snapshot = DailyLogSnapshot(
      id: id, year: year, createdAt: current, debit: debit, credit: credit, finalBalance: debit - credit,
      customerCount: customerIds.length, pageNumber: cleanPage.isEmpty ? null : cleanPage,
      entryIds: periodEntries.map((entry) => entry.id).toList(),
    );
    if (cleanPage.isNotEmpty) {
      final ids = snapshot.entryIds.toSet();
      for (var i = 0; i < entryRows.length; i++) {
        final entry = LedgerEntry.fromJson(Map<String, dynamic>.from(entryRows[i]));
        if (ids.contains(entry.id)) entryRows[i] = entry.copyWith(pageNumber: cleanPage).toJson();
      }
      workspace['entries'] = entryRows;
    }
    rows.add(snapshot.toJson());
    workspace['snapshots'] = rows;
    await _vault.write(data);
    return snapshot;
  }

  Future<void> updateSnapshotPage(String snapshotId, String? pageNumber) async {
    final data = await load();
    final workspace = _activeWorkspace(data);
    final snapshots = (workspace['snapshots'] as List? ?? <Object?>[]).whereType<Map>().toList();
    final index = snapshots.indexWhere((row) => '${row['id']}' == snapshotId);
    if (index < 0) throw StateError('Snapshot not found.');
    final snapshot = DailyLogSnapshot.fromJson(Map<String, dynamic>.from(snapshots[index]));
    final page = (pageNumber ?? '').trim();
    snapshots[index] = DailyLogSnapshot(id: snapshot.id, year: snapshot.year, createdAt: snapshot.createdAt, debit: snapshot.debit, credit: snapshot.credit, finalBalance: snapshot.finalBalance, customerCount: snapshot.customerCount, entryIds: snapshot.entryIds, pageNumber: page.isEmpty ? null : page).toJson();
    if (page.isNotEmpty) {
      final ids = snapshot.entryIds.toSet();
      final entries = (workspace['entries'] as List? ?? <Object?>[]).whereType<Map>().toList();
      for (var i = 0; i < entries.length; i++) {
        final entry = LedgerEntry.fromJson(Map<String, dynamic>.from(entries[i]));
        if (ids.contains(entry.id)) entries[i] = entry.copyWith(pageNumber: page).toJson();
      }
      workspace['entries'] = entries;
    }
    workspace['snapshots'] = snapshots;
    await _vault.write(data);
  }

  Future<void> deleteSnapshot(String snapshotId) async {
    final data = await load();
    final workspace = _activeWorkspace(data);
    final snapshots = (workspace['snapshots'] as List? ?? <Object?>[]).whereType<Map>().toList();
    final remaining = snapshots.where((row) => '${row['id']}' != snapshotId).toList();
    if (remaining.length == snapshots.length) throw StateError('Snapshot not found.');
    workspace['snapshots'] = remaining;
    await _vault.write(data);
  }

  Future<void> clearSnapshots(int year) async {
    final data = await load();
    final workspace = _activeWorkspace(data);
    final snapshots = (workspace['snapshots'] as List? ?? <Object?>[]).whereType<Map>().toList();
    workspace['snapshots'] = snapshots.where((row) => int.tryParse('${row['year'] ?? 0}') != year).toList();
    await _vault.write(data);
  }

  Future<void> setEntryDailyLogVisibility(String entryId, bool visible) async {
    final data = await load();
    final workspace = _activeWorkspace(data);
    final entries = (workspace['entries'] as List? ?? <Object?>[]).whereType<Map>().toList();
    final index = entries.indexWhere((row) => '${row['id']}' == entryId);
    if (index < 0) throw StateError('Entry not found.');
    entries[index] = LedgerEntry.fromJson(Map<String, dynamic>.from(entries[index])).copyWith(dailyLogVisible: visible).toJson();
    workspace['entries'] = entries;
    await _vault.write(data);
  }

  Future<void> restoreEntryToSnapshot(String entryId, String snapshotId) async {
    final data = await load();
    final workspace = _activeWorkspace(data);
    final snapshots = (workspace['snapshots'] as List? ?? <Object?>[]).whereType<Map>().toList();
    Map? snapshotRow;
    for (final row in snapshots) {
      if ('${row['id']}' == snapshotId) { snapshotRow = row; break; }
    }
    if (snapshotRow == null) throw StateError('Snapshot not found.');
    final snapshot = DailyLogSnapshot.fromJson(Map<String, dynamic>.from(snapshotRow));
    final rows = (workspace['entries'] as List? ?? <Object?>[]).whereType<Map>().toList();
    final index = rows.indexWhere((row) => '${row['id']}' == entryId);
    if (index < 0) throw StateError('Entry not found.');
    final entry = LedgerEntry.fromJson(Map<String, dynamic>.from(rows[index]));
    rows[index] = LedgerEntry(id: entry.id, customerId: entry.customerId, entryDate: entry.entryDate, createdAt: snapshot.createdAt, pageNumber: snapshot.pageNumber ?? entry.pageNumber, description: entry.description, debit: entry.debit, credit: entry.credit, buyQuantity: entry.buyQuantity, sellQuantity: entry.sellQuantity, dailyLogVisible: true).toJson();
    workspace['entries'] = rows;
    await _vault.write(data);
  }

  Future<void> recalculateSnapshots(int year) async {
    final data = await load();
    final workspace = _activeWorkspace(data);
    final snapshots = (workspace['snapshots'] as List? ?? <Object?>[]).whereType<Map>().toList();
    final selected = snapshots.map((row) => DailyLogSnapshot.fromJson(Map<String, dynamic>.from(row))).where((snapshot) => snapshot.year == year).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final customers = (workspace['customers'] as List? ?? <Object?>[]).whereType<Map>().map((row) => LedgerCustomer.fromJson(Map<String, dynamic>.from(row))).where((customer) => customer.year == year).toList();
    final customerById = {for (final customer in customers) customer.id: customer};
    final entries = (workspace['entries'] as List? ?? <Object?>[]).whereType<Map>().map((row) => LedgerEntry.fromJson(Map<String, dynamic>.from(row))).toList();
    var openingDebit = double.tryParse('${workspace['dailyLogOpeningDebit'] ?? 0}') ?? 0;
    var openingCredit = double.tryParse('${workspace['dailyLogOpeningCredit'] ?? 0}') ?? 0;
    final processedEntryIds = <String>{};
    final recalculated = <String, DailyLogSnapshot>{};
    for (final snapshot in selected) {
      var debit = openingDebit;
      var credit = openingCredit;
      final period = entries.where((entry) => entry.dailyLogVisible && customerById.containsKey(entry.customerId) && !processedEntryIds.contains(entry.id) && !entry.createdAt.isAfter(snapshot.createdAt)).toList();
      final customersInPeriod = <String>{};
      for (final entry in period) {
        final customer = customerById[entry.customerId]!;
        debit += customer.isStockLedger ? entry.credit : entry.debit;
        credit += customer.isStockLedger ? entry.debit : entry.credit;
        customersInPeriod.add(customer.id);
      }
      final updated = DailyLogSnapshot(id: snapshot.id, year: snapshot.year, createdAt: snapshot.createdAt, debit: debit, credit: credit, finalBalance: debit - credit, customerCount: customersInPeriod.length, pageNumber: snapshot.pageNumber, entryIds: period.map((entry) => entry.id).toList());
      recalculated[snapshot.id] = updated;
      processedEntryIds.addAll(updated.entryIds);
      openingDebit = updated.finalBalance > 0 ? updated.finalBalance : 0;
      openingCredit = updated.finalBalance < 0 ? -updated.finalBalance : 0;
    }
    workspace['snapshots'] = snapshots.map((row) {
      final snapshot = DailyLogSnapshot.fromJson(Map<String, dynamic>.from(row));
      return recalculated[snapshot.id]?.toJson() ?? row;
    }).toList();
    await _vault.write(data);
  }

  /// Parses everything before the atomic vault replacement; failed restores leave old data intact.
  Future<void> restore(ImportedLedger imported) async {
    final current = await load();
    final workspace = _activeWorkspace(current);
    workspace['activeYear'] = imported.year;
    final restoredSnapshots = imported.source['snapshots'] ?? imported.source['dailyLogSnapshots'] ?? <Object?>[];
    final restoredYears = <int>{imported.year, ...imported.customers.map((customer) => customer.year)};
    final sourceYears = imported.source['years'];
    if (sourceYears is List) {
      restoredYears.addAll(sourceYears.map((value) => int.tryParse('$value')).whereType<int>());
    }
    if (restoredSnapshots is List) {
      restoredYears.addAll(restoredSnapshots.whereType<Map>().map((row) => int.tryParse('${row['year'] ?? ''}')).whereType<int>());
    }
    workspace['years'] = restoredYears.toList()..sort();
    workspace['customers'] = imported.customers.map((customer) => customer.toJson()).toList();
    workspace['entries'] = imported.entries.map((entry) => entry.toJson()).toList();
    workspace['snapshots'] = restoredSnapshots;
    workspace['dailyLogOpeningDebit'] = imported.source['dailyLogOpeningDebit'] ?? imported.source['daily_log_opening_debit'] ?? 0;
    workspace['dailyLogOpeningCredit'] = imported.source['dailyLogOpeningCredit'] ?? imported.source['daily_log_opening_credit'] ?? 0;
    workspace['notes'] = imported.source['notes'] ?? workspace['notes'] ?? '';
    workspace['companyName'] = imported.source['companyName'] ?? imported.source['company_name'] ?? workspace['companyName'] ?? '';
    workspace['companyLogo'] = imported.source['companyLogo'] ?? imported.source['company_logo'] ?? workspace['companyLogo'];
    workspace['legacySourceBackup'] = imported.source;
    await _vault.write(current);
  }

  Map<String, dynamic> _activeWorkspace(Map<String, dynamic> data) {
    final workspaces = (data['workspaces'] as List? ?? const []).whereType<Map>().toList();
    final activeId = '${data['activeWorkspaceId'] ?? _workspaceId}';
    final workspace = workspaces.cast<Map>().firstWhere((item) => '${item['id']}' == activeId, orElse: () => throw StateError('Active workspace is missing.'));
    return workspace.cast<String, dynamic>();
  }
}
