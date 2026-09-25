import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/data/repositories/user_repository.dart';

class AuthProvider extends ChangeNotifier {
  String? _uid;
  String? _email;
  String? _role;
  String? _companyId;
  String? _currentStatus;
  bool _isActive = false;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _userData;

  String? get uid => _uid;
  String? get email => _email;
  String? get role => _role;
  String? get companyId => _companyId;
  String? get currentStatus => _currentStatus;
  bool get isActive => _isActive;
  bool get isLoading => _loading;
  String? get error => _error;
  Map<String, dynamic>? get userData => _userData;
  bool get isAdmin => _role?.toLowerCase() == 'admin' || _role?.toLowerCase() == 'hr';
  bool get hasCompany => _companyId != null && _companyId!.isNotEmpty;

  Future<void> initialize() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _clearData();
        return;
      }

      _uid = user.uid;
      _email = user.email;

      final userRepository = UserRepository();
      _userData = await userRepository.getFullUserData();

      if (_userData != null) {
        _role = _userData!['role'] as String?;
        _companyId = _userData!['companyId'] as String?;
        _currentStatus = _userData!['currentStatus'] as String?;
        final isActiveBool = _userData!['isActive'] as bool?;
        _isActive = _currentStatus == 'Active' || isActiveBool == true;
      }
    } catch (e) {
      _error = 'Failed to load user data: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUserData() async {
    if (_uid == null) return;
    try {
      final userRepository = UserRepository();
      _userData = await userRepository.getFullUserData();
      if (_userData != null) {
        _role = _userData!['role'] as String?;
        _companyId = _userData!['companyId'] as String?;
        _currentStatus = _userData!['currentStatus'] as String?;
        final isActiveBool = _userData!['isActive'] as bool?;
        _isActive = _currentStatus == 'Active' || isActiveBool == true;
      }
      notifyListeners();
    } catch (e) {
      _error = 'Failed to refresh user data: $e';
      notifyListeners();
    }
  }

  void _clearData() {
    _uid = null;
    _email = null;
    _role = null;
    _companyId = null;
    _currentStatus = null;
    _isActive = false;
    _userData = null;
    _loading = false;
    notifyListeners();
  }

  void clear() {
    _clearData();
  }
}