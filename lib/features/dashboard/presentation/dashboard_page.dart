import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/theme.dart';
import '../../ledger/data/ledger_backup_importer.dart';
import '../../ledger/data/local_ledger_repository.dart';
import '../../ledger/domain/customer.dart';
import '../../ledger/domain/daily_log_snapshot.dart';
import '../../ledger/domain/ledger_calculator.dart';
import '../../ledger/domain/ledger_entry.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _repository = LocalLedgerRepository();
  final _notesController = TextEditingController();
  final _companyNameController = TextEditingController();
  int _selected = 0;
  String _query = '';
  String _summaryQuery = '';
  int _activeYear = DateTime.now().year;
  String _activeWorkspaceId = 'default-workspace';
  String _workspaceName = 'My workspace';
  String? _companyLogoData;
  List<int> _years = [DateTime.now().year];
  List<Map<String, dynamic>> _workspaces = [];
  bool _loading = true;
  List<LedgerCustomer> _customers = [];
  List<LedgerEntry> _entries = [];
  List<DailyLogSnapshot> _snapshots = [];
  double _dailyOpeningDebit = 0;
  double _dailyOpeningCredit = 0;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final workspaceState = await _repository.workspaceState();
      final workspace = workspaceState.active;
      final customers = (workspace['customers'] as List? ?? const []).whereType<Map>().map((row) => LedgerCustomer.fromJson(Map<String, dynamic>.from(row))).toList();
      final entries = (workspace['entries'] as List? ?? const []).whereType<Map>().map((row) => LedgerEntry.fromJson(Map<String, dynamic>.from(row))).toList();
      final year = int.tryParse('${workspace['activeYear']}') ?? DateTime.now().year;
      final years = (workspace['years'] as List? ?? const []).map((value) => int.tryParse('$value')).whereType<int>().toSet().toList()..sort();
      final workspaces = workspaceState.all;
      final snapshots = (workspace['snapshots'] as List? ?? const []).whereType<Map>().map((row) => DailyLogSnapshot.fromJson(Map<String, dynamic>.from(row))).where((snapshot) => snapshot.year == year).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final openingDebit = double.tryParse('${workspace['dailyLogOpeningDebit'] ?? 0}') ?? 0;
      final openingCredit = double.tryParse('${workspace['dailyLogOpeningCredit'] ?? 0}') ?? 0;
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _entries = entries;
        _snapshots = snapshots;
        _dailyOpeningDebit = openingDebit;
        _dailyOpeningCredit = openingCredit;
        _activeYear = year;
        _years = years;
        _workspaces = workspaces;
        _activeWorkspaceId = '${workspace['id']}';
        _workspaceName = '${workspace['name'] ?? 'My workspace'}';
        _companyLogoData = workspace['companyLogo'] as String?;
        _loading = false;
      });
      if (!_notesController.hasFocus) _notesController.text = '${workspace['notes'] ?? ''}';
      if (!_companyNameController.hasFocus) _companyNameController.text = '${workspace['companyName'] ?? ''}';
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Could not open encrypted local data: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 740;
    final content = switch (_selected) {
      0 => _overview(context),
      1 => _customersView(context),
      2 => _summaryView(context),
      3 => _dailyLogsView(context),
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
          NavigationDestination(icon: Icon(Icons.summarize_outlined), label: 'Summary'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Daily log'),
          NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _rail() => Container(
        width: 244,
        margin: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        decoration: BoxDecoration(
          color: BrandColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BrandColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const _BrandMark(),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('HisabFlow', style: Theme.of(context).textTheme.titleLarge),
              const Text('BOOKKEEPING', style: TextStyle(fontSize: 9, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: BrandColors.muted)),
            ]),
          ]),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: BrandColors.canvas, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.workspaces_outline, size: 18, color: BrandColors.teal),
              const SizedBox(width: 9),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('WORKSPACE', style: TextStyle(fontSize: 9, letterSpacing: 1, color: BrandColors.muted, fontWeight: FontWeight.w700)),
                Text(_workspaceName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
              ])),
              const Icon(Icons.expand_more, size: 18, color: BrandColors.muted),
            ]),
          ),
          const SizedBox(height: 24),
          const Padding(padding: EdgeInsets.only(left: 10, bottom: 9), child: Text('MENU', style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: BrandColors.muted, fontWeight: FontWeight.w700))),
          _railItem(Icons.grid_view_rounded, 'Overview', 0),
          _railItem(Icons.people_alt_outlined, 'Customers', 1),
          _railItem(Icons.summarize_outlined, 'Summary', 2),
          _railItem(Icons.receipt_long_outlined, 'Daily logs', 3),
          _railItem(Icons.tune_rounded, 'Settings', 4),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: BrandColors.mint, borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.lock_outline_rounded, size: 17, color: BrandColors.teal),
              SizedBox(width: 8),
              Expanded(child: Text('Private on this device', style: TextStyle(fontSize: 11, color: BrandColors.ink, fontWeight: FontWeight.w600))),
            ]),
          ),
        ]),
      );

  Widget _railItem(IconData icon, String label, int index) {
    final selected = _selected == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? BrandColors.mint : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () => setState(() => _selected = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
            child: Row(children: [
              Icon(icon, size: 19, color: selected ? BrandColors.teal : BrandColors.muted),
              const SizedBox(width: 11),
              Text(label, style: TextStyle(color: selected ? BrandColors.ink : BrandColors.muted, fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
              if (selected) ...[
                const Spacer(),
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: BrandColors.teal, shape: BoxShape.circle)),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, bool wide) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1100;
    return Padding(
        padding: EdgeInsets.fromLTRB(wide ? 28 : 18, 16, wide ? 28 : 18, 12),
        child: Row(children: [
          if (!wide) const _BrandMark(),
          if (!wide) const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(wide ? const ['Overview', 'Customers', 'Summary', 'Daily logs', 'Settings'][_selected] : 'HisabFlow', style: Theme.of(context).textTheme.titleLarge),
            Text('$_workspaceName  ·  $_activeYear', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium),
          ])),
          if (isDesktop) FilledButton.icon(onPressed: _addEntry, icon: const Icon(Icons.add_rounded), label: const Text('New entry')),
          const SizedBox(width: 8),
          IconButton(onPressed: _restoreBackup, icon: const Icon(Icons.file_upload_outlined), tooltip: 'Restore backup'),
          IconButton(onPressed: () => _showMessage('Offline-first mode is active. Device sync stays disabled until secure pairing is configured.'), icon: const Icon(Icons.devices_outlined), tooltip: 'Linked devices'),
          const SizedBox(width: 4),
          const CircleAvatar(radius: 18, backgroundColor: BrandColors.mint, child: Icon(Icons.person_outline_rounded, color: BrandColors.teal, size: 20)),
        ]),
      );
  }

  Widget _overview(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1100;
    final activeCustomers = _customers.where((item) => item.year == _activeYear).toList();
    final activeIds = activeCustomers.map((item) => item.id).toSet();
    final activeEntries = _entries.where((entry) => activeIds.contains(entry.customerId)).toList();
    var debit = 0.0;
    var credit = 0.0;
    for (final customer in activeCustomers) {
      final ledgerEntries = activeEntries.where((entry) => entry.customerId == customer.id);
      final totals = LedgerCalculator.totals(customer, ledgerEntries);
      debit += totals.debit;
      credit += totals.credit;
    }
    final day = DateTime.now();
    final dateLabel = '${_weekday(day.weekday)}, ${_month(day.month)} ${day.day}';

    return SingleChildScrollView(
      key: const ValueKey('overview'),
      padding: EdgeInsets.fromLTRB(isDesktop ? 30 : 20, 14, isDesktop ? 30 : 20, 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dateLabel.toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.w700, color: BrandColors.muted)),
            const SizedBox(height: 6),
            Text('Good morning', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 3),
            Text('Here’s your ledger position for $_activeYear.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: BrandColors.muted)),
          ])),
          if (isDesktop) ...[
            OutlinedButton.icon(onPressed: _addCustomer, icon: const Icon(Icons.person_add_alt_1_outlined), label: const Text('Customer')),
            const SizedBox(width: 9),
            FilledButton.icon(onPressed: _addEntry, icon: const Icon(Icons.add_rounded), label: const Text('New entry')),
          ],
        ]),
        const SizedBox(height: 22),
        _welcomeBanner(debit, credit),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1000 ? 4 : constraints.maxWidth >= 440 ? 2 : 1;
          const gap = 12.0;
          final cardWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            SizedBox(width: cardWidth, child: _statCard('Customers', '${activeCustomers.length}', 'Active this year', Icons.people_outline_rounded, BrandColors.teal)),
            SizedBox(width: cardWidth, child: _statCard('Total debit', _compactRupees(debit), 'Receivable / buys', Icons.south_west_rounded, BrandColors.teal)),
            SizedBox(width: cardWidth, child: _statCard('Total credit', _compactRupees(credit), 'Payable / sells', Icons.north_east_rounded, BrandColors.gold)),
            SizedBox(width: cardWidth, child: _statCard('Entries', '${activeEntries.length}', 'Across active year', Icons.receipt_long_outlined, BrandColors.ink)),
          ]);
        }),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          final split = constraints.maxWidth >= 850;
          return Flex(direction: split ? Axis.horizontal : Axis.vertical, crossAxisAlignment: CrossAxisAlignment.start, children: [
            ExpandedIf(split, child: _recentActivity(context)),
            if (split) const SizedBox(width: 14) else const SizedBox(height: 14),
            ExpandedIf(split, child: _quickPanel(context)),
          ]);
        }),
        if (!isDesktop) ...[
          const SizedBox(height: 13),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _addCustomer, icon: const Icon(Icons.person_add_alt_1_outlined), label: const Text('Customer'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(onPressed: _addEntry, icon: const Icon(Icons.add_rounded), label: const Text('New entry'))),
          ]),
        ],
      ]),
    );
  }

  Widget _welcomeBanner(double debit, double credit) {
    final balance = debit - credit;
    final balanceText = balance == 0 ? 'Settled' : '${balance > 0 ? 'You are owed' : 'You owe'} Rs ${_compactRupees(balance.abs())}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF174D3F), Color(0xFF236B54)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('YOUR BUSINESS, IN BALANCE', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Color(0xFFC4E5D6), fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          Text(balanceText, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('A clear view of every customer account.', style: TextStyle(fontSize: 12, color: Color(0xFFD5E9E0))),
        ])),
        const SizedBox(width: 15),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(15)),
          child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFE3C27E), size: 26),
        ),
      ]),
    );
  }

  String _compactRupees(double amount) {
    final abs = amount.abs();
    if (abs >= 10000000) return '${(amount / 10000000).toStringAsFixed(1)} Cr';
    if (abs >= 100000) return '${(amount / 100000).toStringAsFixed(1)} L';
    if (abs >= 1000) return '${(amount / 1000).toStringAsFixed(1)} K';
    return amount.toStringAsFixed(0);
  }

  String _weekday(int weekday) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];
  String _month(int month) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];

  Widget _customersView(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final filtered = _customers.where((customer) {
      final query = _query.trim().toLowerCase();
      return customer.year == _activeYear && (query.isEmpty || customer.name.toLowerCase().split(RegExp(r'\s+')).any((word) => word.startsWith(query)));
    }).toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Padding(
      key: const ValueKey('customers'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Customers', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 3),
            Text('${filtered.length} accounts', style: Theme.of(context).textTheme.labelMedium),
          ])),
          FilledButton.icon(onPressed: _addCustomer, icon: const Icon(Icons.add_rounded), label: const Text('Add customer')),
        ]),
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
              trailing: PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'edit') _editCustomer(customer);
                  if (action == 'delete') _deleteCustomer(customer);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit customer')),
                  PopupMenuItem(value: 'delete', child: Text('Delete customer')),
                ],
              ),
            ));
          },
        )),
      ]),
    );
  }

  Widget _summaryView(BuildContext context) {
    final included = <({LedgerCustomer customer, LedgerTotals totals, String pageNumber})>[];
    var overallDebit = 0.0;
    var overallCredit = 0.0;
    for (final customer in _customers.where((item) => item.year == _activeYear)) {
      final customerEntries = _entries.where((entry) => entry.customerId == customer.id).toList();
      final totals = LedgerCalculator.totals(customer, customerEntries);
      final hasOpening = customer.openingDebit != 0 || customer.openingCredit != 0 || customer.openingBuyQuantity != 0 || customer.openingSellQuantity != 0;
      if (customerEntries.isEmpty && !hasOpening) continue;
      overallDebit += totals.debit;
      overallCredit += totals.credit;
      customerEntries.sort((a, b) {
        final byDate = b.entryDate.compareTo(a.entryDate);
        return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
      });
      included.add((customer: customer, totals: totals, pageNumber: customerEntries.isEmpty ? '—' : (customerEntries.last.pageNumber ?? '—')));
    }
    included.sort((a, b) => a.customer.name.toLowerCase().compareTo(b.customer.name.toLowerCase()));
    final query = _summaryQuery.trim().toLowerCase();
    final displayed = included.where((row) => row.customer.name.toLowerCase().contains(query)).toList();
    final overallBalance = overallDebit - overallCredit;

    return Padding(
      key: const ValueKey('summary'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Year summary · $_activeYear', style: Theme.of(context).textTheme.headlineMedium)),
          IconButton.filledTonal(onPressed: _loadCustomers, tooltip: 'Refresh summary', icon: const Icon(Icons.refresh_rounded)),
        ]),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 760 ? 3 : 1;
          final gap = 10.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            SizedBox(width: width, child: _summaryTotalCard('Overall debit / buy', overallDebit, BrandColors.teal)),
            SizedBox(width: width, child: _summaryTotalCard('Overall credit / sell', overallCredit, BrandColors.gold)),
            SizedBox(width: width, child: _summaryBalanceCard(overallBalance)),
          ]);
        }),
        const SizedBox(height: 14),
        TextField(
          onChanged: (value) => setState(() => _summaryQuery = value),
          decoration: const InputDecoration(hintText: 'Search customer name…', prefixIcon: Icon(Icons.search)),
        ),
        const SizedBox(height: 12),
        Expanded(child: displayed.isEmpty
          ? Center(child: Text(included.isEmpty ? 'No activity or opening balances in $_activeYear.' : 'No customers match the search.'))
          : ListView.separated(
              itemCount: displayed.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = displayed[index];
                final balance = row.totals.summaryBalance;
                final label = balance == 0 ? '0' : '${balance.abs().toStringAsFixed(2)} ${balance > 0 ? 'D' : 'C'}';
                return Card(child: ListTile(
                  onTap: () => _openLedger(row.customer),
                  title: Text(row.customer.name),
                  subtitle: Text('${row.customer.isStockLedger ? 'Stock' : 'Ledger'} · Page ${row.pageNumber}'),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('D ${row.totals.debit.toStringAsFixed(2)}', style: const TextStyle(color: BrandColors.teal, fontWeight: FontWeight.w600)),
                    Text('C ${row.totals.credit.toStringAsFixed(2)}', style: const TextStyle(color: BrandColors.gold)),
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ));
              },
            )),
      ]),
    );
  }

  Widget _summaryTotalCard(String title, double value, Color color) => Card(
        child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: BrandColors.muted)),
          const SizedBox(height: 8),
          Text('Rs ${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        ])),
      );

  Widget _summaryBalanceCard(double balance) {
    final label = balance == 0 ? '0' : '${balance.abs().toStringAsFixed(2)} ${balance > 0 ? 'D' : 'C'}';
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Overall balance', style: TextStyle(color: BrandColors.muted)),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
    ])));
  }

  Widget _dailyLogsView(BuildContext context) {
    final byId = {for (final customer in _customers.where((item) => item.year == _activeYear)) customer.id: customer};
    final logs = _entries.where((entry) => byId.containsKey(entry.customerId)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final debitTotal = _dailyOpeningDebit + logs.where((entry) => entry.dailyLogVisible).fold<double>(0, (sum, entry) {
      final customer = byId[entry.customerId]!;
      return sum + (customer.isStockLedger ? entry.credit : entry.debit);
    });
    final creditTotal = _dailyOpeningCredit + logs.where((entry) => entry.dailyLogVisible).fold<double>(0, (sum, entry) {
      final customer = byId[entry.customerId]!;
      return sum + (customer.isStockLedger ? entry.debit : entry.credit);
    });
    return Padding(
      key: const ValueKey('daily-logs'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Daily logs', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            const Text('Ordered by entry creation time; hide entries or save closing snapshots.', style: TextStyle(color: BrandColors.muted)),
          ])),
          IconButton(onPressed: _editDailyOpening, tooltip: 'Edit opening balance', icon: const Icon(Icons.account_balance_wallet_outlined)),
          PopupMenuButton<String>(
            tooltip: 'Snapshot actions',
            onSelected: (action) async {
              try {
                if (action == 'recalculate') {
                  await _repository.recalculateSnapshots(_activeYear);
                  await _loadCustomers();
                  _showMessage('Snapshots recalculated.');
                } else if (action == 'clear') {
                  final confirm = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
                    title: const Text('Clear this year’s snapshots?'),
                    content: const Text('Daily entries remain unchanged. This only removes saved closing snapshots.'),
                    actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Clear snapshots'))],
                  ));
                  if (confirm == true) { await _repository.clearSnapshots(_activeYear); await _loadCustomers(); }
                }
              } catch (error) { _showMessage('$error'); }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'recalculate', child: Text('Recalculate snapshots')),
              PopupMenuItem(value: 'clear', child: Text('Clear snapshots')),
            ],
          ),
        ]),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth > 640;
          final cardWidth = wide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: cardWidth, child: _summaryTotalCard('Daily debit · incl. opening', debitTotal, BrandColors.teal)),
            SizedBox(width: cardWidth, child: _summaryTotalCard('Daily credit · incl. opening', creditTotal, BrandColors.gold)),
          ]);
        }),
        const SizedBox(height: 12),
        Row(children: [
          Text('Snapshots', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          FilledButton.icon(onPressed: _saveDailySnapshot, icon: const Icon(Icons.bookmark_add_outlined), label: const Text('Save closing')),
        ]),
        if (_snapshots.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No snapshots saved yet.', style: TextStyle(color: BrandColors.muted)))
        else
          SizedBox(height: 116, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _snapshots.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final snapshot = _snapshots[index];
              final time = snapshot.createdAt.toLocal();
              final timestamp = '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year} · ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
              return SizedBox(width: 245, child: Card(child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 6, 8), child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(snapshot.pageNumber == null ? timestamp : 'Page ${snapshot.pageNumber} · $timestamp', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Text('D ${snapshot.debit.toStringAsFixed(2)}  ·  C ${snapshot.credit.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                  Text('Balance ${snapshot.finalBalance.toStringAsFixed(2)}', style: const TextStyle(color: BrandColors.muted, fontSize: 12)),
                ])),
                PopupMenuButton<String>(
                  onSelected: (action) => action == 'page' ? _editSnapshotPage(snapshot) : _deleteSnapshot(snapshot),
                  itemBuilder: (_) => const [PopupMenuItem(value: 'page', child: Text('Edit page number')), PopupMenuItem(value: 'delete', child: Text('Delete snapshot'))],
                ),
              ]))));
            },
          )),
        const SizedBox(height: 8),
        Text('Entries · ${logs.where((entry) => entry.dailyLogVisible).length} visible', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 5),
        Expanded(child: logs.isEmpty
          ? const Center(child: Text('No entries in this year yet.'))
          : ListView.separated(
              itemCount: logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = logs[index];
                final customer = byId[entry.customerId]!;
                final logDebit = customer.isStockLedger ? entry.credit : entry.debit;
                final logCredit = customer.isStockLedger ? entry.debit : entry.credit;
                final created = entry.createdAt.toLocal();
                final date = '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}/${created.year} ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
                return Card(child: ListTile(
                  onTap: () => _openLedger(customer),
                  leading: Icon(entry.dailyLogVisible ? Icons.receipt_long_outlined : Icons.visibility_off_outlined, color: entry.dailyLogVisible ? BrandColors.teal : BrandColors.muted),
                  title: Text(customer.name),
                  subtitle: Text('$date · ${entry.description.isEmpty ? 'No description' : entry.description}${entry.pageNumber == null ? '' : ' · Page ${entry.pageNumber}'}'),
                  trailing: SizedBox(width: 145, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Flexible(child: Text('D ${logDebit.toStringAsFixed(2)}\nC ${logCredit.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                    Switch.adaptive(value: entry.dailyLogVisible, onChanged: (value) async {
                      try {
                        await _repository.setEntryDailyLogVisibility(entry.id, value);
                        if (_snapshots.isNotEmpty) await _repository.recalculateSnapshots(_activeYear);
                        await _loadCustomers();
                      } catch (error) { _showMessage('$error'); }
                    }),
                    if (!entry.dailyLogVisible && _snapshots.isNotEmpty)
                      PopupMenuButton<String>(
                        tooltip: 'Restore entry',
                        onSelected: (_) => _restoreLogEntry(entry),
                        itemBuilder: (_) => const [PopupMenuItem(value: 'restore', child: Text('Restore to latest snapshot'))],
                      ),
                  ])),
                ));
              },
            )),
      ]),
    );
  }

  Future<void> _editDailyOpening() async {
    final debitController = TextEditingController(text: _dailyOpeningDebit.toStringAsFixed(2));
    final creditController = TextEditingController(text: _dailyOpeningCredit.toStringAsFixed(2));
    final values = await showDialog<(double, double)>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Daily log opening balance'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: debitController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Opening debit')),
        const SizedBox(height: 10),
        TextField(controller: creditController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Opening credit')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () {
        final debit = double.tryParse(debitController.text.trim());
        final credit = double.tryParse(creditController.text.trim());
        if (debit == null || credit == null || debit < 0 || credit < 0 || !debit.isFinite || !credit.isFinite) return;
        Navigator.pop(dialogContext, (debit, credit));
      }, child: const Text('Save'))],
    ));
    debitController.dispose();
    creditController.dispose();
    if (values == null) return;
    try { await _repository.saveDailyLogOpening(debit: values.$1, credit: values.$2); await _loadCustomers(); }
    catch (error) { _showMessage('$error'); }
  }

  Future<void> _saveDailySnapshot() async {
    final page = await _askText('Save daily closing', 'Page number (optional)');
    if (page == null) return;
    try {
      final snapshot = await _repository.saveSnapshot(year: _activeYear, pageNumber: page.isEmpty ? null : page);
      await _loadCustomers();
      _showMessage('Closing snapshot saved${snapshot.pageNumber == null ? '' : ' on page ${snapshot.pageNumber}'}.');
    } catch (error) { _showMessage('$error'); }
  }

  Future<void> _editSnapshotPage(DailyLogSnapshot snapshot) async {
    final page = await _askText('Edit snapshot page', 'Page number', initial: snapshot.pageNumber ?? '');
    if (page == null) return;
    try { await _repository.updateSnapshotPage(snapshot.id, page); await _loadCustomers(); }
    catch (error) { _showMessage('$error'); }
  }

  Future<void> _deleteSnapshot(DailyLogSnapshot snapshot) async {
    final confirm = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Delete snapshot?'),
      content: const Text('Entries are kept. Later snapshots may need recalculating.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete'))],
    ));
    if (confirm != true) return;
    try { await _repository.deleteSnapshot(snapshot.id); await _loadCustomers(); }
    catch (error) { _showMessage('$error'); }
  }

  Future<void> _restoreLogEntry(LedgerEntry entry) async {
    if (_snapshots.isEmpty) return;
    final latest = _snapshots.last;
    final confirm = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Restore entry?'),
      content: Text('Make this entry visible again and place it at the saved closing time${latest.pageNumber == null ? '' : ' on page ${latest.pageNumber}'}. Later snapshots can be recalculated.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Restore'))],
    ));
    if (confirm != true) return;
    try {
      await _repository.restoreEntryToSnapshot(entry.id, latest.id);
      await _repository.recalculateSnapshots(_activeYear);
      await _loadCustomers();
      _showMessage('Entry restored.');
    } catch (error) { _showMessage('$error'); }
  }

  Widget _settingsView(BuildContext context) => SingleChildScrollView(
        key: const ValueKey('settings'),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1040), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          const Text('Manage your workspaces, years and company details.', style: TextStyle(color: BrandColors.muted)),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
            final sideBySide = constraints.maxWidth >= 760;
            final workspaceCard = _workspaceSettingsCard(context);
            final yearCard = _yearSettingsCard(context);
            return sideBySide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: workspaceCard), const SizedBox(width: 14), Expanded(child: yearCard)])
              : Column(children: [workspaceCard, const SizedBox(height: 12), yearCard]);
          }),
          const SizedBox(height: 14),
          _companySettingsCard(context),
          const SizedBox(height: 14),
          _notesSettingsCard(context),
          const SizedBox(height: 14),
          Card(child: Column(children: [
            const ListTile(
              leading: CircleAvatar(backgroundColor: BrandColors.mint, child: Icon(Icons.lock_outline_rounded, color: BrandColors.teal)),
              title: Text('Private on this device'),
              subtitle: Text('Ledger data is encrypted locally with AES-GCM; the key stays in platform secure storage.'),
            ),
            const Divider(height: 1, indent: 70),
            ListTile(
              leading: const CircleAvatar(backgroundColor: BrandColors.elevated, child: Icon(Icons.devices_outlined, color: BrandColors.muted)),
              title: const Text('Linked devices'),
              subtitle: const Text('Offline-first by default. Optional encrypted device sync requires secure pairing setup.'),
              onTap: () => _showMessage('Ledger data remains on this device. No server copy is created until you opt in to secure pairing.'),
            ),
          ])),
          const SizedBox(height: 14),
          Card(child: Column(children: [
            ListTile(leading: const Icon(Icons.download_outlined, color: BrandColors.teal), title: const Text('Create backup'), subtitle: const Text('Full workspace JSON; sensitive financial information is not file-encrypted.'), onTap: _createBackup),
            const Divider(height: 1, indent: 55),
            ListTile(leading: const Icon(Icons.table_view_outlined, color: BrandColors.teal), title: const Text('Export active year to CSV'), subtitle: Text('Spreadsheet-ready rows for $_activeYear; includes opening balances.'), onTap: _createCsvExport),
            const Divider(height: 1, indent: 55),
            ListTile(leading: const Icon(Icons.restore_rounded, color: BrandColors.teal), title: const Text('Restore backup'), subtitle: const Text('Replaces the active workspace after confirmation.'), onTap: _restoreBackup),
          ])),
        ]))),
      );

  Widget _workspaceSettingsCard(BuildContext context) => Card(child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Workspace', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Separate books and settings for each business.', style: TextStyle(fontSize: 12, color: BrandColors.muted)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _workspaces.any((item) => '${item['id']}' == _activeWorkspaceId) ? _activeWorkspaceId : null,
            decoration: const InputDecoration(labelText: 'Active workspace'),
            items: _workspaces.map((item) => DropdownMenuItem(value: '${item['id']}', child: Text('${item['name']}'))).toList(),
            onChanged: (value) async {
              if (value == null) return;
              try { await _repository.switchWorkspace(value); await _loadCustomers(); } catch (error) { _showMessage('$error'); }
            },
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: _createWorkspace, icon: const Icon(Icons.add), label: const Text('Add')),
            OutlinedButton.icon(onPressed: _renameWorkspace, icon: const Icon(Icons.edit_outlined), label: const Text('Rename')),
            TextButton.icon(onPressed: _deleteWorkspace, icon: const Icon(Icons.delete_outline, color: BrandColors.coral), label: const Text('Delete')),
          ]),
        ]),
      ));

  Widget _yearSettingsCard(BuildContext context) => Card(child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ledger years', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('New year carries forward customer balances, not entries.', style: TextStyle(fontSize: 12, color: BrandColors.muted)),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: _years.contains(_activeYear) ? _activeYear : (_years.isEmpty ? null : _years.first),
            decoration: const InputDecoration(labelText: 'Active year'),
            items: _years.map((year) => DropdownMenuItem(value: year, child: Text('$year'))).toList(),
            onChanged: (year) async {
              if (year == null) return;
              try { await _repository.selectYear(year); await _loadCustomers(); } catch (error) { _showMessage('$error'); }
            },
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(onPressed: _createYear, icon: const Icon(Icons.add), label: const Text('New year')),
            TextButton.icon(onPressed: _deleteYear, icon: const Icon(Icons.delete_outline, color: BrandColors.coral), label: const Text('Delete year')),
          ]),
        ]),
      ));

  Widget _companySettingsCard(BuildContext context) => Card(child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Company profile', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 13),
          Row(children: [
            if (_companyLogoData == null)
              Container(width: 54, height: 54, decoration: BoxDecoration(color: BrandColors.mint, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.storefront_outlined, color: BrandColors.teal))
            else
              ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.memory(base64Decode(_companyLogoData!.split(',').last), width: 54, height: 54, fit: BoxFit.cover)),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _companyNameController, decoration: const InputDecoration(labelText: 'Company name'))),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(onPressed: _chooseCompanyLogo, icon: const Icon(Icons.image_outlined), label: const Text('Choose logo')),
            if (_companyLogoData != null) TextButton(onPressed: () => setState(() => _companyLogoData = null), child: const Text('Remove logo')),
            FilledButton.icon(onPressed: _saveCompanyProfile, icon: const Icon(Icons.save_outlined), label: const Text('Save profile')),
          ]),
        ]),
      ));

  Widget _notesSettingsCard(BuildContext context) => Card(child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Workspace notes', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 11),
          TextField(controller: _notesController, minLines: 3, maxLines: 7, decoration: const InputDecoration(hintText: 'Add private reminders for this workspace…')),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            FilledButton.icon(onPressed: _saveNotes, icon: const Icon(Icons.save_outlined), label: const Text('Save notes')),
            TextButton.icon(onPressed: _clearNotes, icon: const Icon(Icons.delete_outline), label: const Text('Clear')),
          ]),
        ]),
      ));

  Future<String?> _askText(String title, String label, {String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(labelText: label)),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Save'))],
    ));
    controller.dispose();
    return result;
  }

  Future<void> _createWorkspace() async {
    final name = await _askText('Add workspace', 'Workspace name');
    if (name == null || name.isEmpty) return;
    try { await _repository.createWorkspace(name); await _loadCustomers(); _showMessage('Workspace created.'); } catch (error) { _showMessage('$error'); }
  }

  Future<void> _renameWorkspace() async {
    final name = await _askText('Rename workspace', 'Workspace name', initial: _workspaceName);
    if (name == null || name.isEmpty) return;
    try { await _repository.renameWorkspace(_activeWorkspaceId, name); await _loadCustomers(); _showMessage('Workspace renamed.'); } catch (error) { _showMessage('$error'); }
  }

  Future<void> _deleteWorkspace() async {
    if (_workspaces.length <= 1) { _showMessage('The only workspace cannot be deleted.'); return; }
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Delete workspace?'),
      content: Text('Permanently delete “$_workspaceName” and all its years, customers, entries and settings?'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete'))],
    ));
    if (confirmed != true) return;
    try { await _repository.deleteWorkspace(_activeWorkspaceId); await _loadCustomers(); _showMessage('Workspace deleted.'); } catch (error) { _showMessage('$error'); }
  }

  Future<void> _createYear() async {
    final controller = TextEditingController(text: '${_activeYear + 1}');
    final result = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Create ledger year'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Year (1900–9999)')),
        const SizedBox(height: 8),
        const Text('Customers and closing balances carry forward. Old entries stay in the previous year.', style: TextStyle(color: BrandColors.muted)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Create'))],
    ));
    controller.dispose();
    if (result == null) return;
    final year = int.tryParse(result);
    if (year == null) { _showMessage('Enter a valid year.'); return; }
    try { await _repository.createYear(year); await _loadCustomers(); _showMessage('Year $year created; opening balances carried forward.'); } catch (error) { _showMessage('$error'); }
  }

  Future<void> _deleteYear() async {
    if (_years.length <= 1) { _showMessage('The last ledger year cannot be deleted.'); return; }
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text('Delete $_activeYear?'),
      content: const Text('This permanently deletes customers, entries and snapshots in this year. This cannot be undone.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete year'))],
    ));
    if (confirmed != true) return;
    try { await _repository.deleteYear(_activeYear); await _loadCustomers(); _showMessage('Year deleted.'); } catch (error) { _showMessage('$error'); }
  }

  Future<void> _chooseCompanyLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['png', 'jpg', 'jpeg'], withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) throw const FormatException('Image file is empty or unreadable.');
      if (bytes.length > 4 * 1024 * 1024) throw const FormatException('Logo must be smaller than 4 MB.');
      final mime = file.extension?.toLowerCase() == 'png' ? 'image/png' : 'image/jpeg';
      setState(() => _companyLogoData = 'data:$mime;base64,${base64Encode(bytes)}');
    } catch (error) { _showMessage('Could not load logo: $error'); }
  }

  Future<void> _saveCompanyProfile() async {
    try {
      await _repository.saveCompanyProfile(name: _companyNameController.text, logoData: _companyLogoData);
      _showMessage('Company profile saved.');
    } catch (error) { _showMessage('Save failed: $error'); }
  }

  Future<void> _saveNotes() async {
    try { await _repository.saveNotes(_notesController.text); _showMessage('Notes saved.'); } catch (error) { _showMessage('Save failed: $error'); }
  }

  Future<void> _clearNotes() async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Clear notes?'),
      content: const Text('Remove all saved notes from this workspace?'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Clear'))],
    ));
    if (confirmed != true) return;
    _notesController.clear();
    await _saveNotes();
  }

  Future<void> _openLedger(LedgerCustomer customer) async {
    var entries = _entries.where((entry) => entry.customerId == customer.id).toList();
    var filter = 'All';
    DateTime? customStart;
    DateTime? customEnd;
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) {
      final filtered = _filterLedgerEntries(entries, filter, customStart, customEnd);
      final totals = LedgerCalculator.totals(customer, filtered);
      final chronological = [...filtered]..sort((a, b) {
        final byDate = a.entryDate.compareTo(b.entryDate);
        return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
      });
      final balances = LedgerCalculator.runningBalances(customer, chronological);
      final runningById = <String, double>{};
      for (var index = 0; index < chronological.length; index++) {
        runningById[chronological[index].id] = balances[index];
      }
      final newestFirst = [...filtered]..sort((a, b) {
        final byDate = b.entryDate.compareTo(a.entryDate);
        return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
      });
      return AlertDialog(
        title: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(customer.name),
            Text('${customer.isStockLedger ? 'Stock' : 'General'} ledger · ${filtered.length} entries', style: Theme.of(context).textTheme.labelMedium),
          ])),
          IconButton(onPressed: () { Navigator.pop(dialogContext); _editOpeningBalance(customer); }, icon: const Icon(Icons.account_balance_wallet_outlined), tooltip: 'Opening balance'),
          IconButton(onPressed: () { Navigator.pop(dialogContext); _addEntry(initialCustomer: customer); }, icon: const Icon(Icons.add_circle_outline), tooltip: 'New entry'),
        ]),
        content: SizedBox(
          width: MediaQuery.sizeOf(context).width > 980 ? 820 : MediaQuery.sizeOf(context).width * 0.82,
          height: MediaQuery.sizeOf(context).height > 780 ? 540 : MediaQuery.sizeOf(context).height * 0.62,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final option in const ['All', 'Today', 'This week', 'This month', 'Custom'])
              ChoiceChip(
                label: Text(option),
                selected: filter == option,
                onSelected: (_) async {
                  if (option == 'Custom') {
                    final start = await showDatePicker(context: context, initialDate: customStart ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime(9999), helpText: 'Choose start date');
                    if (start == null || !context.mounted) return;
                    final initialEnd = customEnd != null && !customEnd!.isBefore(start) ? customEnd! : start;
                    final end = await showDatePicker(context: context, initialDate: initialEnd, firstDate: start, lastDate: DateTime(9999), helpText: 'Choose end date');
                    if (end == null) return;
                    setDialogState(() { filter = option; customStart = start; customEnd = end; });
                  } else {
                    setDialogState(() => filter = option);
                  }
                },
              ),
          ]),
          if (filter == 'Custom' && customStart != null && customEnd != null)
            Padding(padding: const EdgeInsets.only(left: 4, top: 2), child: Text('${_dateLabel(customStart!)} — ${_dateLabel(customEnd!)}', style: Theme.of(context).textTheme.labelMedium)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 7, children: [
            _ledgerMetric('Debit', 'Rs ${totals.debit.toStringAsFixed(2)}', BrandColors.teal),
            _ledgerMetric('Credit', 'Rs ${totals.credit.toStringAsFixed(2)}', BrandColors.gold),
            _ledgerMetric('Balance', totals.balanceLabel, BrandColors.ink),
          ]),
          const Divider(height: 22),
          Expanded(child: newestFirst.isEmpty
            ? const Center(child: Text('No entries for this date range.'))
            : ListView.separated(
                itemCount: newestFirst.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = newestFirst[index];
                  final running = runningById[entry.id] ?? 0;
                  final runningLabel = running == 0 ? '0' : '${running.abs().toStringAsFixed(2)} ${running > 0 ? 'D' : 'C'}';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.description.isEmpty ? 'Ledger entry' : entry.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text('${_dateLabel(entry.entryDate)} · Page ${entry.pageNumber ?? '—'} · Running $runningLabel'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('D ${entry.debit.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: BrandColors.teal)),
                        Text('C ${entry.credit.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: BrandColors.gold)),
                      ]),
                      PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'edit') {
                            Navigator.pop(dialogContext);
                            await _addEntry(existing: entry, initialCustomer: customer);
                          } else if (action == 'transfer') {
                            Navigator.pop(dialogContext);
                            await _transferEntry(entry, customer);
                          } else if (action == 'delete') {
                            final deleted = await _confirmDeleteEntry(entry);
                            if (deleted && dialogContext.mounted) Navigator.pop(dialogContext);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit entry')),
                          PopupMenuItem(value: 'transfer', child: Text('Transfer to customer')),
                          PopupMenuItem(value: 'delete', child: Text('Delete permanently')),
                        ],
                      ),
                    ]),
                  );
                },
              )),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      );
    }));
  }

  Future<void> _editOpeningBalance(LedgerCustomer customer) async {
    final debit = TextEditingController(text: customer.openingDebit == 0 ? '' : customer.openingDebit.toString());
    final credit = TextEditingController(text: customer.openingCredit == 0 ? '' : customer.openingCredit.toString());
    final buy = TextEditingController(text: customer.openingBuyQuantity == 0 ? '' : (customer.useWeight ? LedgerCalculator.formatWeightKg(customer.openingBuyQuantity) : customer.openingBuyQuantity.toString()));
    final sell = TextEditingController(text: customer.openingSellQuantity == 0 ? '' : (customer.useWeight ? LedgerCalculator.formatWeightKg(customer.openingSellQuantity) : customer.openingSellQuantity.toString()));
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text('Opening balance · ${customer.name}'),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: debit, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: customer.isStockLedger ? 'Opening buy amount / Debit' : 'Opening debit')),
        const SizedBox(height: 10),
        TextField(controller: credit, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: customer.isStockLedger ? 'Opening sell amount / Credit' : 'Opening credit')),
        if (customer.isStockLedger) ...[
          const SizedBox(height: 10),
          TextField(controller: buy, keyboardType: customer.useWeight ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: customer.useWeight ? 'Opening buy weight' : 'Opening buy quantity')),
          const SizedBox(height: 10),
          TextField(controller: sell, keyboardType: customer.useWeight ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: customer.useWeight ? 'Opening sell weight' : 'Opening sell quantity')),
        ],
      ]))),
      actions: [
        TextButton(onPressed: () {
          debit.text = customer.openingDebit == 0 ? '' : customer.openingDebit.toString();
          credit.text = customer.openingCredit == 0 ? '' : customer.openingCredit.toString();
          buy.text = customer.openingBuyQuantity == 0 ? '' : (customer.useWeight ? LedgerCalculator.formatWeightKg(customer.openingBuyQuantity) : customer.openingBuyQuantity.toString());
          sell.text = customer.openingSellQuantity == 0 ? '' : (customer.useWeight ? LedgerCalculator.formatWeightKg(customer.openingSellQuantity) : customer.openingSellQuantity.toString());
        }, child: const Text('Reset')),
        TextButton(onPressed: () async {
          final clear = await showDialog<bool>(context: dialogContext, builder: (confirmContext) => AlertDialog(
            title: const Text('Clear opening balance?'),
            content: const Text('All saved opening amounts and quantities for this customer will be cleared.'),
            actions: [TextButton(onPressed: () => Navigator.pop(confirmContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(confirmContext, true), child: const Text('Clear'))],
          ));
          if (clear == true) {
            await _saveOpeningBalance(customer, debit: 0, credit: 0, buy: 0, sell: 0);
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          }
        }, child: const Text('Clear')),
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          final d = _parseNumber(debit.text);
          final c = _parseNumber(credit.text);
          final b = _parseQuantity(buy.text, customer.useWeight);
          final s = _parseQuantity(sell.text, customer.useWeight);
          if (![d, c, b, s].every((value) => value.isFinite && value >= 0)) { _showMessage('Opening values must be valid and non-negative.'); return; }
          await _saveOpeningBalance(customer, debit: d, credit: c, buy: b, sell: s);
          if (dialogContext.mounted) Navigator.pop(dialogContext);
        }, child: const Text('Save')),
      ],
    ));
    debit.dispose();
    credit.dispose();
    buy.dispose();
    sell.dispose();
  }

  Future<void> _saveOpeningBalance(LedgerCustomer customer, {required double debit, required double credit, required double buy, required double sell}) async {
    try {
      await _repository.updateCustomer(LedgerCustomer(
        id: customer.id, name: customer.name, year: customer.year, phone: customer.phone, address: customer.address,
        isStockLedger: customer.isStockLedger, useWeight: customer.useWeight,
        openingDebit: debit, openingCredit: credit, openingBuyQuantity: buy, openingSellQuantity: sell,
      ));
      await _loadCustomers();
      _showMessage('Opening balance saved.');
    } catch (error) {
      _showMessage('Could not save opening balance: $error');
    }
  }

  List<LedgerEntry> _filterLedgerEntries(List<LedgerEntry> entries, String filter, DateTime? start, DateTime? end) {
    final today = DateUtils.dateOnly(DateTime.now());
    return entries.where((entry) {
      final date = DateUtils.dateOnly(entry.entryDate);
      switch (filter) {
        case 'Today':
          return date == today;
        case 'This week':
          final monday = today.subtract(Duration(days: today.weekday - DateTime.monday));
          return !date.isBefore(monday) && date.isBefore(monday.add(const Duration(days: 7)));
        case 'This month':
          return date.year == today.year && date.month == today.month;
        case 'Custom':
          if (start == null || end == null) return false;
          return !date.isBefore(DateUtils.dateOnly(start)) && !date.isAfter(DateUtils.dateOnly(end));
        default:
          return true;
      }
    }).toList();
  }

  Widget _ledgerMetric(String title, String value, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(color: BrandColors.canvas, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 10, color: BrandColors.muted)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
      );

  Future<void> _transferEntry(LedgerEntry entry, LedgerCustomer source) async {
    final targets = _customers.where((customer) => customer.year == _activeYear && customer.id != source.id).toList();
    if (targets.isEmpty) {
      _showMessage('Add another customer before transferring this entry.');
      return;
    }
    var target = targets.first;
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('Transfer entry'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Move this entry from ${source.name}? Its date, amounts, page and description will be preserved.'),
        const SizedBox(height: 14),
        DropdownButtonFormField<LedgerCustomer>(
          initialValue: target,
          decoration: const InputDecoration(labelText: 'Transfer to'),
          items: targets.map((customer) => DropdownMenuItem(value: customer, child: Text(customer.name))).toList(),
          onChanged: (value) { if (value != null) setDialogState(() => target = value); },
        ),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Transfer'))],
    )));
    if (confirmed != true) return;
    try {
      await _repository.transferEntry(entry.id, target.id);
      await _loadCustomers();
      _showMessage('Entry transferred to ${target.name}.');
    } catch (error) {
      _showMessage('Transfer failed: $error');
    }
  }

  Future<bool> _confirmDeleteEntry(LedgerEntry entry) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Delete entry permanently?'),
      content: const Text('This removes the entry from the customer ledger and daily logs.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete'))],
    ));
    if (confirmed != true) return false;
    try {
      await _repository.deleteEntry(entry.id);
      await _loadCustomers();
      _showMessage('Entry deleted.');
      return true;
    } catch (error) {
      _showMessage('Delete failed: $error');
      return false;
    }
  }

  Widget _statCard(String label, String value, String detail, IconData icon, Color accent) => Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: BrandColors.mint, borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: BrandColors.ink)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BrandColors.ink)),
              Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: BrandColors.muted)),
            ])),
          ]),
        ),
      );

  Widget _recentActivity(BuildContext context) {
    final activeIds = _customers.where((customer) => customer.year == _activeYear).map((customer) => customer.id).toSet();
    final recent = _entries.where((entry) => activeIds.contains(entry.customerId)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Card(
      child: Padding(padding: const EdgeInsets.fromLTRB(18, 17, 18, 13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Recent activity', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            const Text('Latest entries in this ledger year', style: TextStyle(fontSize: 11, color: BrandColors.muted)),
          ])),
          TextButton(onPressed: () => setState(() => _selected = 3), child: const Text('View all')),
        ]),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Center(child: Column(children: [
            Container(width: 46, height: 46, decoration: const BoxDecoration(color: BrandColors.mint, shape: BoxShape.circle), child: const Icon(Icons.receipt_long_outlined, color: BrandColors.teal)),
            const SizedBox(height: 10),
            const Text('No entries yet', style: TextStyle(fontWeight: FontWeight.w700, color: BrandColors.ink)),
            const SizedBox(height: 3),
            const Text('Add your first transaction to see activity here.', style: TextStyle(fontSize: 11, color: BrandColors.muted), textAlign: TextAlign.center),
            const SizedBox(height: 9),
            OutlinedButton.icon(onPressed: _addEntry, icon: const Icon(Icons.add, size: 17), label: const Text('Create entry')),
          ])))
        else
          for (final entry in recent.take(5))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: BrandColors.elevated, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.receipt_outlined, color: BrandColors.teal, size: 18)),
              title: Text(_customerName(entry.customerId), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(entry.description.isEmpty ? _dateLabel(entry.entryDate) : '${entry.description} · ${_dateLabel(entry.entryDate)}', maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text('${entry.debit > 0 ? '−' : '+'} Rs ${_compactRupees(entry.debit > 0 ? entry.debit : entry.credit)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: entry.debit > 0 ? BrandColors.coral : BrandColors.teal)),
              onTap: () {
                for (final customer in _customers) {
                  if (customer.id == entry.customerId) {
                    _openLedger(customer);
                    break;
                  }
                }
              },
            ),
      ])),
    );
  }

  String _dateLabel(DateTime date) => '${date.day.toString().padLeft(2, '0')} ${_month(date.month)} ${date.year}';

  Widget _quickPanel(BuildContext context) => Card(
        child: Padding(padding: const EdgeInsets.fromLTRB(18, 17, 18, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Quick actions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 3),
          const Text('Common tasks, one tap away', style: TextStyle(fontSize: 11, color: BrandColors.muted)),
          const SizedBox(height: 8),
          _quickAction(Icons.person_add_alt_1_rounded, 'Add a customer', 'Set up a new account', _addCustomer),
          _quickAction(Icons.note_add_outlined, 'New entry', 'Record debit or credit', _addEntry),
          _quickAction(Icons.backup_outlined, 'Back up data', 'Save workspace JSON', _createBackup),
        ])),
      );

  Widget _quickAction(IconData icon, String title, String subtitle, VoidCallback onTap) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        onTap: onTap,
        leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: BrandColors.mint, borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: BrandColors.teal, size: 19)),
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: BrandColors.muted),
      );

  Future<void> _addCustomer() => _customerForm();

  Future<void> _editCustomer(LedgerCustomer customer) => _customerForm(existing: customer);

  Future<void> _customerForm({LedgerCustomer? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final address = TextEditingController(text: existing?.address ?? '');
    var stock = existing?.isStockLedger ?? false;
    var weight = existing?.useWeight ?? false;
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text(existing == null ? 'Add customer' : 'Edit customer'),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Customer name *')),
        const SizedBox(height: 10),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)')),
        const SizedBox(height: 10),
        TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address (optional)')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: stock,
          title: const Text('Stock ledger'),
          onChanged: (value) => setDialogState(() { stock = value; if (!stock) weight = false; }),
        ),
        if (stock) SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: weight,
          title: const Text('Weight mode'),
          subtitle: const Text('Weight is stored internally in kilograms.'),
          onChanged: (value) => setDialogState(() => weight = value),
        ),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          final normalizedName = name.text.trim();
          if (normalizedName.isEmpty) { _showMessage('Customer name is required.'); return; }
          final model = LedgerCustomer(
            id: existing?.id ?? '',
            name: normalizedName,
            year: existing?.year ?? _activeYear,
            phone: phone.text.trim(),
            address: address.text.trim(),
            isStockLedger: stock,
            useWeight: stock && weight,
            openingDebit: existing?.openingDebit ?? 0,
            openingCredit: existing?.openingCredit ?? 0,
            openingBuyQuantity: existing?.openingBuyQuantity ?? 0,
            openingSellQuantity: existing?.openingSellQuantity ?? 0,
          );
          try {
            if (existing == null) {
              await _repository.addCustomer(name: model.name, year: model.year, phone: model.phone, address: model.address, isStock: model.isStockLedger, useWeight: model.useWeight);
            } else {
              await _repository.updateCustomer(model);
            }
            await _loadCustomers();
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          } catch (error) {
            _showMessage('$error');
          }
        }, child: Text(existing == null ? 'Add customer' : 'Save changes')),
      ],
    )));
    name.dispose();
    phone.dispose();
    address.dispose();
  }

  Future<void> _deleteCustomer(LedgerCustomer customer) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Delete customer?'),
      content: Text('Permanently delete ${customer.name} and all of their ledger entries? This cannot be undone.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete'))],
    ));
    if (confirmed != true) return;
    try {
      await _repository.deleteCustomer(customer.id);
      await _loadCustomers();
      _showMessage('Customer and related entries deleted.');
    } catch (error) {
      _showMessage('Delete failed: $error');
    }
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

  LedgerCustomer? _customerForId(String id) {
    for (final customer in _customers) {
      if (customer.id == id) return customer;
    }
    return null;
  }

  String _customerName(String id) {
    for (final customer in _customers) {
      if (customer.id == id) return customer.name;
    }
    return 'Customer';
  }

  Future<void> _addEntry({LedgerEntry? existing, LedgerCustomer? initialCustomer}) async {
    final customers = _customers.where((customer) => customer.year == _activeYear).toList();
    if (customers.isEmpty) {
      _showMessage('Add a customer before recording an entry.');
      return;
    }
    final targetCustomer = initialCustomer ?? _customerForId(existing?.customerId ?? '');
    final debit = TextEditingController(text: existing?.debit.toString() ?? '');
    final credit = TextEditingController(text: existing?.credit.toString() ?? '');
    final buyQuantity = TextEditingController(text: existing == null ? '' : (targetCustomer?.useWeight == true ? LedgerCalculator.formatWeightKg(existing.buyQuantity) : existing.buyQuantity.toString()));
    final sellQuantity = TextEditingController(text: existing == null ? '' : (targetCustomer?.useWeight == true ? LedgerCalculator.formatWeightKg(existing.sellQuantity) : existing.sellQuantity.toString()));
    final page = TextEditingController(text: existing?.pageNumber ?? '');
    final description = TextEditingController(text: existing?.description ?? '');
    var customer = targetCustomer ?? customers.first;
    var entryDate = existing?.entryDate ?? DateTime.now();
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text(existing == null ? 'New ledger entry' : 'Edit ledger entry'),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (existing == null) DropdownButtonFormField<LedgerCustomer>(
          initialValue: customer,
          decoration: const InputDecoration(labelText: 'Customer'),
          items: customers.map((item) => DropdownMenuItem(value: item, child: Text(item.name))).toList(),
          onChanged: (item) { if (item != null) setDialogState(() => customer = item); },
        ) else ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline_rounded, color: BrandColors.teal),
          title: Text(customer.name),
          subtitle: const Text('Customer · transfer separately'),
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
            id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
            customerId: customer.id,
            entryDate: entryDate,
            createdAt: existing?.createdAt ?? DateTime.now(),
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
            if (existing == null) {
              await _repository.addEntry(entry, stockLedger: customer.isStockLedger);
            } else {
              await _repository.updateEntry(entry, stockLedger: customer.isStockLedger);
            }
            await _loadCustomers();
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          } catch (error) {
            _showMessage('$error');
          }
        }, child: Text(existing == null ? 'Save entry' : 'Save changes')),
      ],
    )));
    debit.dispose();
    credit.dispose();
    buyQuantity.dispose();
    sellQuantity.dispose();
    page.dispose();
    description.dispose();
  }

  Future<void> _createCsvExport() async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Export ledger rows?'),
      content: const Text('The CSV contains customer details and financial data for the active year. Save and share it carefully.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Export CSV'))],
    ));
    if (confirmed != true) return;
    try {
      final csv = await _repository.exportCsv(year: _activeYear);
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'Export HisabFlow ledger CSV',
        fileName: 'hisabflow-$_activeYear.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]),
      );
      if (saved != null) _showMessage('CSV export saved for $_activeYear.');
    } catch (error) {
      _showMessage('CSV export failed: $error');
    }
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
