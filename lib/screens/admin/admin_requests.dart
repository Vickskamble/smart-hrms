import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:myapp/widgets/common/snackbar_utils.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core.dart';
import 'package:myapp/data/providers/company_provider.dart';
import 'package:myapp/data/repositories.dart';

class AdminRequests extends StatefulWidget {
  const AdminRequests({super.key});

  @override
  State<AdminRequests> createState() => _AdminRequestsState();
}

class _AdminRequestsState extends State<AdminRequests> {
  final _leaveRepo = LeaveRepository();
  bool _loading = true;
  String filter = 'Pending';

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
        title: const Text('Leave Requests', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['Pending', 'Approved', 'Rejected']
                  .map(
                    (f) => ChoiceChip(
                      label: Text(f, style: const TextStyle(fontSize: 12)),
                      selected: filter == f,
                      onSelected: (_) => setState(() => filter = f),
                      selectedColor: AppColors.accent,
                      labelStyle: TextStyle(
                        color: filter == f ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _leaveRepo.watchLeavesByStatus(companyId, filter.toLowerCase()),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                }

                final data = snap.data?.docs ?? [];

                if (data.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.request_page_outlined, size: 64, color: AppColors.textSecondary),
                        const SizedBox(height: 16),
                        Text(
                          'No $filter leave requests',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: data.length,
                  itemBuilder: (context, i) {
                    final d = data[i].data() as Map<String, dynamic>;
                    final status = d['status'] as String? ?? '';
                    final color = _getStatusColor(status);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d['employeeName'] ?? 'Unknown',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      d['employeeId'] ?? 'N/A',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Text(
                                '${d['startDate']} - ${d['endDate']}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.description, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  d['reason'] ?? 'No reason provided',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (status == 'pending')
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _approveLeave(data[i].id, d),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.green,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Approve', style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _rejectLeave(data[i].id, d),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.red,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Reject', style: TextStyle(color: Colors.white)),
                                  ),
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

  Color _getStatusColor(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
        return AppColors.green;
      case 'rejected':
        return AppColors.red;
      case 'pending':
        return AppColors.amber;
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _approveLeave(
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _leaveRepo.updateLeaveStatusWithDocId(
        companyId: context.read<CompanyProvider>().companyId!,
        docId: docId,
        newStatus: 'approved',
        reviewedBy: 'Admin',
      );
      if (!mounted) return;
      SnackBarUtils.showSuccess(context, 'Leave request approved');
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to approve leave: $e');
    }
  }

  Future<void> _rejectLeave(
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _leaveRepo.updateLeaveStatusWithDocId(
        companyId: context.read<CompanyProvider>().companyId!,
        docId: docId,
        newStatus: 'rejected',
        reviewedBy: 'Admin',
      );
      if (!mounted) return;
      SnackBarUtils.showSuccess(context, 'Leave request rejected');
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to reject leave: $e');
    }
  }
}
