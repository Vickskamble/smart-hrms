import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/core.dart';
import 'package:myapp/data/providers/company_provider.dart';
import 'package:myapp/data/repositories/user_repository.dart';
import 'package:myapp/widgets/common.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _loading = true;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _recentEmployees = [];
  List<Map<String, dynamic>> _departmentStats = [];
  Stream<QuerySnapshot>? _employeesStream;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final companyProvider = context.read<CompanyProvider>();
      final companyId = companyProvider.companyId;

      if (companyId == null || companyId.isEmpty) {
        setState(() {
          _loading = false;
        });
        return;
      }

      final userRepo = UserRepository();
      _stats = await userRepo.getEmployeeStats(companyId);
      if (!mounted) return;

      _employeesStream = userRepo.watchEmployeesWithDetails(companyId);

      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      SnackBarUtils.showError(
        context,
        'Failed to load dashboard: \${e.toString()}',
      );
    }
  }

  @override
  void dispose() {
    _employeesStream?.listen((event) {}).cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !context.watch<CompanyProvider>().hasCompany) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildStatCards(),
              const SizedBox(height: 24),
              _buildChartsSection(),
              const SizedBox(height: 24),
              _buildRecentEmployeesSection(),
              const SizedBox(height: 24),
              _buildDepartmentSection(),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome back, Admin 👋',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(DateTime.now()),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: () => _showNotificationDialog(),
              icon: const Icon(
                Icons.notifications_outlined,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.accent,
                child: Icon(Icons.person, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCards() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: _statsCards.length,
      itemBuilder: (context, index) {
        final card = _statsCards[index];
        return _buildStatCard(
          card['title'],
          card['value']?.toString() ?? '0',
          card['icon'],
          card['color'],
          card['subtitle'],
        );
      },
    );
  }

  List<Map<String, dynamic>> get _statsCards {
    return [
      {
        'title': 'Total Staff',
        'value': _stats?['total'] ?? 0,
        'icon': Icons.people,
        'color': AppColors.accent,
        'subtitle': 'All employees',
      },
      {
        'title': 'Present',
        'value': _stats?['active'] ?? 0,
        'icon': Icons.check_circle,
        'color': AppColors.green,
        'subtitle': 'Currently active',
      },
      {
        'title': 'On Leave',
        'value': (_stats?['total'] ?? 0) - (_stats?['active'] ?? 0),
        'icon': Icons.event_busy,
        'color': AppColors.amber,
        'subtitle': 'Currently on leave',
      },
      {
        'title': 'Departments',
        'value': _departmentStats.length.toString(),
        'icon': Icons.business,
        'color': AppColors.purple,
        'subtitle': 'Active departments',
      },
    ];
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Icon(
                Icons.more_vert,
                color: AppColors.textSecondary,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
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
          const Text(
            'Analytics Overview',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildChartsGrid(),
        ],
      ),
    );
  }

  Widget _buildChartsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,

        childAspectRatio: 1.5,
      ),
      itemCount: 2,
      itemBuilder: (context, index) {
        return _buildChartCard(
          index == 0 ? 'Attendance Overview' : 'Workforce Performance',
        );
      },
    );
  }

  Widget _buildChartCard(String title) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
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
          const SizedBox(height: 12),
          const Expanded(
            child: Center(
              child: Icon(
                Icons.bar_chart,
                color: AppColors.textSecondary,
                size: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentEmployeesSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _employeesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'Error loading employees: \${snapshot.error}',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          );
        }

        final employees = snapshot.data?.docs ?? [];
        _recentEmployees = employees
            .take(5)
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();

        return _buildRecentEmployeesList(_recentEmployees);
      },
    );
  }

  Widget _buildRecentEmployeesList(List<Map<String, dynamic>> employees) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Employees',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/admin-management'),
                child: const Text(
                  'View All',
                  style: TextStyle(color: AppColors.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...employees.map((employee) => _buildEmployeeListItem(employee)),
        ],
      ),
    );
  }

  Widget _buildEmployeeListItem(Map<String, dynamic> employee) {
    final name = employee['name'] ?? 'Unknown';
    final email = employee['email'] ?? 'No email';
    final department = employee['dept'] ?? 'Not assigned';
    final createdAt = employee['createdAt'] as Timestamp?;
    final dateStr = createdAt != null
        ? _formatDate(createdAt.toDate())
        : 'Unknown';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                department,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateStr,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _employeesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'Error loading departments: \${snapshot.error}',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          );
        }

        final employees = snapshot.data?.docs ?? [];
        _departmentStats = _calculateDepartmentStats(employees);

        return _buildDepartmentList(_departmentStats);
      },
    );
  }

  List<Map<String, dynamic>> _calculateDepartmentStats(
    List<DocumentSnapshot> employees,
  ) {
    final Map<String, int> deptMap = {};

    for (final doc in employees) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null) {
        final dept = data['dept'] as String? ?? 'Not assigned';
        deptMap[dept] = (deptMap[dept] ?? 0) + 1;
      }
    }

    return deptMap.entries
        .map((entry) => {'department': entry.key, 'count': entry.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  }

  Widget _buildDepartmentList(List<Map<String, dynamic>> departments) {
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
          const Text(
            'Department Wise Employees',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...departments.take(5).map((dept) => _buildDepartmentItem(dept)),
        ],
      ),
    );
  }

  Widget _buildDepartmentItem(Map<String, dynamic> dept) {
    final color = _getDepartmentColor(dept['department']);
    final percentage = (_stats?['total'] ?? 1) > 0
        ? ((dept['count'] as int) / (_stats?['total'] as int) * 100)
              .toStringAsFixed(1)
        : '0.0';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.business, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dept['department'],
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${dept['count']} employees',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$percentage%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (double.parse(percentage) / 100).clamp(0.0, 1.0),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getDepartmentColor(String department) {
    final colors = [
      AppColors.green,
      AppColors.accent,
      AppColors.purple,
      AppColors.amber,
      AppColors.red,
      AppColors.blue,
    ];

    final hash = department.hashCode;
    return colors[hash % colors.length];
  }

  Widget _buildQuickActions() {
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
          const Text(
            'Quick Actions',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: _quickActions.length,
            itemBuilder: (context, index) {
              final action = _quickActions[index];
              return _buildQuickActionCard(action);
            },
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _quickActions {
    return [
      {
        'title': 'Add Employee',
        'icon': Icons.person_add,
        'color': AppColors.accent,
        'onTap': () => Navigator.pushNamed(context, '/admin-add-employee'),
      },
      {
        'title': 'Mark Attendance',
        'icon': Icons.check_circle,
        'color': AppColors.green,
        'onTap': () => _showAttendanceDialog(),
      },
      {
        'title': 'Apply Leave',
        'icon': Icons.event_note,
        'color': AppColors.amber,
        'onTap': () => _showLeaveDialog(),
      },
      {
        'title': 'Generate Payslip',
        'icon': Icons.receipt,
        'color': AppColors.purple,
        'onTap': () => _showPayslipDialog(),
      },
      {
        'title': 'View Reports',
        'icon': Icons.bar_chart,
        'color': AppColors.red,
        'onTap': () => _showReportsDialog(),
      },
      {
        'title': 'Bulk Import',
        'icon': Icons.upload_file,
        'color': AppColors.blue,
        'onTap': () => Navigator.pushNamed(context, '/admin-import'),
      },
    ];
  }

  Widget _buildQuickActionCard(Map<String, dynamic> action) {
    return InkWell(
      onTap: action['onTap'],
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: action['color'].withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(action['icon'], color: action['color'], size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              action['title'],
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Notifications',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'No new notifications',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  void _showAttendanceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Mark Attendance',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Attendance marking feature coming soon',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  void _showLeaveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Apply Leave',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Leave application feature coming soon',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  void _showPayslipDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Generate Payslip',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Payslip generation feature coming soon',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  void _showReportsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Reports',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Reports feature coming soon',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }
}
