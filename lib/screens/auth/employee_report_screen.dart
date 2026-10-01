import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:myapp/core.dart';
import 'package:myapp/data/models/report_model.dart';
import 'package:myapp/services/report_pdf_service.dart';
// ─────────────────────────────────────────────────────────────────────────────
// Employee Report Screen
// ─────────────────────────────────────────────────────────────────────────────
class EmployeeReportScreen extends StatefulWidget {
  const EmployeeReportScreen({super.key});

  @override
  State<EmployeeReportScreen> createState() => _EmployeeReportScreenState();
}

class _EmployeeReportScreenState extends State<EmployeeReportScreen>
    with TickerProviderStateMixin {
  final TextEditingController searchController = TextEditingController();

  String selectedFilter = "All";
  DateTime selectedMonth = DateTime.now();
  bool isLoading = true;

  // Date range selection
  DateTimeRange? selectedDateRange;
  String dateRangeType = "Month"; // "Month", "Day", "Custom"

  // Report period selection
  String reportPeriod =
      "Current Month"; // "Current Month", "Last Month", "Custom"

  // Reports data
  List<ReportModel> attendanceReports = [];
  List<ReportModel> leaveReports = [];
  List<ReportModel> salaryReports = [];

  // Rebuilt on each call so it always sees the latest loaded reports.
  ReportPdfService get _pdf => ReportPdfService(
        attendanceReports: attendanceReports,
        leaveReports: leaveReports,
        salaryReports: salaryReports,
      );

  // Animation controllers
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _initializeDateRange();
    _loadReports();
  }

  // ── Initialize date range ───────────────────────────────────────────────────
  void _initializeDateRange() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(
      now.year,
      now.month,
      DateTime(now.year, now.month + 1, 0).day,
    );

    setState(() {
      selectedDateRange = DateTimeRange(start: startOfMonth, end: endOfMonth);
    });
  }

  // ── Update date range for selected month ─────────────────────────────────────
  void _updateDateRangeForMonth(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(
      month.year,
      month.month,
      DateTime(month.year, month.month + 1, 0).day,
    );

    setState(() {
      selectedDateRange = DateTimeRange(start: startOfMonth, end: endOfMonth);
    });
  }

  // ── Period chip ───────────────────────────────────────────────────────────────
  Widget _periodChip(String title, String value) {
    final selected = reportPeriod == value;

    return ChoiceChip(
      label: Text(title),
      selected: selected,
      onSelected: (_) {
        setState(() {
          reportPeriod = value;
          if (value == "Current Month") {
            _initializeDateRange();
          } else if (value == "Last Month") {
            final now = DateTime.now();
            final lastMonth = DateTime(now.year, now.month - 1, 1);
            final lastMonthEnd = DateTime(now.year, now.month, 0);
            selectedDateRange = DateTimeRange(
              start: lastMonth,
              end: lastMonthEnd,
            );
          }
          _loadReports();
        });
      },
      selectedColor: AppColors.accent,
      backgroundColor: AppColors.card,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
      ),
    );
  }

  // ── Date range type chip ─────────────────────────────────────────────────────
  Widget _rangeTypeChip(String title, String value) {
    final selected = dateRangeType == value;

    return ChoiceChip(
      label: Text(title),
      selected: selected,
      onSelected: (_) {
        setState(() {
          dateRangeType = value;
          if (value == "Month") {
            _updateDateRangeForMonth(selectedMonth);
          }
          _loadReports();
        });
      },
      selectedColor: AppColors.accent,
      backgroundColor: AppColors.card,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
      ),
    );
  }

  // ── Date picker button ───────────────────────────────────────────────────────
  Widget _buildDatePickerButton(
    String label,
    DateTime? initialDate,
    Function(DateTime?) onDateSelected,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                initialDate != null
                    ? DateFormat('dd MMM yyyy', 'en_US').format(initialDate)
                    : 'Select Date',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: initialDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    onDateSelected(date);
                  }
                },
                icon: const Icon(Icons.calendar_today, size: 20),
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Month picker button ──────────────────────────────────────────────────────
  Widget _buildMonthPickerButton(
    String label,
    DateTime initialMonth,
    Function(DateTime) onMonthSelected,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMM yyyy', 'en_US').format(initialMonth),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                onPressed: () async {
                  final month = await showDatePicker(
                    context: context,
                    initialDate: initialMonth,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (month != null) {
                    onMonthSelected(month);
                  }
                },
                icon: const Icon(Icons.calendar_month, size: 20),
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Salary PDF button ────────────────────────────────────────────────────────
  Widget _salaryPdfButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(title, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    searchController.dispose();
    super.dispose();
  }

  // ── Load all reports from Firebase ────────────────────────────────────────
  Future<void> _loadReports() async {
    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final companyId = userDoc.data()?['companyId'] ?? '';
      if (companyId.isEmpty) return;

      // Load attendance reports
      await _loadAttendanceReports(companyId);

      // Load leave reports
      await _loadLeaveReports(companyId);

      // Load salary reports
      await _loadSalaryReports(companyId);

      if (mounted) {
        _fadeCtrl.forward();
      }
    } catch (e) {
      debugPrint('Error loading reports: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ── Load attendance reports ───────────────────────────────────────────────
  Future<void> _loadAttendanceReports(String companyId) async {
    final startDate = selectedDateRange?.start;
    final endDate = selectedDateRange?.end;

    Query query = FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('attendance');

    if (startDate != null && endDate != null) {
      final startStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(endDate);
      query = query
          .where('date', isGreaterThanOrEqualTo: startStr)
          .where('date', isLessThanOrEqualTo: endStr);
    }

    final querySnapshot = await query.get();

    final List<ReportModel> reports = [];

    for (final doc in querySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final employeeDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('employees')
          .doc(data['employeeId'])
          .get();

      final employeeData = employeeDoc.data() ?? {};

      reports.add(
        ReportModel(
          id: doc.id,
          title: 'Attendance Report - ${data['date']}',
          type: 'Attendance',
          date: _formatDate(data['date']),
          description: 'Status: ${data['status'] ?? 'Unknown'}',
          employeeId: data['employeeId'] ?? '',
          employeeName: data['name'] ?? employeeData['name'] ?? 'Unknown',
          amount: 0.0,
          status: data['status'] ?? 'present',
          metadata: {
            'punchIn': data['punchIn']?.toDate(),
            'punchOut': data['punchOut']?.toDate(),
            'isLate': data['isLate'] ?? false,
            'punchInTime': data['punchIn']?.toDate(),
            'punchOutTime': data['punchOut']?.toDate(),
            'isPresent': data['status'] == 'present',
            'isAbsent': data['status'] == 'absent',
          },
        ),
      );
    }

    setState(() => attendanceReports = reports);
  }

  // ── Load leave reports ────────────────────────────────────────────────────
  Future<void> _loadLeaveReports(String companyId) async {
    final startDate = selectedDateRange?.start;
    final endDate = selectedDateRange?.end;

    Query query = FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('leaves');

    if (startDate != null && endDate != null) {
      final startStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(endDate);
      query = query
          .where('appliedOn', isGreaterThanOrEqualTo: startStr)
          .where('appliedOn', isLessThanOrEqualTo: endStr);
    }

    final querySnapshot = await query.get();

    final List<ReportModel> reports = [];

    for (final doc in querySnapshot.docs) {
      final raw = doc.data();
      final data = (raw is Map)
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};

      DateTime? toDate(dynamic v) {
        try {
          if (v == null) return null;
          if (v is DateTime) return v;
          if (v is Timestamp) return v.toDate();
        } catch (_) {}
        return null;
      }

      final appliedOn = toDate(data['appliedOn']) ?? DateTime.now();
      final from = toDate(data['from']);
      final to = toDate(data['to']);
      final daysValue = data['days'];
      final double amount = (daysValue is num)
          ? daysValue.toDouble()
          : double.tryParse('$daysValue') ?? 0.0;

      reports.add(
        ReportModel(
          id: doc.id,
          title: 'Leave Report - ${data['type'] ?? ''}',
          type: 'Leave',
          date: _formatDate(appliedOn),
          description: '${data['days'] ?? 0} days - ${data['reason'] ?? ''}',
          employeeId: data['employeeId'] ?? '',
          employeeName: data['name'] ?? 'Unknown',
          amount: amount,
          status: data['status'] ?? 'pending',
          metadata: {'from': from, 'to': to, 'type': data['type']},
        ),
      );
    }

    setState(() => leaveReports = reports);
  }

  // ── Load salary reports ───────────────────────────────────────────────────
  Future<void> _loadSalaryReports(String companyId) async {
    final startDate = selectedDateRange?.start;
    final endDate = selectedDateRange?.end;
    final startStr = DateFormat(
      'yyyy-MM-dd',
      'en_US',
    ).format(startDate ?? DateTime.now());
    final endStr = DateFormat('yyyy-MM-dd').format(endDate ?? DateTime.now());

    final employeesQuery = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('employees')
        .get();

    final List<ReportModel> reports = [];

    for (final empDoc in employeesQuery.docs) {
      final empData = empDoc.data();
      final basicSalary = (empData['basicSalary'] ?? 0).toDouble();

      // Calculate salary based on attendance and leaves
      final attendanceQuery = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('attendance')
          .where('employeeId', isEqualTo: empDoc.id)
          .where('date', isGreaterThanOrEqualTo: startStr)
          .where('date', isLessThanOrEqualTo: endStr)
          .get();

      final leaveQuery = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('leaves')
          .where('employeeId', isEqualTo: empDoc.id)
          .where('appliedOn', isGreaterThanOrEqualTo: startStr)
          .where('appliedOn', isLessThanOrEqualTo: endStr)
          .get();

      // Calculate deductions
      int absentDays = 0;
      int lateDays = 0;
      for (final attDoc in attendanceQuery.docs) {
        final attData = attDoc.data();
        if (attData['status'] == 'absent') absentDays++;
        if (attData['isLate'] == true) lateDays++;
      }

      int leaveDays = 0;
      for (final leaveDoc in leaveQuery.docs) {
        final leaveData = leaveDoc.data();
        if (leaveData['status'] == 'approved') {
          leaveDays += (leaveData['days'] as num? ?? 0).toInt();
        }
      }

      final perDay = basicSalary / 30;
      final absentDeduction = absentDays * perDay;
      final lateDeduction = (lateDays ~/ 3) * (perDay * 0.5);
      final leaveDeduction = leaveDays * perDay * 0.5;

      final netSalary =
          basicSalary - (absentDeduction + lateDeduction + leaveDeduction);

      reports.add(
        ReportModel(
          id: empDoc.id,
          title: 'Salary Slip - ${startDate?.year}-${startDate?.month}',
          type: 'Salary',
          date: _formatDate(startDate ?? DateTime.now()),
          description: 'Net Salary: ₹${netSalary.toStringAsFixed(0)}',
          employeeId: empDoc.id,
          employeeName: empData['name'] ?? 'Unknown',
          amount: netSalary,
          status: 'paid',
          metadata: {
            'basicSalary': basicSalary,
            'absentDays': absentDays,
            'lateDays': lateDays,
            'leaveDays': leaveDays,
            'absentDeduction': absentDeduction,
            'lateDeduction': lateDeduction,
            'leaveDeduction': leaveDeduction,
            'period': 'Monthly',
          },
        ),
      );
    }

    setState(() => salaryReports = reports);
  }

  // ── Helper: Format date ───────────────────────────────────────────────────
  String _formatDate(dynamic date) {
    if (date == null) return '';
    if (date is DateTime) {
      return DateFormat('dd MMM yyyy', 'en_US').format(date);
    }
    if (date is Timestamp) {
      return DateFormat('dd MMM yyyy', 'en_US').format(date.toDate());
    }
    if (date is String) {
      try {
        final parsed = DateTime.parse(date);
        return DateFormat('dd MMM yyyy', 'en_US').format(parsed);
      } catch (_) {
        return date;
      }
    }
    return date.toString();
  }

  // ── Get all reports combined ───────────────────────────────────────────────
  List<ReportModel> get allReports {
    final List<ReportModel> combined = [];
    combined.addAll(attendanceReports);
    combined.addAll(leaveReports);
    combined.addAll(salaryReports);
    return combined;
  }

  // ── Filtered reports ──────────────────────────────────────────────────────
  List<ReportModel> get filteredReports {
    return allReports.where((report) {
      final searchText = searchController.text.toLowerCase();
      final searchMatch = searchText.isEmpty || report.title.toLowerCase().contains(searchText);

      final filterMatch = selectedFilter == "All"
          ? true
          : report.type == selectedFilter;

      return searchMatch && filterMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          "Employee Reports",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnim,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 1000;
                  final isTablet =
                      constraints.maxWidth >= 700 &&
                      constraints.maxWidth < 1000;

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isDesktop ? 1400 : 900,
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(isDesktop ? 24 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isDesktop)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Smart HRMS Reports",
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      "Comprehensive employee reports with real-time data",
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            /// SEARCH
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: TextField(
                                controller: searchController,
                                onChanged: (_) {
                                  setState(() {});
                                },
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                                decoration: const InputDecoration(
                                  hintText: "Search reports...",
                                  hintStyle: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                  border: InputBorder.none,
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            /// SUMMARY CARDS
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: isDesktop
                                      ? 250
                                      : isTablet
                                      ? 220
                                      : (constraints.maxWidth - 56) / 3,
                                  child: _summaryCard(
                                    "Attendance",
                                    "${attendanceReports.length}",
                                    Icons.calendar_month,
                                    AppColors.blue,
                                  ),
                                ),
                                SizedBox(
                                  width: isDesktop
                                      ? 250
                                      : isTablet
                                      ? 220
                                      : (constraints.maxWidth - 56) / 3,
                                  child: _summaryCard(
                                    "Leave",
                                    "${leaveReports.length}",
                                    Icons.event_busy,
                                    AppColors.orange,
                                  ),
                                ),
                                SizedBox(
                                  width: isDesktop
                                      ? 250
                                      : isTablet
                                      ? 220
                                      : (constraints.maxWidth - 56) / 3,
                                  child: _summaryCard(
                                    "Salary",
                                    "${salaryReports.length}",
                                    Icons.currency_rupee,
                                    AppColors.green,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            /// DATE RANGE SELECTION
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Report Period",
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  /// Period Selection
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _periodChip(
                                          "Current Month",
                                          "Current Month",
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _periodChip(
                                          "Last Month",
                                          "Last Month",
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  /// Date Range Type
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _rangeTypeChip("Month", "Month"),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _rangeTypeChip("Day", "Day"),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _rangeTypeChip(
                                          "Custom",
                                          "Custom",
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  /// Custom Date Range Picker
                                  if (dateRangeType == "Custom")
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDatePickerButton(
                                            "Start Date",
                                            selectedDateRange?.start,
                                            (date) => setState(() {
                                              selectedDateRange = DateTimeRange(
                                                start:
                                                    date ??
                                                    selectedDateRange?.start ??
                                                    DateTime.now(),
                                                end:
                                                    selectedDateRange?.end ??
                                                    DateTime.now(),
                                              );
                                              _loadReports();
                                            }),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildDatePickerButton(
                                            "End Date",
                                            selectedDateRange?.end,
                                            (date) => setState(() {
                                              selectedDateRange = DateTimeRange(
                                                start:
                                                    selectedDateRange?.start ??
                                                    DateTime.now(),
                                                end:
                                                    date ??
                                                    selectedDateRange?.end ??
                                                    DateTime.now(),
                                              );
                                              _loadReports();
                                            }),
                                          ),
                                        ),
                                      ],
                                    )
                                  else if (dateRangeType == "Month")
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildMonthPickerButton(
                                            "Month",
                                            selectedMonth,
                                            (month) => setState(() {
                                              selectedMonth = month;
                                              _updateDateRangeForMonth(month);
                                              _loadReports();
                                            }),
                                          ),
                                        ),
                                      ],
                                    )
                                  else if (dateRangeType == "Day")
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDatePickerButton(
                                            "Select Date",
                                            selectedDateRange?.start,
                                            (date) => setState(() {
                                              final selectedDate =
                                                  date ??
                                                  selectedDateRange?.start ??
                                                  DateTime.now();
                                              selectedDateRange = DateTimeRange(
                                                start: selectedDate,
                                                end: selectedDate,
                                              );
                                              _loadReports();
                                            }),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            /// FILTERS
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _filterChip("All"),
                                  _filterChip("Attendance"),
                                  _filterChip("Leave"),
                                  _filterChip("Salary"),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            /// SALARY PDF DOWNLOAD BUTTONS
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Salary PDF Downloads",
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _salaryPdfButton(
                                          "Current Month",
                                          Icons.picture_as_pdf,
                                          AppColors.accent,
                                          () => _pdf.generateSalary(
                                            "Current Month",
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _salaryPdfButton(
                                          "Last Month",
                                          Icons.picture_as_pdf,
                                          AppColors.green,
                                          () =>
                                              _pdf.generateSalary("Last Month"),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _salaryPdfButton(
                                          "Attendance Report",
                                          Icons.calendar_month,
                                          AppColors.blue,
                                          () => _pdf.generateAttendance(
                                            "Current Month",
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _salaryPdfButton(
                                          "Leave Report",
                                          Icons.event_busy,
                                          AppColors.orange,
                                          () => _pdf.generateLeave(
                                            "Current Month",
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            /// REPORTS
                            isDesktop
                                ? GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: filteredReports.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 16,
                                          childAspectRatio: 2.4,
                                        ),
                                    itemBuilder: (context, index) {
                                      return _reportCard(
                                        filteredReports[index],
                                      );
                                    },
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: filteredReports.length,
                                    itemBuilder: (context, index) {
                                      return _reportCard(
                                        filteredReports[index],
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _summaryCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(
            count,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(title, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _filterChip(String title) {
    final selected = selectedFilter == title;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(title),
        selected: selected,
        onSelected: (_) {
          setState(() {
            selectedFilter = title;
          });
        },
        selectedColor: AppColors.accent,
        backgroundColor: AppColors.card,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _reportCard(ReportModel report) {
    final color = report.type == 'Attendance'
        ? AppColors.blue
        : report.type == 'Leave'
        ? AppColors.orange
        : AppColors.green;

    final icon = report.type == 'Attendance'
        ? Icons.calendar_month
        : report.type == 'Leave'
        ? Icons.beach_access
        : Icons.currency_rupee;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      report.date,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: report.status == 'paid' || report.status == 'present'
                      ? AppColors.green.withValues(alpha: 0.1)
                      : report.status == 'pending'
                      ? AppColors.amber.withValues(alpha: 0.1)
                      : AppColors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  report.status.toUpperCase(),
                  style: TextStyle(
                    color: report.status == 'paid' || report.status == 'present'
                        ? AppColors.green
                        : report.status == 'pending'
                        ? AppColors.amber
                        : AppColors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.description,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const Spacer(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _viewReport(report),
                  icon: const Icon(Icons.visibility),
                  label: const Text("View"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                  ),
                  onPressed: () => _downloadReport(report),
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: const Text(
                    "Download",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── View report details ───────────────────────────────────────────────────
  void _viewReport(ReportModel report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          report.title,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow("Employee", report.employeeName),
              _buildDetailRow("Type", report.type),
              _buildDetailRow("Date", report.date),
              _buildDetailRow("Status", report.status),
              if (report.type == 'Salary') ...[
                _buildDetailRow(
                  "Amount",
                  "₹${report.amount.toStringAsFixed(0)}",
                ),
                if (report.metadata != null) ...[
                  if (report.metadata!['absentDays'] != null)
                    _buildDetailRow(
                      "Absent Days",
                      report.metadata!['absentDays'].toString(),
                    ),
                  if (report.metadata!['lateDays'] != null)
                    _buildDetailRow(
                      "Late Days",
                      report.metadata!['lateDays'].toString(),
                    ),
                  if (report.metadata!['leaveDays'] != null)
                    _buildDetailRow(
                      "Leave Days",
                      report.metadata!['leaveDays'].toString(),
                    ),
                ],
              ],
              if (report.type == 'Attendance') ...[
                if (report.metadata != null) ...[
                  if (report.metadata!['isLate'] != null)
                    _buildDetailRow(
                      "Late",
                      report.metadata!['isLate'] ? "Yes" : "No",
                    ),
                  if (report.metadata!['punchIn'] != null)
                    _buildDetailRow(
                      "Punch In",
                      _formatDate(report.metadata!['punchIn']),
                    ),
                  if (report.metadata!['punchOut'] != null)
                    _buildDetailRow(
                      "Punch Out",
                      _formatDate(report.metadata!['punchOut']),
                    ),
                ],
              ],
              if (report.type == 'Leave') ...[
                _buildDetailRow("Description", report.description),
                if (report.metadata != null) ...[
                  if (report.metadata!['from'] != null)
                    _buildDetailRow(
                      "From",
                      _formatDate(report.metadata!['from']),
                    ),
                  if (report.metadata!['to'] != null)
                    _buildDetailRow("To", _formatDate(report.metadata!['to'])),
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Download report ───────────────────────────────────────────────────────
  void _downloadReport(ReportModel report) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Generating ${report.title} PDF..."),
        backgroundColor: AppColors.accent,
      ),
    );

    // Generate PDF
    _pdf.generate(report).then((pdfBytes) {
      if (!mounted) return;
      if (pdfBytes != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Report downloaded successfully!"),
            backgroundColor: AppColors.green,
          ),
        );
        // In a real app, you would save the PDF to device storage or share it
        debugPrint("PDF generated with ${pdfBytes.length} bytes");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to generate report"),
            backgroundColor: AppColors.red,
          ),
        );
      }
    });
  }

}

