import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class BaseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FirebaseFirestore get firestore => _firestore;
  FirebaseAuth get auth => _auth;

  User? get currentUser => _auth.currentUser;
  String get currentUid => _auth.currentUser?.uid ?? '';

  DocumentReference userDoc(String uid) => _firestore.collection('users').doc(uid);
  CollectionReference get companiesCollection => _firestore.collection('companies');
  DocumentReference companyDoc(String companyId) => _firestore.collection('companies').doc(companyId);
  CollectionReference attendanceCollection(String companyId) => companyDoc(companyId).collection('attendance');
  CollectionReference leavesCollection(String companyId) => companyDoc(companyId).collection('leaves');
  CollectionReference employeesCollection(String companyId) => companyDoc(companyId).collection('employees');

  Future<String> getCompanyId() async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');
    final doc = await userDoc(user.uid).get();
    return doc['companyId'] as String? ?? '';
  }
}