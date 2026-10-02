import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/data/repositories/user_repository.dart';

class ImportService {
  static const int maxRowsPerFile = 500;
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB

  Future<Map<String, dynamic>?> importEmployees(
    String companyId,
    String fileName,
    String fileExtension,
    List<Map<String, dynamic>> rows,
  ) async {
    try {
      if (rows.isEmpty) {
        throw Exception('File is empty or could not be parsed.');
      }

      if (rows.length > maxRowsPerFile) {
        throw Exception('File contains too many rows. Maximum allowed is $maxRowsPerFile rows.');
      }

      // Validate all rows
      final validationResult = await validateRows(rows, companyId);
      if (validationResult['hasErrors'] == true) {
        throw Exception('Validation failed. Please fix the errors in the preview.');
      }

      // Process valid rows in batches
      final result = await _processRows(rows, validationResult['validRows'], companyId);

      // Log the import
      await _logImport(
        adminId: FirebaseAuth.instance.currentUser?.uid ?? '',
        companyId: companyId,
        fileName: fileName,
        totalRows: rows.length,
        successCount: result['successCount'],
        failedCount: result['failedCount'],
        status: result['failedCount'] > 0 ? 'partial' : 'success',
        failedRows: result['failedRows'],
      );

      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> validateRows(
    List<Map<String, dynamic>> rows,
    String companyId,
  ) async {
    final validRows = <Map<String, dynamic>>[];
    final errors = <Map<String, dynamic>>[];
    final Set<String> existingEmails = await _getExistingEmails(companyId);
    final Set<String> existingEmpIds = await _getExistingEmpIds(companyId);

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowErrors = _validateRow(row, i + 1, existingEmails, existingEmpIds);

      if (rowErrors.isEmpty) {
        validRows.add(row);
      } else {
        errors.add({
          'row': i + 1,
          'errors': rowErrors,
          'data': row,
        });
      }
    }

    return {
      'validRows': validRows,
      'errors': errors,
      'hasErrors': errors.isNotEmpty,
      'totalRows': rows.length,
      'validCount': validRows.length,
      'invalidCount': errors.length,
    };
  }

  List<String> _validateRow(
    Map<String, dynamic> row,
    int rowNumber,
    Set<String> existingEmails,
    Set<String> existingEmpIds,
  ) {
    final errors = <String>[];

    // Required fields
    final requiredFields = [
      'name',
      'mobile',
      'email',
      'password',
      'department',
      'designation',
      'reportingManager',
      'gender',
      'bloodGroup',
      'address',
      'emergencyContact',
      'dateOfBirth',
      'dateOfJoining',
      'basicSalary',
    ];

    for (final field in requiredFields) {
      final value = row[field];
      if (value == null || value.toString().trim().isEmpty) {
        errors.add('Missing required field: $field');
      }
    }

    // Email validation
    final email = row['email']?.toString().trim();
    if (email != null) {
      if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}\$').hasMatch(email)) {
        errors.add('Invalid email format');
      } else if (existingEmails.contains(email.toLowerCase())) {
        errors.add('Email already exists');
      }
    }

    // Phone validation
    final phone = row['mobile']?.toString().trim();
    if (phone != null && !RegExp(r'^[0-9]{10}\$').hasMatch(phone)) {
      errors.add('Invalid phone number format (must be 10 digits)');
    }

    // Date validation
    final dateOfBirth = row['dateOfBirth']?.toString().trim();
    if (dateOfBirth != null) {
      if (!RegExp(r'^\d{2}-\d{2}-\d{4}\$').hasMatch(dateOfBirth)) {
        errors.add('Invalid date of birth format (DD-MM-YYYY required)');
      } else {
        final parts = dateOfBirth.split('-');
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day == null || month == null || year == null) {
          errors.add('Invalid date of birth');
        } else {
          try {
            DateTime(year, month, day);
          } catch (_) {
            errors.add('Invalid date of birth');
          }
        }
      }
    }

    final dateOfJoining = row['dateOfJoining']?.toString().trim();
    if (dateOfJoining != null) {
      if (!RegExp(r'^\d{2}-\d{2}-\d{4}\$').hasMatch(dateOfJoining)) {
        errors.add('Invalid date of joining format (DD-MM-YYYY required)');
      } else {
        final parts = dateOfJoining.split('-');
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day == null || month == null || year == null) {
          errors.add('Invalid date of joining');
        } else {
          try {
            DateTime(year, month, day);
          } catch (_) {
            errors.add('Invalid date of joining');
          }
        }
      }
    }

    // Salary validation
    final basicSalary = row['basicSalary']?.toString().trim();
    if (basicSalary != null) {
      if (double.tryParse(basicSalary) == null) {
        errors.add('Invalid basic salary amount');
      }
    }

    // Employee ID validation
    final empId = row['name']?.toString().trim();
    if (empId != null && existingEmpIds.contains(empId)) {
      errors.add('Employee ID already exists');
    }

    return errors;
  }

  Future<Set<String>> _getExistingEmails(String companyId) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('companyId', isEqualTo: companyId)
        .get();

    final emails = <String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final email = data['email']?.toString().toLowerCase();
      if (email != null) {
        emails.add(email);
      }
    }

    return emails;
  }

  Future<Set<String>> _getExistingEmpIds(String companyId) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('companyId', isEqualTo: companyId)
        .get();

    final empIds = <String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final empId = data['empId']?.toString();
      if (empId != null) {
        empIds.add(empId);
      }
    }

    return empIds;
  }

  Future<Map<String, dynamic>> _processRows(
    List<Map<String, dynamic>> rows,
    List<Map<String, dynamic>> validRows,
    String companyId,
  ) async {
    int successCount = 0;
    int failedCount = 0;
    final failedRows = <Map<String, dynamic>>[];

    // Process in batches of 500
    for (var i = 0; i < validRows.length; i += 500) {
      final batchSize = i + 500 < validRows.length ? 500 : validRows.length - i;
      final batch = validRows.sublist(i, i + batchSize);

      try {
        await _processBatch(batch, companyId);
        successCount += batch.length;
      } catch (e) {
        failedCount += batch.length;
        for (final row in batch) {
          failedRows.add({
            'data': row,
            'error': e.toString(),
          });
        }
      }
    }

    return {
      'successCount': successCount,
      'failedCount': failedCount,
      'failedRows': failedRows,
    };
  }

  Future<void> _processBatch(
    List<Map<String, dynamic>> rows,
    String companyId,
  ) async {
    final userRepo = UserRepository();

    for (final row in rows) {
      try {
        // Create user using secondary app for session preservation
        await userRepo.createEmployeeProfile(
          companyId: companyId,
          email: row['email']?.toString().trim() ?? '',
          password: row['password']?.toString().trim() ?? '',
          name: row['name']?.toString().trim() ?? '',
          empId: row['name']?.toString().trim() ?? '', // Using name as empId for now
          phone: row['mobile']?.toString().trim() ?? '',
          dept: row['department']?.toString(),
          hod: row['reportingManager']?.toString(),
          salary: row['basicSalary']?.toString().trim() ?? '0',
          address: row['address']?.toString().trim() ?? '',
          gender: row['gender']?.toString(),
          bloodGroup: row['bloodGroup']?.toString(),
          emergencyContact: row['emergencyContact']?.toString().trim(),
          designation: row['designation']?.toString().trim(),
          dateOfBirth: row['dateOfBirth']?.toString().trim(),
          dateOfJoining: row['dateOfJoining']?.toString().trim(),
          profilePic: null, // Not in template
        );
      } catch (e) {
        rethrow;
      }
    }
  }

  Future<void> _logImport({
    required String adminId,
    required String companyId,
    required String fileName,
    required int totalRows,
    required int successCount,
    required int failedCount,
    required String status,
    required List<Map<String, dynamic>> failedRows,
  }) async {
    final logId = FirebaseFirestore.instance.collection('import_logs').doc().id;

    await FirebaseFirestore.instance.collection('import_logs').doc(logId).set({
      'adminId': adminId,
      'companyId': companyId,
      'timestamp': FieldValue.serverTimestamp(),
      'fileName': fileName,
      'totalRows': totalRows,
      'successCount': successCount,
      'failedCount': failedCount,
      'status': status,
      'failedRows': failedRows,
    });
  }
}