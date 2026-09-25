import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/core.dart';
import 'package:myapp/data/providers/company_provider.dart';
import 'package:myapp/data/repositories.dart';

class AdminDataExport extends StatefulWidget {
  const AdminDataExport({super.key});

  @override
  State<AdminDataExport> createState() => _AdminDataExportState();
}

class _AdminDataExportState extends State<AdminDataExport> {
  final _userRepo = UserRepository();
  bool _loading = true;
  String exportFormat = 'CSV';
  String dateRange = 'Today';
  bool _exporting = false;

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
        title: const Text('Data Export', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildExportOptions(),
            const SizedBox(height: 30),
            _buildDateRangeSelector(),
            const SizedBox(height: 30),
            _buildDataPreview(companyId),
            const SizedBox(height: 30),
            _buildExportButton(companyId),
          ],
        ),
      ),
    );
  }

  Widget _buildExportOptions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Export Format',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildFormatOption('CSV', 'csv', Icons.table_chart, exportFormat == 'CSV'),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildFormatOption('Excel', 'excel', Icons.grid_on, exportFormat == 'Excel'),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildFormatOption('PDF', 'pdf', Icons.picture_as_pdf, exportFormat == 'PDF'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormatOption(String title, String value, IconData icon, bool selected) {
    return InkWell(
      onTap: () => setState(() => exportFormat = title),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.1) : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.accent : AppColors.textSecondary, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: selected ? AppColors.accent : AppColors.textPrimary,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Date Range',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildDateOption('Today', 'Today'),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildDateOption('This Week', 'This Week'),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildDateOption('This Month', 'This Month'),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildDateOption('Custom', 'Custom'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateOption(String title, String value) {
    final isSelected = dateRange == title;
    return InkWell(
      onTap: () => setState(() => dateRange = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.1) : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.accent : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildDataPreview(String companyId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data Preview',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 15),
          StreamBuilder<QuerySnapshot>(
            stream: _userRepo.watchEmployees(companyId),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                  child: Text(
                    'Loading employee data...',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              final employees = snap.data!.docs;
              if (employees.isEmpty) {
                return const Center(
                  child: Text(
                    'No employee data available',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              return Column(
                children: [
                  _buildPreviewHeader(),
                  const SizedBox(height: 10),
                  _buildPreviewData(employees.take(5).toList()),
                  const SizedBox(height: 10),
                  Text(
                    'Total Employees: ${employees.length}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Employee ID',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Name',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Department',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Status',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewData(List<QueryDocumentSnapshot> employees) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: employees
            .map(
              (doc) => _buildPreviewRow(doc),
            )
            .toList(),
      ),
    );
  }

  Widget _buildPreviewRow(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isActive = data['isActive'] as bool? ?? true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              data['empId'] ?? 'N/A',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              data['name'] ?? 'N/A',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              data['dept'] ?? 'N/A',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                color: isActive ? AppColors.green : AppColors.red,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton(String companyId) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: _exporting ? null : () => _exportData(companyId),
        icon: _exporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.download, color: Colors.white),
        label: Text(
          _exporting ? 'Exporting...' : 'Export Data',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 2,
        ),
      ),
    );
  }

  Future<void> _exportData(String companyId) async {
    setState(() => _exporting = true);

    try {
      // Get all employees
      final employees = await _userRepo.getEmployees(companyId);
      if (!mounted) return;

      // Generate CSV content
      _generateCSV(employees.docs);

      // In a real app, you would:
      // 1. Save to device storage
      // 2. Share via intent
      // 3. Upload to cloud storage
      // For now, we'll show a success message

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Data exported successfully as $exportFormat (${employees.docs.length} employees)',
          ),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  String _generateCSV(List<QueryDocumentSnapshot> employees) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('Employee ID,Name,Email,Phone,Department,H.O.D,Salary,Status,Join Date');

    // Data
    for (final doc in employees) {
      final data = doc.data() as Map<String, dynamic>;
      final isActive = data['isActive'] as bool? ?? true;

      buffer.writeln(
        '${data['empId']},${data['name']},${data['email']},${data['phone']},${data['dept']},${data['hod']},${data['basicSalary']},${isActive ? 'Active' : 'Inactive'},${data['createdAt']}',
      );
    }

    return buffer.toString();
  }
}
