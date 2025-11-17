import 'package:adminms/component/colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:gap/gap.dart';
import 'dart:math' show max, min, Random;
import 'dart:async';

import '../widget/side_bar.dart';
import '../widget/top_bar.dart';
import 'inventory_history.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage>
    with TickerProviderStateMixin {
  // control sidebar visibility (matches Dashboard pattern)
  bool isSidebarVisible = true;

  late TabController _tabController;
  late ValueNotifier<int> _selectedTabIndex;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final ValueNotifier<List<String>> categories = ValueNotifier<List<String>>([
    'All',
  ]);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  String? _selectedItemId;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  final TextEditingController _addNameController = TextEditingController();
  final TextEditingController _addCategoryController = TextEditingController();
  final TextEditingController _addQuantityController = TextEditingController();
  final TextEditingController _addUnitController = TextEditingController();
  final TextEditingController _addSupplierController = TextEditingController();
  final TextEditingController _addPriceController = TextEditingController();

  final Map<String, Map<String, dynamic>> _localDocs = {};

  // Validation error messages for edit panel
  String? _editNameError;
  String? _editQuantityError;
  String? _editUnitError;
  String? _editPriceError;
  String? _editSupplierError;

  // Validation error messages for add panel
  String? _addNameError;
  String? _addQuantityError;
  String? _addUnitError;
  String? _addPriceError;
  String? _addSupplierError;

  // Controls visibility of the Add panel (opened by FAB)
  bool _showAddPanel = false;
  // Controls whether the FAB's expanded options are visible
  bool _fabOpen = false;

  final Stream<QuerySnapshot<Map<String, dynamic>>> _rawStream =
      FirebaseFirestore.instance.collection('raw_components').snapshots();

  final Color primaryColor = const Color(0xff4a4a4a);
  final Color secondaryColor = const Color(0xff6fad99);

  // (previous tab tracking removed — not currently used)

  // Supplier cache for dropdown
  List<String> _supplierCache = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: max(1, categories.value.length),
      vsync: this,
    );
    _selectedTabIndex = ValueNotifier<int>(0);

    _tabController.addListener(() {
      final prev = _selectedTabIndex.value;
      if (_tabController.index != prev) {
        _selectedTabIndex.value = _tabController.index;
      }
    });

  _unitController.addListener(_onUnitControllerChanged);
  _addUnitController.addListener(_onAddUnitControllerChanged);
    categories.addListener(_onCategoriesChanged);

    _loadSuppliers();
  }

  void _onUnitControllerChanged() {
    // avoid calling setState during a build — schedule for next frame
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  void _onAddUnitControllerChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _loadSuppliers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('suppliers')
          .get();
      final names = snapshot.docs.map((doc) => doc['name'] as String).toList();
      setState(() {
        _supplierCache = names..sort();
      });
    } catch (e) {
      if (kDebugMode) print('Error loading suppliers: $e');
    }
  }

  Future<void> _saveSupplier(String name, String itemName) async {
    if (_supplierCache.contains(name)) return;

    final fakeEmail = '${name.toLowerCase().replaceAll(' ', '_')}@example.com';
    final fakePhone =
        '+1-${Random().nextInt(900) + 100}-${Random().nextInt(9000) + 1000}';

    await FirebaseFirestore.instance.collection('suppliers').add({
      'name': name,
      'email': fakeEmail,
      'phone': fakePhone,
      'suppliedItems': FieldValue.arrayUnion([itemName]),
    });

    _supplierCache.add(name);
    _supplierCache.sort();
  }

  @override
  void dispose() {
    _unitController.removeListener(_onUnitControllerChanged);
    _addUnitController.removeListener(_onAddUnitControllerChanged);
    categories.removeListener(_onCategoriesChanged);
    try {
      _tabController.dispose();
    } catch (_) {}
    _searchController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _supplierController.dispose();
    _priceController.dispose();
    _addNameController.dispose();
    _addCategoryController.dispose();
    _addQuantityController.dispose();
    _addUnitController.dispose();
    _addSupplierController.dispose();
    _addPriceController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onCategoriesChanged() {
    final newLen = max(1, categories.value.length);
    final currentIndex = _selectedTabIndex.value;
    final safeIndex = (currentIndex >= 0) ? min(currentIndex, newLen - 1) : 0;

    try {
      _tabController.dispose();
    } catch (_) {}

    _tabController = TabController(
      length: newLen,
      vsync: this,
      initialIndex: safeIndex,
    );
    _tabController.addListener(() {
      final prev = _selectedTabIndex.value;
      if (_tabController.index != prev) {
        _selectedTabIndex.value = _tabController.index;
      }
    });

    _selectedTabIndex.value = _tabController.index;
    setState(() {});
  }

  void _onSidebarSelect(String category) {
    final norm = category
        .toLowerCase()
        .replaceAll(RegExp(r"\s+|_|-|/|&"), ' ')
        .trim();
    final idx = categories.value.indexWhere(
      (t) =>
          t.toLowerCase().replaceAll(RegExp(r"\s+|_|-|/|&"), ' ').trim() ==
          norm,
    );
    if (idx >= 0) {
      final safeIdx = idx.clamp(0, max(0, _tabController.length - 1)).toInt();
      _tabController.index = safeIdx;
    } else {
      final existing = [...categories.value];
      existing.removeWhere((e) => e.toLowerCase() == 'all');
      final lowerSet = existing.map((e) => e.toLowerCase()).toSet();
      if (!lowerSet.contains(category.toLowerCase())) existing.add(category);
      existing.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      final newList = ['All', ...existing];

      categories.value = newList;
      final newIndex = newList.indexWhere(
        (t) => t.toLowerCase() == category.toLowerCase(),
      );

      final oldController = _tabController;
      try {
        oldController.dispose();
      } catch (_) {}

      final safeInitial = (newIndex >= 0)
          ? min(newIndex, newList.length - 1)
          : 0;
      _tabController = TabController(
        length: newList.length,
        vsync: this,
        initialIndex: safeInitial,
      );
      _tabController.addListener(() {
        final prev = _selectedTabIndex.value;
        if (_tabController.index != prev) {
          _selectedTabIndex.value = _tabController.index;
        }
      });

      _selectedTabIndex.value = _tabController.index;
      setState(() {});
    }
  }

  void _onSearchChanged(String v) {
    // Debounce the search to avoid frequent rebuilds while the user types
    _searchDebounce?.cancel();
    final pending = v;
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = pending.toLowerCase();
      });
    });
  }

  double _parseQuantity(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is int) return raw.toDouble();
    if (raw is double) return raw;
    final s = raw.toString();
    final doubleVal = double.tryParse(s);
    if (doubleVal != null) return doubleVal;
    final intVal = int.tryParse(s);
    return intVal?.toDouble() ?? 0.0;
  }

  Future<void> _saveItem() async {
    if (_selectedItemId == null) {
      if (kDebugMode) print('No item selected');
      return;
    }

    final name = _nameController.text.trim();
    final category = _categoryController.text.trim();
    final supplier = _supplierController.text.trim();
    final unit = _unitController.text.trim();
    final priceText = _priceController.text.trim();
    final price = double.tryParse(priceText);

    // Clear previous errors
    setState(() {
      _editNameError = null;
      _editQuantityError = null;
      _editUnitError = null;
      _editPriceError = null;
      _editSupplierError = null;
    });

    // Basic validations
    if (name.isEmpty) {
      setState(() { _editNameError = 'Name is required'; });
      return;
    }
    // allow letters and spaces only
      if (!RegExp(r'^[A-Za-z ]+$').hasMatch(name)) {
      setState(() { _editNameError = 'Use English letters and spaces only'; });
      return;
    }
    if (category.isEmpty) {
      if (kDebugMode) print('Category is required');
      return;
    }
    if (supplier.isEmpty) {
      setState(() { _editSupplierError = 'Supplier is required'; });
      return;
    }
    if (unit.isEmpty || !(unit == 'kg' || unit == 'liter')) {
      setState(() { _editUnitError = 'Unit must be kg or liter'; });
      return;
    }
    if (price == null) {
      setState(() { _editPriceError = 'Enter a valid price'; });
      return;
    }

    final quantityText = _quantityController.text.trim();
    double? quantity;
    if (quantityText.isNotEmpty) {
      final doubleVal = double.tryParse(quantityText);
      if (doubleVal != null) {
        quantity = doubleVal;
      } else {
        setState(() { _editQuantityError = 'Invalid quantity'; });
        return;
      }
    }

    final data = {
      'name': name,
      'category': category,
      'quantity':
          quantity ?? _parseQuantity(_localDocs[_selectedItemId!]?['quantity'] ?? 0.0),
      'unit': unit,
      'supplier': supplier,
      'price': price,
      'pricePerUnit': '$price/$unit',
    };

    _localDocs[_selectedItemId!] = {...data, 'id': _selectedItemId!};
    setState(() {});

    try {
      await FirebaseFirestore.instance
          .collection('raw_components')
          .doc(_selectedItemId!)
          .update(data);

      await _saveSupplier(supplier, name);

      if (kDebugMode) print('Item saved');
      _clearSelection();
    } catch (e) {
      if (kDebugMode) print('Save failed: $e');
    }
  }

  Future<void> _saveNewItem() async {
    final name = _addNameController.text.trim();
    final category = _addCategoryController.text.trim();
    final supplier = _addSupplierController.text.trim();
    final unit = _addUnitController.text.trim();
    final priceText = _addPriceController.text.trim();
    final price = double.tryParse(priceText);

    // Clear previous errors
    setState(() {
      _addNameError = null;
      _addQuantityError = null;
      _addUnitError = null;
      _addPriceError = null;
      _addSupplierError = null;
    });

    if (name.isEmpty) {
      setState(() { _addNameError = 'Name is required'; });
      return;
    }
    if (!RegExp(r'^[A-Za-z ]+$').hasMatch(name)) {
      setState(() { _addNameError = 'Use English letters and spaces only'; });
      return;
    }
    if (category.isEmpty) {
      if (kDebugMode) print('Category is required');
      return;
    }
    if (supplier.isEmpty) {
      setState(() { _addSupplierError = 'Supplier is required'; });
      return;
    }
    if (unit.isEmpty || !(unit == 'kg' || unit == 'liter')) {
      setState(() { _addUnitError = 'Unit must be kg or liter'; });
      return;
    }
    if (price == null) {
      setState(() { _addPriceError = 'Enter a valid price'; });
      return;
    }

    final quantityText = _addQuantityController.text.trim();
    double quantity = 0.0;
    if (quantityText.isNotEmpty) {
      final doubleVal = double.tryParse(quantityText);
      if (doubleVal != null) {
        quantity = doubleVal;
      } else {
        setState(() { _addQuantityError = 'Invalid quantity'; });
        return;
      }
    }

    final data = {
      'name': name,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'supplier': supplier,
      'price': price,
      'pricePerUnit': '$price/$unit',
    };

    final tempId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    _localDocs[tempId] = {...data, 'id': tempId};
    setState(() {});

    try {
      final ref = await FirebaseFirestore.instance
          .collection('raw_components')
          .add(data);
      final realId = ref.id;

      final stored = {...?_localDocs[tempId], 'id': realId};
      _localDocs.remove(tempId);
      _localDocs[realId] = stored;
      setState(() {});

      await _saveSupplier(supplier, name);

      if (kDebugMode) print('Item added');
      _clearAddForm();
    } catch (e) {
      _localDocs.remove(tempId);
      setState(() {});
      if (kDebugMode) print('Add failed: $e');
    }
  }

  Future<void> _showAddQuantityDialog(
    String? id,
    Map<String, dynamic> item,
  ) async {
    if (id == null) return;

    final TextEditingController qtyController = TextEditingController();
    final TextEditingController priceController = TextEditingController(text: item['price']?.toString() ?? '');
    String selectedSupplier = (item['supplier'] ?? '').toString();
    bool sameSupplierAndPrice = true;

    final result = await showDialog<bool?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Add Quantity'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: qtyController,
                    decoration: const InputDecoration(
                      hintText: 'Enter quantity to add (e.g., 5 or 2.5)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Same supplier and price'),
                    value: sameSupplierAndPrice,
                    onChanged: (v) => setStateDialog(() => sameSupplierAndPrice = v ?? true),
                  ),
                  if (!sameSupplierAndPrice) ...[
                    const SizedBox(height: 8),
                    // supplier dropdown
                    DropdownButtonFormField<String>(
                      value: selectedSupplier.isNotEmpty && _supplierCache.contains(selectedSupplier) ? selectedSupplier : null,
                      items: _supplierCache.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setStateDialog(() => selectedSupplier = v ?? ''),
                      decoration: const InputDecoration(labelText: 'Supplier', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'Price', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
                  TextButton(
                onPressed: () {
                  final text = qtyController.text.trim();
                  final v = double.tryParse(text);
                  if (v == null) {
                    // show a blocking dialog for validation message instead of a snackbar
                    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Invalid input'), content: const Text('Enter a valid number'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))]));
                    return;
                  }

                  if (!sameSupplierAndPrice) {
                    if (selectedSupplier.isEmpty) {
                      showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Missing supplier'), content: const Text('Select a supplier'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))]));
                      return;
                    }
                    final pText = priceController.text.trim();
                    if (pText.isEmpty || double.tryParse(pText) == null) {
                      showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Invalid price'), content: const Text('Enter a valid price'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))]));
                      return;
                    }
                  }

                  // return true to indicate submit
                  Navigator.of(context).pop(true);
                },
                child: const Text('Add' ,style: TextStyle(color: AppColors.pr)),
              ),
            ],
          );
        });
      },
    );

    if (result != true) return;

  // parse quantity
  final qtyText = qtyController.text.trim();
  final qtyDouble = double.tryParse(qtyText);
  if (qtyDouble == null) return;
  final double added = qtyDouble;

  final current = _parseQuantity(item['quantity']);
  final newQty = current + added;

    // prepare history data
    final oldPrice = (item['price'] != null) ? double.tryParse(item['price'].toString()) : null;
    final oldSupplier = (item['supplier'] ?? '').toString();
    final newSupplier = sameSupplierAndPrice ? oldSupplier : selectedSupplier;
    final newPrice = sameSupplierAndPrice ? oldPrice : double.tryParse(priceController.text.trim());

    // optimistic local update
    _localDocs[id] = {...item, 'quantity': newQty, 'id': id, 'supplier': newSupplier, 'price': newPrice};
    setState(() {});

    if (id.startsWith('local_')) {
      if (kDebugMode) print('Quantity updated (local)');
      return;
    }

    try {
      final updates = <String, dynamic>{'quantity': newQty};
      if (!sameSupplierAndPrice) {
        if (newSupplier.isNotEmpty) updates['supplier'] = newSupplier;
        if (newPrice != null) updates['price'] = newPrice;
      }


  await FirebaseFirestore.instance.collection('raw_components').doc(id).update(updates);

      // write inventory history
      await FirebaseFirestore.instance.collection('inventory_history').add({
        'itemId': id,
        'itemName': item['name'] ?? '',
        'oldSupplier': oldSupplier,
        'newSupplier': newSupplier,
        'sameSupplier': sameSupplierAndPrice,
        'oldPrice': oldPrice,
        'newPrice': newPrice,
        'addedQuantity': added,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) print('Quantity updated');
    } catch (e) {
      // revert local change on failure
      _localDocs.remove(id);
      setState(() {});
      if (kDebugMode) print('Failed to update quantity: $e');
    }
  }

  void _clearAddForm() {
    // Clear fields and hide the add panel
    _clearAddFormFields();
    setState(() {
      _showAddPanel = false;
    });
  }

  void _clearAddFormFields() {
    _addNameController.clear();
    _addCategoryController.clear();
    _addQuantityController.clear();
    _addUnitController.clear();
    _addSupplierController.clear();
    _addPriceController.clear();
  }

  void _clearSelection() {
    _selectedItemId = null;
    _nameController.clear();
    _categoryController.clear();
    _quantityController.clear();
    _unitController.clear();
    _supplierController.clear();
    _priceController.clear();
    _selectedTabIndex.value = _selectedTabIndex.value;
    setState(() {});
  }

  Widget _buildSupplierField(
    TextEditingController controller, {
    bool isAdd = false,
  }) {
    // Autocomplete text field that filters _supplierCache as the user types.
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return const Iterable<String>.empty();
        return _supplierCache.where((s) => s.toLowerCase().startsWith(query));
      },
      displayStringForOption: (opt) => opt,
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        // Synchronously sync the internal textController from the external
        // controller only when the field is NOT focused to avoid clobbering
        // user input while they're typing. Use synchronous copy so we don't
        // schedule async callbacks that may run later and overwrite user input.
        if (!focusNode.hasFocus && textController.text != controller.text) {
          textController.text = controller.text;
          textController.selection = TextSelection.fromPosition(TextPosition(offset: textController.text.length));
        }

        return TextField(
          controller: textController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Supplier *',
            border: const OutlineInputBorder(),
          ),
          onChanged: (val) {
            // Keep the external controller in sync by copying the full
            // TextEditingValue (preserves selection) from the internal
            // textController. This avoids resetting the cursor/selection.
            controller.value = textController.value;
            if (isAdd) {
              if (_addSupplierError != null) setState(() { _addSupplierError = null; });
            } else {
              if (_editSupplierError != null) setState(() { _editSupplierError = null; });
            }
          },
        );
      },
      onSelected: (selection) {
        // Preserve selection/cursor by setting a TextEditingValue.
        controller.value = TextEditingValue(text: selection, selection: TextSelection.collapsed(offset: selection.length));
      },
    );
  }

  Widget editPanel() {
    return SizedBox(
      width: 420,
      child: Container(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Item',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name *'),
              onChanged: (_) => setState(() { _editNameError = null; }),
            ),
            if (_editNameError != null) ...[
              const SizedBox(height: 6),
              Text(_editNameError!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: (_categoryController.text.isNotEmpty && categories.value.where((t) => t.toLowerCase() != 'all').any((t) => t == _categoryController.text))
                  ? _categoryController.text
                  : null,
              items: categories.value.where((t) => t.toLowerCase() != 'all').map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => _categoryController.text = v ?? '',
              decoration: const InputDecoration(labelText: 'Category *'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity *',
                      hintText: 'e.g., 5 or 5.5',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    // only set value if it matches one of the available items to avoid
                    // DropdownButton assertion failures when the controller contains
                    // an unexpected string
                    value: ['kg', 'liter'].contains(_unitController.text) ? _unitController.text : null,
                    items: ['kg', 'liter']
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) {
                      _unitController.text = v ?? '';
                      setState(() { _editUnitError = null; });
                    },
                    decoration: const InputDecoration(labelText: 'Unit *'),
                  ),
                ),
              ],
            ),
            if (_editQuantityError != null) ...[
              const SizedBox(height: 6),
              Text(_editQuantityError!, style: const TextStyle(color: Colors.red)),
            ],
            if (_editUnitError != null) ...[
              const SizedBox(height: 6),
              Text(_editUnitError!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 8),
            _buildSupplierField(_supplierController),
            if (_editSupplierError != null) ...[
              const SizedBox(height: 6),
              Text(_editSupplierError!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 8),
            ValueListenableBuilder(
              valueListenable: _unitController,
              builder: (context, unit, _) {
                return TextField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    labelText:
                        'Price/${unit.text.isNotEmpty ? unit.text : "unit"} *',
                    hintText: 'e.g., 12.50',
                    suffixText: _unitController.text.isNotEmpty
                        ? '/${_unitController.text}'
                        : '/unit',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                );
              },
            ),
            if (_editPriceError != null) ...[
              const SizedBox(height: 6),
              Text(_editPriceError!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: secondaryColor,
                  ),
                  onPressed: _saveItem,
                  icon: const Icon(Icons.save , color : AppColors.pr),
                  label: const Text('Save' , style : TextStyle(color : AppColors.pr)),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _clearSelection,
                  child: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showHistoryDialog(_selectedItemId),
                  icon: const Icon(Icons.history ,color : AppColors.pr),
                  label: const Text('History' , style: TextStyle(color : AppColors.pr),),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget addPanel() {
    return SizedBox(
      width: 420,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Item',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addNameController,
              decoration: const InputDecoration(labelText: 'Name *'),
              onChanged: (_) => setState(() { _addNameError = null; }),
            ),
            if (_addNameError != null) ...[
              const SizedBox(height: 6),
              Text(_addNameError!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: (_addCategoryController.text.isNotEmpty && categories.value.where((t) => t.toLowerCase() != 'all').any((t) => t == _addCategoryController.text))
                  ? _addCategoryController.text
                  : null,
              items: categories.value
                  .where((t) => t.toLowerCase() != 'all')
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => _addCategoryController.text = v ?? '',
              decoration: const InputDecoration(labelText: 'Category *'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addQuantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity *',
                      hintText: 'e.g., 5 or 5.5',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: ['kg', 'liter'].contains(_addUnitController.text) ? _addUnitController.text : null,
                    items: ['kg', 'liter'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) { _addUnitController.text = v ?? ''; setState(() { _addUnitError = null; }); },
                    decoration: const InputDecoration(labelText: 'Unit *'),
                  ),
                ),
              ],
            ),
            if (_addQuantityError != null) ...[
              const SizedBox(height: 6),
              Text(_addQuantityError!, style: const TextStyle(color: Colors.red)),
            ],
            if (_addUnitError != null) ...[
              const SizedBox(height: 6),
              Text(_addUnitError!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 8),
            _buildSupplierField(_addSupplierController, isAdd: true),
            if (_addSupplierError != null) ...[
              const SizedBox(height: 6),
              Text(_addSupplierError!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 8),
            ValueListenableBuilder(
              valueListenable: _addUnitController,
              builder: (context, unit, _) {
                return TextField(
                  controller: _addPriceController,
                  decoration: InputDecoration(
                    labelText:
                        'Price/${unit.text.isNotEmpty ? unit.text : "unit"} *',
                    hintText: 'e.g., 12.50',
                    suffixText: _addUnitController.text.isNotEmpty
                        ? '/${_addUnitController.text}'
                        : '/unit',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                );
              },
            ),
            if (_addPriceError != null) ...[
              const SizedBox(height: 6),
              Text(_addPriceError!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _saveNewItem,
                  icon: const Icon(Icons.add , color : AppColors.pr),
                  label: const Text('Add' , style : TextStyle(color : AppColors.pr) ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: secondaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _clearAddForm,
                  child: const Text('Clear' , style: TextStyle(color : AppColors.pr) ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showHistoryDialog(String? itemId) async {
    // If itemId is provided, show only that item's history; otherwise show all recent history
  // Open the inventory history page which displays the same content inside a container
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => InventoryHistoryPage(itemId: itemId)));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Ensure sidebar is always visible. On very narrow screens use a compact width.
    final bool isCompact = screenWidth < 700; // compact mode for small screens
    final bool isTablet = screenWidth < 1000 && screenWidth >= 700;
    final double sidebarWidth = isCompact ? 120 : (isTablet ? 180 : 220);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF9F9F9),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Expanded mini actions (visible when _fabOpen == true)
          AnimatedOpacity(
            opacity: _fabOpen ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 180),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // History with label
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
                        ],
                      ),
                      child: const Text('History', style: TextStyle(color: Colors.black87)),
                    ),
                    FloatingActionButton(
                      mini: true,
                      heroTag: 'history_fab',
                      backgroundColor: secondaryColor,
                      onPressed: () {
                        setState(() {
                          _fabOpen = false;
                        });
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => InventoryHistoryPage(itemId: _selectedItemId)));
                      },
                      child: const Icon(Icons.history, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Add with label
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
                        ],
                      ),
                      child: const Text('Add', style: TextStyle(color: Colors.black87)),
                    ),
                    FloatingActionButton(
                      mini: true,
                      heroTag: 'add_fab',
                      backgroundColor: secondaryColor,
                      onPressed: () {
                        setState(() {
                          _fabOpen = false;
                          _clearSelection();
                          _clearAddFormFields();
                          _showAddPanel = true;
                        });
                      },
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          FloatingActionButton(
            backgroundColor: secondaryColor,
            onPressed: () {
              setState(() {
                _fabOpen = !_fabOpen;
              });
            },
            child: Icon(_fabOpen ? Icons.close : Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar with animated collapse (matches Dashboard style)
          if (isSidebarVisible)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: sidebarWidth,
              child: SideBar(
                currentPage: 'Inventory',
                onCategorySelect: _onSidebarSelect,
              ),
            )
          else
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 0,
              child: const SizedBox(),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Gap(70),
                            AppTopBar(
                              isSidebarVisible: isSidebarVisible,
                              onToggle: () => setState(() => isSidebarVisible = !isSidebarVisible),
                              title: 'Inventory',
                              iconColor: AppColors.se,
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextField(
                                controller: _searchController,
                                onChanged: _onSearchChanged,
                                decoration: InputDecoration(
                                  hintText: 'Search by name or category...',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ValueListenableBuilder<List<String>>(
                                valueListenable: categories,
                                builder: (context, categoryList, _) {
                                  return ValueListenableBuilder<int>(
                                    valueListenable: _selectedTabIndex,
                                    builder: (context, selectedIdx, _) {
                                      return SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: List.generate(
                                            categoryList.length,
                                            (i) {
                                              final selected = selectedIdx == i;
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 8,
                                                ),
                                                child: InkWell(
                                                  onTap: () {
                                                    final safeI = i
                                                        .clamp(
                                                          0,
                                                          max(
                                                            0,
                                                            _tabController
                                                                    .length -
                                                                1,
                                                          ),
                                                        )
                                                        .toInt();
                                                    _tabController.index =
                                                        safeI;
                                                  },
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 8,
                                                          horizontal: 16,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: selected
                                                          ? secondaryColor
                                                          : Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                      border: Border.all(
                                                        color: selected
                                                            ? secondaryColor
                                                            : Colors
                                                                  .grey
                                                                  .shade300,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      categoryList[i],
                                                      style: TextStyle(
                                                        color: selected
                                                            ? Colors.white
                                                            : primaryColor,
                                                        fontWeight: selected
                                                            ? FontWeight.w600
                                                            : FontWeight.w400,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            Expanded(
                              child: ValueListenableBuilder<int>(
                                valueListenable: _selectedTabIndex,
                                builder: (context, selectedIndex, _) {
                                  return StreamBuilder<
                                    QuerySnapshot<Map<String, dynamic>>
                                  >(
                                    stream: _rawStream,
                                    builder: (context, snapshot) {
                                      final allDocs = snapshot.data?.docs ?? [];
                                      final firestoreDocs = {
                                        for (var d in allDocs)
                                          d.id: {...d.data(), 'id': d.id},
                                      };
                                      final merged = {
                                        ...firestoreDocs,
                                        ..._localDocs,
                                      };
                                      List<Map<String, dynamic>> filteredDocs =
                                          merged.values.toList();

                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            final uniqueCategories = {'All'};
                                            for (final doc in filteredDocs) {
                                              final category =
                                                  (doc['category'] ?? '')
                                                      .toString();
                                              if (category.isNotEmpty)
                                                uniqueCategories.add(category);
                                            }
                                            final tmp = uniqueCategories
                                                .toList();
                                            tmp.removeWhere(
                                              (e) => e.toLowerCase() == 'all',
                                            );
                                            tmp.sort();
                                            final newCategories = [
                                              'All',
                                              ...tmp,
                                            ];
                                            if (!listEquals(
                                              categories.value,
                                              newCategories,
                                            )) {
                                              categories.value = newCategories;
                                            }
                                          });

                                      if (selectedIndex > 0 &&
                                          selectedIndex <
                                              categories.value.length) {
                                        final normSelected = categories
                                            .value[selectedIndex]
                                            .toLowerCase()
                                            .replaceAll(
                                              RegExp(r"\s+|_|-|/|&"),
                                              ' ',
                                            )
                                            .trim();
                                        filteredDocs = filteredDocs.where((
                                          data,
                                        ) {
                                          final rawCat =
                                              (data['category'] ?? '')
                                                  .toString();
                                          final normRaw = rawCat
                                              .toLowerCase()
                                              .replaceAll(
                                                RegExp(r"\s+|_|-|/|&"),
                                                ' ',
                                              )
                                              .trim();
                                          return normRaw == normSelected;
                                        }).toList();
                                      }

                                      if (_searchQuery.isNotEmpty) {
                                        filteredDocs = filteredDocs.where((
                                          item,
                                        ) {
                                          final name = (item['name'] ?? '')
                                              .toString()
                                              .toLowerCase();
                                          final category =
                                              (item['category'] ?? '')
                                                  .toString()
                                                  .toLowerCase();
                                          return name.contains(_searchQuery) ||
                                              category.contains(_searchQuery);
                                        }).toList();
                                      }

                                      // sort descending by quantity so table shows highest qty first
                                      filteredDocs.sort((a, b) => _parseQuantity(b['quantity']).compareTo(_parseQuantity(a['quantity'])));
                                      if (filteredDocs.isEmpty) {
                                        return const Center(
                                          child: Text('No items found.'),
                                        );
                                      }
                                      final dataRows = filteredDocs.map((item) {
                                        final id = item['id']?.toString();
                                        final displayed = {...item};
                                        final quantityVal = _parseQuantity(
                                          displayed['quantity'],
                                        );
                                        return DataRow(
                                          selected: _selectedItemId == id,
                                          cells: [
                                            DataCell(
                                              Text(displayed['category'] ?? ''),
                                            ),
                                            DataCell(
                                              Text(displayed['name'] ?? ''),
                                            ),
                                            DataCell(
                                              Text(
                                                displayed['quantity']
                                                        ?.toString() ??
                                                    '',
                                              ),
                                            ),
                                            DataCell(
                                              Text(displayed['unit'] ?? ''),
                                            ),
                                            DataCell(
                                              Text(displayed['supplier'] ?? ''),
                                            ),
                                            DataCell(
                                              Text(
                                                displayed['price'] != null
                                                    ? '\$${(displayed['price'] is num ? (displayed['price'] as num).toStringAsFixed(2) : double.tryParse(displayed['price'].toString())?.toStringAsFixed(2) ?? '0.00')}/${displayed['unit'] ?? 'unit'}'
                                                    : '\$0.00/${displayed['unit'] ?? 'unit'}',
                                              ),
                                            ),
                                            DataCell(
                                              CircleAvatar(
                                                radius: 8,
                                                backgroundColor:
                                                    quantityVal <= 5.0
                                                    ? Colors.red
                                                    : (quantityVal <= 10.0
                                                          ? Colors.yellow[700]!
                                                          : Colors.green),
                                              ),
                                            ),
                                            DataCell(
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.add_circle,
                                                  size: 18,
                                                  color: Color(0xff4a4a4a),
                                                ),
                                                tooltip: 'Add quantity',
                                                onPressed: () =>
                                                    _showAddQuantityDialog(
                                                      id,
                                                      displayed,
                                                    ),
                                              ),
                                            ),
                                            DataCell(
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit,
                                                  size: 18,
                                                ),
                                                onPressed: () {
                                                  _selectedItemId = id;
                                                  _nameController.text =
                                                      displayed['name'] ?? '';
                                                  _categoryController.text =
                                                      displayed['category'] ??
                                                      '';
                                                  _quantityController.text =
                                                      displayed['quantity']
                                                          ?.toString() ??
                                                      '';
                                                  _unitController.text =
                                                      displayed['unit'] ?? '';
                                                  _supplierController.text =
                                                      displayed['supplier'] ??
                                                      '';
                                                  _priceController.text =
                                                      displayed['price'] is num
                                                      ? (displayed['price']
                                                                as num)
                                                            .toStringAsFixed(2)
                                                      : '0.00';
                                                  setState(() {});
                                                },
                                              ),
                                            ),
                                          ],
                                          onSelectChanged: (sel) {
                                            if (sel == true) {
                                              _selectedItemId = id;
                                              _nameController.text =
                                                  displayed['name'] ?? '';
                                              _categoryController.text =
                                                  displayed['category'] ?? '';
                                              _quantityController.text =
                                                  displayed['quantity']
                                                      ?.toString() ??
                                                  '';
                                              _unitController.text =
                                                  displayed['unit'] ?? '';
                                              _supplierController.text =
                                                  displayed['supplier'] ?? '';
                                              _priceController.text =
                                                  displayed['price'] is num
                                                  ? (displayed['price'] as num)
                                                        .toStringAsFixed(2)
                                                  : '0.00';
                                              setState(() {});
                                            }
                                          },
                                        );
                                      }).toList();

                                      return SingleChildScrollView(
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minHeight: constraints.maxHeight,
                                            minWidth: constraints.maxWidth,
                                          ),
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: DataTable(
                                              headingRowColor:
                                                  MaterialStateProperty.all(
                                                    Colors.grey[200],
                                                  ),
                                              border: TableBorder.all(
                                                color: Colors.grey.shade300,
                                              ),
                                              columns: const [
                                                DataColumn(
                                                  label: Text('Category'),
                                                ),
                                                DataColumn(label: Text('Name')),
                                                DataColumn(label: Text('Qty')),
                                                DataColumn(label: Text('Unit')),
                                                DataColumn(
                                                  label: Text('Supplier'),
                                                ),
                                                DataColumn(
                                                  label: Text('Price/Unit'),
                                                ),
                                                DataColumn(
                                                  label: Text('Status'),
                                                ),
                                                DataColumn(
                                                  label: Text('Add Qty'),
                                                ),
                                                DataColumn(label: Text('Edit')),
                                              ],
                                              rows: dataRows,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 420,
                    child: Column(
                      children: [
                        Gap(150),
                        // Edit panel is hidden until an item is selected (pen clicked)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _selectedItemId != null
                              ? editPanel()
                              : SizedBox(
                                  key: const ValueKey('empty_edit_panel'),
                                  height: 0,
                                ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _showAddPanel
                              ? addPanel()
                              : SizedBox(
                                  key: const ValueKey('empty_add_panel'),
                                  height: 0,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}