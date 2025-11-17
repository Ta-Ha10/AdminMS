import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../component/colors.dart';
import '../widget/top_bar.dart';
import '../widget/side_bar.dart';

class Employee {
  final String id;
  final String name;
  final String phone;
  final String role;
  final double salary;
  final DateTime hireDate;

  Employee({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.salary,
    required this.hireDate,
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
      hireDate: (data['hireDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
  String searchQuery = '';

  // Fake employee data
  final List<Employee> fakeEmployees = [
    Employee(
      id: '1',
      name: 'Ahmed Hassan',
      phone: '+966501234567',
      role: 'Manager',
      salary: 8000,
      hireDate: DateTime(2020, 3, 15),
    ),
    Employee(
      id: '2',
      name: 'Fatima Al-Rashid',
      phone: '+966502345678',
      role: 'Head Chef',
      salary: 7500,
      hireDate: DateTime(2019, 7, 22),
    ),
    Employee(
      id: '3',
      name: 'Mohammed Ali',
      phone: '+966503456789',
      role: 'Sous Chef',
      salary: 5500,
      hireDate: DateTime(2021, 1, 10),
    ),
    Employee(
      id: '4',
      name: 'Layla Omar',
      phone: '+966504567890',
      role: 'Pastry Chef',
      salary: 5000,
      hireDate: DateTime(2022, 5, 18),
    ),
    Employee(
      id: '5',
      name: 'Karim Ibrahim',
      phone: '+966505678901',
      role: 'Server',
      salary: 3500,
      hireDate: DateTime(2022, 9, 3),
    ),
    Employee(
      id: '6',
      name: 'Sara Ahmed',
      phone: '+966506789012',
      role: 'Cashier',
      salary: 3200,
      hireDate: DateTime(2023, 2, 14),
    ),
    Employee(
      id: '7',
      name: 'Hassan Mahmoud',
      phone: '+966507890123',
      role: 'Server',
      salary: 3500,
      hireDate: DateTime(2023, 6, 7),
    ),
    Employee(
      id: '8',
      name: 'Noor Al-Kareem',
      phone: '+966508901234',
      role: 'Manager',
      salary: 8500,
      hireDate: DateTime(2021, 11, 20),
    ),
  ];

  List<Employee> getFilteredEmployees() {
    if (searchQuery.isEmpty) {
      return fakeEmployees;
    }
    return fakeEmployees
        .where((emp) =>
            emp.name.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

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
                  child: SingleChildScrollView(
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
                        // Search Bar
                        TextField(
                          onChanged: (value) {
                            setState(() {
                              searchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search by employee name...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const Gap(16),
                        // Results info
                        Text(
                          'Found ${getFilteredEmployees().length} employee(s)',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const Gap(12),
                        // Table
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(
                                    label: Text('Name',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Phone',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Role',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Hire Date',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Salary (EGP)',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                              ],
                              rows: getFilteredEmployees().map((employee) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(employee.name)),
                                    DataCell(Text(employee.phone)),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getRoleColor(employee.role)
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          employee.role,
                                          style: TextStyle(
                                            color: _getRoleColor(
                                                employee.role),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(
                                        '${employee.hireDate.day}/${employee.hireDate.month}/${employee.hireDate.year}')),
                                    DataCell(
                                      Text(
                                        'EGP ${employee.salary.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
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
