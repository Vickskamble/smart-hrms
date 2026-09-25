import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class BaseKhataRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FirebaseFirestore get firestore => _firestore;
  FirebaseAuth get auth => _auth;

  User? get currentUser => _auth.currentUser;
  String get currentUid => _auth.currentUser?.uid ?? '';

  DocumentReference userDoc(String uid) => _firestore.collection('users').doc(uid);
  DocumentReference businessDoc(String businessId) => _firestore.collection('businesses').doc(businessId);
  DocumentReference customerDoc(String customerId) => _firestore.collection('customers').doc(customerId);
  DocumentReference transactionDoc(String transactionId) => _firestore.collection('transactions').doc(transactionId);
  CollectionReference get customersCollection => _firestore.collection('customers');
  CollectionReference get transactionsCollection => _firestore.collection('transactions');

  Future<String?> getBusinessId() async {
    final user = currentUser;
    if (user == null) return null;
    final doc = await userDoc(user.uid).get();
    return doc['businessId'] as String?;
  }
}
