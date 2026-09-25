import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core.dart';
import 'package:myapp/data/providers.dart';
import 'package:myapp/widgets/common.dart';

class ImportDashboard extends StatefulWidget {
  const ImportDashboard({super.key});

  @override
  State<ImportDashboard> createState() => _ImportDashboardState();
}

class _ImportDashboardState extends State<ImportDashboard> {
  bool _isLoading = false;
  String? _selectedFileName;
  String? _selectedFileExtension;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final companyProvider = context.watch<CompanyProvider>();

    if (companyProvider.isLoading || !companyProvider.hasCompany) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          'Bulk Import Employees',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? _buildLoadingView()
          : _buildImportView(context),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.accent),
          SizedBox(height: 16),
          Text(
            'Processing import...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildImportView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection(),
          const SizedBox(height: 24),
          _buildFileUploadSection(context),
          const SizedBox(height: 20),
          if (_errorMessage != null) _buildErrorSection(),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Import Instructions',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.download,
            'Download template',
            'Download the Excel (.xlsx) or CSV template with all required fields',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.edit,
            'Fill the template',
            'Fill in employee details (name, email, phone, department, etc.)',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.upload_file,
            'Upload file',
            'Upload the filled template for bulk import',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.check_circle,
            'Validation & Import',
            'File will be validated and imported in batches',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.accent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFileUploadSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload File',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildFileTypeSelector(),
          const SizedBox(height: 20),
          _buildFileUploadArea(context),
        ],
      ),
    );
  }

  Widget _buildFileTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _selectFileType('xlsx'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _selectedFileExtension == 'xlsx'
                    ? AppColors.accent.withValues(alpha: 0.1)
                    : AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedFileExtension == 'xlsx'
                      ? AppColors.accent
                      : AppColors.border,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.table_chart, color: AppColors.accent, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Excel (.xlsx)',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () => _selectFileType('csv'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _selectedFileExtension == 'csv'
                    ? AppColors.accent.withValues(alpha: 0.1)
                    : AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedFileExtension == 'csv'
                      ? AppColors.accent
                      : AppColors.border,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list_alt, color: AppColors.accent, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'CSV (.csv)',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileUploadArea(BuildContext context) {
    return InkWell(
      onTap: _pickFile,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.border,
            style: BorderStyle.solid,
          ),
        ),
        child: _selectedFileName != null
            ? _buildSelectedFileInfo()
            : _buildUploadPrompt(),
      ),
    );
  }

  Widget _buildSelectedFileInfo() {
    return Row(
      children: [
        const Icon(Icons.file_present, color: AppColors.green, size: 40),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _selectedFileName!,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _selectedFileExtension!.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _clearSelectedFile(),
          icon: const Icon(Icons.close, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildUploadPrompt() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.cloud_upload, color: AppColors.textSecondary, size: 48),
        SizedBox(height: 12),
        Text(
          'Tap to select file',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Supported: .xlsx, .csv (Max 5MB, 500 rows)',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorSection() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppColors.red,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectFileType(String extension) {
    setState(() {
      _selectedFileExtension = extension;
      _selectedFileName = null;
      _errorMessage = null;
    });
  }

  Future<void> _pickFile() async {
    if (_selectedFileExtension == null) {
      _showError('Please select a file type first');
      return;
    }

    // In a real app, this would open a file picker
    // For now, we'll simulate file selection
    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;

      setState(() {
        _selectedFileName = 'employees_template.\${_selectedFileExtension}';
        _isLoading = false;
      });

      // Navigate to preview screen
      Navigator.pushNamed(
        context,
        '/import-preview',
        arguments: {
          'fileName': _selectedFileName,
          'fileExtension': _selectedFileExtension,
          'file': null, // In real app, this would be the actual file
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to select file: \${e.toString()}');
    }
  }

  void _clearSelectedFile() {
    setState(() {
      _selectedFileName = null;
      _selectedFileExtension = null;
    });
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    SnackBarUtils.showError(context, message);
  }
}