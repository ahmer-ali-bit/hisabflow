import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/security/encrypted_vault.dart';
import '../domain/customer.dart';
import '../domain/ledger_entry.dart';
import '../domain/ledger_calculator.dart';
import 'ledger_backup_importer.dart';

class LocalLedgerRepository {
  LocalLedgerRepository({EncryptedVault? vault}) : _vault = vault ?? EncryptedVault();
  final EncryptedVault _vault;
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

  Future<int> activeYear() async => int.tryParse('${_activeWorkspace(await load())['activeYear']}') ?? DateTime.now().year;

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

  /// Parses everything before the atomic vault replacement; failed restores leave old data intact.
  Future<void> restore(ImportedLedger imported) async {
    final current = await load();
    final workspace = _activeWorkspace(current);
    workspace['activeYear'] = imported.year;
    workspace['years'] = [imported.year];
    workspace['customers'] = imported.customers.map((customer) => customer.toJson()).toList();
    workspace['entries'] = imported.entries.map((entry) => entry.toJson()).toList();
    workspace['snapshots'] = imported.source['snapshots'] ?? imported.source['dailyLogSnapshots'] ?? <Object?>[];
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
