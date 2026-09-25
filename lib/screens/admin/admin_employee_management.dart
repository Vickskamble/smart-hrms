import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:myapp/widgets/common/snackbar_utils.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core.dart';
import 'package:myapp/data/providers/company_provider.dart';
import 'package:myapp/data/repositories.dart';

class AdminEmployeeManagement extends StatefulWidget {
  const AdminEmployeeManagement({super.key});

  @override
  State<AdminEmployeeManagement> createState() =>
      _AdminEmployeeManagementState();
}

class _AdminEmployeeManagementState extends State<AdminEmployeeManagement> {
  final _userRepo = UserRepository();
  bool _loading = true;
  String searchQuery = '';
  String filter = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CompanyProvider>();
    final companyId = provider.companyId ?? '';

    if (_loading || !provider.hasCompany) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          'Employee Management',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.accent),
            onPressed: () =>
                Navigator.pushNamed(context, '/admin-add-employee'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search employees...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: filter,
                      items: ['All', 'Active', 'Inactive']
                          .map(
                            (f) => DropdownMenuItem(
                              value: f,
                              child: Text(
                                f,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => filter = value!),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _userRepo.watchEmployees(companyId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  );
                }

                final allEmployees = snap.data?.docs ?? [];
                final filteredEmployees = allEmployees.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name']?.toString().toLowerCase() ?? '';
                  final empId = data['empId']?.toString().toLowerCase() ?? '';
                  final matchesSearch =
                      name.contains(searchQuery.toLowerCase()) ||
                      empId.contains(searchQuery.toLowerCase());
                  final matchesFilter =
                      filter == 'All' ||
                      (filter == 'Active' && data['isActive'] == true) ||
                      (filter == 'Inactive' && data['isActive'] == false);
                  return matchesSearch && matchesFilter;
                }).toList();

                if (filteredEmployees.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No employees found',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredEmployees.length,
                  itemBuilder: (context, i) {
                    final doc = filteredEmployees[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final isActive = data['isActive'] as bool? ?? true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.green.withValues(alpha: 0.1)
                                  : AppColors.red.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isActive
                                    ? AppColors.green
                                    : AppColors.red,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              isActive ? Icons.check_circle : Icons.cancel,
                              color: isActive ? AppColors.green : AppColors.red,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.badge,
                                      size: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      data['empId'] ?? 'N/A',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.work,
                                      size: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      data['dept'] ?? 'N/A',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.green.withValues(alpha: 0.1)
                                      : AppColors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isActive ? 'ACTIVE' : 'INACTIVE',
                                  style: TextStyle(
                                    color: isActive
                                        ? AppColors.green
                                        : AppColors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: AppColors.accent,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _editEmployee(doc.id, data),
                                    tooltip: 'Edit Employee',
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.lock_reset,
                                      color: AppColors.amber,
                                      size: 20,
                                    ),
                                    onPressed: () => _resetCredentials(
                                      doc.id,
                                      data,
                                    ),
                                    tooltip: 'Reset Credentials',
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isActive
                                          ? Icons.block
                                          : Icons.check_circle,
                                      color: isActive
                                          ? AppColors.red
                                          : AppColors.green,
                                      size: 20,
                                    ),
                                    onPressed: () => _toggleEmployeeStatus(
                                      doc.id,
                                      !isActive,
                                      data,
                                    ),
                                    tooltip: isActive
                                        ? 'Deactivate Employee'
                                        : 'Activate Employee',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editEmployee(
    String docId,
    Map<String, dynamic> data,
  ) async {
    final nameController = TextEditingController(text: data['name']);
    final empIdController = TextEditingController(text: data['empId']);
    final phoneController = TextEditingController(text: data['phone']);
    final salaryController = TextEditingController(
      text: data['salary']?.toString() ?? '',
    );

    final deptController = TextEditingController(text: data['dept']);
    final hodController = TextEditingController(text: data['hod']);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Employee'),
        backgroundColor: AppColors.card,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField('Name', nameController),
              _buildTextField('Employee ID', empIdController),
              _buildTextField(
                'Phone',
                phoneController,
                keyboard: TextInputType.phone,
              ),
              _buildTextField(
                'Salary',
                salaryController,
                keyboard: TextInputType.number,
              ),
              _buildTextField('Department', deptController),
              _buildTextField('H.O.D', hodController),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'name': nameController.text,
              'empId': empIdController.text,
              'phone': phoneController.text,
              'salary': salaryController.text,
              'dept': deptController.text,
              'hod': hodController.text,
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (result != null) {
      try {
        final companyId = context.read<CompanyProvider>().companyId!;
        await _userRepo.updateEmployee(
          companyId,
          docId,
          result['name'],
          result['empId'],
          result['phone'],
          result['salary'],
          result['dept'],
          result['hod'],
        );
        if (!mounted) return;
        SnackBarUtils.showSuccess(context, 'Employee updated successfully');
      } catch (e) {
        if (!mounted) return;
        SnackBarUtils.showError(context, 'Failed to update employee: $e');
      }
    }
  }

  Future<void> _resetCredentials(
    String docId,
    Map<String, dynamic> data,
  ) async {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Credentials'),
        backgroundColor: AppColors.card,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('New Password:'),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter new password',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Confirm Password:'),
            const SizedBox(height: 8),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Confirm new password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (passwordController.text == confirmPasswordController.text) {
                Navigator.pop(context, passwordController.text);
              } else {
                SnackBarUtils.showError(context, 'Passwords do not match');
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (result != null) {
      try {
        await _userRepo.resetEmployeePassword(
          context.read<CompanyProvider>().companyId!,
          docId,
          result,
        );
        if (!mounted) return;
        SnackBarUtils.showSuccess(context, 'Credentials reset successfully');
      } catch (e) {
        if (!mounted) return;
        SnackBarUtils.showError(context, 'Failed to reset credentials: $e');
      }
    }
  }

  Future<void> _toggleEmployeeStatus(
    String docId,
    bool newStatus,
    Map<String, dynamic> data,
  ) async {
    final action = newStatus ? 'activate' : 'deactivate';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm $action'),
        backgroundColor: AppColors.card,
        content: Text('Are you sure you want to $action ${data['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? AppColors.green : AppColors.red,
            ),
            child: Text(newStatus ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (confirm == true) {
      try {
        await _userRepo.updateEmployeeStatusBool(
          context.read<CompanyProvider>().companyId!,
          docId,
          newStatus,
        );
        if (!mounted) return;
        SnackBarUtils.showSuccess(
          context,
          'Employee ${newStatus ? 'activated' : 'deactivated'} successfully',
        );
      } catch (e) {
        if (!mounted) return;
        SnackBarUtils.showError(
          context,
          'Failed to update employee status: $e',
        );
      }
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
      ),
    );
  }
}
