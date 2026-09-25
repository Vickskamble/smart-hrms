import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:myapp/data/repositories/base_repository.dart';

class UserRepository extends BaseRepository {
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = currentUser;
    if (user == null) return null;
    final doc = await userDoc(user.uid).get(const GetOptions(source: Source.server));
    if (!doc.exists) return null;
    return doc.data() as Map<String, dynamic>;
  }

  Future<String?> getUserRole() async {
    final user = currentUser;
    if (user == null) return null;
    final doc = await userDoc(user.uid).get(const GetOptions(source: Source.server));
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>?;
    return data?['role'] as String?;
  }

  Future<Map<String, dynamic>?> getFullUserData() async {
    final user = currentUser;
    if (user == null) return null;
    final doc = await userDoc(user.uid).get(const GetOptions(source: Source.server));
    if (!doc.exists) return null;
    return doc.data() as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getEmployeeStats(String companyId) async {
    final snap = await firestore
        .collection('users')
        .where('companyId', isEqualTo: companyId)
        .get();

    int total = 0;
    int active = 0;
    int inactive = 0;

    for (var doc in snap.docs) {
      final data = doc.data();
      final role = data['role'] as String?;
      if (role?.toLowerCase() == 'employee' || role?.toLowerCase() == 'staff') {
        total++;
        final status = data['currentStatus'] as String?;
        final isActive = data['isActive'] as bool?;
        if (status == 'Active' || isActive == true) {
          active++;
        } else {
          inactive++;
        }
      }
    }

    return {
      'total': total,
      'active': active,
      'inactive': inactive,
    };
  }

  Future<void> createEmployeeProfile({
    required String companyId,
    required String email,
    required String password,
    required String name,
    required String empId,
    required String phone,
    required String? dept,
    required String? hod,
    required String salary,
    required String address,
    required String? gender,
    required String? bloodGroup,
    required String? emergencyContact,
    required String? designation,
    required String? dateOfBirth,
    required String? dateOfJoining,
    required String? profilePic,
  }) async {
    // Create secondary Firebase app to preserve admin session
    final secondaryApp = await Firebase.initializeApp(
      name: 'secondaryApp',
      options: Firebase.app().options,
    );

    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final secondaryFirestore = FirebaseFirestore.instanceFor(app: secondaryApp);

      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = cred.user!.uid;
      final batch = secondaryFirestore.batch();

      // Create user in root users collection only (per spec)
      batch.set(secondaryFirestore.collection('users').doc(uid), {
        'uid': uid,
        'name': name.trim(),
        'empId': empId.trim(),
        'phone': phone.trim(),
        'dept': dept,
        'hod': hod ?? 'Not Assigned',
        'basicSalary': double.tryParse(salary.trim()) ?? 0,
        'address': address.trim(),
        'role': 'Employee',
        'companyId': companyId,
        'employeeId': empId.trim(),
        'currentStatus': 'Active',
        'gender': gender,
        'bloodGroup': bloodGroup,
        'emergencyContact': emergencyContact,
        'designation': designation,
        'dateOfBirth': dateOfBirth,
        'dateOfJoining': dateOfJoining,
        'profilePic': profilePic,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUser?.uid,
      });

      await batch.commit();
    } finally {
      // Clean up secondary app
      await secondaryApp.delete();
    }
  }

  Stream<DocumentSnapshot> watchCurrentUser() {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');
    return userDoc(user.uid).snapshots();
  }

  Future<QuerySnapshot> getEmployees(String companyId) async {
    return await firestore
        .collection('users')
        .where('companyId', isEqualTo: companyId)
        .where('role', isEqualTo: 'Employee')
        .get();
  }

  Stream<QuerySnapshot> watchEmployees(String companyId) {
    return firestore
        .collection('users')
        .where('companyId', isEqualTo: companyId)
        .where('role', isEqualTo: 'Employee')
        .snapshots();
  }

  Stream<QuerySnapshot> watchEmployeesWithDetails(String companyId) {
    return firestore
        .collection('users')
        .where('companyId', isEqualTo: companyId)
        .where('role', isEqualTo: 'Employee')
        .orderBy('name')
        .snapshots();
  }

  Future<int> getEmployeeCount(String companyId) async {
    final snap = await firestore
        .collection('users')
        .where('companyId', isEqualTo: companyId)
        .where('role', isEqualTo: 'Employee')
        .get();
    return snap.docs.length;
  }

  Future<void> updateEmployeeStatusBool(
    String companyId,
    String uid,
    bool isActive,
  ) async {
    await userDoc(uid).update({'isActive': isActive});
  }

  Future<void> updateEmployee(
    String companyId,
    String docId,
    String name,
    String empId,
    String phone,
    String salary,
    String dept,
    String hod,
  ) async {
    await userDoc(docId).update({
      'name': name,
      'empId': empId,
      'phone': phone,
      'basicSalary': double.tryParse(salary) ?? 0,
      'dept': dept,
      'hod': hod,
    });
  }

  Future<void> resetEmployeePassword(
    String companyId,
    String uid,
    String newPassword,
  ) async {
    await userDoc(uid).update({'password': newPassword});
  }

  Future<void> deleteEmployee(String companyId, String uid) async {
    await userDoc(uid).delete();
    
    // Also delete from Auth (requires admin SDK, skip for client-side)
  }
}