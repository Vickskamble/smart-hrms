import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/core.dart';
import 'package:myapp/data/providers/company_provider.dart';
import 'package:myapp/widgets/common.dart';

class ImportHistoryScreen extends StatefulWidget {
  const ImportHistoryScreen({super.key});

  @override
  State<ImportHistoryScreen> createState() => _ImportHistoryScreenState();
}

class _ImportHistoryScreenState extends State<ImportHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _importLogs = [];
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Success', 'Partial', 'Failed'];

  @override
  void initState() {
    super.initState();
    _loadImportHistory();
  }

  Future<void> _loadImportHistory() async {
    setState(() => _isLoading = true);

    try {
      final companyProvider = context.read<CompanyProvider>();
      final companyId = companyProvider.companyId;

      if (companyId == null || companyId.isEmpty) {
        setState(() {
          _importLogs = [];
          _isLoading = false;
        });
        return;
      }

      Query query = FirebaseFirestore.instance
          .collection('import_logs')
          .where('companyId', isEqualTo: companyId)
          .orderBy('timestamp', descending: true);

      if (_selectedFilter != 'All') {
        query = query.where('status', isEqualTo: _selectedFilter.toLowerCase());
      }

      final snapshot = await query.get();
      if (!mounted) return;

      final logs = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          logs.add({
            'id': doc.id,
            'adminId': data['adminId'] ?? '',
            'companyId': data['companyId'] ?? '',
            'timestamp': data['timestamp'] ?? DateTime.now(),
            'fileName': data['fileName'] ?? '',
            'totalRows': data['totalRows'] ?? 0,
            'successCount': data['successCount'] ?? 0,
            'failedCount': data['failedCount'] ?? 0,
            'status': data['status'] ?? 'unknown',
          });
        }
      }

      setState(() {
        _importLogs = logs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      SnackBarUtils.showError(context, 'Failed to load import history: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          'Import History',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : _buildHistoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Filter by Status:',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFilter,
                items: _filters.map((filter) {
                  return DropdownMenuItem<String>(
                    value: filter,
                    child: Text(
                      filter,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedFilter = value);
                    _loadImportHistory();
                  }
                },
                dropdownColor: AppColors.card,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_importLogs.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _importLogs.length,
      itemBuilder: (context, index) {
        final log = _importLogs[index];
        return _buildHistoryCard(log);
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            color: AppColors.textSecondary,
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'No import history found',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Import history will appear here',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> log) {
    final statusColor = _getStatusColor(log['status']);
    final statusIcon = _getStatusIcon(log['status']);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => _showImportDetails(log),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          log['fileName'] ?? 'Unknown',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            log['status']?.toUpperCase() ?? 'UNKNOWN',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildHistoryDetailItem(
                          Icons.people,
                          '${log['successCount'] ?? 0} success',
                          AppColors.green,
                        ),
                        const SizedBox(width: 16),
                        _buildHistoryDetailItem(
                          Icons.close,
                          '${log['failedCount'] ?? 0} failed',
                          AppColors.red,
                        ),
                        const SizedBox(width: 16),
                        _buildHistoryDetailItem(
                          Icons.list_alt,
                          '${log['totalRows'] ?? 0} total',
                          AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTimestamp(log['timestamp']),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryDetailItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return AppColors.green;
      case 'partial':
        return AppColors.amber;
      case 'failed':
        return AppColors.red;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return Icons.check_circle;
      case 'partial':
        return Icons.warning_amber;
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.help_outline;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    DateTime dateTime;
    if (timestamp is String) {
      dateTime = DateTime.parse(timestamp);
    } else if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else {
      dateTime = timestamp as DateTime;
    }

    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showImportDetails(Map<String, dynamic> log) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildImportDetailsSheet(log),
    );
  }

  Widget _buildImportDetailsSheet(Map<String, dynamic> log) {
    final successCount = log['successCount'] ?? 0;
    final failedCount = log['failedCount'] ?? 0;
    final totalRows = log['totalRows'] ?? 0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Import Details',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection('File Information', [
                    _buildDetailRow('File Name', log['fileName'] ?? 'Unknown'),
                    _buildDetailRow('Status', log['status']?.toUpperCase() ?? 'UNKNOWN'),
                    _buildDetailRow('Import Time', _formatTimestamp(log['timestamp'])),
                  ]),
                  const SizedBox(height: 20),
                  _buildDetailSection('Import Summary', [
                    _buildDetailRow('Total Rows', totalRows.toString()),
                    _buildDetailRow('Successful', successCount.toString()),
                    _buildDetailRow('Failed', failedCount.toString()),
                    _buildDetailRow('Success Rate', '${((successCount / totalRows * 100).toStringAsFixed(1))}%'),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}