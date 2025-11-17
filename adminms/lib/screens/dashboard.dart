import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../component/colors.dart';
import '../widget/side_bar.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Future<Map<String, dynamic>> dashboardDataFuture;

  @override
  void initState() {
    super.initState();
    dashboardDataFuture = _loadDashboardData();
  }

  Future<Map<String, dynamic>> _loadDashboardData() async {
    try {
      // Get Orders
      final ordersSnapshot = await _firestore.collection('orders').get();
      final orders = ordersSnapshot.docs;

      // Get Inventory Items from raw_components
      final inventorySnapshot = await _firestore.collection('raw_components').get();
      final inventoryItems = inventorySnapshot.docs;

      // Get Suppliers
      final suppliersSnapshot = await _firestore.collection('suppliers').get();
      final suppliers = suppliersSnapshot.docs;

      // Get Requests from kitchen_requests
      final requestsSnapshot = await _firestore.collection('kitchen_requests').get();
      final requestsData = requestsSnapshot.docs;
      
      // Count total requests (pending + sent)
      int totalRequests = 0;
      for (var doc in requestsData) {
        final pending = doc['pending'] as List? ?? [];
        final sent = doc['sent'] as List? ?? [];
        totalRequests += pending.length + sent.length;
      }

      // Calculate metrics
      double totalRevenue = 0;
      int totalOrders = orders.length;
      int completedOrders = 0;
      int pendingOrders = 0;
      Map<String, int> orderItemCount = {};
      Map<String, int> orderCount = {};

      for (var doc in orders) {
        final data = doc.data();
        totalRevenue += (data['total'] ?? 0.0).toDouble();

        if (data['status'] == 'Completed') completedOrders++;
        if (data['status'] == 'Pending') pendingOrders++;

        // Count items
        if (data['items'] != null) {
          for (var item in data['items'] as List) {
            final itemName = item['name'] ?? 'Unknown';
            orderItemCount[itemName] = (orderItemCount[itemName] ?? 0) + 1;
          }
        }

        // Count orders by service type
        final serviceType = data['diningOption'] ?? 'Unknown';
        orderCount[serviceType] = (orderCount[serviceType] ?? 0) + 1;
      }

      // Sort items and get top 5
      final topItems = orderItemCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topItemsMap =
          Map.fromEntries(topItems.take(5));

      // Sort orders and get top 5 service types
      final topOrders = orderCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topOrdersMap =
          Map.fromEntries(topOrders.take(5));

      // Calculate inventory metrics
      int lowStockItems = 0;
      int totalInventoryItems = inventoryItems.length;

      for (var doc in inventoryItems) {
        final data = doc.data();
        final quantity = (data['quantity'] ?? 0);
        final qty = quantity is num ? quantity.toDouble() : double.tryParse(quantity.toString()) ?? 0.0;
        if (qty < 5) lowStockItems++;
      }

      // Build top inventory by quantity (for bar chart)
      Map<String, double> inventoryQtyMap = {};
      double maxInventoryQty = 0.0;
      for (var doc in inventoryItems) {
        final data = doc.data();
        final name = (data['name'] ?? data['itemName'] ?? 'Unknown').toString();
        final quantity = (data['quantity'] ?? 0);
        final qty = quantity is num ? quantity.toDouble() : double.tryParse(quantity.toString()) ?? 0.0;
        inventoryQtyMap[name] = qty;
        if (qty > maxInventoryQty) maxInventoryQty = qty;
      }

      final sortedInventory = inventoryQtyMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topInventoryMap = Map.fromEntries(sortedInventory.take(8));

      // Count requests by type from kitchen_requests
      Map<String, int> requestTypes = {};
      for (var doc in requestsData) {
        final pending = doc['pending'] as List? ?? [];
        final sent = doc['sent'] as List? ?? [];
        
        for (var p in pending) {
          final type = p['name'] ?? p['product'] ?? 'Unknown';
          requestTypes[type] = (requestTypes[type] ?? 0) + 1;
        }
        
        for (var s in sent) {
          final type = s['name'] ?? s['product'] ?? 'Unknown';
          requestTypes[type] = (requestTypes[type] ?? 0) + 1;
        }
      }

      final topRequests = requestTypes.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topRequestsMap =
          Map.fromEntries(topRequests.take(5));

      return {
        'totalRevenue': totalRevenue,
        'totalOrders': totalOrders,
        'completedOrders': completedOrders,
        'pendingOrders': pendingOrders,
        'totalInventoryItems': totalInventoryItems,
        'lowStockItems': lowStockItems,
        'totalSuppliers': suppliers.length,
        'totalRequests': totalRequests,
        'topInventory': topInventoryMap,
        'maxInventoryQty': maxInventoryQty,
        'topItems': topItemsMap,
        'topOrders': topOrdersMap,
        'topRequests': topRequestsMap,
      };
    } catch (e) {
      print('Error loading dashboard data: $e');
      return {
        'totalRevenue': 0,
        'totalOrders': 0,
        'completedOrders': 0,
        'pendingOrders': 0,
        'totalInventoryItems': 0,
        'lowStockItems': 0,
        'totalSuppliers': 0,
        'totalRequests': 0,
        'topItems': {},
        'topOrders': {},
        'topRequests': {},
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 700;

    return Scaffold(
      backgroundColor: const Color(0xfffefafa),
      appBar: isMobile
          ? AppBar(
              title: const Text('Dashboard'),
              backgroundColor: Colors.white,
              elevation: 0,
            )
          : null,
      drawer: isMobile ? Drawer(child: SideBar(currentPage: 'Dashboard')) : null,
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
                    "BUSINESS DASHBOARD",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.se,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: dashboardDataFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: Text("No data available"));
                      }

                      final data = snapshot.data!;

                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // KPI Cards
                            GridView.count(
                              crossAxisCount: isMobile ? 2 : 4,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 1.0,
                              children: [
                                _buildKPICard(
                                  'Total Revenue',
                                  'EGP ${(data['totalRevenue'] as num).toStringAsFixed(2)}',
                                  Colors.green,
                                  Icons.trending_up,
                                ),
                                _buildKPICard(
                                  'Total Orders',
                                  '${data['totalOrders']}',
                                  AppColors.se,
                                  Icons.shopping_bag,
                                ),
                                _buildKPICard(
                                  'Completed Orders',
                                  '${data['completedOrders']}',
                                  Colors.blue,
                                  Icons.check_circle,
                                ),
                                _buildKPICard(
                                  'Pending Orders',
                                  '${data['pendingOrders']}',
                                  Colors.orange,
                                  Icons.hourglass_empty,
                                ),
                              ],
                            ),
                            const Gap(30),

                            // Inventory & System Stats
                            GridView.count(
                              crossAxisCount: isMobile ? 2 : 4,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 1.0,
                              children: [
                                _buildKPICard(
                                  'Inventory Items',
                                  '${data['totalInventoryItems']}',
                                  Colors.purple,
                                  Icons.inventory_2,
                                ),
                                _buildKPICard(
                                  'Low Stock Items',
                                  '${data['lowStockItems']}',
                                  Colors.red,
                                  Icons.warning,
                                ),
                                _buildKPICard(
                                  'Total Suppliers',
                                  '${data['totalSuppliers']}',
                                  Colors.indigo,
                                  Icons.local_shipping,
                                ),
                                _buildKPICard(
                                  'Total Requests',
                                  '${data['totalRequests']}',
                                  Colors.teal,
                                  Icons.request_quote,
                                ),
                              ],
                            ),
                            const Gap(40),

                            // Charts Section
                            Text(
                              'Performance Analysis',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.se,
                              ),
                            ),
                            const Gap(16),

                            // Top Items Chart
                            Container(
                              padding: const EdgeInsets.all(16),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Most Requested Items from Kitchen',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.pr,
                                    ),
                                  ),
                                  const Gap(16),
                                  if ((data['topItems'] as Map).isEmpty)
                                    const Center(
                                        child: Text('No data available'))
                                  else
                                    Column(
                                      children: (data['topItems'] as Map)
                                          .entries
                                          .map((entry) {
                                        final percentage = ((entry.value as int) /
                                                ((data['totalOrders'] as int) > 0
                                                    ? (data['totalOrders'] as int)
                                                    : 1)) *
                                            100;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(entry.key,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                  Text(
                                                      '${entry.value} orders (${percentage.toStringAsFixed(1)}%)',
                                                      style: const TextStyle(
                                                          color: Colors.grey)),
                                                ],
                                              ),
                                              const Gap(4),
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: percentage / 100,
                                                  minHeight: 6,
                                                  backgroundColor:
                                                      Colors.grey[300],
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(
                                                    Color.lerp(
                                                      Colors.red,
                                                      Colors.green,
                                                      percentage / 100,
                                                    )!,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ),
                            ),
                            const Gap(24),

                            // Top Orders by Service Type
                            Container(
                              padding: const EdgeInsets.all(16),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Orders by Service Type',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.pr,
                                    ),
                                  ),
                                  const Gap(16),
                                  if ((data['topOrders'] as Map).isEmpty)
                                    const Center(
                                        child: Text('No data available'))
                                  else
                                    Column(
                                      children: (data['topOrders'] as Map)
                                          .entries
                                          .map((entry) {
                                        final percentage = ((entry.value as int) /
                                                ((data['totalOrders'] as int) > 0
                                                    ? (data['totalOrders'] as int)
                                                    : 1)) *
                                            100;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(entry.key,
                                                      maxLines: 2,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                  Text(
                                                      '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                                                      style: const TextStyle(
                                                          color: Colors.grey)),
                                                ],
                                              ),
                                              const Gap(4),
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: percentage / 100,
                                                  minHeight: 6,
                                                  backgroundColor:
                                                      Colors.grey[300],
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(
                                                    Color.lerp(
                                                      Colors.orange,
                                                      Colors.blue,
                                                      percentage / 100,
                                                    )!,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ),
                            ),
                            const Gap(24),

                            // Most Requested Inventory Items
                            Container(
                              padding: const EdgeInsets.all(16),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Most Requested Inventory Items',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.pr,
                                    ),
                                  ),
                                  const Gap(16),
                                  // Render top requests (existing)
                                  Column(
                                    children: (data['topRequests'] as Map<String, int>).entries.map((e) {
                                      final percent = (((data['totalRequests'] as int?) ?? 0) == 0) ? 0.0 : e.value / ((data['totalRequests'] as int));
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                                        child: Row(
                                          children: [
                                            Expanded(flex: 3, child: Text(e.key)),
                                            Expanded(
                                              flex: 5,
                                              child: LinearProgressIndicator(value: percent, color: Colors.teal, backgroundColor: Colors.teal.shade100),
                                            ),
                                            SizedBox(width: 8),
                                            Text('${e.value}'),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),

                                  SizedBox(height: 16),
                                  Text('Inventory Stock Levels', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  SizedBox(height: 8),
                                  // Inventory bar chart using topInventory and maxInventoryQty
                                  Builder(builder: (ctx) {
                                    final topInventory = (data['topInventory'] as Map<String, double>?) ?? {};
                                    final maxQty = (data['maxInventoryQty'] as double?) ?? 1.0;
                                    if (topInventory.isEmpty) {
                                      return Text('No inventory data available');
                                    }
                                    return Column(
                                      children: topInventory.entries.map((e) {
                                        final value = e.value;
                                        final ratio = maxQty == 0 ? 0.0 : (value / maxQty).clamp(0.0, 1.0);
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                                          child: Row(
                                            children: [
                                              Expanded(flex: 3, child: Text(e.key, overflow: TextOverflow.ellipsis)),
                                              Expanded(
                                                flex: 5,
                                                child: Container(
                                                  height: 16,
                                                  child: LinearProgressIndicator(value: ratio, color: Colors.purple, backgroundColor: Colors.purple.shade100),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Text('${value.toStringAsFixed(0)}'),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const Gap(40),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPICard(String title, String value, Color color, IconData icon) {
    return Container(
    //  padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2), width: 0.8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 40),
        const Gap(3),
          Text(
            value,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Gap(1),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
