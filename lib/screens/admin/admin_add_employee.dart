import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/core.dart';
import 'package:myapp/data/providers/company_provider.dart';
import 'package:myapp/data/repositories.dart';
import 'package:myapp/widgets/common.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class AdminAddEmployee extends StatefulWidget {
  const AdminAddEmployee({super.key});

  @override
  State<AdminAddEmployee> createState() => _AdminAddEmployeeState();
}

class _AdminAddEmployeeState extends State<AdminAddEmployee> {
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _phoneController = TextEditingController();
  final _salaryController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _designationController = TextEditingController();

  String? selectedDept;
  String? selectedHOD;
  String? selectedGender;
  String? selectedBloodGroup;
  DateTime? selectedDateOfBirth;
  DateTime? selectedDateOfJoining;
  String? selectedProfilePic;
  bool isLoading = false;
  String _companyId = '';

  final List<String> departments = [
    "Production",
    "QC",
    "QA",
    "Software",
    "Accounts",
    "HR",
  ];
  final List<String> hods = [
    "Mr. Sharma",
    "Mr. Patil",
    "Ms. Deshmukh",
    "Mr. Verma",
  ];
  final List<String> genders = ["Male", "Female", "Other"];
  final List<String> bloodGroups = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"];

  @override
  void initState() {
    super.initState();
    _loadCompanyId();
  }

  void _loadCompanyId() {
    final provider = context.read<CompanyProvider>();
    _companyId = provider.companyId ?? '';
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => selectedDateOfBirth = picked);
    }
  }

  Future<void> _selectDateOfJoining(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDateOfJoining ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => selectedDateOfJoining = picked);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd-MM-yyyy').format(date);
  }

  Future<void> _registerEmployee() async {
    if (_companyId.isEmpty) {
      _showError('Company ID not found. Please contact admin to setup company first.');
      return;
    }

    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _nameController.text.isEmpty ||
        _idController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _addressController.text.isEmpty ||
        _salaryController.text.isEmpty ||
        selectedDept == null ||
        selectedGender == null ||
        selectedBloodGroup == null ||
        selectedDateOfBirth == null ||
        selectedDateOfJoining == null) {
      _showError('All fields are required! Please fill all details.');
      return;
    }

    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(_emailController.text.trim())) {
      _showError('Enter a valid email');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (!RegExp(r'^[0-9]{10}$').hasMatch(_phoneController.text.trim())) {
      _showError('Enter a valid 10-digit phone number');
      return;
    }

    setState(() => isLoading = true);

    try {
      final userRepo = UserRepository();
      await userRepo.createEmployeeProfile(
        companyId: _companyId,
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        empId: _idController.text.trim(),
        phone: _phoneController.text.trim(),
        dept: selectedDept,
        hod: selectedHOD,
        salary: _salaryController.text.trim(),
        address: _addressController.text.trim(),
        gender: selectedGender,
        bloodGroup: selectedBloodGroup,
        emergencyContact: _emergencyContactController.text.trim(),
        designation: _designationController.text.trim(),
        dateOfBirth: _formatDate(selectedDateOfBirth),
        dateOfJoining: _formatDate(selectedDateOfJoining),
        profilePic: selectedProfilePic,
      );

      if (mounted) {
        _showSuccess('Employee Registered Successfully!');
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'This email is already registered.';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak. Use at least 6 characters.';
          break;
        case 'invalid-email':
          errorMessage = 'Enter a valid email address.';
          break;
        default:
          errorMessage = 'Registration failed: ${e.message}';
      }
      _showError(errorMessage);
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showError(String msg) {
    SnackBarUtils.showError(context, msg);
  }

  void _showSuccess(String msg) {
    SnackBarUtils.showSuccess(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          'New Staff Registration',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('LOGIN CREDENTIALS'),
                  _buildField(
                    _emailController,
                    'Email Address',
                    Icons.email_outlined,
                    keyboard: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!RegExp(
                        r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$',
                      ).hasMatch(value.trim())) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  _buildField(
                    _passwordController,
                    'Login Password',
                    Icons.lock_outline,
                    isPassword: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),
                  _sectionTitle('PERSONAL DETAILS'),
                  _buildField(
                    _nameController,
                    'Full Name',
                    Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  _buildField(
                    _phoneController,
                    'Phone Number',
                    Icons.phone_android,
                    keyboard: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Phone number is required';
                      }
                      if (!RegExp(r'^[0-9]{10}$').hasMatch(value.trim())) {
                        return 'Enter a valid 10-digit phone number';
                      }
                      return null;
                    },
                  ),
                  _buildField(
                    _addressController,
                    'Residential Address',
                    Icons.home_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Address is required';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),
                  _sectionTitle('OFFICIAL ASSIGNMENT'),
                  _buildField(
                    _idController,
                    'Employee ID (e.g., GKH-001)',
                    Icons.badge_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Employee ID is required';
                      }
                      return null;
                    },
                  ),

                  _buildDropdown(
                    'Select Department',
                    departments,
                    selectedDept,
                    (val) => setState(() => selectedDept = val),
                  ),
                  _buildDropdown(
                    'Reporting H.O.D',
                    hods,
                    selectedHOD,
                    (val) => setState(() => selectedHOD = val),
                  ),

                  _buildField(
                    _salaryController,
                    'Monthly Gross Salary',
                    Icons.payments_outlined,
                    keyboard: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Salary is required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Enter a valid salary amount';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),
                  _sectionTitle('PERSONAL DETAILS'),
                  _buildDropdown(
                    'Gender',
                    genders,
                    selectedGender,
                    (val) => setState(() => selectedGender = val),
                  ),
                  _buildDropdown(
                    'Blood Group',
                    bloodGroups,
                    selectedBloodGroup,
                    (val) => setState(() => selectedBloodGroup = val),
                  ),
                  _buildField(
                    _emergencyContactController,
                    'Emergency Contact',
                    Icons.contact_phone_outlined,
                    keyboard: TextInputType.phone,
                  ),
                  _buildField(
                    _designationController,
                    'Designation',
                    Icons.work_outline,
                  ),

                  const SizedBox(height: 20),
                  _sectionTitle('DATE DETAILS'),
                  _buildDateField(
                    'Date of Birth',
                    selectedDateOfBirth,
                    () => _selectDateOfBirth(context),
                  ),
                  _buildDateField(
                    'Date of Joining',
                    selectedDateOfJoining,
                    () => _selectDateOfJoining(context),
                  ),

                  const SizedBox(height: 40),
                  _saveButton(),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Text(
      title,
      style: const TextStyle(
        color: AppColors.accent,
        fontWeight: FontWeight.bold,
        fontSize: 12,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _saveButton() => SizedBox(
    width: double.infinity,
    height: 55,
    child: ElevatedButton(
      onPressed: _registerEmployee,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 2,
      ),
      child: const Text(
        'CREATE OFFICIAL PROFILE',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    ),
  );

  Widget _buildField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboard,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
          filled: true,
          fillColor: AppColors.card,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String? currentVal,
    Function(String?) onChange,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: currentVal,
            hint: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            dropdownColor: AppColors.card,
            isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down, color: AppColors.accent),
            items: items
                .map(
                  (val) => DropdownMenuItem(
                    value: val,
                    child: Text(
                      val,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                )
                .toList(),
            onChanged: onChange,
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(String label, DateTime? date, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              Text(
                _formatDate(date),
                style: TextStyle(
                  color: date != null ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const Icon(Icons.calendar_today, color: AppColors.accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
