import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/theme.dart';
import '../../ledger/data/ledger_backup_importer.dart';
import '../../ledger/data/local_ledger_repository.dart';
import '../../ledger/domain/customer.dart';
import '../../ledger/domain/ledger_calculator.dart';
import '../../ledger/domain/ledger_entry.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _repository = LocalLedgerRepository();
  int _selected = 0;
  String _query = '';
  int _activeYear = DateTime.now().year;
  bool _loading = true;
  List<LedgerCustomer> _customers = [];
  List<LedgerEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final customers = await _repository.customers();
      final entries = await _repository.entries();
      final year = await _repository.activeYear();
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _entries = entries;
        _activeYear = year;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Could not open encrypted local data: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final content = switch (_selected) {
      0 => _overview(context),
      1 => _customersView(context),
      2 => _dailyLogsView(context),
      _ => _settingsView(context),
    };
    return Scaffold(
      body: SafeArea(
        child: Row(children: [
          if (wide) _rail(),
          Expanded(child: Column(children: [
            _topBar(context, wide),
            Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: content)),
          ])),
        ]),
      ),
      bottomNavigationBar: wide ? null : NavigationBar(
        selectedIndex: _selected,
        onDestinationSelected: (value) => setState(() => _selected = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.people_alt_outlined), label: 'Customers'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Daily log'),
          NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _rail() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: NavigationRail(
            selectedIndex: _selected,
            onDestinationSelected: (value) => setState(() => _selected = value),
            leading: const Padding(padding: EdgeInsets.only(top: 12, bottom: 28), child: _BrandMark()),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.grid_view_rounded), label: Text('Overview')),
              NavigationRailDestination(icon: Icon(Icons.people_alt_outlined), label: Text('Customers')),
              NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), label: Text('Daily log')),
              NavigationRailDestination(icon: Icon(Icons.tune_rounded), label: Text('Settings')),
            ],
          ),
        ),
      );

  Widget _topBar(BuildContext context, bool wide) => Padding(
        padding: EdgeInsets.fromLTRB(wide ? 28 : 20, 16, wide ? 32 : 20, 14),
        child: Row(children: [
          if (!wide) const _BrandMark(),
          if (!wide) const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('HisabFlow', style: Theme.of(context).textTheme.titleLarge),
            Text('My workspace  •  $_activeYear', style: Theme.of(context).textTheme.labelMedium),
          ]),
          const Spacer(),
          IconButton.filledTonal(onPressed: _restoreBackup, icon: const Icon(Icons.file_open_outlined), tooltip: 'Restore backup'),
          const SizedBox(width: 8),
          IconButton.filledTonal(onPressed: () => _showMessage('Linked-device pairing will be available after secure server setup.'), icon: const Icon(Icons.devices_outlined), tooltip: 'Linked devices'),
          const SizedBox(width: 8),
          CircleAvatar(backgroundColor: BrandColors.elevated, child: const Icon(Icons.person_outline_rounded)),
        ]),
      );

  Widget _overview(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final isDesktop = MediaQuery.sizeOf(context).width >= 1100;
    return SingleChildScrollView(
      key: const ValueKey('overview'),
      padding: EdgeInsets.fromLTRB(isDesktop ? 32 : 20, 10, isDesktop ? 32 : 20, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Good morning,', style: Theme.of(context).textTheme.bodyMedium),
            Text('Your books at a glance', style: Theme.of(context).textTheme.headlineMedium),
          ])),
          if (isDesktop) FilledButton.icon(onPressed: _addCustomer, icon: const Icon(Icons.add), label: const Text('New customer')),
        ]),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, constraints) {
          final cols = constraints.maxWidth > 920 ? 4 : constraints.maxWidth > 560 ? 2 : 1;
          const gap = 14.0;
          final width = (constraints.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            SizedBox(width: width, child: _statCard('Customers', '${_customers.where((item) => item.year == _activeYear).length}', 'in active year', Icons.people_outline_rounded, BrandColors.teal)),
            SizedBox(width: width, child: _statCard('Stock ledgers', '${_customers.where((item) => item.year == _activeYear && item.isStockLedger).length}', 'Including weight ledgers', Icons.inventory_2_outlined, BrandColors.gold)),
            SizedBox(width: width, child: _statCard('Ledger year', '$_activeYear', 'Selected workspace year', Icons.calendar_month_outlined, const Color(0xFFE38E7B))),
            SizedBox(width: width, child: _statCard('Entries', '${_entries.length}', 'Across this workspace', Icons.bolt_rounded, const Color(0xFFA6A0FF))),
          ]);
        }),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, constraints) {
          final split = constraints.maxWidth > 820;
          return Flex(direction: split ? Axis.horizontal : Axis.vertical, crossAxisAlignment: CrossAxisAlignment.start, children: [
            ExpandedIf(split, child: _recentActivity(context)),
            if (split) const SizedBox(width: 16) else const SizedBox(height: 16),
            ExpandedIf(split, child: _quickPanel(context)),
          ]);
        }),
        if (!isDesktop) ...[
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _addCustomer, icon: const Icon(Icons.add), label: const Text('Add customer'))),
        ],
      ]),
    );
  }

  Widget _customersView(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final filtered = _customers.where((customer) {
      final query = _query.trim().toLowerCase();
      return query.isEmpty || customer.name.toLowerCase().split(RegExp(r'\s+')).any((word) => word.startsWith(query));
    }).toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Padding(
      key: const ValueKey('customers'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Customers', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextField(onChanged: (value) => setState(() => _query = value), decoration: const InputDecoration(hintText: 'Search names…', prefixIcon: Icon(Icons.search)))),
          const SizedBox(width: 12),
          IconButton.filledTonal(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh_rounded)),
        ]),
        const SizedBox(height: 12),
        Expanded(child: ListView.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 9),
          itemBuilder: (context, index) {
            final customer = filtered[index];
            return Card(child: ListTile(
              onTap: () => _openLedger(customer),
              leading: CircleAvatar(backgroundColor: BrandColors.elevated, child: Text(customer.name.substring(0, 1).toUpperCase())),
              title: Text(customer.name),
              subtitle: Text(customer.isStockLedger ? (customer.useWeight ? 'Stock · Weight ledger' : 'Stock ledger') : 'General ledger'),
              trailing: const Icon(Icons.chevron_right_rounded),
            ));
          },
        )),
      ]),
    );
  }

  Widget _dailyLogsView(BuildContext context) {
    final visible = _entries.where((entry) => entry.dailyLogVisible && _customers.any((customer) => customer.id == entry.customerId && customer.year == _activeYear)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Padding(
      key: const ValueKey('daily-logs'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Daily logs', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Ordered by when an entry was created, not by its selected ledger date.', style: TextStyle(color: BrandColors.muted)),
        const SizedBox(height: 16),
        Expanded(child: visible.isEmpty
          ? const Center(child: Text('No visible entries in this year yet.'))
          : ListView.separated(
              itemCount: visible.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = visible[index];
                final customer = _customers.where((item) => item.id == entry.customerId).first;
                final logDebit = customer.isStockLedger ? entry.credit : entry.debit;
                final logCredit = customer.isStockLedger ? entry.debit : entry.credit;
                return Card(child: ListTile(
                  onTap: () => _openLedger(customer),
                  title: Text(customer.name),
                  subtitle: Text('${entry.entryDate.year}-${entry.entryDate.month.toString().padLeft(2, '0')}-${entry.entryDate.day.toString().padLeft(2, '0')}  ·  ${entry.description.isEmpty ? 'No description' : entry.description}'),
                  trailing: Text('D ${logDebit.toStringAsFixed(2)}\nC ${logCredit.toStringAsFixed(2)}', textAlign: TextAlign.right),
                ));
              },
            )),
      ]),
    );
  }

  Widget _settingsView(BuildContext context) => ListView(
        key: const ValueKey('settings'),
        padding: const EdgeInsets.all(20),
        children: [
          Text('Workspace settings', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          Card(child: ListTile(leading: const Icon(Icons.lock_outline, color: BrandColors.teal), title: const Text('Encrypted local storage'), subtitle: const Text('AES-256-GCM · device-held key'))),
          const SizedBox(height: 10),
          Card(child: ListTile(leading: const Icon(Icons.calendar_month_outlined), title: const Text('Active ledger year'), subtitle: Text('$_activeYear'))),
          const SizedBox(height: 10),
          Card(child: ListTile(leading: const Icon(Icons.devices_outlined), title: const Text('Linked devices'), subtitle: const Text('Pairing requires server credentials and explicit approval.'), onTap: () => _showMessage('Device sync is not enabled until backend security is configured.'))),
          const SizedBox(height: 10),
          Card(child: ListTile(leading: const Icon(Icons.file_open_outlined), title: const Text('Restore JSON backup'), subtitle: const Text('Replaces the active workspace after confirmation.'), onTap: _restoreBackup)),
        ],
      );

  Future<void> _openLedger(LedgerCustomer customer) async {
    final customerEntries = _entries.where((entry) => entry.customerId == customer.id).toList()
      ..sort((a, b) {
        final byDate = a.entryDate.compareTo(b.entryDate);
        return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
      });
    final totals = LedgerCalculator.totals(customer, customerEntries);
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(customer.name),
      content: SizedBox(width: 720, height: 480, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${customer.isStockLedger ? 'Stock ledger' : 'General ledger'}  ·  ${customerEntries.length} entries'),
        const SizedBox(height: 8),
        Text('Debit Rs ${totals.debit.toStringAsFixed(2)}    Credit Rs ${totals.credit.toStringAsFixed(2)}    Balance ${totals.balanceLabel}', style: const TextStyle(color: BrandColors.teal)),
        const Divider(height: 24),
        Expanded(child: customerEntries.isEmpty
          ? const Center(child: Text('No entries yet.'))
          : ListView.builder(itemCount: customerEntries.length, itemBuilder: (context, index) {
              final entry = customerEntries[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.description.isEmpty ? 'Ledger entry' : entry.description),
                subtitle: Text('${entry.entryDate.year}-${entry.entryDate.month.toString().padLeft(2, '0')}-${entry.entryDate.day.toString().padLeft(2, '0')}  ·  Page ${entry.pageNumber ?? '—'}'),
                trailing: Text('D ${entry.debit.toStringAsFixed(2)}\nC ${entry.credit.toStringAsFixed(2)}', textAlign: TextAlign.right),
              );
            })),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')), FilledButton.icon(onPressed: () { Navigator.pop(dialogContext); _addEntry(); }, icon: const Icon(Icons.add), label: const Text('New entry'))],
    ));
  }

  Widget _statCard(String label, String value, String detail, IconData icon, Color accent) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon, color: accent), const Spacer(), Text(detail, style: const TextStyle(fontSize: 11, color: BrandColors.muted))]),
            const SizedBox(height: 22),
            Text(value, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            const SizedBox(height: 4), Text(label, style: const TextStyle(color: BrandColors.muted)),
          ]),
        ),
      );

  Widget _recentActivity(BuildContext context) => Card(
        child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text('Recent activity', style: Theme.of(context).textTheme.titleLarge)), const Text('View all', style: TextStyle(color: BrandColors.teal))]),
          const SizedBox(height: 8),
          if (_entries.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('Your saved entries will appear here.', style: TextStyle(color: BrandColors.muted))))
          else
            for (final entry in (_entries.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt))).take(4))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(backgroundColor: BrandColors.elevated, child: const Icon(Icons.receipt_long_outlined, size: 18)),
                title: Text(_customerName(entry.customerId)),
                subtitle: Text('${entry.description.isEmpty ? 'Ledger entry' : entry.description}  ·  ${entry.createdAt.hour.toString().padLeft(2, '0')}:${entry.createdAt.minute.toString().padLeft(2, '0')}'),
                trailing: Text('Rs ${(entry.debit + entry.credit).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
        ])),
      );

  Widget _quickPanel(BuildContext context) => Card(
        child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Quick actions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _quickAction(Icons.person_add_alt_1_rounded, 'Add a customer', 'Create a new ledger', _addCustomer),
          _quickAction(Icons.note_add_outlined, 'New entry', 'Record debit or credit', _addEntry),
          _quickAction(Icons.backup_outlined, 'Back up data', 'Save workspace JSON', _createBackup),
        ])),
      );

  Widget _quickAction(IconData icon, String title, String subtitle, VoidCallback onTap) => ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: onTap,
        leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: BrandColors.elevated, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: BrandColors.teal, size: 20)),
        title: Text(title), subtitle: Text(subtitle), trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      );

  void _addCustomer() {
    final nameController = TextEditingController();
    showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: const Text('Add customer'),
      content: TextField(controller: nameController, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Customer name')),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () async {
        final name = nameController.text.trim();
        if (name.isEmpty) return;
        if (_customers.any((item) => item.year == _activeYear && item.name.toLowerCase() == name.toLowerCase())) {
          _showMessage('A customer with this name already exists in $_activeYear');
          return;
        }
        try {
          await _repository.addCustomer(name: name, year: _activeYear);
          await _loadCustomers();
          if (context.mounted) Navigator.pop(context);
        } catch (error) {
          _showMessage('$error');
        }
      }, child: const Text('Add'))],
    ));
  }

  double _parseNumber(String value) => value.trim().isEmpty ? 0 : (double.tryParse(value.trim()) ?? double.nan);

  double _parseQuantity(String value, bool weightMode) {
    if (value.trim().isEmpty) return 0;
    if (weightMode) {
      try {
        return LedgerCalculator.parseWeightKg(value);
      } on FormatException {
        return double.nan;
      }
    }
    return double.tryParse(value.trim()) ?? double.nan;
  }

  String _customerName(String id) {
    for (final customer in _customers) {
      if (customer.id == id) return customer.name;
    }
    return 'Customer';
  }

  Future<void> _addEntry() async {
    final customers = _customers.where((customer) => customer.year == _activeYear).toList();
    if (customers.isEmpty) {
      _showMessage('Add a customer before recording an entry.');
      return;
    }
    final debit = TextEditingController();
    final credit = TextEditingController();
    final buyQuantity = TextEditingController();
    final sellQuantity = TextEditingController();
    final page = TextEditingController();
    final description = TextEditingController();
    var customer = customers.first;
    var entryDate = DateTime.now();
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('New ledger entry'),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<LedgerCustomer>(
          value: customer,
          decoration: const InputDecoration(labelText: 'Customer'),
          items: customers.map((item) => DropdownMenuItem(value: item, child: Text(item.name))).toList(),
          onChanged: (item) { if (item != null) setDialogState(() => customer = item); },
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Entry date'),
          subtitle: Text('${entryDate.year}-${entryDate.month.toString().padLeft(2, '0')}-${entryDate.day.toString().padLeft(2, '0')}'),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: () async {
            final selected = await showDatePicker(context: context, initialDate: entryDate, firstDate: DateTime(1900), lastDate: DateTime(9999));
            if (selected != null) setDialogState(() => entryDate = selected);
          },
        ),
        TextField(controller: page, decoration: const InputDecoration(labelText: 'Page number (optional)')),
        const SizedBox(height: 10),
        TextField(controller: description, decoration: const InputDecoration(labelText: 'Description (optional)')),
        const SizedBox(height: 10),
        if (customer.isStockLedger) ...[
          TextField(controller: buyQuantity, keyboardType: customer.useWeight ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: customer.useWeight ? 'Buy weight' : 'Buy quantity', hintText: customer.useWeight ? 'e.g. 10-20 or 25' : null)),
          const SizedBox(height: 10),
        ],
        TextField(controller: debit, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: customer.isStockLedger ? 'Buy amount / Debit' : 'Debit')),
        if (customer.isStockLedger) ...[
          const SizedBox(height: 10),
          TextField(controller: sellQuantity, keyboardType: customer.useWeight ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: customer.useWeight ? 'Sell weight' : 'Sell quantity', hintText: customer.useWeight ? 'e.g. 10-20 or 25' : null)),
        ],
        const SizedBox(height: 10),
        TextField(controller: credit, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: customer.isStockLedger ? 'Sell amount / Credit' : 'Credit')),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          final entry = LedgerEntry(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            customerId: customer.id,
            entryDate: entryDate,
            createdAt: DateTime.now(),
            pageNumber: page.text.trim().isEmpty ? null : page.text.trim(),
            description: description.text.trim(),
            debit: _parseNumber(debit.text),
            credit: _parseNumber(credit.text),
            buyQuantity: _parseQuantity(buyQuantity.text, customer.useWeight),
            sellQuantity: _parseQuantity(sellQuantity.text, customer.useWeight),
          );
          final issue = LedgerCalculator.validateEntry(debit: entry.debit, credit: entry.credit, stock: customer.isStockLedger, buyQuantity: entry.buyQuantity, sellQuantity: entry.sellQuantity);
          if (issue != null) { _showMessage(issue); return; }
          try {
            await _repository.addEntry(entry, stockLedger: customer.isStockLedger);
            await _loadCustomers();
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          } catch (error) {
            _showMessage('$error');
          }
        }, child: const Text('Save entry')),
      ],
    )));
    debit.dispose();
    credit.dispose();
    buyQuantity.dispose();
    sellQuantity.dispose();
    page.dispose();
    description.dispose();
  }

  Future<void> _createBackup() async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Create workspace backup'),
      content: const Text('This JSON file contains sensitive financial data and is not encrypted. Store it somewhere private.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Continue'))],
    ));
    if (confirmed != true) return;
    try {
      final json = await _repository.exportBackupJson();
      final now = DateTime.now();
      final filename = 'hisabflow-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.json';
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'Save HisabFlow backup',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(json)),
      );
      if (saved != null) _showMessage('Backup saved. Keep the file private.');
    } catch (error) {
      _showMessage('Backup failed: $error');
    }
  }

  Future<void> _restoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.single.bytes;
      if (bytes == null || bytes.isEmpty) throw const FormatException('Selected file is empty or unreadable.');
      final imported = const LedgerBackupImporter().decode(utf8.decode(bytes));
      if (!mounted) return;
      final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Replace this workspace?'),
        content: Text('Restore ${imported.customers.length} customers and ${imported.entries.length} entries for ${imported.year}? Current workspace data will be replaced. The selected JSON file may contain unencrypted financial information.'),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Restore'))],
      ));
      if (confirmed != true) return;
      await _repository.restore(imported);
      await _loadCustomers();
      _showMessage('Backup restored successfully.');
    } catch (error) {
      _showMessage('Restore failed: $error');
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/branding/hisabflow-mark.svg',
        width: 42,
        height: 42,
        semanticsLabel: 'HisabFlow logo',
      );
}

class ExpandedIf extends StatelessWidget {
  const ExpandedIf(this.expand, {required this.child, super.key});
  final bool expand;
  final Widget child;
  @override
  Widget build(BuildContext context) => expand ? Expanded(child: child) : SizedBox(width: double.infinity, child: child);
}
