import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseSeeder {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Random _random = Random();

  String? _companyId;

  Future<void> seed({
    required String companyId,
    required String adminEmail,
    required String adminPassword,
    required String adminName,
  }) async {
    _companyId = companyId;

    debugPrint('=== Starting Database Seed ===');
    debugPrint('Company ID: $companyId');
    debugPrint('Admin Email: $adminEmail');

    await _createDepartments();
    await _createAdminUser(adminEmail, adminPassword, adminName);
    await _createEmployees();
    await _createAttendance();
    await _createLeaves();
    await _createAnnouncements();

    debugPrint('=== Database Seed Complete ===');
  }

  Future<void> seedAll({
    required String companyId,
    required String adminUid,
  }) async {
    _companyId = companyId;

    debugPrint('=== Seeding database for company: $companyId ===');

    await _seedAdminUserDoc(adminUid);
    await _createDepartments();
    await _createEmployees();
    await _createAttendance();
    await _createLeaves();
    await _createSalarySlips();
    await _createAnnouncements();

    debugPrint('=== Seed Complete ===');
  }

  Future<void> _seedAdminUserDoc(String uid) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'name': 'Admin User',
      'email': _auth.currentUser?.email ?? 'admin@company.com',
      'role': 'Admin',
      'companyId': _companyId,
      'currentStatus': 'Active',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint('  users/$uid - Admin user document created');
  }

  Future<void> _createAdminUser(
    String email,
    String password,
    String name,
  ) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;

      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
        'role': 'Admin',
        'companyId': _companyId,
        'currentStatus': 'Active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _createCompanyDoc(uid);
      debugPrint('  Admin created: $email (UID: $uid)');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        debugPrint('  Admin already exists, updating user doc...');
        final user = _auth.currentUser;
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'name': name,
            'email': email,
            'role': 'Admin',
            'companyId': _companyId,
            'currentStatus': 'Active',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          await _createCompanyDoc(user.uid);
        }
      } else {
        rethrow;
      }
    }
  }

  Future<void> _createCompanyDoc(String adminUid) async {
    final companyRef = _firestore.collection('companies').doc(_companyId);
    final existing = await companyRef.get();
    if (existing.exists) {
      debugPrint('  Company doc already exists, skipping...');
      return;
    }
    await companyRef.set({
      'name': 'WorkForce Corp',
      'address': '123 Business Park, Mumbai, Maharashtra 400001',
      'phone': '+91-22-12345678',
      'email': 'info@workforcecorp.com',
      'adminUid': adminUid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('  companies/$_companyId - Company document created');
  }

  Future<void> _createDepartments() async {
    final depts = [
      {'name': 'Production', 'description': 'Manufacturing and production operations'},
      {'name': 'QC', 'description': 'Quality control and assurance'},
      {'name': 'QA', 'description': 'Quality analysis and testing'},
      {'name': 'Software', 'description': 'Software development and IT'},
      {'name': 'Accounts', 'description': 'Finance and accounting'},
      {'name': 'HR', 'description': 'Human resources and personnel management'},
    ];

    for (final dept in depts) {
      await _firestore
          .collection('companies')
          .doc(_companyId)
          .collection('departments')
          .add({
        ...dept,
        'hod': '',
        'employeeCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    debugPrint('  Departments - 6 departments created');
  }

  Future<void> _createEmployees() async {
    final employees = [
      {
        'name': 'Rahul Sharma',
        'empId': 'GKH-001',
        'email': 'rahul.sharma@workforcecorp.com',
        'phone': '9876543210',
        'address': '42, Sector 12, Vashi, Navi Mumbai',
        'dept': 'Production',
        'hod': 'Mr. Sharma',
        'basicSalary': 45000.0,
        'role': 'Employee',
        'currentStatus': 'Active',
        'isActive': true,
      },
      {
        'name': 'Priya Patel',
        'empId': 'GKH-002',
        'email': 'priya.patel@workforcecorp.com',
        'phone': '9876543211',
        'address': '15, Green Park, Andheri East, Mumbai',
        'dept': 'QC',
        'hod': 'Mr. Patil',
        'basicSalary': 38000.0,
        'role': 'Employee',
        'currentStatus': 'Active',
        'isActive': true,
      },
      {
        'name': 'Amit Kumar',
        'empId': 'GKH-003',
        'email': 'amit.kumar@workforcecorp.com',
        'phone': '9876543212',
        'address': '7, Lake View, Powai, Mumbai',
        'dept': 'Software',
        'hod': 'Mr. Verma',
        'basicSalary': 65000.0,
        'role': 'Employee',
        'currentStatus': 'Active',
        'isActive': true,
      },
      {
        'name': 'Sneha Deshmukh',
        'empId': 'GKH-004',
        'email': 'sneha.deshmukh@workforcecorp.com',
        'phone': '9876543213',
        'address': '88, Palm Avenue, Bandra West, Mumbai',
        'dept': 'HR',
        'hod': 'Ms. Deshmukh',
        'basicSalary': 52000.0,
        'role': 'Employee',
        'currentStatus': 'Active',
        'isActive': true,
      },
      {
        'name': 'Vikram Joshi',
        'empId': 'GKH-005',
        'email': 'vikram.joshi@workforcecorp.com',
        'phone': '9876543214',
        'address': '23, Rose Colony, Thane West',
        'dept': 'Accounts',
        'hod': 'Mr. Sharma',
        'basicSalary': 41000.0,
        'role': 'Employee',
        'currentStatus': 'On Leave',
        'isActive': true,
      },
    ];

    for (final emp in employees) {
      try {
        final cred = await _auth.createUserWithEmailAndPassword(
          email: emp['email'] as String,
          password: 'password123',
        );
        final uid = cred.user!.uid;

        final batch = _firestore.batch();

        batch.set(_firestore.collection('users').doc(uid), {
          ...emp,
          'uid': uid,
          'companyId': _companyId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        batch.set(
          _firestore
              .collection('companies')
              .doc(_companyId)
              .collection('employees')
              .doc(uid),
          {
            ...emp,
            'uid': uid,
            'companyId': _companyId,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );

        await batch.commit();
        debugPrint('  Employee created: ${emp['name']} (${emp['empId']}) - Password: password123');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          debugPrint('  Employee ${emp['name']} already exists, skipping...');
        } else {
          debugPrint('  Error creating employee ${emp['name']}: $e');
        }
      }
    }
  }

  Future<void> _createAttendance() async {
    final employees = await _firestore
        .collection('companies')
        .doc(_companyId)
        .collection('employees')
        .get();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final emp in employees.docs) {
      final empData = emp.data();
      final batch = _firestore.batch();

      for (int day = 0; day < 30; day++) {
        final date = today.subtract(Duration(days: day));
        if (date.weekday == DateTime.sunday) continue;

        final isPresent = _random.nextDouble() > 0.15;
        final isLate = isPresent && _random.nextDouble() < 0.2;

        final punchInHour = isLate ? 9 : 8;
        final punchInMin = isLate ? _random.nextInt(45) + 15 : _random.nextInt(30) + 30;

        final attRef = _firestore
            .collection('companies')
            .doc(_companyId)
            .collection('attendance')
            .doc();

        batch.set(attRef, {
          'employeeId': emp.id,
          'employeeName': empData['name'] ?? 'Unknown',
          'date': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          'punchIn': DateTime(date.year, date.month, date.day, punchInHour, punchInMin),
          'punchOut': DateTime(date.year, date.month, date.day, 17, _random.nextInt(30) + 30),
          'status': isPresent ? (isLate ? 'late' : 'present') : 'absent',
          'isLate': isLate,
          'lateMinutes': isLate ? _random.nextInt(45) + 15 : 0,
          'workingHours': isPresent ? 8.0 + _random.nextDouble() : 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('  Attendance: 30 records for ${empData['name']}');
    }
  }

  Future<void> _createLeaves() async {
    final employees = await _firestore
        .collection('companies')
        .doc(_companyId)
        .collection('employees')
        .get();

    final leaveTypes = ['Casual', 'Sick', 'Annual'];
    final statuses = ['pending', 'approved', 'rejected'];

    final now = DateTime.now();

    for (final emp in employees.docs) {
      final empData = emp.data();
      final batch = _firestore.batch();

      for (int i = 0; i < 3; i++) {
        final leaveType = leaveTypes[_random.nextInt(leaveTypes.length)];
        final status = statuses[_random.nextInt(statuses.length)];
        final days = _random.nextInt(4) + 1;
        final fromDate = now.subtract(Duration(days: _random.nextInt(60) + 5));

        final leaveRef = _firestore
            .collection('companies')
            .doc(_companyId)
            .collection('leaves')
            .doc();

        batch.set(leaveRef, {
          'employeeId': emp.id,
          'employeeName': empData['name'] ?? 'Unknown',
          'type': leaveType,
          'from': fromDate,
          'to': fromDate.add(Duration(days: days)),
          'days': days,
          'reason': '$leaveType leave request for $days day${days > 1 ? 's' : ''}',
          'status': status,
          'appliedOn': fromDate.subtract(Duration(days: _random.nextInt(7) + 1)),
          if (status != 'pending') ...{
            'reviewedBy': 'admin-uid',
            'reviewedOn': DateTime.now(),
            if (status == 'rejected') 'rejectionReason': 'Insufficient balance',
          },
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('  Leaves: 3 records for ${empData['name']}');
    }
  }

  Future<void> _createSalarySlips() async {
    final employees = await _firestore
        .collection('companies')
        .doc(_companyId)
        .collection('employees')
        .get();

    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final prevMonth = now.month == 1
        ? '${now.year - 1}-12'
        : '${now.year}-${(now.month - 1).toString().padLeft(2, '0')}';

    for (final month in [prevMonth, currentMonth]) {
      for (final emp in employees.docs) {
        final empData = emp.data();
        final basicSalary = (empData['basicSalary'] as num?)?.toDouble() ?? 40000;

        final presentDays = _random.nextInt(5) + 22;
        final absentDays = 30 - presentDays;
        final lateDays = _random.nextInt(5);
        final leaveDays = _random.nextInt(3);

        final perDay = basicSalary / 30;
        final absentDeduction = absentDays * perDay;
        final lateDeduction = (lateDays ~/ 3) * (perDay * 0.5);
        final leaveDeduction = leaveDays * perDay * 0.5;
        final netSalary = basicSalary - (absentDeduction + lateDeduction + leaveDeduction);

        await _firestore
            .collection('companies')
            .doc(_companyId)
            .collection('salarySlips')
            .add({
          'employeeId': emp.id,
          'employeeName': empData['name'] ?? 'Unknown',
          'month': month,
          'basicSalary': basicSalary,
          'presentDays': presentDays,
          'absentDays': absentDays,
          'lateDays': lateDays,
          'leaveDays': leaveDays,
          'absentDeduction': absentDeduction,
          'lateDeduction': lateDeduction,
          'leaveDeduction': leaveDeduction,
          'allowances': 2000,
          'netSalary': netSalary,
          'status': month == currentMonth ? 'pending' : 'paid',
          if (month != currentMonth) 'paidOn': DateTime.now(),
          'generatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    debugPrint('  SalarySlips: created for all employees (2 months)');
  }

  Future<void> _createAnnouncements() async {
    final announcements = [
      {
        'title': 'Company Holiday on Jan 26',
        'message': 'Office will remain closed on January 26th on account of Republic Day.',
        'type': 'info',
        'targetAudience': 'all',
      },
      {
        'title': 'Annual Performance Review',
        'message': 'Annual performance reviews will begin from next month. Please prepare your self-assessment reports.',
        'type': 'info',
        'targetAudience': 'all',
      },
      {
        'title': 'Server Maintenance',
        'message': 'The HR system will be down for maintenance on Saturday from 10 PM to 2 AM.',
        'type': 'warning',
        'targetAudience': 'all',
      },
    ];

    for (final announcement in announcements) {
      await _firestore
          .collection('companies')
          .doc(_companyId)
          .collection('announcements')
          .add({
        ...announcement,
        'createdBy': _auth.currentUser?.uid ?? 'admin',
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
    }
    debugPrint('  Announcements: 3 created');
  }

  static Future<bool> checkIfSeeded(String companyId) async {
    final snap = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('employees')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }
}
