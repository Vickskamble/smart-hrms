import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/widgets/common.dart';
import 'package:myapp/data/repositories/user_repository.dart';

import 'employee_main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ─── Color palette ────────────────────────────────────────────────
  static const Color _bg = Color(0xFF0A0D14);
  static const Color _surface = Color(0xFF131720);
  static const Color _accent = Color(0xFF2E6FF3);
  static const Color _textPrimary = Color(0xFFE8EDF5);
  static const Color _textSecondary = Color(0xFF8A94A6);
  static const Color _border = Color(0xFF1E2535);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // ─── Login handler ─────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passController.text.trim(),
      );

      if (!mounted) return;

      final userRepository = UserRepository();
      final userData = await userRepository.getFullUserData();

      if (!mounted) return;

      if (userData == null) {
        await FirebaseAuth.instance.signOut();
        _showSnack('User data not found. Contact your administrator.');
        setState(() => _isLoading = false);
        return;
      }

      final currentStatus = userData['currentStatus'] as String?;
      final isActive = userData['isActive'] as bool?;

      if (currentStatus != 'Active' && isActive != true) {
        await FirebaseAuth.instance.signOut();
        _showSnack('Account inactive. Contact your administrator.');
        setState(() => _isLoading = false);
        return;
      }

      final role = userData['role'] as String?;

      debugPrint(
        'Login - User: ${cred.user!.uid}, Role: "$role", Status: "$currentStatus"',
      );

      if (role?.toLowerCase() == 'admin' || role?.toLowerCase() == 'hr') {
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EmployeeMainScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(_mapFirebaseError(e.code));
      setState(() => _isLoading = false);
    } catch (_) {
      _showSnack('Login failed. Please check your credentials and try again.');
      setState(() => _isLoading = false);
    }
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-disabled':
        return 'Your account has been disabled.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check and retry.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return 'Login failed. Please try again.';
    }
  }

  void _showSnack(String message) {
    SnackBarUtils.showError(context, message);
  }

  // ─── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 800;
          return isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
        },
      ),
    );
  }

  // ─── Desktop: two-column layout ────────────────────────────────────
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left panel — branding
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D1528), Color(0xFF0A0D14)],
              ),
            ),
            child: Stack(
              children: [
                // Decorative grid pattern
                Positioned.fill(child: _GridPattern()),
                // Content
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(60),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _LogoBadge(size: 72),
                        const SizedBox(height: 32),
                        const Text(
                          'WorkForce\nCommand',
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'The all-in-one HR platform for managing\nyour people, payroll, and performance.',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 16,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 48),
                        _StatRow(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right panel — form
        SizedBox(
          width: 480,
          child: Container(
            color: _surface,
            padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
            child: Center(child: _buildForm(isDesktop: true)),
          ),
        ),
      ],
    );
  }

  // ─── Mobile: single column ─────────────────────────────────────────
  Widget _buildMobileLayout() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D1528), _bg],
          stops: [0.0, 0.45],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              children: [
                const _LogoBadge(size: 60),
                const SizedBox(height: 16),
                const Text(
                  'WorkForce Command',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'HR Management Platform',
                  style: TextStyle(color: _textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 40),
                _buildForm(isDesktop: false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Shared form ───────────────────────────────────────────────────
  Widget _buildForm({required bool isDesktop}) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDesktop) ...[
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to your account to continue',
                  style: TextStyle(color: _textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 40),
              ],
              _fieldLabel('Email Address'),
              const SizedBox(height: 8),
              _emailField(),
              const SizedBox(height: 20),
              _fieldLabel('Password'),
              const SizedBox(height: 8),
              _passwordField(),
              const SizedBox(height: 32),
              _loginButton(),
              const SizedBox(height: 24),
              _footerNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _emailField() {
    return TextFormField(
      controller: _emailController,
      enabled: !_isLoading,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: _textPrimary, fontSize: 15),
      decoration: _inputDecoration(
        hint: 'you@company.com',
        icon: Icons.mail_outline_rounded,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Email is required';
        if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(v.trim())) {
          return 'Enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _passController,
      enabled: !_isLoading,
      obscureText: _obscurePassword,
      style: const TextStyle(color: _textPrimary, fontSize: 15),
      decoration:
          _inputDecoration(
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
          ).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _textSecondary,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Password is required';
        if (v.length < 6) return 'Password must be at least 6 characters';
        return null;
      },
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textSecondary, fontSize: 14),
      prefixIcon: Icon(icon, color: _textSecondary, size: 20),
      filled: true,
      fillColor: _bg,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD64045)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD64045), width: 1.5),
      ),
      errorStyle: const TextStyle(color: Color(0xFFD64045), fontSize: 12),
    );
  }

  Widget _loginButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          disabledBackgroundColor: _accent.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }

  Widget _footerNote() {
    return const Center(
      child: Text(
        'Access is restricted to authorized personnel only.\nContact IT for account issues.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _textSecondary, fontSize: 12, height: 1.5),
      ),
    );
  }
}

// ─── Logo badge widget ──────────────────────────────────────────────────────
class _LogoBadge extends StatelessWidget {
  final double size;
  const _LogoBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E6FF3), Color(0xFF1A4DB8)],
        ),
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E6FF3).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        Icons.shield_outlined,
        color: Colors.white,
        size: size * 0.52,
      ),
    );
  }
}

// ─── Stats row (desktop branding panel) ────────────────────────────────────
class _StatRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const stats = [
      ('Employees', '10K+'),
      ('Departments', '50+'),
      ('Uptime', '99.9%'),
    ];
    return Wrap(
      runSpacing: 12,
      children: stats.map((s) {
        return Padding(
          padding: const EdgeInsets.only(right: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.$2,
                style: const TextStyle(
                  color: Color(0xFF2E6FF3),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                s.$1,
                style: const TextStyle(color: Color(0xFF8A94A6), fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Decorative grid background ────────────────────────────────────────────
class _GridPattern extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E2535).withValues(alpha: 0.5)
      ..strokeWidth = 0.5;

    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
