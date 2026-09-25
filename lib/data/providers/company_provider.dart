import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyProvider extends ChangeNotifier {
  String? _companyId;
  bool _loading = true;
  String? _error;

  String? get companyId => _companyId;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get hasCompany => _companyId != null && _companyId!.isNotEmpty;

  Future<void> loadCompanyId() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _error = 'User not authenticated';
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        _companyId = doc.data()?['companyId'] as String? ?? '';
      } else {
        _error = 'User document not found';
      }
    } catch (e) {
      _error = 'Failed to load company: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    _companyId = null;
    _loading = true;
    _error = null;
    notifyListeners();
  }
}
