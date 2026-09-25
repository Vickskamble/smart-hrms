import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart'; // IMPORT THIS
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/admin/admin_add_employee.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/admin_management.dart';
import 'screens/admin/import_dashboard.dart';
import 'screens/admin/import_preview_screen.dart';
import 'screens/admin/import_result_screen.dart';
import 'screens/admin/import_history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // CRITICAL: Initialize intl for Android
  await initializeDateFormatting('en_US', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Builder(
        builder: (context) {
          final themeProvider = Provider.of<ThemeProvider>(context);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Admin Dashboard',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            initialRoute: '/login',
            routes: {
              '/login': (context) => const LoginScreen(),
              '/admin': (context) => const AdminShell(),
              '/admin-add-employee': (context) => const AdminAddEmployee(),
              '/admin-dashboard': (context) => const AdminDashboard(),
              '/admin-management': (context) => const AdminManagement(initialFilter: 'All'),
              '/admin-import': (context) => const ImportDashboard(),
              '/import-preview': (context) => const ImportPreviewScreen(),
              '/import-result': (context) => const ImportResultScreen(),
              '/import-history': (context) => const ImportHistoryScreen(),
            },
          );
        },
      ),
    );
  }
}
