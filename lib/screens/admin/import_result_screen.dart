import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:myapp/core.dart';
import 'package:myapp/widgets/common.dart';

class ImportResultScreen extends StatefulWidget {
  const ImportResultScreen({super.key});

  @override
  State<ImportResultScreen> createState() => _ImportResultScreenState();
}

class _ImportResultScreenState extends State<ImportResultScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _importResult;
  String? _errorMessage;
  List<Map<String, dynamic>> _failedRows = [];

  @override
  void initState() {
    super.initState();
    _loadResultData();
  }

  Future<void> _loadResultData() async {
    setState(() => _isLoading = true);

    try {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args == null) {
        _showError('No import result found');
        return;
      }

      setState(() {
        _importResult = args['result'] as Map<String, dynamic>?;
        _failedRows = List<Map<String, dynamic>>.from(
          _importResult?['failedRows'] ?? [],
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load result: ${e.toString()}');
    }
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    SnackBarUtils.showError(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          'Import Result',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _errorMessage != null
              ? _buildErrorView()
              : _buildResultView(),
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

  Widget _buildResultView() {
    final successCount = _importResult?['successCount'] ?? 0;
    final failedCount = _importResult?['failedCount'] ?? 0;
    final totalRows = _importResult?['totalRows'] ?? 0;
    final status = _importResult?['status'] ?? 'unknown';

    Color statusColor = AppColors.green;
    String statusText = 'Success';

    if (status == 'partial') {
      statusColor = AppColors.amber;
      statusText = 'Partial Success';
    } else if (status == 'failed') {
      statusColor = AppColors.red;
      statusText = 'Failed';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCard(statusColor, statusText, successCount, failedCount, totalRows),
          const SizedBox(height: 24),
          _buildFailedRowsSection(),
          const SizedBox(height: 24),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    Color statusColor,
    String statusText,
    int successCount,
    int failedCount,
    int totalRows,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  statusText == 'Success'
                      ? Icons.check_circle
                      : statusText == 'Partial Success'
                          ? Icons.warning_amber
                          : Icons.error_outline,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Import completed',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildResultStatItem('Total Rows', totalRows.toString(), AppColors.textPrimary),
              _buildResultStatItem('Success', successCount.toString(), AppColors.green),
              _buildResultStatItem('Failed', failedCount.toString(), AppColors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
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

  Widget _buildFailedRowsSection() {
    if (_failedRows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.red, size: 20),
              SizedBox(width: 8),
              Text(
                'Failed Rows Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._failedRows.map((failedRow) => _buildFailedRowItem(failedRow)),
        ],
      ),
    );
  }

  Widget _buildFailedRowItem(Map<String, dynamic> failedRow) {
    final rowData = failedRow['data'] as Map<String, dynamic>? ?? {};
    final error = failedRow['error'] as String? ?? 'Unknown error';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.close, color: AppColors.red, size: 16),
              const SizedBox(width: 8),
              Text(
                'Row ${failedRow['row'] ?? 'Unknown'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          if (rowData.isNotEmpty) ...[
            const Text(
              'Data:',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: SelectableText(
                jsonEncode(rowData),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            label: const Text('Back to Dashboard', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        if (_failedRows.isNotEmpty)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _downloadFailedRowsCSV,
              icon: const Icon(Icons.download, color: AppColors.textPrimary),
              label: const Text('Download Failed Rows', style: TextStyle(color: AppColors.textPrimary)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _downloadFailedRowsCSV() async {
    setState(() => _isLoading = true);

    try {
      final fileName = 'failed_rows_${DateTime.now().millisecondsSinceEpoch}.csv';

      SnackBarUtils.showSuccess(context, 'Failed rows CSV would be downloaded as $fileName');
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to generate CSV: ${e.toString()}');
    }
  }
}