import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core.dart';
import 'package:myapp/data/providers.dart';
import 'package:myapp/core/theme/theme_provider.dart';
import 'admin_dashboard.dart';
import 'admin_employee_management.dart';
import 'admin_management.dart';
import 'admin_requests.dart';
import 'admin_more.dart';
import 'import_dashboard.dart';
import 'import_preview_screen.dart';
import 'import_result_screen.dart';
import 'import_history_screen.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => CompanyProvider()..loadCompanyId()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const _AdminShellView(),
    );
  }
}

class _AdminShellView extends StatefulWidget {
  const _AdminShellView();

  @override
  State<_AdminShellView> createState() => _AdminShellViewState();
}

class _AdminShellViewState extends State<_AdminShellView> {
  int _index = 0;
  final _screens = [
    const AdminDashboard(),
    const AdminEmployeeManagement(),
    const AdminManagement(initialFilter: 'All'),
    const AdminRequests(),
    const AdminMore(),
    const ImportDashboard(),
    const ImportPreviewScreen(),
    const ImportResultScreen(),
    const ImportHistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        return Scaffold(
          backgroundColor: AppColors.bg,
          body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          bottomNavigationBar: isDesktop ? null : _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: AppColors.surface,
          extended: true,
          selectedIconTheme: const IconThemeData(color: AppColors.accent),
          unselectedIconTheme: const IconThemeData(
            color: AppColors.textSecondary,
          ),
          selectedLabelTextStyle: const TextStyle(
            color: AppColors.accent,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelTextStyle: const TextStyle(
            color: AppColors.textSecondary,
          ),
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: Text('Dashboard'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: Text('Employees'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: Text('Management'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.request_page_outlined),
              selectedIcon: Icon(Icons.request_page),
              label: Text('Requests'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.more_horiz_outlined),
              selectedIcon: Icon(Icons.more_horiz),
              label: Text('More'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.upload_file_outlined),
              selectedIcon: Icon(Icons.upload_file),
              label: Text('Import'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: Text('History'),
            ),
          ],
        ),
        const VerticalDivider(thickness: 1, color: AppColors.border),
        Expanded(child: _screens[_index]),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return IndexedStack(index: _index, children: _screens);
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _index,
      onTap: (i) => setState(() => _index = i),
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.textSecondary,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_outline),
          activeIcon: Icon(Icons.people),
          label: 'Employees',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_outline),
          activeIcon: Icon(Icons.people),
          label: 'Management',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.request_page_outlined),
          activeIcon: Icon(Icons.request_page),
          label: 'Requests',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.more_horiz_outlined),
          activeIcon: Icon(Icons.more_horiz),
          label: 'More',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.upload_file_outlined),
          activeIcon: Icon(Icons.upload_file),
          label: 'Import',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_outlined),
          activeIcon: Icon(Icons.history),
          label: 'History',
        ),
      ],
    );
  }
}
