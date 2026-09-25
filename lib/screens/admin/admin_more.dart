import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/core.dart';
import 'package:myapp/data/providers/company_provider.dart';
import 'package:myapp/core/theme/theme_provider.dart';
import 'package:myapp/services/database_seeder.dart';
import 'package:myapp/widgets/common.dart';

class AdminMore extends StatefulWidget {
  const AdminMore({super.key});

  @override
  State<AdminMore> createState() => _AdminMoreState();
}

class _AdminMoreState extends State<AdminMore> {
  bool _loading = true;

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

    if (_loading || !provider.hasCompany) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          'More Options',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Account', [
            _buildMenuItem(Icons.person_outline, 'Profile', () => Navigator.pushNamed(context, '/profile')),
            _buildMenuItem(Icons.lock_outline, 'Change Password', () => _showChangePasswordDialog()),
          ]),
          _buildSection('Company', [
            _buildMenuItem(Icons.business_outlined, 'Company Info', () => _showCompanyInfoDialog()),
            _buildMenuItem(Icons.people_outline, 'Manage Employees', () => Navigator.pushNamed(context, '/admin-management', arguments: 'All')),
          ]),
          _buildSection('Reports', [
            _buildMenuItem(Icons.bar_chart_outlined, 'Attendance Reports', () => _showReportsDialog()),
            _buildMenuItem(Icons.file_download_outlined, 'Export Data', () => _showExportDialog()),
          ]),
          _buildSection('System', [
            _buildMenuItem(Icons.settings_outlined, 'Settings', () => _showSettingsDialog()),
            _buildMenuItem(Icons.help_outline, 'Help & Support', () => _showHelpDialog()),
            _buildMenuItem(Icons.storage, 'Seed Database', () => _showSeedDialog()),
            _buildMenuItem(Icons.logout, 'Logout', () => _logout()),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Settings', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeSelector(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Theme',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildThemeOption(
                Icons.brightness_auto,
                'System Default',
                ThemeMode.system,
                themeProvider,
              ),
              _buildThemeOption(
                Icons.brightness_high,
                'Light',
                ThemeMode.light,
                themeProvider,
              ),
              _buildThemeOption(
                Icons.brightness_low,
                'Dark',
                ThemeMode.dark,
                themeProvider,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption(
    IconData icon,
    String title,
    ThemeMode mode,
    ThemeProvider themeProvider,
  ) {
    final isSelected = themeProvider.themeMode == mode;

    return InkWell(
      onTap: () => themeProvider.setThemeMode(mode),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? AppColors.accent : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.accent, size: 20),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Change Password', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogTextField(currentPasswordController, 'Current Password', Icons.lock_outline),
            const SizedBox(height: 16),
            _buildDialogTextField(newPasswordController, 'New Password', Icons.lock_outline, isPassword: true),
            const SizedBox(height: 16),
            _buildDialogTextField(confirmPasswordController, 'Confirm Password', Icons.lock_outline, isPassword: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => _changePassword(
              currentPasswordController.text,
              newPasswordController.text,
              confirmPasswordController.text,
            ),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTextField(TextEditingController controller, String hint, IconData icon, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.accent),
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent)),
      ),
    );
  }

  Future<void> _changePassword(String current, String newPass, String confirm) async {
    if (newPass != confirm) {
      SnackBarUtils.showError(context, 'Passwords do not match');
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final cred = EmailAuthProvider.credential(email: user.email!, password: current);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPass);
      if (!mounted) return;
      SnackBarUtils.showSuccess(context, 'Password updated successfully');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to update password: $e');
    }
  }

  void _showCompanyInfoDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Company Info', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoRow('Company ID', context.read<CompanyProvider>().companyId!),
            const SizedBox(height: 8),
            _buildInfoRow('Role', 'Administrator'),
            const SizedBox(height: 8),
            _buildInfoRow('Status', 'Active'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('$label:', style: const TextStyle(color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(color: AppColors.textPrimary)),
      ],
    );
  }

  void _showSeedDialog() {
    final provider = context.read<CompanyProvider>();
    final companyId = provider.companyId ?? '';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Seed Database',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This will populate the database with sample employees, '
          'attendance records, leaves, salary slips, and announcements.\n\n'
          'Passwords for sample employees: password123\n\n'
          'Do you want to continue?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _executeSeed(companyId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text(
              'Seed Now',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeSeed(String companyId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          color: AppColors.card,
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.accent),
                SizedBox(height: 16),
                Text(
                  'Seeding database...',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final seeder = DatabaseSeeder();
      await seeder.seedAll(
        companyId: companyId,
        adminUid: uid,
      );

      if (mounted) {
        Navigator.pop(context);
        SnackBarUtils.showSuccess(
          context,
          'Database seeded successfully! Sample employee passwords: password123',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        SnackBarUtils.showError(context, 'Seed failed: $e');
      }
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  void _showReportsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Reports', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select Report Type:', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            _buildReportOption(Icons.bar_chart, 'Attendance Report', 'View attendance statistics and trends'),
            _buildReportOption(Icons.people, 'Employee Report', 'Generate employee lists and details'),
            _buildReportOption(Icons.calendar_month, 'Leave Report', 'Track leave requests and approvals'),
            _buildReportOption(Icons.currency_rupee, 'Salary Report', 'Generate salary slips and calculations'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildReportOption(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.accent),
      ),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: () => Navigator.pop(context),
    );
  }

  void _showExportDialog() {
    Navigator.pushNamed(context, '/admin-data-export');
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Help & Support', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Need help? Here are some quick links:', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            _buildHelpOption(Icons.help_outline, 'User Guide', 'View detailed user guide and tutorials'),
            _buildHelpOption(Icons.contact_support, 'Contact Support', 'Get in touch with our support team'),
            _buildHelpOption(Icons.bug_report, 'Report Issue', 'Report bugs or technical issues'),
            _buildHelpOption(Icons.update, 'Check Updates', 'Check for latest app updates'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpOption(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.blue),
      ),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: () => Navigator.pop(context),
    );
  }
}