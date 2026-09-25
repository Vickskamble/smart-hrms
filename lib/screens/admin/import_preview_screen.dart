import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core.dart';
import 'package:myapp/data/providers/company_provider.dart';
import 'package:myapp/data/services/import_service.dart';
import 'package:myapp/utility/file_parser.dart';
import 'package:myapp/widgets/common.dart';

class ImportPreviewScreen extends StatefulWidget {
  const ImportPreviewScreen({super.key});

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _previewRows = [];
  Map<String, dynamic>? _validationResult;
  String? _errorMessage;
  int _currentPage = 0;
  final int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadPreviewData();
  }

  Future<void> _loadPreviewData() async {
    setState(() => _isLoading = true);

    try {
      final companyProvider = context.read<CompanyProvider>();
      final companyId = companyProvider.companyId ?? '';

      if (companyId.isEmpty) {
        _showError('Company ID not found');
        return;
      }

      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args == null) {
        _showError('No file data found');
        return;
      }

      final fileExtension = args['fileExtension'] as String;
      final file = args['file'] as File?;

      if (file == null) {
        _showError('File not found');
        return;
      }

      final parsedData = await FileParser.parseFile(file, fileExtension);
      final rows = parsedData['rows'] as List<Map<String, dynamic>>;

      setState(() {
        _previewRows = rows;
        _isLoading = false;
      });

      _validatePreviewData(companyId);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load preview: \${e.toString()}');
    }
  }

  Future<void> _validatePreviewData(String companyId) async {
    setState(() => _isLoading = true);

    try {
      final importService = ImportService();
      final validationResult = await importService.validateRows(_previewRows, companyId);

      setState(() {
        _validationResult = validationResult;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Validation failed: \${e.toString()}');
    }
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    SnackBarUtils.showError(context, message);
  }

  List<Map<String, dynamic>> get _paginatedRows {
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, _previewRows.length);
    return _previewRows.sublist(startIndex, endIndex);
  }

  int get _totalPages {
    if (_previewRows.isEmpty) return 0;
    return ((_previewRows.length - 1) / _rowsPerPage).ceil();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          'Import Preview',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.green),
            onPressed: _validationResult != null && _validationResult!['hasErrors'] == false
                ? _proceedToImport
                : null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _errorMessage != null
              ? _buildErrorView()
              : _buildPreviewView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.red, size: 64),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewView() {
    return Column(
      children: [
        _buildSummaryCard(),
        const SizedBox(height: 16),
        Expanded(child: _buildDataTable()),
        const SizedBox(height: 16),
        _buildPaginationControls(),
        const SizedBox(height: 16),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            'Total Rows',
            _previewRows.length.toString(),
            AppColors.textPrimary,
          ),
          _buildSummaryItem(
            'Valid Rows',
            (_validationResult?['validCount'] ?? 0).toString(),
            AppColors.green,
          ),
          _buildSummaryItem(
            'Invalid Rows',
            (_validationResult?['invalidCount'] ?? 0).toString(),
            AppColors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          const Divider(height: 1, color: AppColors.border),
          Expanded(child: _buildTableBody()),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Field',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Value',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableBody() {
    return ListView.builder(
      itemCount: _paginatedRows.length,
      itemBuilder: (context, index) {
        final row = _paginatedRows[index];
        return _buildTableRow(row, index);
      },
    );
  }

  Widget _buildTableRow(Map<String, dynamic> row, int index) {
    final rowNumber = (_currentPage * _rowsPerPage) + index + 1;
    final rowErrors = _validationResult?['errors'] as List<Map<String, dynamic>>? ?? [];
    final currentError = rowErrors.firstWhere(
      (e) => e['row'] == rowNumber,
      orElse: () => <String, dynamic>{},
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.1),
        border: const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Row $rowNumber',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: _buildErrorDetails(currentError),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorDetails(Map<String, dynamic> error) {
    final errors = error['errors'] as List<String>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (errors.isNotEmpty) ...[
          ...errors.map((errorMsg) => Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMsg,
                    style: const TextStyle(
                      color: AppColors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildPaginationControls() {
    if (_totalPages <= 1) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Page ${_currentPage + 1} of $_totalPages',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: _currentPage < _totalPages - 1
                ? () => setState(() => _currentPage++)
                : null,
            icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              label: const Text('Back', style: TextStyle(color: AppColors.textPrimary)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _validationResult != null && _validationResult!['hasErrors'] == false
                  ? _proceedToImport
                  : null,
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text('Proceed to Import', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _proceedToImport() async {
    setState(() => _isLoading = true);

    try {
      final companyProvider = context.read<CompanyProvider>();
      final companyId = companyProvider.companyId ?? '';

      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args == null) {
        _showError('No file data found');
        return;
      }

      final fileName = args['fileName'] as String;
      final fileExtension = args['fileExtension'] as String;
      final file = args['file'] as File?;

      if (file == null) {
        _showError('File not found');
        return;
      }

      final importService = ImportService();
      final result = await importService.importEmployees(
        companyId,
        fileName,
        fileExtension,
        _previewRows,
      );

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/import-result',
          arguments: {
            'result': result,
            'fileName': fileName,
          },
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Import failed: \${e.toString()}');
    }
  }
}