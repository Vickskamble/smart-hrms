import 'package:flutter/material.dart';

import 'package:myapp/screens/auth/employee_home.dart';
import 'package:myapp/screens/auth/employee_explore_screen.dart';
import 'package:myapp/screens/auth/employee_report_screen.dart';
import 'package:myapp/screens/auth/profile_screen.dart';

class EmployeeMainScreen extends StatefulWidget {
  const EmployeeMainScreen({super.key});

  @override
  State<EmployeeMainScreen> createState() => _EmployeeMainScreenState();
}

class _EmployeeMainScreenState extends State<EmployeeMainScreen> {
  int index = 0;

  // ✅ IMPORTANT: 4 screens hone chahiye (bottom nav ke equal)
  final List<Widget> screens = [
    const HomeScreen(userName: ""),
    const EmployeeExploreScreen(),
    const EmployeeReportScreen(),
    const ProfileScreen(),
  ];
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      // ✅ SAFE CHECK (extra protection)
      body: screens[index],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.white54,

        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: "Explore"),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: "Reports",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
