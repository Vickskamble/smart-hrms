import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/core.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _formatDate(dynamic value) {
    if (value == null) return '-';

    if (value is Timestamp) {
      return DateFormat('dd MMM yyyy').format(value.toDate());
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textPrimary),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                Navigator.pushReplacementNamed(context, '/login');
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Logout failed. Please try again.'),
                    backgroundColor: AppColors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                "Profile not found",
                style: TextStyle(color: AppColors.textPrimary),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final name = data['name'] ?? '-';
          final employeeId = data['employeeId'] ?? '-';
          final companyId = data['companyId'] ?? '-';
          final designation = data['designation'] ?? '-';
          final department = data['department'] ?? '-';
          final email = data['email'] ?? '-';
          final mobile = data['mobile'] ?? '-';
          final address = data['address'] ?? '-';
          final bloodGroup = data['bloodGroup'] ?? '-';
          final emergencyContact = data['emergencyContact'] ?? '-';
          final reportingManager = data['reportingManager'] ?? '-';
          final salary = data['basicSalary'] ?? 0;
          final status = data['status'] ?? 'active';

          final dob = _formatDate(data['dateOfBirth']);
          final doj = _formatDate(data['dateOfJoining']);

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 1000;

              final profileSection = _profileCard(
                name: name,
                employeeId: employeeId,
                designation: designation,
                department: department,
                status: status,
              );

              final detailsSection = Column(
                children: [
                  _sectionTitle("Personal Information"),
                  _infoCard([
                    _infoRow(Icons.person_outline, "Full Name", name),
                    _infoRow(Icons.email_outlined, "Email", email),
                    _infoRow(Icons.phone_outlined, "Mobile", mobile),
                    _infoRow(Icons.cake_outlined, "Date Of Birth", dob),
                    _infoRow(
                      Icons.bloodtype_outlined,
                      "Blood Group",
                      bloodGroup,
                    ),
                    _infoRow(Icons.location_on_outlined, "Address", address),
                    _infoRow(
                      Icons.emergency_outlined,
                      "Emergency Contact",
                      emergencyContact,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  _sectionTitle("Employment Details"),
                  _infoCard([
                    _infoRow(Icons.badge_outlined, "Employee ID", employeeId),
                    _infoRow(Icons.business_outlined, "Company ID", companyId),
                    _infoRow(Icons.work_outline, "Department", department),
                    _infoRow(
                      Icons.account_tree_outlined,
                      "Designation",
                      designation,
                    ),
                    _infoRow(
                      Icons.supervisor_account_outlined,
                      "Reporting Manager",
                      reportingManager,
                    ),
                    _infoRow(
                      Icons.calendar_month_outlined,
                      "Date Of Joining",
                      doj,
                    ),
                    _infoRow(Icons.currency_rupee, "Basic Salary", "₹ $salary"),
                  ]),

                  const SizedBox(height: 20),

                  _sectionTitle("Employee ID Card"),
                  _idCard(
                    name: name,
                    employeeId: employeeId,
                    designation: designation,
                    department: department,
                    companyId: companyId,
                  ),
                ],
              );

              if (isDesktop) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 1, child: profileSection),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: detailsSection),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    profileSection,
                    const SizedBox(height: 20),
                    detailsSection,
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _profileCard({
    required String name,
    required String employeeId,
    required String designation,
    required String department,
    required String status,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 55,
            backgroundColor: AppColors.accent,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            designation,
            style: const TextStyle(color: AppColors.accent, fontSize: 15),
          ),

          Text(
            department,
            style: const TextStyle(color: AppColors.textSecondary),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              status.toUpperCase(),
              style: const TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            employeeId,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _idCard({
    required String name,
    required String employeeId,
    required String designation,
    required String department,
    required String companyId,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent),
      ),
      child: Column(
        children: [
          const Text(
            "EMPLOYEE ID CARD",
            style: TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          CircleAvatar(
            radius: 35,
            backgroundColor: AppColors.accent,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),

          Text(
            employeeId,
            style: const TextStyle(color: AppColors.textSecondary),
          ),

          const Divider(height: 30),

          _idRow("Designation", designation),
          _idRow("Department", department),
          _idRow("Company", companyId),
        ],
      ),
    );
  }

  Widget _idRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
