// Standalone seed entry point
// Run: flutter run -t lib/seed_main.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:myapp/services/database_seeder.dart';
import '../firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint('=== Firebase Seed Tool ===');
  debugPrint('');

  final companyId = _prompt('Enter Company ID (e.g., "comp-001"): ');
  final adminEmail = _prompt('Enter Admin Email: ');
  final adminPassword = _prompt('Enter Admin Password: ');
  final adminName = _prompt('Enter Admin Name: ');

  debugPrint('');
  debugPrint('Starting seed with:');
  debugPrint('  Company ID: $companyId');
  debugPrint('  Admin Email: $adminEmail');
  debugPrint('  Admin Name: $adminName');
  debugPrint('');

  try {
    final seeder = DatabaseSeeder();
    await seeder.seed(
      companyId: companyId,
      adminEmail: adminEmail,
      adminPassword: adminPassword,
      adminName: adminName,
    );

    debugPrint('');
    debugPrint('✓ Database seeded successfully!');
    debugPrint('  Sample employee passwords: password123');
  } catch (e) {
    debugPrint('✗ Seed failed: $e');
  }

  debugPrint('');
  debugPrint('Press Enter to exit...');
  stdin.readLineSync();
}

String _prompt(String message) {
  stdout.write(message);
  return stdin.readLineSync()?.trim() ?? '';
}
