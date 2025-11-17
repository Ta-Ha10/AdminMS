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
  bool isSidebarVisible = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Order? selectedOrder;
  DateTime? selectedDate;
  int? selectedMonth;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 700;

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              title: const Text('Orders'),
              backgroundColor: Colors.white,
              elevation: 0,
            )
          : null,
      drawer: isMobile ? Drawer(child: SideBar(currentPage: 'Orders')) : null,
      body: Row(
        children: [
          if (!isMobile) SideBar(currentPage: 'Orders'),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('orders').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData) {
                  return const Center(child: Text("No Data"));
                }

                var allOrders = snapshot.data!.docs
                    .map((doc) => Order.fromFirestore(doc))
                    .toList();

                var filteredOrders = allOrders.where((order) {
                  if (selectedDate != null &&
                      order.timestamp.day != selectedDate!.day) {
                    return false;
                  }
                  if (selectedMonth != null &&
                      order.timestamp.month != selectedMonth!) {
                    return false;
                  }
                  return true;
                }).toList();

                return Row(
                  children: [
                    // ==========================================
                    // LEFT SIDE — ORDERS TABLE — Full Width
                    // ==========================================
                    Expanded(
                      flex: 60,
                      child: Column(
                        children: [
                          // Filters
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: Colors.white,
                            child: Row(
                              children: [
                                Expanded(
                                  child: DropdownButton<int?>(
                                    value: selectedDate?.day,
                                    isExpanded: true,
                                    hint: const Text("All Days"),
                                    items: [
                                      const DropdownMenuItem(
                                          value: null, child: Text("All Days")),
                                      ...List.generate(31, (i) {
                                        return DropdownMenuItem(
                                          value: i + 1,
                                          child: Text('Day ${i + 1}'),
                                        );
                                      })
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        selectedDate = val == null
                                            ? null
                                            : DateTime(DateTime.now().year,
                                                DateTime.now().month, val);
                                      });
                                    },
                                  ),
                                ),
                                const Gap(16),
                                Expanded(
                                  child: DropdownButton<int?>(
                                    value: selectedMonth,
                                    isExpanded: true,
                                    hint: const Text("All Months"),
                                    items: [
                                      const DropdownMenuItem(
                                          value: null,
                                          child: Text("All Months")),
                                      ...List.generate(12, (index) {
                                        final months = [
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
                                        return DropdownMenuItem(
                                          value: index + 1,
                                          child: Text(months[index]),
                                        );
                                      }),
                                    ],
                                    onChanged: (val) {
                                      setState(() => selectedMonth = val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ============================
                          // Table Full Width — No Padding
                          // ============================
                          Expanded(
                            child: SingleChildScrollView(
                              child: DataTable(
                                headingRowColor:
                                    WidgetStateColor.transparent, // remove bg
                                dataRowColor:
                                    WidgetStateColor.transparent, // remove bg
                                columns: const [
                                  DataColumn(label: Text('Order ID')),
                                  DataColumn(label: Text('Time')),
                                  DataColumn(label: Text('Total')),
                                  DataColumn(label: Text('Service')),
                                  DataColumn(label: Text('Status')),
                                ],
                                rows: filteredOrders.map((order) {
                                  final selected =
                                      selectedOrder?.id == order.id;

                                  return DataRow(
                                    selected: selected,
                                    onSelectChanged: (_) {
                                      setState(() {
                                        selectedOrder =
                                            selected ? null : order;
                                      });
                                    },
                                    cells: [
                                      DataCell(Text(order.id)),
                                      DataCell(Text(_formatTime(order.timestamp))),
                                      DataCell(Text(
                                          'SAR ${order.total.toStringAsFixed(2)}')),
                                      DataCell(Text(order.serviceType)),
                                      DataCell(Text(order.status)),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ===============================
                    // RIGHT PANEL — ORDER DETAILS
                    // ===============================
                    Expanded(
                      flex: 40,
                      child: Container(
                        color: Colors.grey[50],
                        child: selectedOrder == null
                            ? Center(
                                child: Text(
                                  "Select an order to view details",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.pr,
                                  ),
                                ),
                              )
                            : _buildOrderDetailsPanel(selectedOrder!),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Helper Functions
  // ==========================================
  String _formatTime(DateTime t) {
    return "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}   ${t.day}/${t.month}";
  }

  Color _getServiceColor(String s) {
    if (s.contains('Table')) return Colors.blue;
    return Colors.orange;
  }

  Color _getStatusColor(String s) {
    switch (s) {
      case "Completed":
        return Colors.green;
      case "In Progress":
        return Colors.blue;
      default:
        return Colors.orange;
    }
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
                  fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.pr)),
          const Divider(),
          const Gap(10),

          Text("Order ID"),
          Text(order.id, style: const TextStyle(fontWeight: FontWeight.bold)),

          const Gap(20),
          Text("Service"),
          Text(order.serviceType,
              style: TextStyle(
                  color: _getServiceColor(order.serviceType),
                  fontWeight: FontWeight.bold)),

          const Gap(20),
          Text("Status"),
          Text(order.status,
              style: TextStyle(
                  color: _getStatusColor(order.status),
                  fontWeight: FontWeight.bold)),

          const Gap(20),
          Text("Time"),
          Text(_formatTime(order.timestamp)),

          const Gap(20),
          Text("Items", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Gap(8),

          ...order.items.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item.name),
                  Text("SAR ${item.total.toStringAsFixed(2)}"),
                ],
              ),
            );
          }),

          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Subtotal"),
              Text("SAR ${order.subtotal.toStringAsFixed(2)}"),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Tax"),
              Text("SAR ${order.tax.toStringAsFixed(2)}"),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("SAR ${order.total.toStringAsFixed(2)}",
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green)),
            ],
          )
        ],
      ),
    );
  }
}
  