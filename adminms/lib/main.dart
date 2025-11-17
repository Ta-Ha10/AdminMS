import 'package:adminms/screens/Request.dart';
import 'package:adminms/screens/supplier.dart';
import 'package:firebase_core/firebase_core.dart';
//import 'package:rrms/screens/Request.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/Inventory.dart';
import 'screens/employee.dart';
import 'screens/orders.dart';
//import 'screens/dashboard.dart';
//import 'screens/supplier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/inventory',
      onGenerateRoute: (settings) {
        Widget page = const Scaffold(body: Center(child: Text('Page not found')));
        switch (settings.name) {
          //case '/dashboard':
            //page = DashboardPage();
            //break;
          case '/inventory':
            page = InventoryPage();
            break;
          case '/supplier':
            page = SupplierPage();
            break;
          case '/RequestItemPage':
            page = RequestItemPage();
            break;
          case '/employee':
            page = EmployeePage();
            break;
          case '/orders':
            page = OrdersPage();
            break;
        }

        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (_, __, ___) => page,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
