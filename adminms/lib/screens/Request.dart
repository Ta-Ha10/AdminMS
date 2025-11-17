import 'package:adminms/component/colors.dart';
import 'package:adminms/widget/side_bar.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';

class RequestItemPage extends StatefulWidget {
  const RequestItemPage({super.key});

  @override
  State<RequestItemPage> createState() => _RequestItemPageState();
}

class _RequestItemPageState extends State<RequestItemPage> {
  // We will read the latest kitchen_requests document which contains
  // arrays 'pending' and 'sent'. Convert them into a unified list for the table.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper: parse ISO strings to a short date/time or return '-'
  String _formatDate(dynamic iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso.toString());
      return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso.toString();
    }
  }

  // Filters
  DateTime? _filterExactDate; // matches year-month-day
  DateTime? _filterMonthYear; // matches year-month

  Future<void> _pickExactDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _filterExactDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() {
      // exact date is exclusive with month filter
      _filterExactDate = d;
      _filterMonthYear = null;
    });
  }

  Future<void> _pickMonth() async {
    // Open a month-only picker dialog (year + month) instead of a full calendar.
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
          // Build a list of years (2000..current+5)
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
              TextButton(
                style: ButtonStyle(
                  foregroundColor: MaterialStateProperty.all(Colors.black),
                  overlayColor: MaterialStateProperty.all(Colors.black12),
                ),
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(AppColors.se),
                  foregroundColor: MaterialStateProperty.all(Colors.black),
                  overlayColor: MaterialStateProperty.all(Colors.black12),
                ),
                onPressed: () => Navigator.of(context).pop(DateTime(selectedYear, selectedMonth)),
                child: const Text('Apply'),
              ),
            ],
          );
        });
      },
    );

    if (picked != null) setState(() {
      // Make month selection exclusive: clear exact date
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

  Future<void> _handleSend(Map<String, dynamic> pendingItem, String parentDocId) async {
    // Find matching inventory item in 'raw_components' by name
    final name = (pendingItem['name'] ?? pendingItem['product'] ?? '').toString();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid item name')));
      return;
    }

    // Query inventory for exact name match
    final invQuery = await _firestore.collection('raw_components').where('name', isEqualTo: name).limit(1).get();
    if (invQuery.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No inventory record found for item')));
      return;
    }

    final invDoc = invQuery.docs.first;
    final availableRaw = invDoc.data()['quantity'];
    final available = (availableRaw is num) ? availableRaw.toDouble() : double.tryParse(availableRaw?.toString() ?? '0') ?? 0.0;

    final TextEditingController qtyController = TextEditingController();

    // Show a stateful dialog so we can display inline validation messages there
    String? inlineError;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(primary: Colors.black),
              ),
              child: AlertDialog(
                // Use default dialog background (remove custom color)
                title: Text('Send "$name"', style: const TextStyle(color: Colors.black)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Available qty: ${available.toString()}', style: const TextStyle(color: Colors.black)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Qty to send',
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (inlineError != null) ...[
                      const SizedBox(height: 8),
                      Text(inlineError!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    style: ButtonStyle(
                      foregroundColor: MaterialStateProperty.all(Colors.black),
                      overlayColor: MaterialStateProperty.all(Colors.black12),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(AppColors.se),
                      foregroundColor: MaterialStateProperty.all(Colors.black),
                      overlayColor: MaterialStateProperty.all(Colors.black12),
                    ),
                    onPressed: () {
                      final val = double.tryParse(qtyController.text.trim());
                      if (val == null || val <= 0) {
                        setStateDialog(() => inlineError = 'Enter a valid number');
                        return;
                      }
                      if (val > available) {
                        setStateDialog(() => inlineError = 'Entered qty is greater than available');
                        return;
                      }
                      Navigator.of(context).pop(true);
                    },
                    child: const Text('Send'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != true) return;

    final entered = double.tryParse(qtyController.text.trim()) ?? 0.0;

    final kitchenDocRef = _firestore.collection('kitchen_requests').doc(parentDocId);
    final invDocRef = invDoc.reference;

    // Prepare maps exactly like stored in Firestore for arrayRemove/arrayUnion
    final originalPendingMap = Map<String, dynamic>.from(pendingItem['rawMap'] ?? pendingItem);

    final nowIso = DateTime.now().toIso8601String();
    final sentMap = {
      ...originalPendingMap,
      'requestDate': originalPendingMap['date'] ?? originalPendingMap['requestDate'] ?? nowIso,
      'sentDate': nowIso,
      'sentQty': entered,
      'status': 'sent',
    };

    final newInvQty = (available - entered).clamp(0, double.infinity);

    final batch = _firestore.batch();
    batch.update(invDocRef, {'quantity': newInvQty});
    batch.update(kitchenDocRef, {
      'pending': FieldValue.arrayRemove([originalPendingMap]),
      'sent': FieldValue.arrayUnion([sentMap]),
    });

    try {
      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    }
  }

  Future<void> _deleteSent(Map<String, dynamic> sentItem, String parentDocId) async {
    final kitchenDocRef = _firestore.collection('kitchen_requests').doc(parentDocId);
    final original = Map<String, dynamic>.from(sentItem['rawMap'] ?? sentItem);
    try {
      await kitchenDocRef.update({'sent': FieldValue.arrayRemove([original])});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent item deleted')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete sent item: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffefafa),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SideBar(),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Gap(70),
                Center(
                  child: const Text(
                    "REQUEST ITEM",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.se,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _firestore.collection('kitchen_requests').orderBy('createdAt', descending: true).limit(1).snapshots(),
                      builder: (context, snap) {
                        if (snap.hasError) return const Center(child: Text('Error loading requests'));
                        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                        final docs = snap.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const Center(child: Text('No kitchen requests found'));
                        }

                        final doc = docs.first;
                        final data = doc.data();
                        final List pending = List.from(data['pending'] ?? []);
                        final List sent = List.from(data['sent'] ?? []);

                        // Build separate lists for pending and sent
                        final List<Map<String, dynamic>> pendingRows = [];
                        final List<Map<String, dynamic>> sentRows = [];

                        for (final p in pending) {
                          final dateStr = p['date'] ?? p['requestDate'];
                          DateTime? dt;
                          try {
                            dt = dateStr != null ? DateTime.parse(dateStr.toString()) : null;
                          } catch (_) {
                            dt = null;
                          }

                          // Apply filters: exact date takes precedence over month filter
                          if (_filterExactDate != null) {
                            if (dt == null) continue;
                            if (!(dt.year == _filterExactDate!.year && dt.month == _filterExactDate!.month && dt.day == _filterExactDate!.day)) continue;
                          } else if (_filterMonthYear != null) {
                            if (dt == null) continue;
                            if (!(dt.year == _filterMonthYear!.year && dt.month == _filterMonthYear!.month)) continue;
                          }

                          pendingRows.add({
                            'name': p['name'] ?? p['product'] ?? '',
                            'category': p['category'] ?? '',
                            'requestDate': dateStr ?? null,
                            'parentDoc': doc.id,
                            'rawMap': p,
                          });
                        }

                        for (final s in sent) {
                          final sentDateStr = s['sentDate'] ?? s['requestDate'];
                          DateTime? sdt;
                          try {
                            sdt = sentDateStr != null ? DateTime.parse(sentDateStr.toString()) : null;
                          } catch (_) {
                            sdt = null;
                          }

                          if (_filterExactDate != null) {
                            if (sdt == null) continue;
                            if (!(sdt.year == _filterExactDate!.year && sdt.month == _filterExactDate!.month && sdt.day == _filterExactDate!.day)) continue;
                          } else if (_filterMonthYear != null) {
                            if (sdt == null) continue;
                            if (!(sdt.year == _filterMonthYear!.year && sdt.month == _filterMonthYear!.month)) continue;
                          }

                          sentRows.add({
                            'name': s['name'] ?? s['product'] ?? '',
                            'category': s['category'] ?? '',
                            'requestDate': s['requestDate'] ?? null,
                            'sentDate': s['sentDate'] ?? null,
                            'qty': s['sentQty'] ?? null,
                            'parentDoc': doc.id,
                            'rawMap': s,
                          });
                        }

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Filter controls
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.se),
                                      onPressed: _pickExactDate,
                                      child: Text(_filterExactDate == null ? 'Filter by date' : 'Date: ${_filterExactDate!.year}-${_filterExactDate!.month.toString().padLeft(2,'0')}-${_filterExactDate!.day.toString().padLeft(2,'0')}' , style: TextStyle(color: AppColors.pr)),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.se),
                                      onPressed: _pickMonth,
                                      child: Text(_filterMonthYear == null ? 'Filter by month' : 'Month: ${_filterMonthYear!.year}-${_filterMonthYear!.month.toString().padLeft(2,'0')}' ,style: TextStyle(color: AppColors.pr))
                        ),
                                    if (_filterExactDate != null || _filterMonthYear != null) ...[
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: _clearFilters,
                                        child: const Text('Clear filters' , style: TextStyle(color: AppColors.pr))  ,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Pending table
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(minWidth: 300),
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          dataRowHeight: 40,
                                          headingRowHeight: 36,
                                          headingRowColor: MaterialStateProperty.all(const Color(0xfff6f6f6)),
                                          border: TableBorder.all(color: Colors.grey.shade300),
                                          columns: const [
                                            DataColumn(label: Text('Name')),
                                            DataColumn(label: Text('Category')),
                                            DataColumn(label: Text('Request Date')),
                                            DataColumn(label: Text('Status')),
                                            DataColumn(label: Text('Action')),
                                          ],
                                          rows: pendingRows.map((item) {
                                            return DataRow(cells: [
                                              DataCell(Text(item['name'] ?? '')),
                                              DataCell(Text(item['category'] ?? '')),
                                              DataCell(Text(_formatDate(item['requestDate']))),
                                              DataCell(const CircleAvatar(radius: 6, backgroundColor: Colors.red)),
                                              DataCell(ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                    backgroundColor: AppColors.se,
                                                    foregroundColor: Colors.white,
                                                    minimumSize: const Size(64, 32),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                                                onPressed: () => _handleSend(item, item['parentDoc']),
                                                child: const Text('Send', style: TextStyle(fontSize: 13)),
                                              )),
                                            ]);
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    // Sent table
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(minWidth: 420),
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          dataRowHeight: 40,
                                          headingRowHeight: 36,
                                          headingRowColor: MaterialStateProperty.all(const Color(0xfff6f6f6)),
                                          border: TableBorder.all(color: Colors.grey.shade300),
                                          columns: const [
                                            DataColumn(label: Text('Name')),
                                            DataColumn(label: Text('Category')),
                                            DataColumn(label: Text('Request Date')),
                                            DataColumn(label: Text('Sent Date')),
                                            DataColumn(label: Text('Qty')),
                                            DataColumn(label: Text('Status')),
                                            DataColumn(label: Text('Action')),
                                          ],
                                          rows: sentRows.map((item) {
                                            return DataRow(cells: [
                                              DataCell(Text(item['name'] ?? '')),
                                              DataCell(Text(item['category'] ?? '')),
                                              DataCell(Text(_formatDate(item['requestDate']))),
                                              DataCell(Text(_formatDate(item['sentDate']))),
                                              DataCell(Text(item['qty']?.toString() ?? '-')),
                                              DataCell(const CircleAvatar(radius: 6, backgroundColor: Colors.green)),
                                              DataCell(IconButton(
                                                onPressed: () => _deleteSent(item, item['parentDoc']),
                                                icon: const Icon(Icons.delete),
                                                color: AppColors.se,
                                              )),
                                            ]);
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}