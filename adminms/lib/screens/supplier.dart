import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// foundation not used here
import 'package:gap/gap.dart';
import '../widget/side_bar.dart';
import '../widget/top_bar.dart';

class SupplierPage extends StatefulWidget {
  const SupplierPage({super.key});

  @override
  State<SupplierPage> createState() => _SupplierPageState();
}

class _SupplierPageState extends State<SupplierPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // control sidebar visibility like Dashboard
  bool isSidebarVisible = true;

  // controllers for edit
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // add controllers
  final TextEditingController _addNameController = TextEditingController();
  final TextEditingController _addEmailController = TextEditingController();
  final TextEditingController _addPhoneController = TextEditingController();
  final TextEditingController _addAddressController = TextEditingController();

  // search
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  String? _selectedSupplierId;
  bool _showAddPanel = false;

  final Color primaryColor = const Color(0xff4a4a4a);
  final Color secondaryColor = const Color(0xff6fad99);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _addNameController.dispose();
    _addEmailController.dispose();
    _addPhoneController.dispose();
    _addAddressController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _clearSelection() {
    _selectedSupplierId = null;
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _addressController.clear();
    setState(() {});
  }

  void _clearAddForm() {
    _addNameController.clear();
    _addEmailController.clear();
    _addPhoneController.clear();
    _addAddressController.clear();
    setState(() {
      _showAddPanel = false;
    });
  }

  Future<void> _saveSupplier() async {
    if (_selectedSupplierId == null) return;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }

    final data = {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore.collection('suppliers').doc(_selectedSupplierId).update(data);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supplier saved')));
      _clearSelection();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _addNewSupplier() async {
    final name = _addNameController.text.trim();
    final email = _addEmailController.text.trim();
    final phone = _addPhoneController.text.trim();
    final address = _addAddressController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }

    final data = {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'createdAt': FieldValue.serverTimestamp(),
      'suppliedItems': [],
    };

    try {
      await _firestore.collection('suppliers').add(data);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supplier added')));
      _clearAddForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Add failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isCompact = screenWidth < 700;
    final bool isTablet = screenWidth < 1000 && screenWidth >= 700;
    final double sidebarWidth = isCompact ? 120 : (isTablet ? 180 : 220);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF9F9F9),
      floatingActionButton: FloatingActionButton(
        backgroundColor: secondaryColor,
        onPressed: () {
          setState(() {
            _clearSelection();
            _addNameController.clear();
            _addEmailController.clear();
            _addPhoneController.clear();
            _addAddressController.clear();
            _showAddPanel = true;
          });
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isSidebarVisible ? sidebarWidth : 0,
            child: isSidebarVisible ? SideBar(currentPage: 'Supplier', onCategorySelect: (cat) {}) : const SizedBox.shrink(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                //  const SizedBox(height: 8),
                  const Gap(70),
                  AppTopBar(
                    isSidebarVisible: isSidebarVisible,
                    onToggle: () => setState(() => isSidebarVisible = !isSidebarVisible),
                    title: 'Suppliers',
                    iconColor: primaryColor,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 420,
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search by name, phone, email or address',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (v) {
                        setState(() {
                          _search = v.trim().toLowerCase();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _firestore.collection('suppliers').orderBy('name').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return const Center(child: Text('Error loading suppliers'));
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                        final docs = snapshot.data!.docs;
                        final filtered = docs.where((d) {
                          if (_search.isEmpty) return true;
                          final data = d.data();
                          final contact = (data['contact'] is Map) ? Map<String, dynamic>.from(data['contact'] as Map) : null;
                          final name = (data['name'] ?? '').toString().toLowerCase();
                          final phone = (data['phone'] ?? contact?['phone'] ?? '').toString().toLowerCase();
                          final email = (data['email'] ?? contact?['email'] ?? '').toString().toLowerCase();
                          final address = (data['address'] ?? contact?['address'] ?? '').toString().toLowerCase();
                          return name.contains(_search) || phone.contains(_search) || email.contains(_search) || address.contains(_search);
                        }).toList();

                        if (filtered.isEmpty) return const Center(child: Text('No suppliers found'));

                        final rows = filtered.map((d) {
                          final data = d.data();
                          final id = d.id;
                          final contact = (data['contact'] is Map) ? Map<String, dynamic>.from(data['contact'] as Map) : null;
                          final phone = (data['phone'] ?? contact?['phone'] ?? '').toString();
                          final email = (data['email'] ?? contact?['email'] ?? '').toString();
                          final address = (data['address'] ?? contact?['address'] ?? '').toString();
                          final items = (data['suppliedItems'] as List?)?.cast<String>() ?? [];
                          return DataRow(
                            selected: _selectedSupplierId == id,
                            onSelectChanged: (sel) {
                              if (sel == true) {
                                _selectedSupplierId = id;
                                _nameController.text = data['name'] ?? '';
                                _emailController.text = email;
                                _phoneController.text = phone;
                                _addressController.text = address;
                                setState(() {});
                              }
                            },
                            cells: [
                              DataCell(Text(data['name'] ?? '')),
                              DataCell(Text(phone)),
                              DataCell(Text(email)),
                              DataCell(Text(address)),
                              DataCell(Text(items.join(', '))),
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () {
                                      _selectedSupplierId = id;
                                      _nameController.text = data['name'] ?? '';
                                      _emailController.text = data['email'] ?? '';
                                      _phoneController.text = data['phone'] ?? '';
                                      _addressController.text = data['address'] ?? '';
                                      setState(() {});
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: const Text('Delete supplier'),
                                          content: const Text('Are you sure?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
                                            TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await _firestore.collection('suppliers').doc(id).delete();
                                        if (_selectedSupplierId == id) _clearSelection();
                                      }
                                    },
                                  ),
                                ],
                              )),
                            ],
                          );
                        }).toList();

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
                                    border: TableBorder.all(color: Colors.grey.shade300),
                                    columns: const [
                                      DataColumn(label: Text('Name')),
                                      DataColumn(label: Text('Phone')),
                                      DataColumn(label: Text('Email')),
                                      DataColumn(label: Text('Address')),
                                      DataColumn(label: Text('Supplied Items')),
                                      DataColumn(label: Text('Actions')),
                                    ],
                                    rows: rows,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 420,
                              child: Column(
                                children: [
                                  Gap(150),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    child: _selectedSupplierId != null ? _editPanel() : const SizedBox.shrink(),
                                  ),
                                  const SizedBox(height: 12),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    child: _showAddPanel ? _addPanel() : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
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

  Widget _editPanel() {
    return SizedBox(
      width: 420,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Supplier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name *')),
            const SizedBox(height: 8),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 8),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 8),
            TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Address')),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(onPressed: _saveSupplier, icon: const Icon(Icons.save), label: const Text('Save'), style: ElevatedButton.styleFrom(backgroundColor: Color(0xff6fad99))),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _clearSelection, child: const Text('Clear')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _addPanel() {
    return SizedBox(
      width: 420,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Supplier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(controller: _addNameController, decoration: const InputDecoration(labelText: 'Name *')),
            const SizedBox(height: 8),
            TextField(controller: _addPhoneController, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 8),
            TextField(controller: _addEmailController, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 8),
            TextField(controller: _addAddressController, decoration: const InputDecoration(labelText: 'Address')),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(onPressed: _addNewSupplier, icon: const Icon(Icons.add), label: const Text('Add'), style: ElevatedButton.styleFrom(backgroundColor: Color(0xff6fad99))),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _clearAddForm, child: const Text('Clear')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
