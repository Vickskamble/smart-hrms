import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/data/repositories/base_repository.dart';

class AttendanceRepository extends BaseRepository {
  Future<QuerySnapshot> getTodayAttendance(String companyId, String employeeId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    return await attendanceCollection(companyId)
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isEqualTo: today)
        .get();
  }

  Future<QuerySnapshot> getMonthlyAttendance(String companyId, String employeeId, DateTime month) async {
    final monthStr = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    return await attendanceCollection(companyId)
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isGreaterThanOrEqualTo: '$monthStr-01')
        .where('date', isLessThanOrEqualTo: '$monthStr-31')
        .get();
  }

  Future<QuerySnapshot> getAttendanceByStatus(String companyId, String status) async {
    return await attendanceCollection(companyId)
        .where('status', isEqualTo: status)
        .get();
  }

  Stream<QuerySnapshot> watchAttendanceByStatus(String companyId, String status) {
    return attendanceCollection(companyId)
        .where('status', isEqualTo: status.toLowerCase())
        .snapshots();
  }

  Stream<QuerySnapshot> watchMonthlyAttendance(String companyId, String employeeId, DateTime month) {
    final monthStr = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    return attendanceCollection(companyId)
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isGreaterThanOrEqualTo: '$monthStr-01')
        .where('date', isLessThanOrEqualTo: '$monthStr-31')
        .snapshots();
  }

  Stream<QuerySnapshot> watchCompanyAttendance(String companyId) {
    return attendanceCollection(companyId)
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<DocumentReference> punchIn({
    required String companyId,
    required String employeeId,
    required String name,
    required DateTime punchInTime,
  }) async {
    final today = punchInTime.toIso8601String().split('T').first;
    final isLate = punchInTime.hour > 9 || (punchInTime.hour == 9 && punchInTime.minute > 30);
    return await attendanceCollection(companyId).add({
      'employeeId': employeeId,
      'name': name,
      'date': today,
      'punchIn': Timestamp.fromDate(punchInTime),
      'punchOut': null,
      'status': isLate ? 'late' : 'present',
      'isLate': isLate,
    });
  }

  Future<void> punchOut({
    required String companyId,
    required String attendanceDocId,
    required DateTime punchOutTime,
  }) async {
    await attendanceCollection(companyId).doc(attendanceDocId).update({
      'punchOut': Timestamp.fromDate(punchOutTime),
      'status': 'present',
    });
  }

  Future<void> updatePunch({
    required String companyId,
    required String employeeId,
    required String date,
    DateTime? punchIn,
    DateTime? punchOut,
  }) async {
    final query = await attendanceCollection(companyId)
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isEqualTo: date)
        .get();

    final Map<String, dynamic> payload = {
      'employeeId': employeeId,
      'date': date,
      'manualEdit': true,
      'editedAt': FieldValue.serverTimestamp(),
    };

    if (punchIn != null) {
      payload['punchIn'] = Timestamp.fromDate(punchIn);
      final isLate = punchIn.hour > 9 || (punchIn.hour == 9 && punchIn.minute > 30);
      payload['isLate'] = isLate;
      payload['status'] = isLate ? 'late' : 'present';
    }
    if (punchOut != null) {
      payload['punchOut'] = Timestamp.fromDate(punchOut);
      payload['status'] = 'present';
    }

    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.update(payload);
    } else {
      await attendanceCollection(companyId).add(payload);
    }
  }

  Future<void> fixMissedPunch({
    required String companyId,
    required String docId,
    required DateTime checkOut,
  }) async {
    await attendanceCollection(companyId).doc(docId).update({
      'status': 'present',
      'punchOut': Timestamp.fromDate(checkOut),
    });
  }

  Future<void> markAbsent({
    required String companyId,
    required String employeeId,
    required String name,
    required String date,
  }) async {
    await attendanceCollection(companyId).add({
      'employeeId': employeeId,
      'name': name,
      'date': date,
      'punchIn': null,
      'punchOut': null,
      'status': 'absent',
      'isLate': false,
    });
  }

  Stream<QuerySnapshot> watchAttendanceStats(String companyId, DateTime month) {
    final monthStr = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    return attendanceCollection(companyId)
        .where('date', isGreaterThanOrEqualTo: '$monthStr-01')
        .where('date', isLessThanOrEqualTo: '$monthStr-31')
        .snapshots();
  }
}