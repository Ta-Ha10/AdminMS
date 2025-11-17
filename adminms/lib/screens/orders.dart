import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../component/colors.dart';
import '../widget/side_bar.dart';

// ===============================
// Order Item Model
// ===============================
class OrderItem {
  final String id;
  final String name;
  final int qty;
  final double price;
  final double total;

  OrderItem({
    required this.id,
    required this.name,
    required this.qty,
    required this.price,
    required this.total,
  });

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      id: data['id'] ?? 'N/A',
      name: data['name'] ?? 'N/A',
      qty: (data['qty'] ?? 0) as int,
      price: (data['price'] ?? 0.0).toDouble(),
      total: (data['total'] ?? 0.0).toDouble(),
    );
  }
}

// ===============================
// Order Model
// ===============================
class Order {
  final String id;
  final double total;
  final String serviceType; 
  final DateTime timestamp;
  final List<OrderItem> items;
  final String status;
  final double subtotal;
  final double tax;
  final String? tableName;

  Order({
    required this.id,
    required this.total,
    required this.serviceType,
    required this.timestamp,
    required this.items,
    required this.status,
    required this.subtotal,
    required this.tax,
    this.tableName,
  });

  // -------------------------------
  // Firestore converter
  // -------------------------------
  factory Order.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Parse items
    List<OrderItem> items = [];
    if (data['items'] != null) {
      items = (data['items'] as List<dynamic>)
          .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    // Fix diningOption Parsing
    String rawDining = (data['diningOption'] ?? '').toString().trim();
    String serviceType = '';
    String? tableName;

    if (rawDining.toLowerCase() == "takeaway") {
      serviceType = "Takeaway";
    } else {
      if (rawDining.contains('(')) {
        final inside = rawDining.split('(').last.replaceAll(')', '').trim();
        serviceType = inside; // → Table Table 06
        tableName = inside.replaceAll('Table', '').trim(); // → 06
      } else {
        serviceType = rawDining;
      }
    }

    return Order(
      id: doc.id,
      total: (data['total'] ?? 0.0).toDouble(),
      serviceType: serviceType,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      items: items,
      status: data['status'] ?? 'Pending',
      subtotal: (data['subtotal'] ?? 0.0).toDouble(),
      tax: (data['tax'] ?? 0.0).toDouble(),
      tableName: tableName,
    );
  }
}

// ===============================
// Orders Page
// ===============================
class OrdersPage extends StatefulWidget {
  const OrdersPage({Key? key}) : super(key: key);

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Order? selectedOrder;
  DateTime? selectedDate;
  int? selectedMonth;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 700;

    return Scaffold(
      backgroundColor: const Color(0xfffefafa),
      appBar: isMobile
          ? AppBar(
              title: const Text('Orders'),
              backgroundColor: Colors.white,
              elevation: 0,
            )
          : null,
      drawer: isMobile ? Drawer(child: SideBar(currentPage: 'Orders')) : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SideBar(),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(70),
                Center(
                  child: const Text(
                    "ORDER MANAGEMENT",
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
                    child: Row(
                      children: [
                        // Left side: Table (60%)
                        Expanded(
                          flex: 60,
                          child: StreamBuilder<QuerySnapshot>(
                            stream:
                                _firestore.collection('orders').snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              if (!snapshot.hasData) {
                                return const Center(
                                    child: Text("No Data"));
                              }

                              var allOrders = snapshot.data!.docs
                                  .map((doc) => Order.fromFirestore(doc))
                                  .toList();

                              var filteredOrders = allOrders.where((order) {
                                if (selectedDate != null &&
                                    order.timestamp.day !=
                                        selectedDate!.day) {
                                  return false;
                                }
                                if (selectedMonth != null &&
                                    order.timestamp.month !=
                                        selectedMonth!) {
                                  return false;
                                }
                                return true;
                              }).toList();

                              return Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // Filter controls
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.se),
                                              onPressed: () {
                                                _showDayPicker(context);
                                              },
                                              child: Text(
                                                  selectedDate == null
                                                      ? 'Filter by day'
                                                      : 'Day: ${selectedDate!.day}',
                                                  style: TextStyle(
                                                      color: AppColors.pr)),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.se),
                                              onPressed: () {
                                                _showMonthPicker(context);
                                              },
                                              child: Text(
                                                  selectedMonth == null
                                                      ? 'Filter by month'
                                                      : 'Month: ${_getMonthName(selectedMonth!)}',
                                                  style: TextStyle(
                                                      color: AppColors.pr)),
                                            ),
                                            if (selectedDate != null ||
                                                selectedMonth != null) ...[
                                              const SizedBox(width: 8),
                                              OutlinedButton(
                                                onPressed: () {
                                                  setState(() {
                                                    selectedDate = null;
                                                    selectedMonth = null;
                                                  });
                                                },
                                                child: const Text(
                                                    'Clear filters',
                                                    style: TextStyle(
                                                        color: AppColors.pr)),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Orders table
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        dataRowHeight: 40,
                                        headingRowHeight: 36,
                                        headingRowColor:
                                            MaterialStateProperty.all(
                                                const Color(0xfff6f6f6)),
                                        dataRowColor:
                                            MaterialStateProperty.resolveWith(
                                                (states) {
                                          if (states.contains(
                                              MaterialState.selected)) {
                                            return Colors.grey[300];
                                          }
                                          return Colors.white;
                                        }),
                                        border: TableBorder.all(
                                            color: Colors.grey.shade300),
                                        columns: const [
                                          DataColumn(
                                              label: Text('Order')),
                                          DataColumn(
                                              label: Text('Time')),
                                          DataColumn(
                                              label: Text('Total')),
                                          DataColumn(
                                              label: Text('Service')),
                                          DataColumn(
                                              label: Text('Status')),
                                          DataColumn(
                                              label: Text('Action')),
                                        ],
                                        rows: List.generate(
                                            filteredOrders.length,
                                            (index) {
                                          final order =
                                              filteredOrders[index];
                                          final selected =
                                              selectedOrder?.id ==
                                                  order.id;

                                          return DataRow(
                                            selected: selected,
                                            onSelectChanged: (_) {
                                              setState(() {
                                                selectedOrder = selected
                                                    ? null
                                                    : order;
                                              });
                                            },
                                            cells: [
                                              DataCell(Text(
                                                  'Order ${index + 1}')),
                                              DataCell(Text(
                                                  _formatTime(order
                                                      .timestamp))),
                                              DataCell(Text(
                                                  'EGP ${order.total.toStringAsFixed(2)}')),
                                              DataCell(Text(
                                                  order.serviceType)),
                                              DataCell(
                                                  Text(order.status)),
                                              DataCell(
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.edit),
                                                  onPressed: () {
                                                    _showEditOrderDialog(
                                                        order);
                                                  },
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        // Divider
                        VerticalDivider(
                          width: 1,
                          color: Colors.grey.shade300,
                        ),
                        // Right side: Details panel (40%)
                        Expanded(
                          flex: 40,
                          child: selectedOrder == null
                              ? Container()
                              : _buildOrderDetailsPanel(selectedOrder!),
                        ),
                      ],
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

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  // ==========================================
  // Helper Functions
  // ==========================================
  String _formatTime(DateTime t) {
    return "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} ${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}";
  }

  // ==========================================
  // Order Details Panel
  // ==========================================
  Widget _buildOrderDetailsPanel(Order order) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Order Details",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.se)),
          const Divider(),
          const Gap(10),
          Text("Time"),
          Text(_formatTime(order.timestamp),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const Gap(20),
          Text("Service"),
          Text(order.serviceType,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const Gap(20),
          Text("Status"),
          Text(order.status,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const Gap(20),
          Text("Items",
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const Gap(8),
          ...order.items.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Gap(4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Qty: ${item.qty}"),
                      Text(
                          "EGP ${item.total.toStringAsFixed(2)}"),
                    ],
                  ),
                ],
              ),
            );
          }),
          const Gap(20),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Subtotal"),
              Text(
                  "EGP ${order.subtotal.toStringAsFixed(2)}"),
            ],
          ),
          const Gap(8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Tax"),
              Text("EGP ${order.tax.toStringAsFixed(2)}"),
            ],
          ),
          const Gap(8),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total",
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text("EGP ${order.total.toStringAsFixed(2)}",
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green)),
            ],
          ),
          const Gap(30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Order'),
                    content: const Text('Are you sure you want to delete this order? This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  // Delete order from Firebase completely
                  await FirebaseFirestore.instance
                      .collection('orders')
                      .doc(order.id)
                      .delete();
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Order deleted successfully')),
                    );
                  }
                  
                  setState(() {
                    selectedOrder = null;
                  });
                }
              },
              child: const Text(
                'Delete Order',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
    );
  }

  // ==========================================
  // Day Picker Dialog
  // ==========================================
  void _showDayPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Day'),
          content: SizedBox(
            width: 300,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.5,
              ),
              itemCount: 31,
              itemBuilder: (context, index) {
                final day = index + 1;
                final isSelected = selectedDate?.day == day;
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? AppColors.se : Colors.grey[300],
                  ),
                  onPressed: () {
                    setState(() {
                      selectedDate = DateTime(DateTime.now().year,
                          DateTime.now().month, day);
                    });
                    Navigator.pop(context);
                  },
                  child: Text(
                    day.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // Month Picker Dialog
  // ==========================================
  void _showMonthPicker(BuildContext context) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Month'),
          content: SizedBox(
            width: 300,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final isSelected = selectedMonth == month;
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? AppColors.se : Colors.grey[300],
                  ),
                  onPressed: () {
                    setState(() {
                      selectedMonth = month;
                    });
                    Navigator.pop(context);
                  },
                  child: Text(
                    months[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // Edit Order Dialog
  // ==========================================
  void _showEditOrderDialog(Order order) {
    List<OrderItem> editableItems = List.from(order.items);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Theme(
              data: Theme.of(context).copyWith(
                dialogBackgroundColor: Colors.white,
                primaryColor: Colors.grey,
                useMaterial3: true,
              ),
              child: AlertDialog(
                backgroundColor: Colors.white,
                title: const Text('Edit Order Items'),
                titleTextStyle: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                content: SizedBox(
                  width: 400,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...editableItems.asMap().entries.map((entry) {
                          int idx = entry.key;
                          OrderItem item = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.name,
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.bold)),
                                      const Gap(4),
                                      Text(
                                          'Qty: ${item.qty} | EGP ${item.total.toStringAsFixed(2)}'),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () {
                                    setStateDialog(() {
                                      editableItems.removeAt(idx);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.se),
                    onPressed: () async {
                      // Calculate new totals
                      double newSubtotal = editableItems
                          .fold(0.0, (sum, item) => sum + item.total);
                      double newTax = order.tax;
                      double newTotal = newSubtotal + newTax;

                      // If no items left, delete the order
                      if (editableItems.isEmpty) {
                        await _firestore
                            .collection('orders')
                            .doc(order.id)
                            .delete();
                        
                        if (mounted) {
                          Navigator.pop(context);
                          setState(() {
                            selectedOrder = null;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Order deleted (no items remaining)')),
                          );
                        }
                        return;
                      }

                      // Update Firestore
                      try {
                        await _firestore
                            .collection('orders')
                            .doc(order.id)
                            .update({
                              'items': editableItems
                                  .map((item) => {
                                        'id': item.id,
                                        'name': item.name,
                                        'qty': item.qty,
                                        'price': item.price,
                                        'total': item.total,
                                      })
                                  .toList(),
                              'subtotal': newSubtotal,
                              'total': newTotal,
                            });

                        // Fetch updated order to refresh details
                        final doc = await _firestore
                            .collection('orders')
                            .doc(order.id)
                            .get();
                        
                        if (mounted) {
                          if (doc.exists) {
                            setState(() {
                              selectedOrder = Order.fromFirestore(doc);
                            });
                          }
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Order updated successfully')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}