import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:myapp/core.dart';
import 'package:myapp/widgets/common.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class EmployeeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> employee;
  const EmployeeDetailScreen({super.key, required this.employee});

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  String _companyId = '';
  bool _loadingCo = true;
  bool _updating = false;

  // Month picker — defaults to current month
  DateTime _viewMonth = DateTime(DateTime.now().year, DateTime.now().month);

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
    _loadCompanyId();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Fetch companyId from the currently signed-in admin account ─────────────
  Future<void> _loadCompanyId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loadingCo = false);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (mounted) {
      _companyId = doc.data()?['companyId'] ?? '';
      setState(() => _loadingCo = false);
      _fadeCtrl.forward();
    }
  }

  // ── Attendance stream — same collection as employee_home.dart ──────────────
  Stream<QuerySnapshot> get _attendanceStream {
    if (_companyId.isEmpty) return const Stream.empty();
    final monthStr = DateFormat('yyyy-MM').format(_viewMonth);
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('attendance')
        .where(
          'employeeId',
          isEqualTo: widget.employee['employeeId'] ?? widget.employee['uid'],
        )
        .where('date', isGreaterThanOrEqualTo: '$monthStr-01')
        .where('date', isLessThanOrEqualTo: '$monthStr-31')
        .snapshots();
  }

  // ── Manual punch fix (writes to same path as employee_home.dart) ───────────
  Future<void> _updatePunch({
    required String date,
    required String inTime,
    required String outTime,
  }) async {
    if (_companyId.isEmpty) {
      _showSnack('Company ID not found. Please re-login.', isError: true);
      return;
    }
    setState(() => _updating = true);

    // Parse times into proper DateTime+Timestamp values
    DateTime? punchIn, punchOut;
    try {
      final fmt = DateFormat('hh:mm a');
      final base = DateFormat('yyyy-MM-dd').parse(date);
      if (inTime.isNotEmpty) {
        final t = fmt.parse(inTime);
        punchIn = DateTime(base.year, base.month, base.day, t.hour, t.minute);
      }
      if (outTime.isNotEmpty) {
        final t = fmt.parse(outTime);
        punchOut = DateTime(base.year, base.month, base.day, t.hour, t.minute);
      }
    } catch (_) {
      _showSnack('Invalid time format. Use hh:mm AM/PM.', isError: true);
      setState(() => _updating = false);
      return;
    }

    try {
      // Query existing doc for that date
      final snap = await FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('attendance')
          .where(
            'employeeId',
            isEqualTo: widget.employee['employeeId'] ?? widget.employee['uid'],
          )
          .where('date', isEqualTo: date)
          .get();

      final Map<String, dynamic> payload = {
        'employeeId': widget.employee['employeeId'] ?? widget.employee['uid'],
        'name': widget.employee['name'],
        'date': date,
        if (punchIn != null) 'punchIn': Timestamp.fromDate(punchIn),
        if (punchOut != null) 'punchOut': Timestamp.fromDate(punchOut),
        'manualEdit': true,
        'editedAt': FieldValue.serverTimestamp(),
      };

      if (snap.docs.isNotEmpty) {
        await snap.docs.first.reference.update(payload);
      } else {
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(_companyId)
            .collection('attendance')
            .add(payload);
      }

      _showSnack('✅ Attendance updated for $date');
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    SnackBarUtils.show(context, msg, isError: isError);
  }

  // ── Days in the selected month ─────────────────────────────────────────────
  int get _daysInMonth =>
      DateUtils.getDaysInMonth(_viewMonth.year, _viewMonth.month);

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loadingCo) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    final double basic =
        double.tryParse(widget.employee['salary']?.toString() ?? '0') ?? 25000;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(),
      floatingActionButton: _updating
          ? const FloatingActionButton.extended(
              onPressed: null,
              label: SizedBox(
                width: 80,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
              backgroundColor: AppColors.purple,
              icon: null,
            )
          : FloatingActionButton.extended(
              onPressed: () => _showAddPunchDialog(context),
              label: const Text(
                'Fix Punch',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              icon: const Icon(Icons.edit_calendar_rounded),
              backgroundColor: AppColors.purple,
            ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _attendanceStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading data\n${snapshot.error}',
                style: const TextStyle(color: AppColors.red),
                textAlign: TextAlign.center,
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          // Build a set of present dates for O(1) lookup
          final Set<String> presentDates = {};
          final Set<String> missedDates = {};
          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            final date = data['date'] as String? ?? '';
            if (data['punchIn'] != null && data['punchOut'] != null) {
              presentDates.add(date);
            } else if (data['punchIn'] != null) {
              missedDates.add(date); // punched in but no punch-out
            }
          }

          // Salary calc
          final int presentDays = presentDates.length;
          final int missedPunches = missedDates.length;
          final double perDay = basic / 30;
          final double absentDeduction =
              ((30 - presentDays).clamp(0, 30)) * perDay;
          final double missedDeduction = missedPunches * (perDay * 0.5);
          final double netSalary = (basic - absentDeduction - missedDeduction)
              .clamp(0, double.infinity);

          return FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 20),
                  _buildStatRow(
                    presentDays,
                    missedPunches,
                    30 - presentDays - missedPunches,
                  ),
                  const SizedBox(height: 24),
                  _buildMonthSelector(),
                  const SizedBox(height: 12),
                  _buildCalendarGrid(presentDates, missedDates),
                  const SizedBox(height: 24),
                  _buildSalaryCard(
                    basic: basic,
                    absentDeduction: absentDeduction,
                    missedDeduction: missedDeduction,
                    netSalary: netSalary,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: AppColors.surface,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    leading: IconButton(
      icon: const Icon(
        Icons.arrow_back_ios_new_rounded,
        color: AppColors.textPrimary,
        size: 18,
      ),
      onPressed: () => Navigator.pop(context),
    ),
    title: const Text(
      'Employee Report',
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: AppColors.border),
    ),
  );

  // ── Profile header ─────────────────────────────────────────────────────────
  Widget _buildProfileHeader() {
    final name = widget.employee['name'] as String? ?? 'Unknown';
    final empId =
        widget.employee['empId'] ?? widget.employee['employeeId'] ?? '—';
    final dept = widget.employee['dept'] ?? 'General';
    final picUrl = widget.employee['profilePic'] as String?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.accent.withValues(alpha: 0.2),
            backgroundImage: (picUrl != null && picUrl.isNotEmpty)
                ? NetworkImage(picUrl)
                : null,
            child: (picUrl == null || picUrl.isEmpty)
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 26,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'ID: $empId',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    dept,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stat row ───────────────────────────────────────────────────────────────
  Widget _buildStatRow(int present, int missed, int absent) {
    return Row(
      children: [
        StatChip(label: 'Present', value: '$present', color: AppColors.green),
        const SizedBox(width: 10),
        StatChip(label: 'Missed', value: '$missed', color: AppColors.amber),
        const SizedBox(width: 10),
        StatChip(
          label: 'Absent',
          value: '${absent.clamp(0, 30)}',
          color: AppColors.red,
        ),
      ],
    );
  }

  // ── Month selector ─────────────────────────────────────────────────────────
  Widget _buildMonthSelector() {
    return Row(
      children: [
        const Text(
          'Attendance  ·',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _viewMonth,
              firstDate: DateTime(2023),
              lastDate: DateTime.now(),
              initialDatePickerMode: DatePickerMode.year,
              builder: (ctx, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(primary: AppColors.accent), dialogTheme: const DialogThemeData(backgroundColor: AppColors.card),
                ),
                child: child!,
              ),
            );
            if (picked != null && mounted) {
              setState(() => _viewMonth = DateTime(picked.year, picked.month));
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_viewMonth),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.expand_more_rounded,
                  color: AppColors.accent,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Calendar grid — FIXED date calculation ─────────────────────────────────
  Widget _buildCalendarGrid(Set<String> presentDates, Set<String> missedDates) {
    final days = _daysInMonth;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day-of-week header
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map(
                  (d) => Center(
                    child: Text(
                      d,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (_, i) {
              // FIX: build date correctly using DateTime constructor
              final day = i + 1;
              final date = DateTime(_viewMonth.year, _viewMonth.month, day);
              final dateStr = DateFormat('yyyy-MM-dd').format(date);
              final isPresent = presentDates.contains(dateStr);
              final isMissed = missedDates.contains(dateStr);
              final isFuture = date.isAfter(DateTime.now());
              final isToday =
                  DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateStr;

              Color bgColor;
              Color borderColor;
              Color textColor;

              if (isFuture) {
                bgColor = Colors.transparent;
                borderColor = AppColors.border.withValues(alpha: 0.3);
                textColor = AppColors.textSecondary.withValues(alpha: 0.3);
              } else if (isPresent) {
                bgColor = AppColors.green.withValues(alpha: 0.18);
                borderColor = AppColors.green.withValues(alpha: 0.5);
                textColor = AppColors.green;
              } else if (isMissed) {
                bgColor = AppColors.amber.withValues(alpha: 0.15);
                borderColor = AppColors.amber.withValues(alpha: 0.5);
                textColor = AppColors.amber;
              } else {
                bgColor = AppColors.red.withValues(alpha: 0.08);
                borderColor = AppColors.red.withValues(alpha: 0.2);
                textColor = AppColors.red.withValues(alpha: 0.7);
              }

              return Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isToday ? AppColors.accent : borderColor,
                    width: isToday ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: isToday ? AppColors.accent : textColor,
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          // Legend
          const Row(
            children: [
              LegendDot(color: AppColors.green, label: 'Present'),
              SizedBox(width: 12),
              LegendDot(color: AppColors.amber, label: 'Missed Punch'),
              SizedBox(width: 12),
              LegendDot(color: AppColors.red, label: 'Absent'),
              SizedBox(width: 12),
              LegendDot(color: AppColors.accent, label: 'Today'),
            ],
          ),
        ],
      ),
    );
  }

  // ── Salary card ────────────────────────────────────────────────────────────
  Widget _buildSalaryCard({
    required double basic,
    required double absentDeduction,
    required double missedDeduction,
    required double netSalary,
  }) {
    final fmt = NumberFormat('#,##,##0', 'en_IN');
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
            'Salary Breakdown',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 16),
          _salRow('Basic Pay', '₹ ${fmt.format(basic)}', AppColors.textPrimary),
          const SizedBox(height: 10),
          _salRow(
            'Absent Deduction',
            '− ₹ ${fmt.format(absentDeduction)}',
            AppColors.red,
          ),
          const SizedBox(height: 10),
          _salRow(
            'Missed Punch (50%)',
            '− ₹ ${fmt.format(missedDeduction)}',
            AppColors.amber,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Container(height: 1, color: AppColors.border),
          ),
          _salRow(
            'Net Payout',
            '₹ ${fmt.format(netSalary)}',
            AppColors.green,
            isBold: true,
            fontSize: 18,
          ),
        ],
      ),
    );
  }

  Widget _salRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
    double fontSize = 14,
  }) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );

  // ── Manual punch dialog — with time picker ─────────────────────────────────
  void _showAddPunchDialog(BuildContext context) {
    // Default to today
    String selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    TimeOfDay? inTime;
    TimeOfDay? outTime;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          String fmtTime(TimeOfDay? t) =>
              t == null ? '— not set —' : t.format(ctx);

          return AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Fix Punch',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Date picker row
                DialogRow(
                  label: 'Date',
                  value: selectedDate,
                  icon: Icons.calendar_today_rounded,
                  color: AppColors.accent,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                      builder: (c, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppColors.accent,
                          ), dialogTheme: const DialogThemeData(backgroundColor: AppColors.card),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setDlgState(
                        () => selectedDate = DateFormat(
                          'yyyy-MM-dd',
                        ).format(picked),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                // Punch-in time picker
                DialogRow(
                  label: 'Punch In',
                  value: fmtTime(inTime),
                  icon: Icons.login_rounded,
                  color: AppColors.green,
                  onTap: () async {
                    final t = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.now(),
                      builder: (c, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppColors.green,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (t != null) setDlgState(() => inTime = t);
                  },
                ),
                const SizedBox(height: 12),
                // Punch-out time picker
                DialogRow(
                  label: 'Punch Out',
                  value: fmtTime(outTime),
                  icon: Icons.logout_rounded,
                  color: AppColors.red,
                  onTap: () async {
                    final t = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.now(),
                      builder: (c, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(primary: AppColors.red),
                        ),
                        child: child!,
                      ),
                    );
                    if (t != null) setDlgState(() => outTime = t);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _updatePunch(
                    date: selectedDate,
                    inTime: inTime != null ? inTime!.format(context) : '',
                    outTime: outTime != null ? outTime!.format(context) : '',
                  );
                },
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets - using shared widgets from widgets/common.dart
// ─────────────────────────────────────────────────────────────────────────────
