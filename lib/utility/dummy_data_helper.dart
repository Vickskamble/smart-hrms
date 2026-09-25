import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class DummyDataHelper {
  static Future<void> generate30DaysData({
    required String companyId,
    required String employeeId,
    required String employeeName,
  }) async {
    final firestore = FirebaseFirestore.instance;

    final attendanceRef = firestore
        .collection('companies')
        .doc(companyId)
        .collection('attendance');

    final leavesRef = firestore
        .collection('companies')
        .doc(companyId)
        .collection('leaves');

    final random = Random();

    final batch = firestore.batch();

    // ==========================
    // ATTENDANCE (30 DAYS)
    // ==========================

    for (int i = 0; i < 30; i++) {
      final date = DateTime.now().subtract(Duration(days: i));

      // Sundays skip
      if (date.weekday == DateTime.sunday) continue;

      final dateString =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      // 20% chance late punch
      final bool isLate = random.nextInt(100) < 20;

      final punchIn = DateTime(
        date.year,
        date.month,
        date.day,
        isLate ? 10 : 9,
        isLate ? (10 + random.nextInt(40)) : random.nextInt(20),
      );

      // 10% chance missed punch-out
      final bool missedPunch = random.nextInt(100) < 10;

      DateTime? punchOut;

      if (!missedPunch) {
        punchOut = DateTime(
          date.year,
          date.month,
          date.day,
          18,
          random.nextInt(30),
        );
      }

      final doc = attendanceRef.doc();

      batch.set(doc, {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'date': dateString,
        'punchIn': Timestamp.fromDate(punchIn),
        'punchOut': punchOut != null ? Timestamp.fromDate(punchOut) : null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // ==========================
    // LEAVES
    // ==========================

    final leaveData = [
      {
        'type': 'Casual',
        'status': 'approved',
        'days': 2,
        'reason': 'Family Function',
      },
      {
        'type': 'Sick',
        'status': 'approved',
        'days': 1,
        'reason': 'Viral Fever',
      },
      {
        'type': 'Earned',
        'status': 'pending',
        'days': 3,
        'reason': 'Personal Work',
      },
      {
        'type': 'Casual',
        'status': 'rejected',
        'days': 1,
        'reason': 'Outstation Travel',
      },
    ];

    for (final leave in leaveData) {
      final from = DateTime.now().subtract(Duration(days: random.nextInt(25)));

      final to = from.add(Duration(days: (leave['days'] as int) - 1));

      final doc = leavesRef.doc();

      batch.set(doc, {
        'employeeId': employeeId,
        'name': employeeName,
        'type': leave['type'],
        'reason': leave['reason'],
        'status': leave['status'],
        'days': leave['days'],
        'from': Timestamp.fromDate(from),
        'to': Timestamp.fromDate(to),
        'appliedOn': Timestamp.fromDate(from),
      });
    }

    await batch.commit();
  }
}
