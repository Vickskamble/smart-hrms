import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:myapp/widgets/common/snackbar_utils.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core.dart';
import 'package:myapp/data/providers/company_provider.dart';
import 'package:myapp/data/repositories.dart';

class AdminManagement extends StatefulWidget {
  final String initialFilter;

  const AdminManagement({super.key, required this.initialFilter});

  @override
  State<AdminManagement> createState() => _AdminManagementState();
}

class _AdminManagementState extends State<AdminManagement> {
  final _attendanceRepo = AttendanceRepository();
  String filter = 'All';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    filter = widget.initialFilter;
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
        title: Text(filter, style: const TextStyle(color: AppColors.textPrimary)),
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
              children: ['All', 'Present', 'Absent', 'Late', 'Miss']
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
              stream: filter == 'All'
                  ? _attendanceRepo.firestore
                      .collection('companies')
                      .doc(companyId)
                      .collection('attendance')
                      .snapshots()
                  : _attendanceRepo.watchAttendanceByStatus(companyId, filter.toLowerCase()),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                }

                final data = snap.data?.docs ?? [];

                if (data.isEmpty) {
                  return const Center(
                    child: Text(
                      'No Data',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: data.length,
                  itemBuilder: (context, i) {
                    final d = data[i].data() as Map<String, dynamic>;
                    final status = d['status'] as String? ?? '';
                    final color = _getColor(status);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d['employeeId'] ?? 'Unknown',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  d['date'] ?? '',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            status,
                            style: TextStyle(color: color, fontWeight: FontWeight.w600),
                          ),
                          if (status == 'Miss')
                            IconButton(
                              icon: const Icon(Icons.edit, color: AppColors.amber),
                              onPressed: () => _fixMissPunch(data[i].id),
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

  Color _getColor(String s) {
    switch (s) {
      case 'Present':
        return AppColors.green;
      case 'Absent':
        return AppColors.red;
      case 'Late':
        return AppColors.amber;
      default:
        return AppColors.purple;
    }
  }

  Future<void> _fixMissPunch(String docId) async {
    try {
      await _attendanceRepo.fixMissedPunch(
        companyId: context.read<CompanyProvider>().companyId!,
        docId: docId,
        checkOut: DateTime.now(),
      );
      if (!mounted) return;
      SnackBarUtils.showSuccess(context, 'Punch fixed successfully');
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to fix: $e');
    }
  }
}