import 'package:adminms/component/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

class InventoryHistoryPage extends StatefulWidget {
  final String? itemId;

  const InventoryHistoryPage({Key? key, this.itemId}) : super(key: key);

  @override
  State<InventoryHistoryPage> createState() => _InventoryHistoryPageState();
}

class _InventoryHistoryPageState extends State<InventoryHistoryPage> {
  // Filters and search controllers
  DateTime? _filterExactDate;
  DateTime? _filterMonthYear;

  final TextEditingController _leftSearchController = TextEditingController();
  final TextEditingController _midSearchController = TextEditingController();
  final TextEditingController _rightSearchController = TextEditingController();
  // Debounce timers for search inputs (prevent rebuild on every keystroke)
  Timer? _leftSearchDebounce;
  Timer? _midSearchDebounce;
  Timer? _rightSearchDebounce;
  // Debounced search query notifiers (updated after timer fires) — rebuild only small subtrees
  final ValueNotifier<String> _leftSearchNotifier = ValueNotifier<String>('');
  final ValueNotifier<String> _midSearchNotifier = ValueNotifier<String>('');
  final ValueNotifier<String> _rightSearchNotifier = ValueNotifier<String>('');

  @override
  void dispose() {
    _leftSearchController.dispose();
    _midSearchController.dispose();
    _rightSearchController.dispose();
    _leftSearchDebounce?.cancel();
    _midSearchDebounce?.cancel();
    _rightSearchDebounce?.cancel();
    _leftSearchNotifier.dispose();
    _midSearchNotifier.dispose();
    _rightSearchNotifier.dispose();
    super.dispose();
  }

  void _onLeftSearchChanged(String v) {
    _leftSearchDebounce?.cancel();
    final pending = v;
    _leftSearchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _leftSearchNotifier.value = pending.trim().toLowerCase();
    });
  }

  void _onMidSearchChanged(String v) {
    _midSearchDebounce?.cancel();
    final pending = v;
    _midSearchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _midSearchNotifier.value = pending.trim().toLowerCase();
    });
  }

  void _onRightSearchChanged(String v) {
    _rightSearchDebounce?.cancel();
    final pending = v;
    _rightSearchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _rightSearchNotifier.value = pending.trim().toLowerCase();
    });
  }

  String formatDate(dynamic ts) {
    DateTime? dt;
    if (ts == null) return '-';
    if (ts is Timestamp) dt = ts.toDate().toLocal();
    else if (ts is DateTime) dt = ts.toLocal();
    else if (ts is String) {
      // try parse ISO strings
      dt = DateTime.tryParse(ts);
      if (dt != null) dt = dt.toLocal();
    } else if (ts is num) {
      // treat as milliseconds since epoch
      try {
        dt = DateTime.fromMillisecondsSinceEpoch(ts.toInt()).toLocal();
      } catch (_) {
        dt = null;
      }
    }

    if (dt == null) return '-';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} :: ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // Recursively search a kitchen-request entry for any value that matches `itemId`.
  bool _entryMatchesItemId(dynamic entry, String? itemId, [String? itemName]) {
    if (itemId == null && (itemName == null || itemName.isEmpty)) return false;
    if (entry == null) return false;
    // Match by id first
    if (itemId != null) {
      if (entry is String || entry is num || entry is bool) {
        if (entry.toString() == itemId) return true;
      }
    }
    // Match by name if provided
    if (itemName != null && itemName.isNotEmpty) {
      if (entry is String) {
        if (entry == itemName) return true;
      }
    }
    if (entry is Map) {
      for (final v in entry.values) {
        if (_entryMatchesItemId(v, itemId, itemName)) return true;
      }
      return false;
    }
    if (entry is Iterable) {
      for (final v in entry) {
        if (_entryMatchesItemId(v, itemId, itemName)) return true;
      }
      return false;
    }
    return false;
  }

  // (debug helper removed)

  DateTime? _parseDate(dynamic ts) {
    if (ts == null) return null;
    if (ts is Timestamp) return ts.toDate().toLocal();
    if (ts is DateTime) return ts.toLocal();
    try {
      return DateTime.parse(ts.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickExactDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _filterExactDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() {
      _filterExactDate = d;
      _filterMonthYear = null;
    });
  }

  Future<void> _pickMonth() async {
    final months = const [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final now = DateTime.now();
    int selectedYear = _filterMonthYear?.year ?? now.year;
    int selectedMonth = _filterMonthYear?.month ?? now.month;

    final picked = await showDialog<DateTime?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          final currentYear = DateTime.now().year;
          final years = List<int>.generate(currentYear + 6 - 2000, (i) => 2000 + i);
          return AlertDialog(
            title: const Text('Select month and year', style: TextStyle(color: Colors.black)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<int>(
                        value: selectedYear,
                        isExpanded: true,
                        onChanged: (v) {
                          if (v == null) return;
                          setStateDialog(() => selectedYear = v);
                        },
                        items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(12, (i) {
                    final m = i + 1;
                    final isSelected = m == selectedMonth;
                    return ChoiceChip(
                      label: Text(months[i]),
                      selected: isSelected,
                      onSelected: (_) => setStateDialog(() => selectedMonth = m),
                    );
                  }),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.of(context).pop(DateTime(selectedYear, selectedMonth)), child: const Text('Apply')),
            ],
          );
        });
      },
    );

    if (picked != null) setState(() {
      _filterExactDate = null;
      _filterMonthYear = DateTime(picked.year, picked.month);
    });
  }

  void _clearFilters() {
    setState(() {
      _filterExactDate = null;
      _filterMonthYear = null;
    });
  }

  bool _matchesFiltersForTs(dynamic ts) {
    final dt = _parseDate(ts);
    if (_filterExactDate != null) {
      if (dt == null) return false;
      return dt.year == _filterExactDate!.year && dt.month == _filterExactDate!.month && dt.day == _filterExactDate!.day;
    }
    if (_filterMonthYear != null) {
      if (dt == null) return false;
      return dt.year == _filterMonthYear!.year && dt.month == _filterMonthYear!.month;
    }
    return true; // no filter
  }

  @override
  Widget build(BuildContext context) {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream = widget.itemId != null
    ? FirebaseFirestore.instance
      .collection('inventory_history')
      .where('itemId', isEqualTo: widget.itemId)
            .orderBy('timestamp', descending: true)
            .snapshots()
        : FirebaseFirestore.instance
            .collection('inventory_history')
            .orderBy('timestamp', descending: true)
            .snapshots();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
  title: Text(widget.itemId != null ? 'History for item' : 'Inventory History'),
        backgroundColor: AppColors.se,
      ),
      body: Padding(
        
        padding: const EdgeInsets.all(16.0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))
            ],
          ),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snap) {
              if (snap.hasError) {
                final errStr = snap.error?.toString() ?? 'Unknown error';
                final needsIndex = errStr.toLowerCase().contains('requires an index') ||
                    errStr.toLowerCase().contains('create_composite');
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Error loading history', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (needsIndex) ...[
                      const Text(
                          'Firestore reports this query requires a composite index. Create an index for the collection "inventory_history" with the following fields:'),
                      const SizedBox(height: 6),
                      const Text('- Field: itemId   Direction: Ascending'),
                      const Text('- Field: timestamp Direction: Descending'),
                      const SizedBox(height: 8),
                      const Text(
                          'You can create this index in the Firebase Console → Firestore Database → Indexes → Create composite index, or follow the link contained in the original error message below.'),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 6),
                    const Text('Error details (select/copy):', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Expanded(child: SingleChildScrollView(child: SelectableText(errStr))),
                    const SizedBox(height: 8),
                    Row(children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: errStr));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Error details copied to clipboard')));
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy error'),
                      ),
                      const SizedBox(width: 8),
                      if (needsIndex)
                        OutlinedButton(
                            child: const Text('How to create'),
                            onPressed: () => showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                        title: const Text('Create composite index'),
                                        content: const Text(
                                            'Open Firebase Console → Firestore → Indexes and create a composite index for collection "inventory_history" with fields: itemId (Ascending), timestamp (Descending). After the index builds the query will succeed.'),
                                        actions: [
                                          TextButton(
                                              onPressed: () => Navigator.of(ctx).pop(),
                                              child: const Text('OK'))
                                        ])),
                            ),
                    ]),
                  ]),
                );
              }

              if (snap.connectionState == ConnectionState.waiting)
                return const SizedBox(
                    height: 120, child: Center(child: CircularProgressIndicator()));

              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty)
                return const Padding(padding: EdgeInsets.all(16), child: Text('No history entries'));

              final allEntries = docs.map((d) => d.data()).toList();
              final changedEntries = allEntries.where((d) {
                final oldSup = (d['oldSupplier'] ?? '').toString();
                final newSup = (d['newSupplier'] ?? '').toString();
                final oldP = d['oldPrice']?.toString() ?? '';
                final newP = d['newPrice']?.toString() ?? '';
                final priceChanged = oldP.isNotEmpty && newP.isNotEmpty && oldP != newP;
                final supplierChanged = oldSup.isNotEmpty && newSup.isNotEmpty && oldSup != newSup;
                return priceChanged || supplierChanged;
              }).toList();

              return LayoutBuilder(builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                if (isWide) {
                  final textStyle = const TextStyle(fontSize: 16);
                  double maxTextWidth = 0.0;
                  for (final d in allEntries) {
                    final addedQ = d['addedQuantity']?.toString() ?? '';
                    final title = '${d['itemName'] ?? ''} — +$addedQ';
                    final tp =
                        TextPainter(text: TextSpan(text: title, style: textStyle), textDirection: TextDirection.ltr);
                    tp.layout();
                    if (tp.width > maxTextWidth) maxTextWidth = tp.width;
                  }
                  // Make left panel a bit wider by default so content has breathing room
                  double leftWidth = (maxTextWidth + 340.0).clamp(260.0, 640.0);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Gap(20),
                      SizedBox(
                        width: leftWidth,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
                              ]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Supplied Items',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.se),
                                          onPressed: _pickExactDate,
                                          child: Text(_filterExactDate == null ? 'Filter by date' : 'Date: ${_filterExactDate!.year}-${_filterExactDate!.month.toString().padLeft(2,'0')}-${_filterExactDate!.day.toString().padLeft(2,'0')}', style: TextStyle(color: AppColors.pr)),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.se),
                                          onPressed: _pickMonth,
                                          child: Text(_filterMonthYear == null ? 'Filter by month' : 'Month: ${_filterMonthYear!.year}-${_filterMonthYear!.month.toString().padLeft(2,'0')}', style: TextStyle(color: AppColors.pr)),
                                        ),
                                        if (_filterExactDate != null || _filterMonthYear != null) ...[
                                          const SizedBox(width: 8),
                                          OutlinedButton(onPressed: _clearFilters, child: const Text('Clear filters', style: TextStyle(color: AppColors.pr))),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _leftSearchController,
                                      onChanged: _onLeftSearchChanged,
                                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search supplied items'),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Builder(builder: (context) {
                                  return ValueListenableBuilder<String>(
                                    valueListenable: _leftSearchNotifier,
                                    builder: (context, q, _) {
                                      final filtered = allEntries.where((d) {
                                    if (!_matchesFiltersForTs(d['timestamp'])) return false;
                                    if (q.isEmpty) return true;
                                    final name = (d['itemName'] ?? '').toString().toLowerCase();
                                    final addedQ = (d['addedQuantity']?.toString() ?? '').toLowerCase();
                                    return name.contains(q) || addedQ.contains(q);
                                  }).toList();
                                      return ListView.separated(
                                    padding: const EdgeInsets.all(8),
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, i) {
                                      final d = filtered[i];
                                      final ts = d['timestamp'];
                                      final when = formatDate(ts);
                                      final oldSup = d['oldSupplier'] ?? '';
                                      final newSup = d['newSupplier'] ?? '';
                                      final same = d['sameSupplier'] == true;
                                      final oldP = d['oldPrice']?.toString() ?? '';
                                      final newP = d['newPrice']?.toString() ?? '';
                                      final addedQ = d['addedQuantity']?.toString() ?? '';

                                      return ListTile(
                                        title: Text('${d['itemName'] ?? ''} — +$addedQ',
                                            style: const TextStyle(color: Colors.green)),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Request: $when'),
                                            Text(same
                                                ? 'Supplier: $oldSup (unchanged)'
                                                : 'Supplier: $oldSup → $newSup'),
                                            Text(same
                                                ? (oldP.isNotEmpty ? 'Price: $oldP (unchanged)' : 'Price: $oldP')
                                                : 'Price: $oldP → $newP'),
                                          ],
                                        ),
                                        isThreeLine: true,
                                      );
                                    },
                                      );
                                    },
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 25),

                      // Middle panel: Kitchen Requests
                      SizedBox(
                        width: leftWidth,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
                              ]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Kitchen Requests',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
                                child: TextField(
                                  controller: _midSearchController,
                                  onChanged: _onMidSearchChanged,
                                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search kitchen requests'),
                                ),
                              ),
                              // inner card to visually separate the list from surrounding container
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F9FB),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                                    ],
                                  ),
                                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            // Listen to the most recent kitchen_requests documents (last 50)
            stream: FirebaseFirestore.instance
              .collection('kitchen_requests')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
                                    builder: (context, snapKR) {
                                      if (snapKR.hasError) return const Text('Kitchen requests: error');
                                      if (snapKR.connectionState == ConnectionState.waiting)
                                        return const Center(child: CircularProgressIndicator());

                                      final docsKR = snapKR.data?.docs ?? [];
                                      // Combine pending+sent from the most recent docs
                                      final List<dynamic> allKR = [];
                                      for (final d in docsKR) {
                                        final dd = d.data();
                                        final pending = (dd['pending'] ?? []) as List<dynamic>;
                                        final sent = (dd['sent'] ?? []) as List<dynamic>;
                                        allKR.addAll(pending);
                                        allKR.addAll(sent);
                                      }
                                      // If itemId is provided, we also fetch the raw_components doc
                                      // to get the item's canonical name and match by name as well.
                                      if (widget.itemId != null) {
                                        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                          future: FirebaseFirestore.instance.collection('raw_components').doc(widget.itemId).get(),
                                          builder: (context, rawSnap) {
                                            if (rawSnap.connectionState == ConnectionState.waiting)
                                              return const Center(child: CircularProgressIndicator());
                                            final itemName = rawSnap.data?.data()?['name']?.toString();
                                            final entries0 = allKR.where((e) => _entryMatchesItemId(e, widget.itemId, itemName)).toList();
                                            // entries0 computed above — apply debounced mid search via notifier
                                            return ValueListenableBuilder<String>(
                                              valueListenable: _midSearchNotifier,
                                              builder: (context, midQ, _) {
                                                final entries = entries0.where((s) {
                                                  final requestTs = s['requestDate'] ?? s['date'] ?? s['createdAt'];
                                                  final sentTs = s['sentDate'] ?? s['updatedAt'];
                                                  final dateOk = _matchesFiltersForTs(requestTs) || _matchesFiltersForTs(sentTs);
                                                  if (!dateOk) return false;
                                                  if (midQ.isEmpty) return true;
                                                  final name = (s['name'] ?? s['product'] ?? '').toString().toLowerCase();
                                                  final cat = (s['category'] ?? '').toString().toLowerCase();
                                                  final qtyStr = (s['sentQty'] ?? s['qty'] ?? s['quantity'] ?? s['requestedQty'])?.toString().toLowerCase() ?? '';
                                                  return name.contains(midQ) || cat.contains(midQ) || qtyStr.contains(midQ);
                                                }).toList();
                                                if (entries.isEmpty) return const SizedBox.shrink();

                                                return ListView.separated(
                                                  itemCount: entries.length,
                                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                                  itemBuilder: (context, idx) {
                                                    final s = (entries[idx] ?? {}) as Map<String, dynamic>;
                                                    final requestTs = s['requestDate'] ?? s['date'] ?? s['createdAt'];
                                                    final sentTs = s['sentDate'] ?? s['updatedAt'];
                                                    final qtyRaw = s['sentQty'] ?? s['qty'] ?? s['quantity'] ?? s['requestedQty'];
                                                    final qty = qtyRaw != null ? qtyRaw.toString() : '-';
                                                    final qtyLabel = qty == '-' ? '-' : '-$qty';
                                                    final name = s['name'] ?? s['product'] ?? '';

                                                    return ListTile(
                                                      title: Text('$name — $qtyLabel', style: const TextStyle(color: Colors.red)),
                                                      subtitle: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text('Request: ${formatDate(requestTs)}'),
                                                          Text('Sent: ${formatDate(sentTs)}'),
                                                        ],
                                                      ),
                                                      isThreeLine: true,
                                                    );
                                                  },
                                                );
                                              },
                                            );
                                          },
                                        );
                                      }

                                      // apply debounced mid search using notifier so only this list rebuilds
                                      return ValueListenableBuilder<String>(
                                        valueListenable: _midSearchNotifier,
                                        builder: (context, midQ2, _) {
                                          final entries = allKR.where((s) {
                                            final requestTs = s['requestDate'] ?? s['date'] ?? s['createdAt'];
                                            final sentTs = s['sentDate'] ?? s['updatedAt'];
                                            final dateOk = _matchesFiltersForTs(requestTs) || _matchesFiltersForTs(sentTs);
                                            if (!dateOk) return false;
                                            if (midQ2.isEmpty) return true;
                                            final name = (s['name'] ?? s['product'] ?? '').toString().toLowerCase();
                                            final cat = (s['category'] ?? '').toString().toLowerCase();
                                            final qtyStr = (s['sentQty'] ?? s['qty'] ?? s['quantity'] ?? s['requestedQty'])?.toString().toLowerCase() ?? '';
                                            return name.contains(midQ2) || cat.contains(midQ2) || qtyStr.contains(midQ2);
                                          }).toList();
                                          if (entries.isEmpty) return const Text('No kitchen requests');

                                          return ListView.separated(
                                            itemCount: entries.length,
                                            separatorBuilder: (_, __) => const Divider(height: 1),
                                            itemBuilder: (context, idx) {
                                              final s = (entries[idx] ?? {}) as Map<String, dynamic>;
                                              final requestTs = s['requestDate'] ?? s['date'] ?? s['createdAt'];
                                              final sentTs = s['sentDate'] ?? s['updatedAt'];
                                              final qtyRaw = s['sentQty'] ?? s['qty'] ?? s['quantity'] ?? s['requestedQty'];
                                              final qty = qtyRaw != null ? qtyRaw.toString() : '-';
                                              final qtyLabel = qty == '-' ? '-' : '-$qty';
                                              final name = s['name'] ?? s['product'] ?? '';

                                              return ListTile(
                                                title: Text('$name — $qtyLabel', style: const TextStyle(color: Colors.red)),
                                                subtitle: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Request: ${formatDate(requestTs)}'),
                                                    Text('Sent: ${formatDate(sentTs)}'),
                                                  ],
                                                ),
                                                isThreeLine: true,
                                              );
                                            },
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 35),

                      // Right panel: Price / Supplier Changes
                      Align(
                        alignment: Alignment.topRight,
                        child: IntrinsicWidth(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
                                ]),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Price / Supplier Changes',
                                    style: TextStyle(fontWeight: FontWeight.bold)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: SizedBox(
                                    width: 240,
                                    child: TextField(
                                      controller: _rightSearchController,
                                      onChanged: _onRightSearchChanged,
                                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search changes'),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Builder(builder: (context) {
                                  return ValueListenableBuilder<String>(
                                    valueListenable: _rightSearchNotifier,
                                    builder: (context, rq, _) {
                                      final filteredChanged = changedEntries.where((d) {
                                        if (!_matchesFiltersForTs(d['timestamp'])) return false;
                                        if (rq.isEmpty) return true;
                                        final itemName = (d['itemName'] ?? '').toString().toLowerCase();
                                        final oldSup = (d['oldSupplier'] ?? '').toString().toLowerCase();
                                        final newSup = (d['newSupplier'] ?? '').toString().toLowerCase();
                                        return itemName.contains(rq) || oldSup.contains(rq) || newSup.contains(rq);
                                      }).toList();
                                      return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('Item')),
                                        DataColumn(label: Text('Old Price')),
                                        DataColumn(label: Text('New Price')),
                                        DataColumn(label: Text('Old Supplier')),
                                        DataColumn(label: Text('New Supplier')),
                                      ],
                                      rows: filteredChanged.map((d) {
                                        final itemName = d['itemName'] ?? '';
                                        final oldPstr = d['oldPrice']?.toString() ?? '';
                                        final newPstr = d['newPrice']?.toString() ?? '';
                                        final oldSup = d['oldSupplier'] ?? '';
                                        final newSup = d['newSupplier'] ?? '';
                                        double? oldPd = double.tryParse(oldPstr.replaceAll(',', ''));
                                        double? newPd = double.tryParse(newPstr.replaceAll(',', ''));
                                        Widget priceCell = Text(newPstr);
                                        if (oldPd != null && newPd != null) {
                                          if (newPd > oldPd) {
                                            priceCell = Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(newPstr),
                                                  const SizedBox(width: 6),
                                                  const Icon(Icons.arrow_upward, color: Colors.green, size: 16)
                                                ]);
                                          } else if (newPd < oldPd) {
                                            priceCell = Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(newPstr),
                                                  const SizedBox(width: 6),
                                                  const Icon(Icons.arrow_downward, color: Colors.red, size: 16)
                                                ]);
                                          }
                                        }
                                        return DataRow(cells: [
                                          DataCell(Text(itemName)),
                                          DataCell(Text(oldPstr)),
                                          DataCell(priceCell),
                                          DataCell(Text(oldSup)),
                                          DataCell(Text(newSup))
                                        ]);
                                      }).toList(),
                                    ),
                                  );
                                }
                                );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  // Mobile / narrow layout
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        // Supplied Items
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
                              ]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Supplied Items',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.se),
                                          onPressed: _pickExactDate,
                                          child: Text(_filterExactDate == null ? 'Filter by date' : 'Date: ${_filterExactDate!.year}-${_filterExactDate!.month.toString().padLeft(2,'0')}-${_filterExactDate!.day.toString().padLeft(2,'0')}', style: TextStyle(color: AppColors.pr)),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.se),
                                          onPressed: _pickMonth,
                                          child: Text(_filterMonthYear == null ? 'Filter by month' : 'Month: ${_filterMonthYear!.year}-${_filterMonthYear!.month.toString().padLeft(2,'0')}', style: TextStyle(color: AppColors.pr)),
                                        ),
                                        if (_filterExactDate != null || _filterMonthYear != null) ...[
                                          const SizedBox(width: 8),
                                          OutlinedButton(onPressed: _clearFilters, child: const Text('Clear filters', style: TextStyle(color: AppColors.pr))),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _leftSearchController,
                                      onChanged: _onLeftSearchChanged,
                                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search supplied items'),
                                    ),
                                  ],
                                ),
                              ),
                              Builder(builder: (context) {
                                final q = _leftSearchController.text.trim().toLowerCase();
                                final filtered = allEntries.where((d) {
                                  if (!_matchesFiltersForTs(d['timestamp'])) return false;
                                  if (q.isEmpty) return true;
                                  final name = (d['itemName'] ?? '').toString().toLowerCase();
                                  final addedQ = (d['addedQuantity']?.toString() ?? '').toLowerCase();
                                  return name.contains(q) || addedQ.contains(q);
                                }).toList();
                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(8),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final d = filtered[i];
                                    final ts = d['timestamp'];
                                    final when = formatDate(ts);
                                    final oldSup = d['oldSupplier'] ?? '';
                                    final newSup = d['newSupplier'] ?? '';
                                    final same = d['sameSupplier'] == true;
                                    final oldP = d['oldPrice']?.toString() ?? '';
                                    final newP = d['newPrice']?.toString() ?? '';
                                    final addedQ = d['addedQuantity']?.toString() ?? '';

                                    return ListTile(
                                      title: Text('${d['itemName'] ?? ''} — +$addedQ',
                                          style: const TextStyle(color: Colors.green)),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Request: $when'),
                                          Text(same
                                              ? 'Supplier: $oldSup (unchanged)'
                                              : 'Supplier: $oldSup → $newSup'),
                                          Text(same
                                              ? (oldP.isNotEmpty ? 'Price: $oldP (unchanged)' : 'Price: $oldP')
                                              : 'Price: $oldP → $newP'),
                                        ],
                                      ),
                                      isThreeLine: true,
                                    );
                                  },
                                );
                              }),
                            ],
                          ),
                        ),

                        // Kitchen Requests
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
                              ]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Kitchen Requests',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              ),
                                      Container(
                                        margin: const EdgeInsets.only(top: 6),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF7F9FB),
                                          borderRadius: BorderRadius.circular(6),
                                          boxShadow: const [
                                            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                                          ],
                                        ),
                                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                            .collection('kitchen_requests')
                            .orderBy('createdAt', descending: true)
                            .limit(50)
                            .snapshots(),
                                          builder: (context, snapKR) {
                                            if (snapKR.hasError) return const Text('Kitchen requests: error');
                                            if (snapKR.connectionState == ConnectionState.waiting)
                                              return const Center(child: CircularProgressIndicator());

                                          final docsKR = snapKR.data?.docs ?? [];
                                          final List<dynamic> allKR = [];
                                          for (final d in docsKR) {
                                            final dd = d.data();
                                            final pending = (dd['pending'] ?? []) as List<dynamic>;
                                            final sent = (dd['sent'] ?? []) as List<dynamic>;
                                            allKR.addAll(pending);
                                            allKR.addAll(sent);
                                          }
                                          // If itemId is provided, fetch the raw component name and filter by id OR name
                                          if (widget.itemId != null) {
                                            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                              future: FirebaseFirestore.instance.collection('raw_components').doc(widget.itemId).get(),
                                              builder: (context, rawSnap) {
                                                if (rawSnap.connectionState == ConnectionState.waiting)
                                                  return const Center(child: CircularProgressIndicator());
                                                final itemName = rawSnap.data?.data()?['name']?.toString();
                                                final entries = allKR.where((e) => _entryMatchesItemId(e, widget.itemId, itemName)).toList();
                                                if (entries.isEmpty) return const SizedBox.shrink();

                                                return ListView.separated(
                                                  shrinkWrap: true,
                                                  physics: const NeverScrollableScrollPhysics(),
                                                  itemCount: entries.length,
                                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                                  itemBuilder: (context, idx) {
                                                    final s = (entries[idx] ?? {}) as Map<String, dynamic>;
                                                    final requestTs = s['requestDate'] ?? s['date'] ?? s['createdAt'];
                                                    final sentTs = s['sentDate'] ?? s['updatedAt'];
                                                    final qtyRaw = s['sentQty'] ?? s['qty'] ?? s['quantity'] ?? s['requestedQty'];
                                                    final qty = qtyRaw != null ? qtyRaw.toString() : '-';
                                                    final qtyLabel = qty == '-' ? '-' : '-$qty';
                                                    final name = s['name'] ?? s['product'] ?? '';

                                                    return ListTile(
                                                      title: Text('$name — $qtyLabel', style: const TextStyle(color: Colors.red)),
                                                      subtitle: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text('Request: ${formatDate(requestTs)}'),
                                                          Text('Sent: ${formatDate(sentTs)}'),
                                                        ],
                                                      ),
                                                      isThreeLine: true,
                                                    );
                                                  },
                                                );
                                              },
                                            );
                                          }

                                          // No itemId provided: show all entries
                                          if (allKR.isEmpty) return const Text('No kitchen requests');

                                          return ListView.separated(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            itemCount: allKR.length,
                                            separatorBuilder: (_, __) => const Divider(height: 1),
                                            itemBuilder: (context, idx) {
                                              final s = (allKR[idx] ?? {}) as Map<String, dynamic>;
                                              final requestTs = s['requestDate'] ?? s['date'] ?? s['createdAt'];
                                              final sentTs = s['sentDate'] ?? s['updatedAt'];
                                              final qtyRaw = s['sentQty'] ?? s['qty'] ?? s['quantity'] ?? s['requestedQty'];
                                              final qty = qtyRaw != null ? qtyRaw.toString() : '-';
                                              final qtyLabel = qty == '-' ? '-' : '-$qty';
                                              final name = s['name'] ?? s['product'] ?? '';

                                              return ListTile(
                                                title: Text('$name — $qtyLabel', style: const TextStyle(color: Colors.red)),
                                                subtitle: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Request: ${formatDate(requestTs)}'),
                                                    Text('Sent: ${formatDate(sentTs)}'),
                                                  ],
                                                ),
                                                isThreeLine: true,
                                              );
                                            },
                                          );
                                          },
                                        ),
                                      ),
                            ],
                          ),
                        ),

                        // Price / Supplier Changes
                        Container(
                          height: 260,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
                              ]),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Price / Supplier Changes',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: SizedBox(
                                width: 240,
                                child: TextField(
                                  controller: _rightSearchController,
                                  onChanged: _onRightSearchChanged,
                                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search changes'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ValueListenableBuilder<String>(
                                valueListenable: _rightSearchNotifier,
                                builder: (context, rq, _) {
                                  final filteredChanged = changedEntries.where((d) {
                                    if (!_matchesFiltersForTs(d['timestamp'])) return false;
                                    if (rq.isEmpty) return true;
                                    final itemName = (d['itemName'] ?? '').toString().toLowerCase();
                                    final oldSup = (d['oldSupplier'] ?? '').toString().toLowerCase();
                                    final newSup = (d['newSupplier'] ?? '').toString().toLowerCase();
                                    return itemName.contains(rq) || oldSup.contains(rq) || newSup.contains(rq);
                                  }).toList();
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('Item')),
                                        DataColumn(label: Text('Old Price')),
                                        DataColumn(label: Text('New Price')),
                                        DataColumn(label: Text('Old Supplier')),
                                        DataColumn(label: Text('New Supplier')),
                                      ],
                                      rows: filteredChanged.map((d) {
                                        final itemName = d['itemName'] ?? '';
                                        final oldPstr = d['oldPrice']?.toString() ?? '';
                                        final newPstr = d['newPrice']?.toString() ?? '';
                                        final oldSup = d['oldSupplier'] ?? '';
                                        final newSup = d['newSupplier'] ?? '';
                                        double? oldPd = double.tryParse(oldPstr.replaceAll(',', ''));
                                        double? newPd = double.tryParse(newPstr.replaceAll(',', ''));
                                        Widget priceCell = Text(newPstr);
                                        if (oldPd != null && newPd != null) {
                                          if (newPd > oldPd) {
                                            priceCell = Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(newPstr),
                                                  const SizedBox(width: 6),
                                                  const Icon(Icons.arrow_upward, color: Colors.green, size: 16)
                                                ]);
                                          } else if (newPd < oldPd) {
                                            priceCell = Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(newPstr),
                                                  const SizedBox(width: 6),
                                                  const Icon(Icons.arrow_downward, color: Colors.red, size: 16)
                                                ]);
                                          }
                                        }
                                        return DataRow(cells: [
                                          DataCell(Text(itemName)),
                                          DataCell(Text(oldPstr)),
                                          DataCell(priceCell),
                                          DataCell(Text(oldSup)),
                                          DataCell(Text(newSup))
                                        ]);
                                      }).toList(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  );
                }
              });
            },
          ),
        ),
      ),
    );
  }
}
