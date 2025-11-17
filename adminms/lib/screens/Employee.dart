import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../component/colors.dart';
import '../widget/top_bar.dart';
import '../widget/side_bar.dart';

// Employee Model
class Employee {
  final String id;
  final String name;
  final String phone;
  final String role;
  final double salary;

  Employee({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.salary,
  });

  // Factory constructor to create Employee from Firestore document
  factory Employee.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Employee(
      id: doc.id,
      name: data['name'] ?? 'N/A',
      phone: data['phone'] ?? 'N/A',
      role: data['role'] ?? 'N/A',
      salary: (data['salary'] ?? 0.0).toDouble(),
    );
  }
}

class EmployeePage extends StatefulWidget {
  const EmployeePage({Key? key}) : super(key: key);

  @override
  State<EmployeePage> createState() => _EmployeePageState();
}

class _EmployeePageState extends State<EmployeePage> {
  bool isSidebarVisible = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 700;

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              title: const Text('Employees'),
              backgroundColor: Colors.grey[300],
            )
          : null,
      drawer: isMobile ? Drawer(child: SideBar(currentPage: 'Employee')) : null,
      body: Row(
        children: [
          // Sidebar (Desktop only)
          if (!isMobile)
            SideBar(currentPage: 'Employee'),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                if (!isMobile)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: AppTopBar(
                      isSidebarVisible: isSidebarVisible,
                      onToggle: () {
                        setState(() {
                          isSidebarVisible = !isSidebarVisible;
                        });
                      },
                      title: 'Employees',
                    ),
                  ),

                // Content Area - Table fills entire remaining space
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('employees').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Text(
                            'No employees found',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppColors.pr,
                            ),
                          ),
                        );
                      }

                      final employees = snapshot.data!.docs
                          .map((doc) => Employee.fromFirestore(doc))
                          .toList();

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Employee Management',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.pr,
                              ),
                            ),
                            const Gap(16),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[400]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Salary (SAR)', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: employees.map((employee) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(employee.id)),
                                        DataCell(Text(employee.name)),
                                        DataCell(Text(employee.phone)),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _getRoleColor(employee.role).withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              employee.role,
                                              style: TextStyle(
                                                color: _getRoleColor(employee.role),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            'SAR ${employee.salary.toStringAsFixed(2)}',
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
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

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Manager':
      case 'Head Chef':
        return const Color(0xFF4CAF50);
      case 'Sous Chef':
      case 'Pastry Chef':
        return const Color(0xFF2196F3);
      case 'Server':
        return const Color(0xFFFFC107);
      case 'Cashier':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF757575);
    }
  }
}
