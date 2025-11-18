import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../component/colors.dart';
import '../widget/side_bar.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

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

  // ---------------- Helper converters ----------------
  Map<String, int> _toStringIntMap(dynamic raw) {
    final Map<String, int> out = {};
    if (raw is Map) {
      raw.forEach((k, v) {
        final key = k?.toString() ?? 'Unknown';
        int valueInt;
        if (v is int) {
          valueInt = v;
        } else if (v is num) {
          valueInt = v.toInt();
        } else {
          valueInt = int.tryParse(v?.toString() ?? '') ?? 0;
        }
        out[key] = valueInt;
      });
    }
    return out;
  }

  Map<String, double> _toStringDoubleMap(dynamic raw) {
    final Map<String, double> out = {};
    if (raw is Map) {
      raw.forEach((k, v) {
        final key = k?.toString() ?? 'Unknown';
        double valueDouble;
        if (v is num) {
          valueDouble = v.toDouble();
        } else {
          valueDouble = double.tryParse(v?.toString() ?? '') ?? 0.0;
        }
        out[key] = valueDouble;
      });
    }
    return out;
  }

  // ---------------- Load Data ----------------
  Future<Map<String, dynamic>> _loadDashboardData() async {
    try {
      final ordersSnapshot = await _firestore.collection('orders').get();
      final inventorySnapshot = await _firestore.collection('raw_components').get();
      final suppliersSnapshot = await _firestore.collection('suppliers').get();
      final requestsSnapshot = await _firestore.collection('kitchen_requests').get();

      final orders = ordersSnapshot.docs;
      final inventoryItems = inventorySnapshot.docs;
      final suppliers = suppliersSnapshot.docs;
      final requestsData = requestsSnapshot.docs;

      // Requests
      int totalRequests = 0;
      for (var doc in requestsData) {
        final docData = doc.data();
        final rawPending = docData['pending'];
        final rawSent = docData['sent'];

        int pendingLen = 0;
        int sentLen = 0;
        if (rawPending is List) pendingLen = rawPending.length;
        else if (rawPending is Map) pendingLen = rawPending.length;

        if (rawSent is List) sentLen = rawSent.length;
        else if (rawSent is Map) sentLen = rawSent.length;

        totalRequests += pendingLen + sentLen;
      }

      // Orders
      double totalRevenue = 0;
      int totalOrders = orders.length;
      int completedOrders = 0;
      int pendingOrders = 0;

      Map<String, int> orderItemCount = {};
      Map<String, int> orderCount = {};

      for (var doc in orders) {
        final data = doc.data();

        // total revenue: safe parsing
        final totalRaw = data['total'];
        totalRevenue += (totalRaw is num)
            ? totalRaw.toDouble()
            : double.tryParse(totalRaw?.toString() ?? '') ?? 0.0;

        final status = data['status']?.toString() ?? '';
        if (status.toLowerCase() == 'completed') completedOrders++;
        if (status.toLowerCase() == 'pending') pendingOrders++;

        // items list
        final items = data['items'];
        if (items is List) {
          for (var item in items) {
            if (item is Map) {
              final itemName = item['name']?.toString() ?? 'Unknown';
              orderItemCount[itemName] = (orderItemCount[itemName] ?? 0) + 1;
            }
          }
        }

        final serviceType = data['diningOption']?.toString() ?? 'Unknown';
        orderCount[serviceType] = (orderCount[serviceType] ?? 0) + 1;
      }

      final topItems = orderItemCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topItemsMap = Map<String, int>.fromEntries(topItems.take(5));

      final topOrders = orderCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topOrdersMap = Map<String, int>.fromEntries(topOrders.take(5));

      // Inventory metrics
      int lowStockItems = 0;
      int totalInventoryItems = inventoryItems.length;

      Map<String, double> inventoryQtyMap = {};
      double maxInventoryQty = 0.0;

      for (var doc in inventoryItems) {
        final data = doc.data();
        final name = data['name']?.toString() ?? data['itemName']?.toString() ?? 'Unknown';
        final quantity = data['quantity'];
        final qty = (quantity is num)
            ? quantity.toDouble()
            : double.tryParse(quantity?.toString() ?? '') ?? 0.0;

        if (qty < 5) lowStockItems++;
        inventoryQtyMap[name] = qty;
        if (qty > maxInventoryQty) maxInventoryQty = qty;
      }

      final sortedInventory = inventoryQtyMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topInventoryMap = Map<String, double>.fromEntries(sortedInventory.take(8));

      // Requests by type (handle pending/sent as List or Map)
      Map<String, int> requestTypes = {};
      for (var doc in requestsData) {
        final data = doc.data();
        final rawPending = data['pending'];
        final rawSent = data['sent'];

        Iterable pendingIter = const Iterable.empty();
        Iterable sentIter = const Iterable.empty();
        if (rawPending is List) pendingIter = rawPending;
        else if (rawPending is Map) pendingIter = rawPending.values;

        if (rawSent is List) sentIter = rawSent;
        else if (rawSent is Map) sentIter = rawSent.values;

        for (var p in pendingIter) {
          if (p is Map) {
            final type = p['name']?.toString() ?? p['product']?.toString() ?? 'Unknown';
            requestTypes[type] = (requestTypes[type] ?? 0) + 1;
          }
        }
        for (var s in sentIter) {
          if (s is Map) {
            final type = s['name']?.toString() ?? s['product']?.toString() ?? 'Unknown';
            requestTypes[type] = (requestTypes[type] ?? 0) + 1;
          }
        }
      }

      final topRequests = requestTypes.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topRequestsMap = Map<String, int>.fromEntries(topRequests.take(5));

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
    } catch (e, st) {
      debugPrint('Error loading dashboard data: $e\n$st');
      return {
        'totalRevenue': 0.0,
        'totalOrders': 0,
        'completedOrders': 0,
        'pendingOrders': 0,
        'totalInventoryItems': 0,
        'lowStockItems': 0,
        'totalSuppliers': 0,
        'totalRequests': 0,
        'topItems': <String, int>{},
        'topOrders': <String, int>{},
        'topRequests': <String, int>{},
        'topInventory': <String, double>{},
        'maxInventoryQty': 1.0,
      };
    }
  }

  // ---------------- Build UI ----------------
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
          // Use non-const in case SideBar constructor isn't const
          SideBar(currentPage: 'Dashboard'),
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
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text('Error loading dashboard: ${snapshot.error}', textAlign: TextAlign.center),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: Text("No data available"));
                      }

                      final data = snapshot.data!;
                      debugPrint('Dashboard data loaded with keys: ${data.keys.toList()}');

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
                                  (data['totalOrders']).toString(),
                                  AppColors.se,
                                  Icons.shopping_bag,
                                ),
                                _buildKPICard(
                                  'Completed Orders',
                                  (data['completedOrders']).toString(),
                                  Colors.blue,
                                  Icons.check_circle,
                                ),
                                _buildKPICard(
                                  'Pending Orders',
                                  (data['pendingOrders']).toString(),
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
                                  (data['totalInventoryItems']).toString(),
                                  Colors.purple,
                                  Icons.inventory_2,
                                ),
                                _buildKPICard(
                                  'Low Stock Items',
                                  (data['lowStockItems']).toString(),
                                  Colors.red,
                                  Icons.warning,
                                ),
                                _buildKPICard(
                                  'Total Suppliers',
                                  (data['totalSuppliers']).toString(),
                                  Colors.indigo,
                                  Icons.local_shipping,
                                ),
                                _buildKPICard(
                                  'Total Requests',
                                  (data['totalRequests']).toString(),
                                  Colors.teal,
                                  Icons.request_quote,
                                ),
                              ],
                            ),
                            const Gap(40),

                            // Charts Section Title
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
                                  Builder(builder: (ctx) {
                                    final topItems = _toStringIntMap(data['topItems']);
                                    if (topItems.isEmpty) return const Center(child: Text('No data available'));
                                    final totalOrders = (data['totalOrders'] as int?) ?? 0;
                                    return Column(
                                      children: topItems.entries.map((entry) {
                                        final percentage = totalOrders > 0 ? (entry.value / totalOrders) * 100 : 0.0;
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                                                  const SizedBox(width: 8),
                                                  Text('${entry.value} (${percentage.toStringAsFixed(1)}%)', style: const TextStyle(color: Colors.grey)),
                                                ],
                                              ),
                                              const Gap(4),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: (percentage / 100).clamp(0.0, 1.0),
                                                  minHeight: 6,
                                                  backgroundColor: Colors.grey[300],
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    Color.lerp(Colors.red, Colors.green, (percentage / 100)) ?? Colors.green,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const Gap(24),

                            // Orders by Service Type
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
                                  Builder(builder: (ctx) {
                                    final topOrders = _toStringIntMap(data['topOrders']);
                                    if (topOrders.isEmpty) return const Center(child: Text('No data available'));
                                    final totalOrders = (data['totalOrders'] as int?) ?? 0;
                                    return Column(
                                      children: topOrders.entries.map((entry) {
                                        final percentage = totalOrders > 0 ? (entry.value / totalOrders) * 100 : 0.0;
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(child: Text(entry.key, maxLines: 2, style: const TextStyle(fontWeight: FontWeight.w600))),
                                                  const SizedBox(width: 8),
                                                  Text('${entry.value} (${percentage.toStringAsFixed(1)}%)', style: const TextStyle(color: Colors.grey)),
                                                ],
                                              ),
                                              const Gap(4),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: (percentage / 100).clamp(0.0, 1.0),
                                                  minHeight: 6,
                                                  backgroundColor: Colors.grey[300],
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    Color.lerp(Colors.orange, Colors.blue, (percentage / 100)) ?? Colors.blue,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const Gap(24),

                            // Most Requested Inventory Items & Inventory Stock Levels
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
                                  Builder(builder: (ctx) {
                                    final topRequests = _toStringIntMap(data['topRequests']);
                                    if (topRequests.isEmpty) return const Center(child: Text('No requests recorded'));
                                    final totalReq = (data['totalRequests'] as int?) ?? 0;
                                    return Column(
                                      children: topRequests.entries.map((e) {
                                        final percent = totalReq == 0 ? 0.0 : (e.value / totalReq);
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                                          child: Row(
                                            children: [
                                              Expanded(flex: 3, child: Text(e.key)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 5,
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: LinearProgressIndicator(
                                                    value: percent.clamp(0.0, 1.0),
                                                    minHeight: 12,
                                                    backgroundColor: Colors.teal.shade100,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text('${e.value}'),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  }),

                                  const SizedBox(height: 16),
                                  Text('Inventory Stock Levels', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),

                                  Builder(builder: (ctx) {
                                    final topInventory = _toStringDoubleMap(data['topInventory']);
                                    final maxQty = (data['maxInventoryQty'] is num) ? (data['maxInventoryQty'] as num).toDouble() : double.tryParse(data['maxInventoryQty']?.toString() ?? '') ?? 1.0;
                                    if (topInventory.isEmpty) return const Text('No inventory data available');

                                    return Column(
                                      children: topInventory.entries.map((e) {
                                        final value = e.value;
                                        final ratio = maxQty == 0 ? 0.0 : (value / maxQty).clamp(0.0, 1.0);
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                                          child: Row(
                                            children: [
                                              Expanded(flex: 3, child: Text(e.key, overflow: TextOverflow.ellipsis)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 5,
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: Container(
                                                    height: 16,
                                                    child: LinearProgressIndicator(
                                                      value: ratio,
                                                      minHeight: 16,
                                                      backgroundColor: Colors.purple.shade100,
                                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
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
