import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:myapp/utility/dummy_data_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens  (identical palette to home + detail screens)
// ─────────────────────────────────────────────────────────────────────────────
class _T {
  static const bg = Color(0xFF07090F);
  static const surface = Color(0xFF0F1219);
  static const card = Color(0xFF141B26);
  static const accent = Color(0xFF3D7BF7);
  static const textPrimary = Color(0xFFEDF1F9);
  static const textSecondary = Color(0xFF6B7A96);
  static const border = Color(0xFF1C2335);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
  static const amber = Color(0xFFF59E0B);
  static const purple = Color(0xFF818CF8);
  static const teal = Color(0xFF14B8A6);
}

// ─────────────────────────────────────────────────────────────────────────────
// Responsive breakpoints
// ─────────────────────────────────────────────────────────────────────────────
class _Breakpoints {
  static const double tablet = 900;
  static const double desktop = 1200;

  static _DeviceType getDeviceType(double width) {
    if (width >= desktop) return _DeviceType.desktop;
    if (width >= tablet) return _DeviceType.tablet;
    return _DeviceType.mobile;
  }
}

enum _DeviceType { mobile, tablet, desktop }

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────
class LeaveRecord {
  final String id;
  final String type;
  final String reason;
  final String status; // 'pending' | 'approved' | 'rejected'
  final DateTime from;
  final DateTime to;
  final DateTime appliedOn;
  final int days;

  LeaveRecord({
    required this.id,
    required this.type,
    required this.reason,
    required this.status,
    required this.from,
    required this.to,
    required this.appliedOn,
    required this.days,
  });

  factory LeaveRecord.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    // FIX: guard against missing Timestamps instead of hard-casting
    final from = (d['from'] as Timestamp?)?.toDate() ?? DateTime.now();
    final to = (d['to'] as Timestamp?)?.toDate() ?? DateTime.now();
    return LeaveRecord(
      id: doc.id,
      type: d['type'] as String? ?? 'Casual',
      reason: d['reason'] as String? ?? '',
      status: d['status'] as String? ?? 'pending',
      from: from,
      to: to,
      appliedOn: (d['appliedOn'] as Timestamp?)?.toDate() ?? DateTime.now(),
      // FIX: use stored days field if present; fallback to diff+1
      days: d['days'] as int? ?? (to.difference(from).inDays + 1),
    );
  }
}

class AttendanceRecord {
  final String date;
  final DateTime? punchIn;
  final DateTime? punchOut;
  final bool isLate; // punch-in after 09:30

  const AttendanceRecord({
    required this.date,
    this.punchIn,
    this.punchOut,
    required this.isLate,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// EmployeeExploreScreen
// ─────────────────────────────────────────────────────────────────────────────
class EmployeeExploreScreen extends StatefulWidget {
  const EmployeeExploreScreen({super.key});

  @override
  State<EmployeeExploreScreen> createState() => _EmployeeExploreScreenState();
}

class _EmployeeExploreScreenState extends State<EmployeeExploreScreen>
    with SingleTickerProviderStateMixin {
  // ── User ───────────────────────────────────────────────────────────────────
  String _companyId = '';
  String _employeeId = '';
  String _userName = '';
  double _basicSalary = 25000;
  bool _loading = true;

  // ── Live data ──────────────────────────────────────────────────────────────
  List<LeaveRecord> _allLeaves = [];
  List<AttendanceRecord> _attendance = [];

  StreamSubscription<QuerySnapshot>? _leaveSub;
  StreamSubscription<QuerySnapshot>? _attendSub;

  // ── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── Company config (fetched from Firestore) ────────────────────────────────
  Map<String, int> _leavePolicy = {
    'Casual': 12,
    'Sick': 8,
    'Earned': 15,
    'Maternity': 90,
    'Paternity': 5,
    'Unpaid': 0,
  };
  int _lateHour = 9;
  int _lateMinute = 30;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _init();
  }

  @override
  void dispose() {
    _leaveSub?.cancel();
    _attendSub?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      _employeeId = user.uid;
      _userName = user.displayName ?? _userName;

      final profileDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_employeeId)
          .get();

      if (profileDoc.exists) {
        final data = profileDoc.data() as Map<String, dynamic>;
        _companyId = data['companyId'] as String? ?? _companyId;
        _userName = data['name'] as String? ?? _userName;
        _basicSalary =
            (data['basicSalary'] as num?)?.toDouble() ?? _basicSalary;
      } else {
        debugPrint('User profile not found in Firestore');
      }

      if (_companyId.isEmpty) {
        debugPrint('Company ID not found in user profile');
        _showSnack('Company not linked. Contact administrator.', isError: true);
      }

      await _fetchCompanyConfig();
      _subscribeLeaves();
      _subscribeAttendance();
      _fadeCtrl.forward();
    } catch (e) {
      debugPrint('Initialization failed: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _fetchCompanyConfig() async {
    if (_companyId.isEmpty) return;
    try {
      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .get();

      if (!companyDoc.exists) return;

      final data = companyDoc.data()!;
      final settings = data['settings'] as Map<String, dynamic>?;

      if (settings != null) {
        if (settings['leavePolicy'] is Map) {
          final policy = Map<String, int>.from(
            (settings['leavePolicy'] as Map).map(
              (k, v) => MapEntry(k as String, v as int),
            ),
          );
          if (policy.isNotEmpty) _leavePolicy = policy;
        }

        if (settings['lateThreshold'] is Map) {
          final lt = settings['lateThreshold'] as Map;
          _lateHour = (lt['hour'] as num?)?.toInt() ?? 9;
          _lateMinute = (lt['minute'] as num?)?.toInt() ?? 30;
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch company config: $e');
    }
  }

  // ── Streams ────────────────────────────────────────────────────────────────
  void _subscribeLeaves() {
    if (_companyId.isEmpty || _employeeId.isEmpty) return;

    // FIX: removed orderBy('appliedOn') to avoid mandatory composite index.
    // Sorting is done client-side after fetch.
    _leaveSub = FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('leaves')
        .where('employeeId', isEqualTo: _employeeId)
        .snapshots()
        .listen(
          (snap) {
            if (!mounted) return;
            final list = snap.docs.map((d) => LeaveRecord.fromDoc(d)).toList();
            // Client-side sort: newest first
            list.sort((a, b) => b.appliedOn.compareTo(a.appliedOn));
            setState(() => _allLeaves = list);
          },
          onError: (e) {
            _showSnack('Leave stream error: $e', isError: true);
          },
        );
  }

  void _subscribeAttendance() {
    if (_companyId.isEmpty || _employeeId.isEmpty) return;
    final monthStr = DateFormat('yyyy-MM').format(DateTime.now());
    final monthStart = '$monthStr-01';
    final monthEnd = DateTime.now()
        .add(const Duration(days: 1))
        .toString()
        .split(' ')[0];

    _attendSub = FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('attendance')
        .where('employeeId', isEqualTo: _employeeId)
        .where('date', isGreaterThanOrEqualTo: monthStart)
        .where('date', isLessThanOrEqualTo: monthEnd)
        .snapshots()
        .listen(
          (snap) {
            if (!mounted) return;
            setState(() {
              _attendance = snap.docs.map((doc) {
                final d = doc.data();
                final pIn = (d['punchIn'] as Timestamp?)?.toDate();
                final isLate =
                    pIn != null &&
                    (pIn.hour > _lateHour ||
                        (pIn.hour == _lateHour && pIn.minute > _lateMinute));
                return AttendanceRecord(
                  date: d['date'] as String? ?? '',
                  punchIn: pIn,
                  punchOut: (d['punchOut'] as Timestamp?)?.toDate(),
                  isLate: isLate,
                );
              }).toList();
            });
          },
          onError: (e) {
            _showSnack('Attendance stream error: $e', isError: true);
          },
        );
  }

  // ── Computed: Leave ────────────────────────────────────────────────────────
  int get _totalAllocated => _leavePolicy.values.fold(0, (a, b) => a + b);
  int get _applied => _allLeaves.length;
  int get _approved => _allLeaves.where((l) => l.status == 'approved').length;
  int get _rejected => _allLeaves.where((l) => l.status == 'rejected').length;
  int get _pending => _allLeaves.where((l) => l.status == 'pending').length;

  // Total approved leave days consumed this year
  int get _approvedDays => _allLeaves
      .where((l) => l.status == 'approved')
      .fold(0, (s, l) => s + l.days);

  // Total pending leave days
  int get _pendingDays => _allLeaves
      .where((l) => l.status == 'pending')
      .fold(0, (s, l) => s + l.days);

  // ── Computed: Attendance ───────────────────────────────────────────────────
  int get _presentDays =>
      _attendance.where((a) => a.punchIn != null && a.punchOut != null).length;
  int get _missedPunch =>
      _attendance.where((a) => a.punchIn != null && a.punchOut == null).length;
  int get _latePunches => _attendance.where((a) => a.isLate).length;

  // FIX: absent = days with no record at all (exclude present + missed-punch days)
  int get _absentDays {
    final today = DateTime.now();
    final daysElapsed = today.day; // days so far this month
    return (daysElapsed - _presentDays - _missedPunch).clamp(0, daysElapsed);
  }

  // ── Computed: Salary ───────────────────────────────────────────────────────
  double get _perDay => _basicSalary / 30;
  // FIX: absent deduction only on days with NO record; missed punch is separate
  double get _absentDeduction => _absentDays * _perDay;
  double get _missedDeduction => _missedPunch * (_perDay * 0.5);
  double get _lateDeduction => _latePunches * (_perDay * 0.1);
  double get _totalDeductions =>
      _absentDeduction + _missedDeduction + _lateDeduction;
  double get _netSalary =>
      (_basicSalary - _totalDeductions).clamp(0, double.infinity);

  // ── Snackbar ───────────────────────────────────────────────────────────────
  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: isError ? _T.red : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // BUILD
  // ───────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _T.bg,
        body: Center(child: CircularProgressIndicator(color: _T.accent)),
      );
    }

    final deviceType = _Breakpoints.getDeviceType(
      MediaQuery.of(context).size.width,
    );
    final isDesktop = deviceType == _DeviceType.desktop;
    final isTablet = deviceType == _DeviceType.tablet;
    final isMobile = deviceType == _DeviceType.mobile;

    return Scaffold(
      backgroundColor: _T.bg,
      floatingActionButton: _buildResponsiveFAB(isDesktop, isTablet, isMobile),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final deviceType = _Breakpoints.getDeviceType(
                constraints.maxWidth,
              );
              final isDesktop = deviceType == _DeviceType.desktop;
              final isTablet = deviceType == _DeviceType.tablet;
              final isMobile = deviceType == _DeviceType.mobile;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _SliverHeader(userName: _userName),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 32 : 20,
                      4,
                      isDesktop ? 32 : 20,
                      isDesktop ? 20 : 110,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // ── Leave overview ────────────────────────────────────
                        const _SectionLabel(label: 'LEAVE OVERVIEW'),
                        const SizedBox(height: 12),
                        _buildLeaveGrid(isDesktop, isTablet, isMobile),
                        const SizedBox(height: 14),
                        _buildLeaveBalanceBar(),

                        // ── Attendance ────────────────────────────────────────
                        const SizedBox(height: 24),
                        _SectionLabel(
                          label:
                              'ATTENDANCE  ·  ${DateFormat('MMMM').format(DateTime.now())}',
                        ),
                        const SizedBox(height: 12),
                        _buildAttendanceGrid(isDesktop, isTablet, isMobile),

                        // ── Salary ────────────────────────────────────────────
                        const SizedBox(height: 24),
                        const _SectionLabel(label: 'SALARY BREAKDOWN'),
                        const SizedBox(height: 12),
                        _buildSalaryCard(isDesktop, isTablet, isMobile),

                        // ── Quick links ───────────────────────────────────────
                        const SizedBox(height: 24),
                        const _SectionLabel(label: 'QUICK ACTIONS'),
                        const SizedBox(height: 12),
                        _buildQuickActions(isDesktop, isTablet, isMobile),
                      ]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Leave responsive grid ───────────────────────────────────────────────────
  Widget _buildLeaveGrid(bool isDesktop, bool isTablet, bool isMobile) {
    final crossAxisCount = isDesktop
        ? 4
        : isTablet
        ? 2
        : 2;
    final childAspectRatio = isDesktop
        ? 1.6
        : isTablet
        ? 1.5
        : 1.4;
    final spacing = isDesktop
        ? 16.0
        : isTablet
        ? 14.0
        : 12.0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      childAspectRatio: childAspectRatio,
      children: [
        _InfoCard(
          label: 'Total Allocated',
          value: '$_totalAllocated',
          sub: 'days per year',
          color: _T.accent,
          icon: Icons.calendar_month_rounded,
          onTap: _openAllocationSheet,
        ),
        _InfoCard(
          label: 'Applied',
          value: '$_applied',
          sub: '$_approvedDays days consumed',
          color: _T.purple,
          icon: Icons.send_rounded,
          onTap: () => _openLeaveListSheet('All Applied Leaves', _allLeaves),
        ),
        _InfoCard(
          label: 'Approved',
          value: '$_approved',
          sub: '$_approvedDays days sanctioned',
          color: _T.green,
          icon: Icons.check_circle_outline_rounded,
          onTap: () => _openLeaveListSheet(
            'Approved Leaves',
            _allLeaves.where((l) => l.status == 'approved').toList(),
          ),
        ),
        _InfoCard(
          label: 'Rejected',
          value: '$_rejected',
          sub: '$_pending pending approval',
          color: _T.red,
          icon: Icons.cancel_outlined,
          onTap: () => _openLeaveListSheet(
            'Rejected Leaves',
            _allLeaves.where((l) => l.status == 'rejected').toList(),
          ),
        ),
      ],
    );
  }

  // ── Responsive FAB ───────────────────────────────────────────────────────────
  Widget _buildResponsiveFAB(bool isDesktop, bool isTablet, bool isMobile) {
    final labelFontSize = isDesktop ? 15.0 : 14.0;
    final iconSize = isDesktop ? 22.0 : 20.0;

    if (isDesktop) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: "dummyDataDesktop",
            backgroundColor: Colors.orange,
            icon: const Icon(Icons.storage),
            label: const Text("Dummy Data"),
            onPressed: () async {
              debugPrint("Company ID = '$_companyId'");
              debugPrint("Employee ID = '$_employeeId'");
              debugPrint("User Name = '$_userName'");
              await DummyDataHelper.generate30DaysData(
                companyId: _companyId,
                employeeId: _employeeId,
                employeeName: _userName,
              );

              _showSnack("30 Days Dummy Data Added");
            },
          ),
          const SizedBox(width: 10),
          FloatingActionButton.extended(
            heroTag: "applyLeaveDesktop",
            onPressed: () => _openApplyLeaveSheet(),
            label: Text(
              'Apply Leave',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: labelFontSize,
              ),
            ),
            icon: Icon(Icons.add_rounded, size: iconSize),
            backgroundColor: _T.accent,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ],
      );
    } else {
      return FloatingActionButton.extended(
        heroTag: "applyLeaveMobile",
        onPressed: () => _openApplyLeaveSheet(),
        label: Text(
          'Apply Leave',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: labelFontSize,
          ),
        ),
        icon: Icon(Icons.add_rounded, size: iconSize),
        backgroundColor: _T.accent,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      );
    }
  }

  // ── Leave balance progress bar ─────────────────────────────────────────────
  Widget _buildLeaveBalanceBar() {
    // FIX: use days not count; guard against total=0 crash
    final total = _totalAllocated == 0 ? 1 : _totalAllocated;
    final used = _approvedDays.clamp(0, total);
    final pending = _pendingDays.clamp(0, total - used);
    final left = (total - used - pending).clamp(0, total);

    // FIX: ensure at least flex=1 for each segment to prevent zero-flex crash
    return GestureDetector(
      onTap: _openAllocationSheet,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _T.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _T.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Leave Balance',
                  style: TextStyle(
                    color: _T.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '$left days left',
                  style: TextStyle(
                    color: left > 5 ? _T.green : _T.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    if (used > 0)
                      Flexible(
                        flex: used,
                        child: Container(color: _T.green),
                      ),
                    if (pending > 0)
                      Flexible(
                        flex: pending,
                        child: Container(color: _T.amber),
                      ),
                    // FIX: always at least flex 1 so Row doesn't throw
                    Flexible(
                      flex: left > 0 ? left : 1,
                      child: Container(
                        color: left > 0
                            ? _T.border.withValues(alpha: 0.5)
                            : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _BarLegend(color: _T.green, label: 'Used ($used d)'),
                _BarLegend(color: _T.amber, label: 'Pending ($pending d)'),
                _BarLegend(color: _T.border, label: 'Available ($left d)'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Attendance responsive grid ──────────────────────────────────────────────
  Widget _buildAttendanceGrid(bool isDesktop, bool isTablet, bool isMobile) {
    final crossAxisCount = isDesktop
        ? 4
        : isTablet
        ? 2
        : 2;
    final childAspectRatio = isDesktop
        ? 1.6
        : isTablet
        ? 1.5
        : 1.4;
    final spacing = isDesktop
        ? 16.0
        : isTablet
        ? 14.0
        : 12.0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      childAspectRatio: childAspectRatio,
      children: [
        _InfoCard(
          label: 'Present',
          value: '$_presentDays',
          sub: 'days this month',
          color: _T.green,
          icon: Icons.check_circle_rounded,
          onTap: () => _openAttendanceSheet(
            'Present Days',
            _attendance
                .where((a) => a.punchIn != null && a.punchOut != null)
                .toList(),
          ),
        ),
        _InfoCard(
          label: 'Late Punch',
          value: '$_latePunches',
          sub: 'after 09:30 AM',
          color: _T.amber,
          icon: Icons.access_time_rounded,
          onTap: () => _openAttendanceSheet(
            'Late Punch Records',
            _attendance.where((a) => a.isLate).toList(),
          ),
        ),
        _InfoCard(
          label: 'Missed Punch',
          value: '$_missedPunch',
          sub: 'no punch-out',
          color: _T.purple,
          icon: Icons.fingerprint_rounded,
          onTap: () => _openAttendanceSheet(
            'Missed Punch-Out',
            _attendance
                .where((a) => a.punchIn != null && a.punchOut == null)
                .toList(),
          ),
        ),
        // FIX: Absent card now opens a proper informational sheet
        _InfoCard(
          label: 'Absent',
          value: '$_absentDays',
          sub: 'no record days',
          color: _T.red,
          icon: Icons.event_busy_rounded,
          onTap: _openAbsentInfoSheet,
        ),
      ],
    );
  }

  // ── Salary responsive card ─────────────────────────────────────────────────
  Widget _buildSalaryCard(bool isDesktop, bool isTablet, bool isMobile) {
    final fmt = NumberFormat('#,##,##0', 'en_IN');
    final padding = isDesktop
        ? 24.0
        : isTablet
        ? 22.0
        : 20.0;
    final iconSize = isDesktop
        ? 22.0
        : isTablet
        ? 20.0
        : 18.0;
    final titleSize = isDesktop
        ? 16.0
        : isTablet
        ? 15.0
        : 14.0;
    final subtitleSize = isDesktop
        ? 13.0
        : isTablet
        ? 12.0
        : 11.0;
    final rowSpacing = isDesktop
        ? 10.0
        : isTablet
        ? 9.0
        : 8.0;
    final fontSize = isDesktop
        ? 15.0
        : isTablet
        ? 14.0
        : 13.0;
    final netFontSize = isDesktop
        ? 20.0
        : isTablet
        ? 18.0
        : 17.0;

    return GestureDetector(
      onTap: _openSalarySheet,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: _T.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _T.accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(
                    isDesktop
                        ? 10
                        : isTablet
                        ? 9
                        : 8,
                  ),
                  decoration: BoxDecoration(
                    color: _T.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: _T.accent,
                    size: iconSize,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated Salary',
                      style: TextStyle(
                        color: _T.textPrimary,
                        fontSize: titleSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(DateTime.now()),
                      style: TextStyle(
                        color: _T.textSecondary,
                        fontSize: subtitleSize,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _T.textSecondary,
                  size: isDesktop
                      ? 22
                      : isTablet
                      ? 20
                      : 18,
                ),
              ],
            ),
            SizedBox(
              height: isDesktop
                  ? 20
                  : isTablet
                  ? 18
                  : 16,
            ),
            _SalRow(
              label: 'Basic Pay',
              value: '₹ ${fmt.format(_basicSalary)}',
              color: _T.textPrimary,
              fontSize: fontSize,
            ),
            SizedBox(height: rowSpacing),
            _SalRow(
              label: 'Absent  ($_absentDays d)',
              value: '− ₹ ${fmt.format(_absentDeduction)}',
              color: _T.red,
              fontSize: fontSize,
            ),
            SizedBox(height: rowSpacing),
            _SalRow(
              label: 'Missed Punch  ($_missedPunch)',
              value: '− ₹ ${fmt.format(_missedDeduction)}',
              color: _T.purple,
              fontSize: fontSize,
            ),
            SizedBox(height: rowSpacing),
            _SalRow(
              label: 'Late Arrival  ($_latePunches)',
              value: '− ₹ ${fmt.format(_lateDeduction)}',
              color: _T.amber,
              fontSize: fontSize,
            ),
            Container(
              margin: EdgeInsets.symmetric(
                vertical: isDesktop
                    ? 16
                    : isTablet
                    ? 14
                    : 12,
              ),
              height: 1,
              color: _T.border,
            ),
            _SalRow(
              label: 'Net Payout',
              value: '₹ ${fmt.format(_netSalary)}',
              color: _T.green,
              isBold: true,
              fontSize: netFontSize,
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick actions responsive grid ───────────────────────────────────────────
  Widget _buildQuickActions(bool isDesktop, bool isTablet, bool isMobile) {
    final items = <_QAItem>[
      _QAItem(
        'Apply\nLeave',
        Icons.add_card_rounded,
        _T.accent,
        () => _openApplyLeaveSheet(),
      ),
      _QAItem(
        'My\nLeaves',
        Icons.list_alt_rounded,
        _T.purple,
        () => _openLeaveListSheet('My Leaves', _allLeaves),
      ),
      _QAItem(
        'Attendance\nLog',
        Icons.history_rounded,
        _T.teal,
        () => _openAttendanceSheet('Attendance Log', _attendance),
      ),
      _QAItem(
        'Salary\nDetails',
        Icons.receipt_long_rounded,
        _T.green,
        _openSalarySheet,
      ),
      _QAItem(
        'Late\nReport',
        Icons.alarm_rounded,
        _T.amber,
        () => _openAttendanceSheet(
          'Late Records',
          _attendance.where((a) => a.isLate).toList(),
        ),
      ),
      _QAItem(
        'Pending\nLeaves',
        Icons.hourglass_top_rounded,
        _T.red,
        () => _openLeaveListSheet(
          'Pending Leaves',
          _allLeaves.where((l) => l.status == 'pending').toList(),
        ),
      ),
    ];

    final crossAxisCount = isDesktop
        ? 6
        : isTablet
        ? 3
        : 3;
    final childAspectRatio = isDesktop
        ? 1.3
        : isTablet
        ? 1.2
        : 1.1;

    final iconSize = isDesktop
        ? 28.0
        : isTablet
        ? 26.0
        : 24.0;
    final labelFontSize = isDesktop
        ? 13.0
        : isTablet
        ? 12.0
        : 11.0;
    final spacing = isDesktop
        ? 14.0
        : isTablet
        ? 12.0
        : 10.0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      childAspectRatio: childAspectRatio,
      children: items
          .map(
            (a) => GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                a.onTap();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: a.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: a.color.withValues(alpha: 0.22)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(a.icon, color: a.color, size: iconSize),
                    SizedBox(height: spacing),
                    Text(
                      a.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: a.color,
                        fontSize: labelFontSize,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // BOTTOM SHEETS
  // ───────────────────────────────────────────────────────────────────────────

  // ── Leave list sheet ────────────────────────────────────────────────────────
  void _openLeaveListSheet(String title, List<LeaveRecord> leaves) {
    _showSheet(
      child: _LeaveListSheetBody(title: title, leaves: leaves),
    );
  }

  // ── Leave allocation sheet ──────────────────────────────────────────────────
  void _openAllocationSheet() {
    _showSheet(
      child: _AllocationSheetBody(policy: _leavePolicy, allLeaves: _allLeaves),
    );
  }

  // ── Attendance list sheet ───────────────────────────────────────────────────
  void _openAttendanceSheet(String title, List<AttendanceRecord> records) {
    _showSheet(
      child: _AttendanceSheetBody(title: title, records: records),
    );
  }

  // ── Absent info sheet ───────────────────────────────────────────────────────
  void _openAbsentInfoSheet() {
    _showSheet(
      child: _AbsentInfoBody(
        absentDays: _absentDays,
        presentDays: _presentDays,
        missedPunch: _missedPunch,
        perDay: _perDay,
      ),
    );
  }

  // ── Salary detail sheet ─────────────────────────────────────────────────────
  void _openSalarySheet() {
    _showSheet(
      child: _SalarySheetBody(
        basicSalary: _basicSalary,
        absentDays: _absentDays,
        absentDeduction: _absentDeduction,
        missedPunch: _missedPunch,
        missedDeduction: _missedDeduction,
        latePunches: _latePunches,
        lateDeduction: _lateDeduction,
        netSalary: _netSalary,
        perDay: _perDay,
      ),
    );
  }

  // ── Apply leave sheet ───────────────────────────────────────────────────────
  void _openApplyLeaveSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _T.surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final deviceType = _Breakpoints.getDeviceType(
          MediaQuery.of(context).size.width,
        );
        final initialSize = deviceType == _DeviceType.desktop ? 0.85 : 0.95;
        final maxSize = deviceType == _DeviceType.desktop ? 0.97 : 1.0;
        final minSize = deviceType == _DeviceType.desktop ? 0.75 : 0.5;

        return DraggableScrollableSheet(
          initialChildSize: initialSize,
          maxChildSize: maxSize,
          minChildSize: minSize,
          expand: false,
          builder: (_, ctrl) => _ApplyLeaveSheetBody(
            companyId: _companyId,
            employeeId: _employeeId,
            userName: _userName,
            policy: _leavePolicy,
            onSuccess: (msg) {
              Navigator.pop(ctx);
              _showSnack(msg);
            },
            onError: (msg) => _showSnack(msg, isError: true),
          ),
        );
      },
    );
  }

  // ── Generic sheet wrapper ───────────────────────────────────────────────────
  void _showSheet({required Widget child}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _T.surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final deviceType = _Breakpoints.getDeviceType(
          MediaQuery.of(context).size.width,
        );
        final initialSize = deviceType == _DeviceType.desktop ? 0.75 : 0.85;
        final maxSize = deviceType == _DeviceType.desktop ? 0.95 : 0.97;
        final minSize = deviceType == _DeviceType.desktop ? 0.5 : 0.35;

        return DraggableScrollableSheet(
          initialChildSize: initialSize,
          maxChildSize: maxSize,
          minChildSize: minSize,
          expand: false,
          builder: (_, ctrl) => child is _SheetScrollChild
              ? (child).buildWithController(ctrl)
              : child,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Marker interface so sheet bodies can receive the scroll controller
// ─────────────────────────────────────────────────────────────────────────────
abstract class _SheetScrollChild extends StatelessWidget {
  const _SheetScrollChild();
  Widget buildWithController(ScrollController ctrl);
  @override
  Widget build(BuildContext context) => buildWithController(ScrollController());
}

// ─────────────────────────────────────────────────────────────────────────────
// Leave List Sheet Body
// ─────────────────────────────────────────────────────────────────────────────
class _LeaveListSheetBody extends _SheetScrollChild {
  final String title;
  final List<LeaveRecord> leaves;
  const _LeaveListSheetBody({required this.title, required this.leaves});

  @override
  Widget buildWithController(ScrollController ctrl) {
    return Column(
      children: [
        const _SheetHandle(),
        _SheetTitle(title: title),
        Expanded(
          child: leaves.isEmpty
              ? const _EmptyState(msg: 'No records found')
              : ListView.separated(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                  itemCount: leaves.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _LeaveDetailTile(leave: leaves[i]),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leave Allocation Sheet Body
// ─────────────────────────────────────────────────────────────────────────────
class _AllocationSheetBody extends _SheetScrollChild {
  final Map<String, int> policy;
  final List<LeaveRecord> allLeaves;
  const _AllocationSheetBody({required this.policy, required this.allLeaves});

  @override
  Widget buildWithController(ScrollController ctrl) {
    return Column(
      children: [
        const _SheetHandle(),
        _SheetTitle(title: 'Leave Allocation  ·  ${DateTime.now().year}'),
        Expanded(
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
            children: policy.entries.map((e) {
              final used = allLeaves
                  .where((l) => l.type == e.key && l.status == 'approved')
                  .fold(0, (s, l) => s + l.days);
              final left = (e.value - used).clamp(0, e.value > 0 ? e.value : 1);
              final ratio = e.value == 0
                  ? 0.0
                  : (used / e.value).clamp(0.0, 1.0);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _T.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _T.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.key,
                            style: const TextStyle(
                              color: _T.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            e.value == 0
                                ? 'Unlimited / as required'
                                : 'Used $used of ${e.value} days',
                            style: const TextStyle(
                              color: _T.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          if (e.value > 0) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                backgroundColor: _T.border,
                                color: ratio > 0.8
                                    ? _T.red
                                    : ratio > 0.5
                                    ? _T.amber
                                    : _T.green,
                                minHeight: 5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (e.value > 0)
                      Text(
                        '$left left',
                        style: TextStyle(
                          color: left > 0 ? _T.green : _T.red,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendance Sheet Body
// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceSheetBody extends _SheetScrollChild {
  final String title;
  final List<AttendanceRecord> records;
  const _AttendanceSheetBody({required this.title, required this.records});

  @override
  Widget buildWithController(ScrollController ctrl) {
    final fmt = DateFormat('hh:mm a');
    return Column(
      children: [
        const _SheetHandle(),
        _SheetTitle(title: title),
        Expanded(
          child: records.isEmpty
              ? const _EmptyState(msg: 'No records found')
              : ListView.separated(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final r = records[i];
                    final hasOut = r.punchOut != null;
                    final color = r.isLate
                        ? _T.amber
                        : hasOut
                        ? _T.green
                        : _T.purple;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _T.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              r.isLate
                                  ? Icons.access_time_rounded
                                  : hasOut
                                  ? Icons.check_rounded
                                  : Icons.fingerprint_rounded,
                              color: color,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.date,
                                  style: const TextStyle(
                                    color: _T.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'In: ${r.punchIn != null ? fmt.format(r.punchIn!) : "—"}'
                                  '   Out: ${hasOut ? fmt.format(r.punchOut!) : "—"}',
                                  style: const TextStyle(
                                    color: _T.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                if (r.punchIn != null && hasOut) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Duration: ${_duration(r.punchIn!, r.punchOut!)}',
                                    style: const TextStyle(
                                      color: _T.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (r.isLate)
                            const _StatusBadge(label: 'Late', color: _T.amber)
                          else if (!hasOut && r.punchIn != null)
                            const _StatusBadge(
                              label: 'No Out',
                              color: _T.purple,
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _duration(DateTime in_, DateTime out) {
    final d = out.difference(in_);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '${h}h ${m}m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Absent Info Sheet Body
// ─────────────────────────────────────────────────────────────────────────────
class _AbsentInfoBody extends _SheetScrollChild {
  final int absentDays;
  final int presentDays;
  final int missedPunch;
  final double perDay;
  const _AbsentInfoBody({
    required this.absentDays,
    required this.presentDays,
    required this.missedPunch,
    required this.perDay,
  });

  @override
  Widget buildWithController(ScrollController ctrl) {
    final fmt = NumberFormat('#,##,##0', 'en_IN');
    return SingleChildScrollView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHandle(),
          const _SheetTitle(title: 'Absent Days Details'),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _T.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _T.red.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                _DetailRow(
                  'Days Elapsed (month)',
                  '${DateTime.now().day}',
                  _T.textPrimary,
                ),
                const SizedBox(height: 10),
                _DetailRow('Present Days', '$presentDays', _T.green),
                const SizedBox(height: 10),
                _DetailRow(
                  'Missed Punch (half-day)',
                  '$missedPunch',
                  _T.purple,
                ),
                const Divider(color: _T.border, height: 24),
                _DetailRow('Absent Days', '$absentDays', _T.red, isBold: true),
                const SizedBox(height: 10),
                _DetailRow(
                  'Deduction per day',
                  '₹ ${fmt.format(perDay)}',
                  _T.textSecondary,
                ),
                _DetailRow(
                  'Total Absent Deduction',
                  '− ₹ ${fmt.format(absentDays * perDay)}',
                  _T.red,
                  isBold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _T.amber.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _T.amber.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: _T.amber, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Absent = days with no punch-in record. '
                    'Approved leaves do not count as absent.',
                    style: TextStyle(color: _T.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Salary Detail Sheet Body
// ─────────────────────────────────────────────────────────────────────────────
class _SalarySheetBody extends _SheetScrollChild {
  final double basicSalary;
  final int absentDays;
  final double absentDeduction;
  final int missedPunch;
  final double missedDeduction;
  final int latePunches;
  final double lateDeduction;
  final double netSalary;
  final double perDay;

  const _SalarySheetBody({
    required this.basicSalary,
    required this.absentDays,
    required this.absentDeduction,
    required this.missedPunch,
    required this.missedDeduction,
    required this.latePunches,
    required this.lateDeduction,
    required this.netSalary,
    required this.perDay,
  });

  @override
  Widget buildWithController(ScrollController ctrl) {
    final fmt = NumberFormat('#,##,##0', 'en_IN');
    final total = absentDeduction + missedDeduction + lateDeduction;

    return SingleChildScrollView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHandle(),
          _SheetTitle(
            title:
                'Salary Details  ·  ${DateFormat('MMMM yyyy').format(DateTime.now())}',
          ),

          // Earnings
          const _SectionChip(label: 'EARNINGS'),
          const SizedBox(height: 10),
          _DetailRow(
            'Basic Pay',
            '₹ ${fmt.format(basicSalary)}',
            _T.textPrimary,
          ),

          const SizedBox(height: 20),
          const _SectionChip(label: 'DEDUCTIONS'),
          const SizedBox(height: 10),
          _DetailRow(
            'Absent  ($absentDays d × ₹ ${fmt.format(perDay.round())})',
            '− ₹ ${fmt.format(absentDeduction)}',
            _T.red,
          ),
          const SizedBox(height: 8),
          _DetailRow(
            'Missed Punch  ($missedPunch × 50%)',
            '− ₹ ${fmt.format(missedDeduction)}',
            _T.purple,
          ),
          const SizedBox(height: 8),
          _DetailRow(
            'Late Arrival  ($latePunches × 10%)',
            '− ₹ ${fmt.format(lateDeduction)}',
            _T.amber,
          ),
          const Divider(color: _T.border, height: 24),
          _DetailRow(
            'Total Deductions',
            '− ₹ ${fmt.format(total)}',
            _T.red,
            isBold: true,
          ),

          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _T.green.withValues(alpha: 0.12),
                  _T.green.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _T.green.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Text(
                  'Estimated Net Payout',
                  style: TextStyle(color: _T.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  '₹ ${fmt.format(netSalary)}',
                  style: const TextStyle(
                    color: _T.green,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _T.border.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '* Estimate only. Final amount subject to HR approval & tax deductions.',
              style: TextStyle(color: _T.textSecondary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Apply Leave Sheet Body  (StatefulWidget — manages its own form state)
// ─────────────────────────────────────────────────────────────────────────────
class _ApplyLeaveSheetBody extends StatefulWidget {
  final String companyId;
  final String employeeId;
  final String userName;
  final Map<String, int> policy;
  final void Function(String) onSuccess;
  final void Function(String) onError;

  const _ApplyLeaveSheetBody({
    required this.companyId,
    required this.employeeId,
    required this.userName,
    required this.policy,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_ApplyLeaveSheetBody> createState() => _ApplyLeaveSheetBodyState();
}

class _ApplyLeaveSheetBodyState extends State<_ApplyLeaveSheetBody> {
  String _type = 'Casual';
  DateTime? _from;
  DateTime? _to;
  bool _submitting = false;

  // FIX: TextEditingController properly created and disposed here
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  int get _days =>
      (_from != null && _to != null) ? _to!.difference(_from!).inDays + 1 : 0;

  Future<void> _submit() async {
    if (_from == null || _to == null) {
      widget.onError('Please select from and to dates.');
      return;
    }
    if (_to!.isBefore(_from!)) {
      widget.onError('"To" date cannot be before "From" date.');
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      widget.onError('Please enter a reason for the leave.');
      return;
    }
    if (widget.companyId.isEmpty || widget.employeeId.isEmpty) {
      widget.onError('User profile error. Please re-login.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('leaves')
          .add({
            'employeeId': widget.employeeId,
            'name': widget.userName,
            'type': _type,
            'reason': _reasonCtrl.text.trim(),
            'from': Timestamp.fromDate(_from!),
            'to': Timestamp.fromDate(_to!),
            'days': _days,
            'status': 'pending',
            'appliedOn': FieldValue.serverTimestamp(),
          });
      widget.onSuccess(
        '✅ Leave applied for $_days day${_days > 1 ? 's' : ''}!',
      );
    } catch (e) {
      widget.onError('Submission failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<DateTime?> _pickDate({DateTime? first, DateTime? initial}) =>
      showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: first ?? DateTime.now().subtract(const Duration(days: 30)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (c, child) => Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: _T.accent),
            dialogTheme: const DialogThemeData(backgroundColor: _T.card),
          ),
          child: child!,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final deviceType = _Breakpoints.getDeviceType(
      MediaQuery.of(context).size.width,
    );
    final padding = deviceType == _DeviceType.desktop ? 32.0 : 24.0;
    final inputFontSize = deviceType == _DeviceType.desktop ? 15.0 : 14.0;
    final buttonHeight = deviceType == _DeviceType.desktop ? 56.0 : 52.0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: deviceType == _DeviceType.desktop ? 0.85 : 0.95,
        maxChildSize: deviceType == _DeviceType.desktop ? 0.97 : 1.0,
        minChildSize: deviceType == _DeviceType.desktop ? 0.75 : 0.5,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: EdgeInsets.fromLTRB(padding, 0, padding, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHandle(),
              const _SheetTitle(title: 'Apply for Leave'),

              // ── Leave type ───────────────────────────────────────────
              const _FieldLabel(text: 'Leave Type'),
              const SizedBox(height: 8),
              Wrap(
                spacing: deviceType == _DeviceType.desktop ? 12.0 : 8.0,
                runSpacing: deviceType == _DeviceType.desktop ? 12.0 : 8.0,
                children: widget.policy.keys.map((type) {
                  final sel = _type == type;
                  return GestureDetector(
                    onTap: () => setState(() => _type = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                        horizontal: deviceType == _DeviceType.desktop
                            ? 16.0
                            : 14.0,
                        vertical: deviceType == _DeviceType.desktop
                            ? 10.0
                            : 9.0,
                      ),
                      decoration: BoxDecoration(
                        color: sel ? _T.accent : _T.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? _T.accent : _T.border),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: sel ? Colors.white : _T.textSecondary,
                          fontSize: deviceType == _DeviceType.desktop
                              ? 14.0
                              : 12.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // ── Dates ────────────────────────────────────────────────
              SizedBox(height: deviceType == _DeviceType.desktop ? 24.0 : 20.0),
              const _FieldLabel(text: 'Select Dates'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DateBox(
                      label: 'From',
                      date: _from,
                      onTap: () async {
                        final d = await _pickDate();
                        if (d != null) {
                          setState(() {
                            _from = d;
                            // FIX: auto-reset "to" if it is now before "from"
                            if (_to != null && _to!.isBefore(d)) _to = null;
                          });
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: deviceType == _DeviceType.desktop ? 16.0 : 10.0,
                  ),
                  Expanded(
                    child: _DateBox(
                      label: 'To',
                      date: _to,
                      onTap: () async {
                        final d = await _pickDate(
                          first: _from ?? DateTime.now(),
                          initial: _from ?? DateTime.now(),
                        );
                        if (d != null) setState(() => _to = d);
                      },
                    ),
                  ),
                ],
              ),

              // Duration badge
              if (_days > 0) ...[
                SizedBox(
                  height: deviceType == _DeviceType.desktop ? 16.0 : 10.0,
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: deviceType == _DeviceType.desktop ? 16.0 : 12.0,
                    vertical: deviceType == _DeviceType.desktop ? 10.0 : 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: _T.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _T.accent.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    'Duration: $_days day${_days > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: _T.accent,
                      fontSize: deviceType == _DeviceType.desktop ? 14.0 : 12.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              // ── Reason ───────────────────────────────────────────────
              SizedBox(height: deviceType == _DeviceType.desktop ? 24.0 : 20.0),
              const _FieldLabel(text: 'Reason'),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonCtrl,
                maxLines: 4,
                style: TextStyle(
                  color: _T.textPrimary,
                  fontSize: inputFontSize,
                ),
                decoration: InputDecoration(
                  hintText: 'Describe your reason…',
                  hintStyle: TextStyle(
                    color: _T.textSecondary,
                    fontSize: deviceType == _DeviceType.desktop ? 14.0 : 13.0,
                  ),
                  filled: true,
                  fillColor: _T.card,
                  contentPadding: EdgeInsets.all(
                    deviceType == _DeviceType.desktop ? 16.0 : 14.0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _T.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _T.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _T.accent, width: 1.5),
                  ),
                ),
              ),

              // ── Submit ───────────────────────────────────────────────
              SizedBox(height: deviceType == _DeviceType.desktop ? 28.0 : 24.0),
              SizedBox(
                width: double.infinity,
                height: buttonHeight,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _T.accent,
                    disabledBackgroundColor: _T.accent.withValues(alpha: 0.35),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Submit Application',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: deviceType == _DeviceType.desktop
                                ? 16.0
                                : 15.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

// Sliver collapsible header
class _SliverHeader extends StatelessWidget {
  final String userName;
  const _SliverHeader({required this.userName});

  @override
  Widget build(BuildContext context) {
    final deviceType = _Breakpoints.getDeviceType(
      MediaQuery.of(context).size.width,
    );
    final titlePadding = deviceType == _DeviceType.desktop
        ? const EdgeInsets.fromLTRB(32, 0, 32, 20)
        : const EdgeInsets.fromLTRB(20, 0, 20, 14);
    final dateFontSize = deviceType == _DeviceType.desktop ? 11.0 : 10.0;
    final titleFontSize = deviceType == _DeviceType.desktop ? 17.0 : 15.0;

    return SliverAppBar(
      backgroundColor: _T.surface,
      surfaceTintColor: Colors.transparent,
      expandedHeight: deviceType == _DeviceType.desktop ? 120 : 100,
      pinned: true,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _T.border),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: titlePadding,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMMM yyyy').format(DateTime.now()),
              style: TextStyle(
                color: _T.textSecondary,
                fontSize: dateFontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Explore  ·  $userName',
              style: TextStyle(
                color: _T.textPrimary,
                fontSize: titleFontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Tappable info card (used for both leave + attendance grids)
class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _InfoCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = _Breakpoints.getDeviceType(
      MediaQuery.of(context).size.width,
    );
    final iconSize = deviceType == _DeviceType.desktop ? 18.0 : 15.0;
    final chevronSize = deviceType == _DeviceType.desktop ? 18.0 : 16.0;
    final valueFontSize = deviceType == _DeviceType.desktop ? 28.0 : 26.0;
    final labelFontSize = deviceType == _DeviceType.desktop ? 13.0 : 12.0;
    final subFontSize = deviceType == _DeviceType.desktop ? 11.0 : 10.0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _T.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: iconSize),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  color: color.withValues(alpha: 0.45),
                  size: chevronSize,
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: valueFontSize,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: _T.textPrimary,
                fontSize: labelFontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              sub,
              style: TextStyle(color: _T.textSecondary, fontSize: subFontSize),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final deviceType = _Breakpoints.getDeviceType(
      MediaQuery.of(context).size.width,
    );
    final fontSize = deviceType == _DeviceType.desktop ? 11.0 : 10.0;

    return Text(
      label,
      style: TextStyle(
        color: _T.textSecondary,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    final deviceType = _Breakpoints.getDeviceType(
      MediaQuery.of(context).size.width,
    );
    final width = deviceType == _DeviceType.desktop ? 40.0 : 36.0;
    final height = deviceType == _DeviceType.desktop ? 5.0 : 4.0;
    final margin = deviceType == _DeviceType.desktop
        ? const EdgeInsets.symmetric(vertical: 12)
        : const EdgeInsets.symmetric(vertical: 10);

    return Center(
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: _T.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  final String title;
  const _SheetTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final deviceType = _Breakpoints.getDeviceType(
      MediaQuery.of(context).size.width,
    );
    final padding = deviceType == _DeviceType.desktop
        ? const EdgeInsets.fromLTRB(32, 2, 32, 20)
        : const EdgeInsets.fromLTRB(20, 2, 20, 14);
    final fontSize = deviceType == _DeviceType.desktop ? 18.0 : 16.0;

    return Padding(
      padding: padding,
      child: Text(
        title,
        style: TextStyle(
          color: _T.textPrimary,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final deviceType = _Breakpoints.getDeviceType(
      MediaQuery.of(context).size.width,
    );
    final fontSize = deviceType == _DeviceType.desktop ? 12.0 : 11.0;

    return Text(
      text,
      style: TextStyle(
        color: _T.textSecondary,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SectionChip extends StatelessWidget {
  final String label;
  const _SectionChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final deviceType = _Breakpoints.getDeviceType(
      MediaQuery.of(context).size.width,
    );
    final fontSize = deviceType == _DeviceType.desktop ? 11.0 : 10.0;

    return Text(
      label,
      style: TextStyle(
        color: _T.textSecondary,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String msg;
  const _EmptyState({required this.msg});

  @override
  Widget build(BuildContext context) {
    final deviceType = _Breakpoints.getDeviceType(
      MediaQuery.of(context).size.width,
    );
    final iconSize = deviceType == _DeviceType.desktop ? 44.0 : 40.0;
    final spacing = deviceType == _DeviceType.desktop ? 12.0 : 10.0;
    final fontSize = deviceType == _DeviceType.desktop ? 16.0 : 14.0;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, color: _T.textSecondary, size: iconSize),
          SizedBox(height: spacing),
          Text(
            msg,
            style: TextStyle(color: _T.textSecondary, fontSize: fontSize),
          ),
        ],
      ),
    );
  }
}

class _LeaveDetailTile extends StatelessWidget {
  final LeaveRecord leave;
  const _LeaveDetailTile({required this.leave});

  Color get _color {
    switch (leave.status) {
      case 'approved':
        return _T.green;
      case 'rejected':
        return _T.red;
      default:
        return _T.amber;
    }
  }

  IconData get _icon {
    switch (leave.status) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    final sht = DateFormat('d MMM');
    final deviceType = _Breakpoints.getDeviceType(
      MediaQuery.of(context).size.width,
    );
    final typeFontSize = deviceType == _DeviceType.desktop ? 12.0 : 11.0;
    final iconSize = deviceType == _DeviceType.desktop ? 16.0 : 14.0;
    final statusFontSize = deviceType == _DeviceType.desktop ? 13.0 : 12.0;
    final dateFontSize = deviceType == _DeviceType.desktop ? 17.0 : 16.0;
    final metaFontSize = deviceType == _DeviceType.desktop ? 12.0 : 11.0;
    final reasonFontSize = deviceType == _DeviceType.desktop ? 13.0 : 12.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _T.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  leave.type,
                  style: TextStyle(
                    color: _T.accent,
                    fontSize: typeFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Icon(_icon, color: _color, size: iconSize),
              const SizedBox(width: 4),
              Text(
                leave.status[0].toUpperCase() + leave.status.substring(1),
                style: TextStyle(
                  color: _color,
                  fontSize: statusFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${sht.format(leave.from)}  →  ${sht.format(leave.to)}',
            style: TextStyle(
              color: _T.textPrimary,
              fontSize: dateFontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${leave.days} day${leave.days > 1 ? 's' : ''}  ·  Applied ${fmt.format(leave.appliedOn)}',
            style: TextStyle(color: _T.textSecondary, fontSize: metaFontSize),
          ),
          if (leave.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              leave.reason,
              style: TextStyle(
                color: _T.textSecondary,
                fontSize: reasonFontSize,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final deviceType = _Breakpoints.getDeviceType(
      MediaQuery.of(context).size.width,
    );
    final padding = deviceType == _DeviceType.desktop
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 3);
    final fontSize = deviceType == _DeviceType.desktop ? 11.0 : 10.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BarLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _BarLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final deviceType = _Breakpoints.getDeviceType(
      MediaQuery.of(context).size.width,
    );
    final dotSize = deviceType == _DeviceType.desktop ? 10.0 : 8.0;
    final spacing = deviceType == _DeviceType.desktop ? 8.0 : 5.0;
    final fontSize = deviceType == _DeviceType.desktop ? 11.0 : 10.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: spacing),
        Text(
          label,
          style: TextStyle(color: _T.textSecondary, fontSize: fontSize),
        ),
      ],
    );
  }
}

class _DateBox extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const _DateBox({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = _Breakpoints.getDeviceType(
      MediaQuery.of(context).size.width,
    );
    final labelFontSize = deviceType == _DeviceType.desktop ? 11.0 : 10.0;
    final valueFontSize = deviceType == _DeviceType.desktop ? 14.0 : 13.0;
    final spacing = deviceType == _DeviceType.desktop ? 6.0 : 4.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _T.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date != null ? _T.accent.withValues(alpha: 0.4) : _T.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: _T.textSecondary,
                fontSize: labelFontSize,
              ),
            ),
            SizedBox(height: spacing),
            Text(
              date != null
                  ? DateFormat('d MMM yy').format(date!)
                  : 'Tap to pick',
              style: TextStyle(
                color: date != null ? _T.textPrimary : _T.textSecondary,
                fontSize: valueFontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isBold;
  final double fontSize;
  const _SalRow({
    required this.label,
    required this.value,
    required this.color,
    this.isBold = false,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = _Breakpoints.getDeviceType(
      MediaQuery.of(context).size.width,
    );
    final labelFontSize = deviceType == _DeviceType.desktop ? 13.0 : 12.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: _T.textSecondary, fontSize: labelFontSize),
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
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isBold;
  const _DetailRow(this.label, this.value, this.color, {this.isBold = false});

  @override
  Widget build(BuildContext context) {
    final deviceType = _Breakpoints.getDeviceType(
      MediaQuery.of(context).size.width,
    );
    final labelFontSize = deviceType == _DeviceType.desktop ? 13.0 : 12.0;
    final valueFontSize = deviceType == _DeviceType.desktop ? 15.0 : 14.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: _T.textSecondary, fontSize: labelFontSize),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: valueFontSize,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _QAItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QAItem(this.label, this.icon, this.color, this.onTap);
}
