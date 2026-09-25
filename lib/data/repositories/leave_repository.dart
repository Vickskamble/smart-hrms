import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/data/repositories/base_repository.dart';

class LeaveRepository extends BaseRepository {
  Stream<QuerySnapshot> watchPendingLeaves(String companyId) {
    return leavesCollection(companyId)
        .where('status', isEqualTo: 'pending')
        .orderBy('appliedOn', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> watchLeavesByStatus(String companyId, String status) {
    return leavesCollection(companyId)
        .where('status', isEqualTo: status)
        .orderBy('appliedOn', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> watchAllLeaves(String companyId) {
    return leavesCollection(companyId)
        .orderBy('appliedOn', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> watchEmployeeLeaves(String companyId, String employeeId) {
    return leavesCollection(companyId)
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('appliedOn', descending: true)
        .snapshots();
  }

  Future<void> createLeaveRequest({
    required String companyId,
    required String employeeId,
    required String employeeName,
    required String reason,
    required DateTime from,
    required DateTime to,
    required int days,
    required String type,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await leavesCollection(companyId).add({
      'employeeId': employeeId,
      'name': employeeName,
      'uid': user.uid,
      'type': type,
      'reason': reason,
      'from': Timestamp.fromDate(from),
      'to': Timestamp.fromDate(to),
      'days': days,
      'status': 'pending',
      'appliedOn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateLeaveStatus({
    required String companyId,
    required String leaveDocId,
    required String newStatus,
    String? userId,
    String? reviewedBy,
    String? reviewNote,
  }) async {
    final updateData = <String, dynamic>{
      'status': newStatus,
      'reviewedOn': FieldValue.serverTimestamp(),
    };
    if (reviewedBy != null) updateData['reviewedBy'] = reviewedBy;
    if (reviewNote != null) updateData['reviewNote'] = reviewNote;

    await leavesCollection(companyId).doc(leaveDocId).update(updateData);

    if (newStatus == 'approved' && userId != null) {
      await firestore.collection('users').doc(userId).update({'status': 'On Leave'});
    } else if (newStatus == 'rejected' && userId != null) {
      await firestore.collection('users').doc(userId).update({'status': 'Active'});
    }
  }

  Future<void> updateLeaveStatusWithDocId({
    required String companyId,
    required String docId,
    required String newStatus,
    String? reviewedBy,
    String? reviewNote,
  }) async {
    final updateData = <String, dynamic>{
      'status': newStatus,
      'reviewedOn': FieldValue.serverTimestamp(),
    };
    if (reviewedBy != null) updateData['reviewedBy'] = reviewedBy;
    if (reviewNote != null) updateData['reviewNote'] = reviewNote;

    await leavesCollection(companyId).doc(docId).update(updateData);
  }
}