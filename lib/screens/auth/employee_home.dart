import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/core.dart';
import 'package:myapp/data/repositories.dart';
import 'package:myapp/widgets/common.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Office config
// ─────────────────────────────────────────────────────────────────────────────
class _OfficeConfig {
  static const double latitude = AppConstants.officeLatitude;
  static const double longitude = AppConstants.officeLongitude;
  static const double geofenceRadius = AppConstants.geofenceRadiusMeters;
}

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  final String userName;
  const HomeScreen({super.key, required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ── Timers ──────────────────────────────────────────────────────────────────
  Timer? _workTimer;
  Timer? _locationTimer;
  Timer? _clockTimer;

  // ── State ───────────────────────────────────────────────────────────────────
  DateTime? punchInTime;
  DateTime? punchOutTime;
  Duration workingDuration = Duration.zero;
  DateTime _now = DateTime.now();

  bool isPunchedIn = false;
  bool isCompleted = false;
  bool _locationLoading = true;
  bool _isPunching = false;

  String companyId = '';
  String employeeId = '';
  String? _attendanceDocId;
  double distanceMeters = double.infinity;

  // ── Office config ────────────────────────────────────────────────────────────
  static const double officeLat = _OfficeConfig.latitude;
  static const double officeLng = _OfficeConfig.longitude;
  static const double geofenceRadius = _OfficeConfig.geofenceRadius;

  // ── Swipe state ──────────────────────────────────────────────────────────────
  double _swipeDx = 0;
  bool _swipeCompleted = false;
  late AnimationController _swipeSnapCtrl;
  late Animation<double> _swipeSnapAnim;

  // ── Entrance animations ──────────────────────────────────────────────────────
  late AnimationController _entranceCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── Pulse ────────────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── Shimmer for greeting illustration ────────────────────────────────────────
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut));

    _swipeSnapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _swipeSnapAnim = const AlwaysStoppedAnimation(0);
    _swipeSnapCtrl.addListener(() {
      setState(() => _swipeDx = _swipeSnapAnim.value);
    });

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Live clock
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _entranceCtrl.forward();
    _initUser();
  }

  @override
  void dispose() {
    _workTimer?.cancel();
    _locationTimer?.cancel();
    _clockTimer?.cancel();
    _entranceCtrl.dispose();
    _swipeSnapCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── Init ─────────────────────────────────────────────────────────────────────
  Future<void> _initUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      companyId = doc['companyId'] ?? '';
      employeeId = doc['employeeId'] ?? '';
    }

    await Future.wait([_checkDistance(), _loadTodayAttendance()]);

    _locationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkDistance(),
    );
  }

  // ── Location ─────────────────────────────────────────────────────────────────
  Future<bool> _checkDistance() async {
    if (!mounted) return false;
    setState(() => _locationLoading = true);

    // Web: skip geolocator permission flow (use browser geolocation instead if needed)
    if (kIsWeb) {
      // On web, geolocation still works via Geolocator but needs HTTPS
      // We'll attempt it and handle gracefully
    }

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationLoading = false);
        return false;
      }

      Position? quick = await Geolocator.getLastKnownPosition();
      if (quick != null && mounted) {
        distanceMeters = Geolocator.distanceBetween(
          officeLat,
          officeLng,
          quick.latitude,
          quick.longitude,
        );
        setState(() => _locationLoading = false);
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (!mounted) return distanceMeters <= geofenceRadius;
      distanceMeters = Geolocator.distanceBetween(
        officeLat,
        officeLng,
        pos.latitude,
        pos.longitude,
      );
      setState(() => _locationLoading = false);
    } catch (_) {
      if (mounted) setState(() => _locationLoading = false);
    }

    return distanceMeters <= geofenceRadius;
  }

  // ── Load today attendance ─────────────────────────────────────────────────────
  Future<void> _loadTodayAttendance() async {
    if (companyId.isEmpty || employeeId.isEmpty) return;
    final today = DateFormat('yyyy-MM-dd').format(_now);

    final snap = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('attendance')
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isEqualTo: today)
        .get();

    if (!mounted) return;

    if (snap.docs.isNotEmpty) {
      final data = snap.docs.first;
      _attendanceDocId = data.id;

      if (data['punchIn'] != null) {
        punchInTime = (data['punchIn'] as Timestamp).toDate();
        workingDuration = DateTime.now().difference(punchInTime!);
        isPunchedIn = true;
        _startWorkTimer();
      }
      if (data['punchOut'] != null) {
        punchOutTime = (data['punchOut'] as Timestamp).toDate();
        isCompleted = true;
        workingDuration = punchOutTime!.difference(punchInTime!);
        _workTimer?.cancel();
      }
      setState(() {});
    }
  }

  void _startWorkTimer() {
    _workTimer?.cancel();
    _workTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (punchInTime != null && !isCompleted && mounted) {
        setState(
          () => workingDuration = DateTime.now().difference(punchInTime!),
        );
      }
    });
  }

  // ── Punch In ──────────────────────────────────────────────────────────────────
  Future<void> _punchIn() async {
    setState(() => _isPunching = true);
    final allowed = await _checkDistance();
    if (!allowed) {
      _showSnack(
        '📍 Outside office range. Move within 200m to punch in.',
        isError: true,
      );
      setState(() => _isPunching = false);
      return;
    }

    if (companyId.isEmpty || employeeId.isEmpty) {
      _showSnack('User data not loaded. Please re-login.', isError: true);
      setState(() => _isPunching = false);
      return;
    }

    punchInTime = DateTime.now();
    isPunchedIn = true;

    final repo = AttendanceRepository();
    final ref = await repo.punchIn(
      companyId: companyId,
      employeeId: employeeId,
      name: widget.userName,
      punchInTime: punchInTime!,
    );

    _attendanceDocId = ref.id;
    if (!kIsWeb) HapticFeedback.mediumImpact();
    _startWorkTimer();
    setState(() => _isPunching = false);
    _showSnack('✅ Punched in at ${DateFormat('hh:mm a').format(punchInTime!)}');
  }

  // ── Punch Out ─────────────────────────────────────────────────────────────────
  Future<void> _punchOut() async {
    setState(() => _isPunching = true);
    final allowed = await _checkDistance();
    if (!allowed) {
      _showSnack(
        '📍 Outside office range. Move within 200m to punch out.',
        isError: true,
      );
      setState(() => _isPunching = false);
      return;
    }

    if (_attendanceDocId == null) {
      _showSnack('No active punch-in found.', isError: true);
      setState(() => _isPunching = false);
      return;
    }

    punchOutTime = DateTime.now();
    isCompleted = true;
    workingDuration = punchOutTime!.difference(punchInTime!);
    _workTimer?.cancel();

    final repo = AttendanceRepository();
    await repo.punchOut(
      companyId: companyId,
      attendanceDocId: _attendanceDocId!,
      punchOutTime: punchOutTime!,
    );

    if (!kIsWeb) HapticFeedback.heavyImpact();
    setState(() => _isPunching = false);
    _showSnack('👋 Punched out. Total: ${_formatDuration(workingDuration)}');
  }

  void _showSnack(String msg, {bool isError = false}) {
    SnackBarUtils.show(context, msg, isError: isError);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h : $m : $s';
  }

  String get _greeting {
    final h = _now.hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _greetingEmoji {
    final h = _now.hour;
    if (h < 12) return '🌤';
    if (h < 17) return '☀️';
    return '🌙';
  }

  Color get _greetingColor {
    final h = _now.hour;
    if (h < 12) return const Color(0xFFF59E0B);
    if (h < 17) return const Color(0xFF3D7BF7);
    return const Color(0xFF818CF8);
  }

  bool get _inRange => distanceMeters <= geofenceRadius;

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
        ),
      ),
    );
  }

  // ── Narrow (phone) layout ─────────────────────────────────────────────────────
  Widget _buildNarrowLayout() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildGreetingBanner(),
                  const SizedBox(height: 20),
                  _buildGeofenceBadge(),
                  const SizedBox(height: 22),
                  _buildTimerRing(),
                  const SizedBox(height: 22),
                  _buildPunchCards(),
                ],
              ),
            ),
          ),
        ),
        // ── SWIPE BUTTON pinned to bottom ──
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: _buildSwipeButton(),
          ),
        ),
      ],
    );
  }

  // ── Wide (web/tablet) layout ──────────────────────────────────────────────────
  Widget _buildWideLayout() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          children: [
            _buildGreetingBanner(),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _buildGeofenceBadge(),
                        const SizedBox(height: 24),
                        _buildTimerRing(),
                        const SizedBox(height: 24),
                        _buildPunchCards(),
                        const Spacer(),
                        _buildSwipeButton(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Right column — decorative illustration
                  Expanded(
                    flex: 4,
                    child: _GreetingIllustration(
                      hour: _now.hour,
                      shimmer: _shimmerCtrl,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Greeting banner ───────────────────────────────────────────────────────────
  Widget _buildGreetingBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _greetingColor.withValues(alpha: 0.18),
            _greetingColor.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _greetingColor.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          // Illustration (narrow only — wide shows it in right column)
          if (MediaQuery.of(context).size.width <= 700)
            _GreetingIllustration(
              hour: _now.hour,
              shimmer: _shimmerCtrl,
              size: 72,
            ),
          if (MediaQuery.of(context).size.width <= 700)
            const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date + Today
                Row(
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(_now),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Today',
                  style: TextStyle(
                    color: _greetingColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_greetingEmoji  $_greeting,',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.userName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Live clock
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('hh:mm').format(_now),
                style: TextStyle(
                  color: _greetingColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: -1,
                ),
              ),
              Text(
                DateFormat('a').format(_now),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Geofence badge ────────────────────────────────────────────────────────────
  Widget _buildGeofenceBadge() {
    final Color c = _locationLoading
        ? AppColors.textSecondary
        : _inRange
        ? AppColors.green
        : AppColors.red;
    final String label = _locationLoading
        ? 'Checking your location…'
        : _inRange
        ? 'Inside office range  ·  ${distanceMeters.toStringAsFixed(0)} m'
        : 'Outside office  ·  ${distanceMeters.toStringAsFixed(0)} m away';

    return GestureDetector(
      onTap: _locationLoading ? null : _checkDistance,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            _locationLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c),
                  )
                : Icon(
                    _inRange
                        ? Icons.my_location_rounded
                        : Icons.location_off_rounded,
                    color: c,
                    size: 16,
                  ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: c,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (!_locationLoading)
              Icon(Icons.refresh_rounded, color: c.withValues(alpha: 0.6), size: 15),
          ],
        ),
      ),
    );
  }

  // ── Timer ring ────────────────────────────────────────────────────────────────
  Widget _buildTimerRing() {
    final bool active = isPunchedIn && !isCompleted;
    final Color ringColor = isCompleted
        ? AppColors.textSecondary.withValues(alpha: 0.3)
        : active
        ? AppColors.accent
        : AppColors.border;

    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, child) => Transform.scale(
          scale: active ? _pulseAnim.value : 1.0,
          child: child,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow ring
            if (active)
              Container(
                width: 196,
                height: 196,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.22),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: ringColor, width: 2.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    active
                        ? 'WORKING'
                        : isCompleted
                        ? 'COMPLETED'
                        : 'NOT STARTED',
                    style: TextStyle(
                      color: isCompleted
                          ? AppColors.textSecondary
                          : AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _formatDuration(workingDuration),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'hh  ·  mm  ·  ss',
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.45),
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Punch cards ───────────────────────────────────────────────────────────────
  Widget _buildPunchCards() {
    return Row(
      children: [
        Expanded(
          child: _PunchCard(
            label: 'Punch In',
            time: punchInTime != null
                ? DateFormat('hh:mm a').format(punchInTime!)
                : '--:-- --',
            color: AppColors.green,
            icon: Icons.login_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PunchCard(
            label: 'Punch Out',
            time: punchOutTime != null
                ? DateFormat('hh:mm a').format(punchOutTime!)
                : '--:-- --',
            color: AppColors.red,
            icon: Icons.logout_rounded,
          ),
        ),
      ],
    );
  }

  // ── Swipe button (pinned to bottom) ───────────────────────────────────────────
  Widget _buildSwipeButton() {
    if (isCompleted) {
      return CompletedBadge(duration: _formatDuration(workingDuration));
    }

    final bool canAct = _inRange && !_locationLoading && !_isPunching;
    final bool punchOut = isPunchedIn;
    final Color thumbColor = punchOut ? AppColors.red : AppColors.green;
    const double trackH = 64.0;
    const double thumbSz = 52.0;
    const double pad = 6.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDrag = constraints.maxWidth - thumbSz - pad * 2;

        return Opacity(
          opacity: canAct ? 1.0 : 0.45,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Track background
              Container(
                height: trackH,
                decoration: BoxDecoration(
                  color: thumbColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(trackH / 2),
                  border: Border.all(color: thumbColor.withValues(alpha: 0.22)),
                ),
                alignment: Alignment.center,
                child: AnimatedOpacity(
                  opacity: (_swipeDx / maxDrag) < 0.35 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chevron_right_rounded,
                        color: thumbColor.withValues(alpha: 0.55),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        punchOut ? 'Swipe to Punch Out' : 'Swipe to Punch In',
                        style: TextStyle(
                          color: thumbColor.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Fill gradient
              Positioned(
                left: 0,
                child: Container(
                  height: trackH,
                  width: (_swipeDx + thumbSz + pad * 2).clamp(
                    thumbSz + pad * 2,
                    constraints.maxWidth,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        thumbColor.withValues(alpha: 0.28),
                        thumbColor.withValues(alpha: 0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(trackH / 2),
                  ),
                ),
              ),

              // Thumb
              Positioned(
                left: pad + _swipeDx,
                child: GestureDetector(
                  onHorizontalDragUpdate: canAct
                      ? (d) {
                          setState(() {
                            _swipeDx = (_swipeDx + d.delta.dx).clamp(
                              0.0,
                              maxDrag,
                            );
                          });
                        }
                      : null,
                  onHorizontalDragEnd: canAct
                      ? (d) async {
                          if (_swipeDx >= maxDrag * 0.75) {
                            setState(() {
                              _swipeDx = maxDrag;
                              _swipeCompleted = true;
                            });
                            await Future.delayed(
                              const Duration(milliseconds: 200),
                            );
                            if (punchOut) {
                              await _punchOut();
                            } else {
                              await _punchIn();
                            }
                            if (mounted) {
                              setState(() {
                                _swipeDx = 0;
                                _swipeCompleted = false;
                              });
                            }
                          } else {
                            _swipeSnapAnim =
                                Tween<double>(begin: _swipeDx, end: 0).animate(
                                  CurvedAnimation(
                                    parent: _swipeSnapCtrl,
                                    curve: Curves.easeOut,
                                  ),
                                );
                            _swipeSnapCtrl
                              ..reset()
                              ..forward();
                          }
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: thumbSz,
                    height: thumbSz,
                    decoration: BoxDecoration(
                      color: thumbColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: thumbColor.withValues(alpha: 0.5),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _isPunching
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _swipeCompleted
                                ? Icons.check_rounded
                                : punchOut
                                ? Icons.logout_rounded
                                : Icons.login_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Greeting Illustration (SVG-like custom painter)
// ─────────────────────────────────────────────────────────────────────────────
class _GreetingIllustration extends StatelessWidget {
  final int hour;
  final AnimationController shimmer;
  final double size;

  const _GreetingIllustration({
    required this.hour,
    required this.shimmer,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmer,
      builder: (_, __) {
        return CustomPaint(
          size: Size(size, size),
          painter: _SkyPainter(hour: hour, t: shimmer.value),
        );
      },
    );
  }
}

class _SkyPainter extends CustomPainter {
  final int hour;
  final double t;
  _SkyPainter({required this.hour, required this.t});

  bool get isMorning => hour < 12;
  bool get isAfternoon => hour >= 12 && hour < 17;
  bool get isEvening => hour >= 17;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy);

    // Background circle
    final bgGrad = RadialGradient(
      colors: isMorning
          ? [const Color(0xFF1A2A4A), const Color(0xFF0A1020)]
          : isAfternoon
          ? [const Color(0xFF0A1A3A), const Color(0xFF070D1A)]
          : [const Color(0xFF0A0A1F), const Color(0xFF050510)],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));

    canvas.drawCircle(Offset(cx, cy), r, Paint()..shader = bgGrad);

    if (isMorning || isAfternoon) {
      _drawSun(canvas, cx, cy, r);
    } else {
      _drawMoon(canvas, cx, cy, r);
    }

    _drawStars(canvas, size, r);
  }

  void _drawSun(Canvas canvas, double cx, double cy, double r) {
    final sunColor = isMorning
        ? const Color(0xFFFBBF24)
        : const Color(0xFFF97316);
    final sunY = cy - r * 0.15;

    // Glow
    final glowPaint = Paint()
      ..color = sunColor.withValues(alpha: 0.15 + 0.08 * math.sin(t * math.pi * 2))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(Offset(cx, sunY), r * 0.3, glowPaint);

    // Sun body
    canvas.drawCircle(Offset(cx, sunY), r * 0.2, Paint()..color = sunColor);

    // Rays
    final rayPaint = Paint()
      ..color = sunColor.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * math.pi * 2 + t * math.pi * 0.5;
      final inner = r * 0.24;
      final outer = r * 0.32;
      canvas.drawLine(
        Offset(cx + inner * math.cos(angle), sunY + inner * math.sin(angle)),
        Offset(cx + outer * math.cos(angle), sunY + outer * math.sin(angle)),
        rayPaint,
      );
    }

    // Clouds
    _drawCloud(
      canvas,
      cx - r * 0.2,
      cy + r * 0.2,
      r * 0.15,
      const Color(0xFF1E3A5F).withValues(alpha: 0.8),
    );
    _drawCloud(
      canvas,
      cx + r * 0.25,
      cy + r * 0.35,
      r * 0.12,
      const Color(0xFF1E3A5F).withValues(alpha: 0.6),
    );
  }

  void _drawMoon(Canvas canvas, double cx, double cy, double r) {
    const moonColor = Color(0xFFE0E8FF);
    final moonY = cy - r * 0.1;

    // Glow
    canvas.drawCircle(
      Offset(cx, moonY),
      r * 0.28,
      Paint()
        ..color = moonColor.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    // Crescent: full circle then overlay
    canvas.drawCircle(Offset(cx, moonY), r * 0.2, Paint()..color = moonColor);
    canvas.drawCircle(
      Offset(cx + r * 0.1, moonY - r * 0.05),
      r * 0.16,
      Paint()..color = const Color(0xFF0A0A1F),
    );
  }

  void _drawCloud(Canvas canvas, double x, double y, double sz, Color color) {
    final p = Paint()..color = color;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: sz * 2, height: sz),
      p,
    );
    canvas.drawCircle(Offset(x - sz * 0.4, y), sz * 0.6, p);
    canvas.drawCircle(Offset(x + sz * 0.4, y), sz * 0.55, p);
  }

  void _drawStars(Canvas canvas, Size size, double r) {
    final rng = math.Random(42);
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.6);
    for (int i = 0; i < 18; i++) {
      final sx = rng.nextDouble() * size.width;
      final sy = rng.nextDouble() * size.height * 0.6;
      final dist = math.sqrt(
        (sx - size.width / 2) * (sx - size.width / 2) +
            (sy - size.height / 2) * (sy - size.height / 2),
      );
      if (dist > r * 0.45) continue;
      final twinkle = (math.sin(t * math.pi * 2 + i) + 1) / 2;
      canvas.drawCircle(
        Offset(sx, sy),
        0.8 + twinkle * 1.2,
        starPaint..color = Colors.white.withValues(alpha: 0.3 + twinkle * 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// Punch card widget
// ─────────────────────────────────────────────────────────────────────────────
class _PunchCard extends StatelessWidget {
  final String label;
  final String time;
  final Color color;
  final IconData icon;

  const _PunchCard({
    required this.label,
    required this.time,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = !time.contains('--');
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
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            time,
            style: TextStyle(
              color: hasValue ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shift completed badge - uses shared CompletedBadge widget
// ─────────────────────────────────────────────────────────────────────────────
