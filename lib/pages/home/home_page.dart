import 'dart:async';
import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/common/event/event_bus_event.dart';
import 'package:face_time_keeping/common/event/event_bus_mixin.dart';
import 'package:face_time_keeping/pages/setting/setting_page.dart';
import 'package:face_time_keeping/pages/setting/spoof_list_page.dart';
import 'package:face_time_keeping/pages/checking/checking_page.dart';
import 'package:face_time_keeping/route/app_route.dart';
import 'package:face_time_keeping/route/navigator.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/common/resources/index.dart';
import 'package:face_time_keeping/common/utils/widgets/spacing.dart';
import 'package:face_time_keeping/data/remote/session_service.dart';
import 'package:face_time_keeping/entities/session.dart';
import 'package:face_time_keeping/common/enums/session_attendance_mode.dart';
import 'package:face_time_keeping/pages/account/account_cubit.dart';
import 'package:face_time_keeping/pages/widgets/app_dialog.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

const Duration _homeSessionRefreshInterval = Duration(minutes: 1);
const Duration _fallbackSessionDuration = Duration(minutes: 45);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with EventBusMixin {
  late final LocalService _localService;
  StreamSubscription<AvatarChangedEvent>? _avatarChangedSubscription;
  StreamSubscription<CourseChangeEvent>? _courseChangedSubscription;
  Timer? _sessionRefreshTimer;
  bool _showPinVerification = false;
  String _displayName = 'Người dùng';
  String _avatarPath = '';
  List<Session>? _todaySessions;
  String? _generatedSessionsDateKey;
  bool _isLoadingSessions = false;
  int _fetchTodaySessionsRequestId = 0;

  bool get _isTeacherOrAdmin {
    final role = _localService.getUserRole().toLowerCase();
    return role == 'teacher' || role == 'admin';
  }

  void _openSessionsFocus(Session selectedSession) {
    final sessions = List<Session>.from(_todaySessions ?? <Session>[])
      ..sort((a, b) {
        final aTime = a.startTime;
        final bTime = b.startTime;
        return aTime.compareTo(
            bTime); // tăng dần: cũ nhất (CLOSED) → mới nhất (NOT_OPEN)
      });
    if (sessions.isEmpty) return;

    final initialIndex = sessions.indexWhere((e) => e.id == selectedSession.id);

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.50),
        barrierLabel:
            MaterialLocalizations.of(context).modalBarrierDismissLabel,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) {
          return _SessionsFocusPage(
            sessions: sessions,
            initialIndex: initialIndex < 0 ? 0 : initialIndex,
            isTeacherOrAdmin: _isTeacherOrAdmin,
            onCheckIn: (session) {
              Navigator.of(context).pop();

              AppNavigator.pushNamed(
                RouterName.checking,
                arguments: const CheckingArgs(isCheckIn: true),
              );
            },
            onOpen: (session) async {
              Navigator.of(context).pop();
              await _openSession(session.id);
            },
            onClose: (session) async {
              Navigator.of(context).pop();
              await _closeSession(session.id);
            },
          );
        },
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _localService = getIt<LocalService>();
    _localService.initDefaultData();
    _loadUserInfo();
    _fetchTodaySessions();
    _sessionRefreshTimer = Timer.periodic(_homeSessionRefreshInterval, (_) {
      if (mounted && !_isLoadingSessions) {
        _fetchTodaySessions();
      }
    });

    _avatarChangedSubscription =
        listenEvent<AvatarChangedEvent>(_onAvatarChanged);
    _courseChangedSubscription =
        listenEvent<CourseChangeEvent>(_onCourseChanged);
  }

  void _onAvatarChanged(AvatarChangedEvent event) {
    if (!mounted) {
      return;
    }

    setState(() {
      _avatarPath = event.avatarPath;
    });
  }

  void _onCourseChanged(CourseChangeEvent event) {
    _generatedSessionsDateKey = null;
    _fetchTodaySessions(forceGenerate: true);
  }

  Future<void> _loadUserInfo() async {
    final name = _localService.getUserFullName();
    final avatar = _localService.getAvatarPath();
    if (mounted) {
      setState(() {
        _displayName = name.isNotEmpty ? name : 'Người dùng';
        _avatarPath = avatar;
      });
    }
  }

  Future<void> _fetchTodaySessions({bool forceGenerate = false}) async {
    if (!mounted) return;
    final requestId = ++_fetchTodaySessionsRequestId;
    setState(() {
      _isLoadingSessions = true;
    });
    try {
      final sessionService = getIt<SessionService>();
      final now = DateTime.now();
      final todayKey = _dateKey(now);

      if (forceGenerate || _generatedSessionsDateKey != todayKey) {
        final generateResult = await sessionService.generateDailySessions(now);
        if (generateResult.isSuccess) {
          _generatedSessionsDateKey = todayKey;
        }
      }

      final role = _localService.getUserRole().toLowerCase();
      final DataState<List<Session>> result;
      if (role == 'admin') {
        result = await sessionService.getAdminSessions(date: now);
      } else if (role == 'teacher') {
        result = await sessionService.getTeacherSessions(date: now);
      } else {
        result = await sessionService.getSessions(date: now);
      }

      if (requestId != _fetchTodaySessionsRequestId) {
        return;
      }

      if (result.isSuccess && mounted) {
        final sessions = (result.data ?? [])
            .where((session) => _isSameLocalDate(
                  session.sessionDate ?? session.startTime,
                  now,
                ))
            .toList();
        // Sắp xếp dựa trên mappedStatus do backend cung cấp (source of truth):
        // OPEN → CAN_OPEN/NOT_OPEN/UPCOMING → CLOSED
        sessions.sort((a, b) {
          int score(Session s) {
            final ms = (s.mappedStatus ?? '').toUpperCase();
            if (ms == 'OPEN') return 1;
            if (ms == 'CLOSED') return 3;
            return 2; // NOT_OPEN, CAN_OPEN, UPCOMING
          }

          final sA = score(a);
          final sB = score(b);
          if (sA != sB) return sA.compareTo(sB);

          if (sA == 3) {
            // Đã đóng: gần nhất lên trước (giảm dần)
            return (b.endTime ?? b.startTime)
                .compareTo(a.endTime ?? a.startTime);
          }
          // Sắp / đang: thời gian bắt đầu tăng dần
          return a.startTime.compareTo(b.startTime);
        });
        setState(() {
          _todaySessions = sessions;
        });
      }
    } catch (e) {
      pushLog('Error fetching today sessions: $e');
    } finally {
      if (mounted && requestId == _fetchTodaySessionsRequestId) {
        setState(() {
          _isLoadingSessions = false;
        });
      }
    }
  }

  Future<void> _openSession(String id) async {
    final sessionService = getIt<SessionService>();
    final result = await sessionService.activateSession(id);
    if (result.isSuccess) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mở phiên học thành công')));
      _fetchTodaySessions();
    } else {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.error ?? 'Lỗi mở phiên')));
    }
  }

  Future<void> _closeSession(String id) async {
    final sessionService = getIt<SessionService>();
    final result = await sessionService.closeSession(id);
    if (result.isSuccess) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đóng phiên học thành công')));
      _fetchTodaySessions();
    } else {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.error ?? 'Lỗi đóng phiên')));
    }
  }

  String _getGreetingByTime() {
    final vietnamNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    final hour = vietnamNow.hour;
    if (hour < 12) {
      return 'Chào buổi sáng';
    }
    if (hour < 18) {
      return 'Chào buổi chiều';
    }
    return 'Chào buổi tối';
  }

  Future<void> _onPinVerified() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (context) => const SettingPage()));
    setState(() {
      _showPinVerification = false;
    });
  }

  @override
  void dispose() {
    _avatarChangedSubscription?.cancel();
    _courseChangedSubscription?.cancel();
    _sessionRefreshTimer?.cancel();
    super.dispose();
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppDialog(
          title: 'Đăng xuất',
          icon: Icons.logout,
          accentColor: AppColors.red600,
          content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gray200,
              ),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final accountCubit = getIt<AccountCubit>();
                await accountCubit.logout();
                if (!mounted) return;
                Navigator.of(dialogContext).pop();
                AppNavigator.pushNamedAndRemoveUntil(
                  RouterName.login,
                  (_) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showPinVerification) {
      return _PinVerificationPage(
        localService: _localService,
        onVerified: _onPinVerified,
        onBack: () {
          setState(() {
            _showPinVerification = false;
          });
        },
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTodaySessionsCard(),
                    _buildQuickAccess(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final bool isNetworkAvatar =
        _avatarPath.startsWith('http') || _avatarPath.startsWith('https');
    final bool hasLocalAvatar = !isNetworkAvatar &&
        _avatarPath.isNotEmpty &&
        File(_avatarPath).existsSync();

    if (isNetworkAvatar) {
      return CachedNetworkImage(
        imageUrl: _avatarPath,
        imageBuilder: (context, imageProvider) => Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border:
                Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
        ),
        placeholder: (context, url) => Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: AppColors.slate200),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) => _buildDefaultAvatar(),
      );
    } else if (hasLocalAvatar) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border:
              Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
          image: DecorationImage(
              image: FileImage(File(_avatarPath)), fit: BoxFit.cover),
        ),
      );
    } else {
      return _buildDefaultAvatar();
    }
  }

  Widget _buildDefaultAvatar() {
    final String initial =
        _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
        color: AppColors.primary.withOpacity(0.1),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.slate200, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Menu button
          GestureDetector(
            onTap: () async {
              final String? pinApp = await _localService.getPinApp();
              if (pinApp != null) {
                setState(() => _showPinVerification = true);
              } else {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingPage()));
              }
            },
            child: const Icon(Icons.menu, size: 28, color: AppColors.slate900),
          ),
          const SizedBox(width: 12),
          // Avatar
          Stack(
            children: [
              _buildAvatar(),
            ],
          ),
          const SizedBox(width: 12),
          // Greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreetingByTime(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate500,
                  ),
                ),
                Text(
                  _displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate900,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          // Logout button
          GestureDetector(
            onTap: _showLogoutDialog,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.red100,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.logout, size: 22, color: AppColors.red600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySessionsCard() {
    final sessions = _todaySessions ?? <Session>[];

    // Ưu tiên phiên học đang diễn ra gần nhất (startTime lớn nhất = bắt đầu muộn nhất)
    final ongoingSessions = sessions.where(_sessionIsActive).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    final selectedSession = _selectTodayRepresentativeSession(
      sessions,
      DateTime.now(),
    );

    final displaySessions =
        selectedSession == null ? <Session>[] : <Session>[selectedSession];

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildTodaySessionContent(
              sessions: sessions,
              ongoingSessions: ongoingSessions,
              displaySessions: displaySessions,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySessionContent({
    required List<Session> sessions,
    required List<Session> ongoingSessions,
    required List<Session> displaySessions,
  }) {
    if (_isLoadingSessions && sessions.isEmpty) {
      return Container(
        key: const ValueKey('loading-sessions'),
        height: 256,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (sessions.isEmpty) {
      return Container(
        key: const ValueKey('empty-sessions'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.slate200.withOpacity(0.7)),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_busy, color: AppColors.slate500),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Không có phiên học nào hôm nay',
                style: TextStyle(
                  color: AppColors.slate500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (!_isLoadingSessions)
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                onPressed: () => _fetchTodaySessions(forceGenerate: true),
                tooltip: 'Làm mới',
              )
            else
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      );
    }

    return Column(
      key: ValueKey(
        'sessions-${displaySessions.map((e) => e.id).join("-")}',
      ),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < displaySessions.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == displaySessions.length - 1 ? 0 : 12,
            ),
            child: GestureDetector(
              onTap: () => _openSessionsFocus(displaySessions[i]),
              child: Hero(
                tag: _sessionHeroTag(displaySessions[i]),
                child: Material(
                  type: MaterialType.transparency,
                  child: _SessionHeroCard(
                    session: displaySessions[i],
                    isTeacherOrAdmin: _isTeacherOrAdmin,
                    teacherName: displaySessions[i].teacherName ?? '—',
                    onRefresh: _isLoadingSessions
                        ? null
                        : () => _fetchTodaySessions(forceGenerate: true),
                    onCheckIn: _sessionIsActive(displaySessions[i])
                        ? () {
                            AppNavigator.pushNamed(
                              RouterName.checking,
                              arguments: const CheckingArgs(isCheckIn: true),
                            );
                          }
                        : null,
                    onOpen: () => _openSession(displaySessions[i].id),
                    onClose: () => _closeSession(displaySessions[i].id),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Quick Access ─────────────────────────────────────────
  Widget _buildQuickAccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _QuickAccessCard(
              icon: Icons.calendar_month,
              title: (_localService.getUserRole().toLowerCase() == 'teacher' ||
                      _localService.getUserRole().toLowerCase() == 'admin')
                  ? 'Lịch giảng dạy'
                  : 'Lịch học',
              subtitle: 'Kế hoạch theo tuần',
              iconBg: AppColors.purple50,
              iconColor: AppColors.purple600,
              onTap: () {
                AppNavigator.pushNamed(RouterName.schedule);
              },
            ),
            if (_localService.getUserRole().toLowerCase() == 'teacher' ||
                _localService.getUserRole().toLowerCase() == 'admin')
              _QuickAccessCard(
                icon: Icons.checklist_rtl,
                title: 'Quản lý điểm danh',
                subtitle: 'Mở/đóng phiên học',
                iconBg: AppColors.orange50,
                iconColor: AppColors.orange,
                onTap: () {
                  AppNavigator.pushNamed(RouterName.sessionManagement);
                },
              ),
            if (_localService.getUserRole().toLowerCase() == 'admin')
              _QuickAccessCard(
                icon: Icons.security_rounded,
                title: 'Cảnh báo giả mạo',
                subtitle: 'Phát hiện bất thường',
                iconBg: AppColors.red.withOpacity(0.1),
                iconColor: AppColors.red,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SpoofListPage()),
                  );
                },
              ),
            _QuickAccessCard(
              icon: Icons.school,
              title: 'Học phần',
              subtitle: 'Quản lý môn học',
              iconBg: AppColors.blue50,
              iconColor: AppColors.blue600,
              onTap: () {
                AppNavigator.pushNamed(RouterName.courseList);
              },
            ),
            _QuickAccessCard(
              icon: Icons.history,
              title: 'Lịch sử',
              subtitle: 'Lịch sử điểm danh',
              iconBg: AppColors.green100,
              iconColor: AppColors.green600,
              onTap: () {
                AppNavigator.pushNamed(RouterName.attendanceHistory);
              },
            ),
            _QuickAccessCard(
              icon: Icons.assignment_ind_outlined,
              title: 'Đơn xin phép',
              subtitle:
                  (_localService.getUserRole().toLowerCase() == 'teacher' ||
                          _localService.getUserRole().toLowerCase() == 'admin')
                      ? 'Quản lý đơn xin phép'
                      : 'Gửi yêu cầu nghỉ',
              iconBg: AppColors.teal50,
              iconColor: AppColors.teal600,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tính năng đang phát triển'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            _QuickAccessCard(
              icon: Icons.person_outline,
              title: 'Tài khoản',
              subtitle: 'Thông tin cá nhân',
              iconBg: AppColors.slate200,
              iconColor: AppColors.slate900,
              onTap: () {
                AppNavigator.pushNamed(RouterName.account);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _PinVerificationPage extends StatefulWidget {
  const _PinVerificationPage({
    required this.localService,
    required this.onVerified,
    required this.onBack,
  });

  final LocalService localService;
  final VoidCallback onVerified;
  final VoidCallback onBack;

  @override
  State<_PinVerificationPage> createState() => _PinVerificationPageState();
}

class _PinVerificationPageState extends State<_PinVerificationPage> {
  String _pin = '';
  bool _isLoading = false;
  String? _errorMessage;
  int _attemptCount = 0;
  static const int _maxAttempts = 5;
  @override
  void initState() {
    super.initState();
    //force portrait
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    super.dispose();
    //restore all orientations
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitDown,
    ]);
  }

  void _onNumberTap(String number) {
    if (_isLoading || _pin.length >= 6) return;

    HapticFeedback.lightImpact();

    setState(() {
      //_errorMessage = null;
      _pin += number;

      if (_pin.length == 6) {
        _verifyPin();
      }
    });
  }

  void _onDeleteTap() {
    if (_isLoading || _pin.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() {
      // _errorMessage = null;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  void _onClearTap() {
    if (_isLoading) return;

    HapticFeedback.mediumImpact();

    setState(() {
      _pin = '';
      _errorMessage = null;
    });
  }

  Future<void> _verifyPin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final String? savedPin = await widget.localService.getPinApp();

      if (savedPin == _pin) {
        if (mounted) {
          HapticFeedback.heavyImpact();
          widget.onVerified();
        }
      } else {
        _attemptCount++;
        if (mounted) {
          setState(() {
            _pin = '';
            _isLoading = false;

            if (_attemptCount >= _maxAttempts) {
              _errorMessage = 'Quá nhiều lần nhập sai. Vui lòng thử lại sau.';
              _showMaxAttemptsDialog();
            } else {
              _errorMessage =
                  'Mã PIN không đúng. Còn lại ${_maxAttempts - _attemptCount} lần thử.';
            }
          });
          HapticFeedback.heavyImpact();
        }
      }
    } catch (e) {
      await pushLog('Error in _verifyPin: $e');
      if (mounted) {
        setState(() {
          _pin = '';
          _isLoading = false;
          _errorMessage = 'Có lỗi xảy ra. Vui lòng thử lại.';
        });
      }
    }
  }

  void _showMaxAttemptsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Quá nhiều lần thử'),
        content: const Text('Bạn đã nhập sai mã PIN quá nhiều lần.\n\n'
            'Vui lòng đóng ứng dụng và thử lại sau ít phút.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Exit the app
              SystemNavigator.pop();
            },
            child: const Text('Đóng ứng dụng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Back button
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      widget.onBack();
                    },
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 28,
                      color: AppColors.black,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const Spacing(height: 20),

              // App Icon/Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.blue.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 50,
                  color: AppColors.blue,
                ),
              ),

              const Spacing(height: 40),

              // Title
              const Text(
                'Nhập mã PIN',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
              ),

              const Spacing(height: 20),

              // PIN dots display
              _PinDotsDisplay(
                pinLength: _pin.length,
                hasError: _errorMessage != null,
              ),

              const Spacing(height: 24),

              // Error message
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.red,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacing(height: 24),
              ],

              // PIN Keypad
              Expanded(
                child: _PinKeypad(
                  onNumberTap: _onNumberTap,
                  onDeleteTap: _onDeleteTap,
                  onClearTap: _onClearTap,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinDotsDisplay extends StatelessWidget {
  const _PinDotsDisplay({
    required this.pinLength,
    required this.hasError,
  });

  final int pinLength;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final bool isFilled = index < pinLength;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? (hasError ? AppColors.red : AppColors.blue)
                : AppColors.gray100,
            border: Border.all(
              color: hasError
                  ? AppColors.red
                  : (isFilled ? AppColors.blue : AppColors.gray200),
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

class _PinKeypad extends StatelessWidget {
  const _PinKeypad({
    required this.onNumberTap,
    required this.onDeleteTap,
    required this.onClearTap,
    required this.isLoading,
  });

  final Function(String) onNumberTap;
  final VoidCallback onDeleteTap;
  final VoidCallback onClearTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Numbers 1-3
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _KeypadButton(
              text: '1',
              onTap: () => onNumberTap('1'),
              isEnabled: !isLoading,
            ),
            _KeypadButton(
              text: '2',
              onTap: () => onNumberTap('2'),
              isEnabled: !isLoading,
            ),
            _KeypadButton(
              text: '3',
              onTap: () => onNumberTap('3'),
              isEnabled: !isLoading,
            ),
          ],
        ),
        const Spacing(height: 16),

        // Numbers 4-6
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _KeypadButton(
              text: '4',
              onTap: () => onNumberTap('4'),
              isEnabled: !isLoading,
            ),
            _KeypadButton(
              text: '5',
              onTap: () => onNumberTap('5'),
              isEnabled: !isLoading,
            ),
            _KeypadButton(
              text: '6',
              onTap: () => onNumberTap('6'),
              isEnabled: !isLoading,
            ),
          ],
        ),
        const Spacing(height: 16),

        // Numbers 7-9
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _KeypadButton(
              text: '7',
              onTap: () => onNumberTap('7'),
              isEnabled: !isLoading,
            ),
            _KeypadButton(
              text: '8',
              onTap: () => onNumberTap('8'),
              isEnabled: !isLoading,
            ),
            _KeypadButton(
              text: '9',
              onTap: () => onNumberTap('9'),
              isEnabled: !isLoading,
            ),
          ],
        ),
        const Spacing(height: 16),

        // Clear, 0, Delete
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _KeypadButton(
              text: 'Xóa',
              onTap: onClearTap,
              isEnabled: !isLoading,
              isTextButton: true,
            ),
            _KeypadButton(
              text: '0',
              onTap: () => onNumberTap('0'),
              isEnabled: !isLoading,
            ),
            _KeypadButton(
              icon: Icons.backspace_outlined,
              onTap: onDeleteTap,
              isEnabled: !isLoading,
              isIconButton: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    this.text,
    this.icon,
    required this.onTap,
    required this.isEnabled,
    this.isTextButton = false,
    this.isIconButton = false,
  });

  final String? text;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isEnabled;
  final bool isTextButton;
  final bool isIconButton;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(36),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEnabled ? AppColors.white : AppColors.gray100,
              border: Border.all(
                color: isEnabled ? AppColors.gray200 : AppColors.gray100,
                width: 1,
              ),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isIconButton
                  ? Icon(
                      icon,
                      size: 24,
                      color: isEnabled ? AppColors.black : AppColors.gray200,
                    )
                  : Text(
                      text ?? '',
                      style: TextStyle(
                        fontSize: isTextButton ? 14 : 24,
                        fontWeight:
                            isTextButton ? FontWeight.w500 : FontWeight.w600,
                        color: isEnabled ? AppColors.black : AppColors.gray200,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.slate200.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.slate900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _sessionHeroTag(Session session) => 'today-session-${session.id}';

Session? _selectTodayRepresentativeSession(
  List<Session> sessions,
  DateTime now,
) {
  if (sessions.isEmpty) return null;

  final active = sessions.where(_sessionIsActive).toList()
    ..sort((a, b) => b.startTime.compareTo(a.startTime));
  if (active.isNotEmpty) return active.first;

  final canOpen = sessions.where((s) {
    final mappedStatus = (s.mappedStatus ?? '').toUpperCase();
    return !_sessionIsClosed(s) &&
        (s.canOpen || mappedStatus == 'CAN_OPEN') &&
        _sessionEffectiveEnd(s).toLocal().isAfter(now);
  }).toList()
    ..sort((a, b) => _sessionDistanceFromNow(a, now)
        .compareTo(_sessionDistanceFromNow(b, now)));
  if (canOpen.isNotEmpty) return canOpen.first;

  final stillInWindow = sessions.where((s) {
    final mappedStatus = (s.mappedStatus ?? s.status.name).toUpperCase();
    final waiting = mappedStatus == 'NOT_OPEN' ||
        mappedStatus == 'UPCOMING' ||
        s.status == SessionStatus.scheduled;
    return waiting &&
        !_sessionIsClosed(s) &&
        !_sessionStartsInFuture(s, now) &&
        _sessionEffectiveEnd(s).toLocal().isAfter(now);
  }).toList()
    ..sort((a, b) => b.startTime.compareTo(a.startTime));
  if (stillInWindow.isNotEmpty) return stillInWindow.first;

  final future = sessions.where((s) {
    final mappedStatus = (s.mappedStatus ?? s.status.name).toUpperCase();
    final waiting = mappedStatus == 'NOT_OPEN' ||
        mappedStatus == 'UPCOMING' ||
        s.status == SessionStatus.scheduled;
    return waiting && !_sessionIsClosed(s) && _sessionStartsInFuture(s, now);
  }).toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
  if (future.isNotEmpty) return future.first;

  final recentlyEnded = sessions.where(_sessionIsClosed).toList()
    ..sort(
        (a, b) => _sessionEffectiveEnd(b).compareTo(_sessionEffectiveEnd(a)));
  if (recentlyEnded.isNotEmpty) return recentlyEnded.first;

  return null;
}

DateTime _sessionEffectiveEnd(Session session) {
  final explicitEnd = session.endTime;
  if (explicitEnd != null) return explicitEnd;

  return session.startTime.add(_fallbackSessionDuration);
}

String _dateKey(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

bool _isSameLocalDate(DateTime a, DateTime b) {
  final localA = a.toLocal();
  final localB = b.toLocal();
  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day;
}

bool _sessionStartsInFuture(Session session, DateTime now) {
  return session.startTime.toLocal().isAfter(now);
}

int _sessionDistanceFromNow(Session session, DateTime now) {
  return session.startTime.toLocal().difference(now).inMilliseconds.abs();
}

bool _sessionIsActive(Session session) {
  final mappedStatus = (session.mappedStatus ?? '').toUpperCase();
  final now = DateTime.now();

  // If the session is explicitly closed or end time has passed, it's NOT active
  final isClosed = mappedStatus == 'CLOSED' ||
      session.status == SessionStatus.closed ||
      _sessionEffectiveEnd(session).toLocal().isBefore(now);

  if (isClosed) return false;

  return mappedStatus == 'OPEN' || session.status == SessionStatus.active;
}

bool _sessionIsClosed(Session session) {
  final now = DateTime.now();
  final mappedStatus = (session.mappedStatus ?? '').toUpperCase();

  return mappedStatus == 'CLOSED' ||
      session.status == SessionStatus.closed ||
      _sessionEffectiveEnd(session).toLocal().isBefore(now);
}

String _sessionStatusLabel(Session session) {
  if (_sessionIsActive(session)) return 'Đang diễn ra';
  if (_sessionIsClosed(session)) return 'Đã kết thúc';
  return 'Sắp diễn ra';
}

class _SessionsFocusPage extends StatefulWidget {
  const _SessionsFocusPage({
    required this.sessions,
    required this.initialIndex,
    required this.isTeacherOrAdmin,
    required this.onCheckIn,
    required this.onOpen,
    required this.onClose,
  });

  final List<Session> sessions;
  final int initialIndex;
  final bool isTeacherOrAdmin;
  final ValueChanged<Session> onCheckIn;
  final ValueChanged<Session> onOpen;
  final ValueChanged<Session> onClose;

  @override
  State<_SessionsFocusPage> createState() => _SessionsFocusPageState();
}

class _SessionsFocusPageState extends State<_SessionsFocusPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _pageController = PageController(
      initialPage: widget.initialIndex,
      viewportFraction: 0.84,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Card sẽ tự co giãn theo nội dung để show full

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        // Bao ngoài toàn bộ bằng GestureDetector để bắt sự kiện tap ra ngoài (dismiss)
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: Stack(
            children: [
              // ── PageView overlay toàn màn hình ──────────────────────
              PageView.builder(
                clipBehavior: Clip.none,
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: widget.sessions.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  final session = widget.sessions[index];

                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double delta = 0;

                      if (_pageController.hasClients &&
                          _pageController.position.haveDimensions) {
                        delta =
                            (_pageController.page ?? _currentIndex.toDouble()) -
                                index;
                      } else {
                        delta = (_currentIndex - index).toDouble();
                      }

                      final scale =
                          (1 - delta.abs() * 0.06).clamp(0.92, 1.0).toDouble();

                      final opacity =
                          (1 - delta.abs() * 0.25).clamp(0.55, 1.0).toDouble();

                      return Center(
                        child: Opacity(
                          opacity: opacity,
                          child: Transform.scale(
                            scale: scale,
                            child: child,
                          ),
                        ),
                      );
                    },
                    // Sử dụng Padding horizontal + SizedBox height thay vì Expanded/Padding dọc
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),

                      // Chặn sự kiện tap bubble up lên GestureDetector ngoài cùng
                      child: GestureDetector(
                        onTap: () {},
                        child: Hero(
                          tag: _sessionHeroTag(session),
                          child: Material(
                            type: MaterialType.transparency,
                            child: _SessionHeroCard(
                              session: session,
                              expanded: true,
                              isTeacherOrAdmin: widget.isTeacherOrAdmin,
                              teacherName: session.teacherName ?? '—',
                              onCheckIn: _sessionIsActive(session)
                                  ? () => widget.onCheckIn(session)
                                  : null,
                              onOpen: () => widget.onOpen(session),
                              onClose: () => widget.onClose(session),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // ── Indicator Positioned — overlay, không đẩy layout PageView ──
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: IgnorePointer(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      '${_currentIndex + 1}/${widget.sessions.length}',
                      key: ValueKey(_currentIndex),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
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

class _SessionHeroCard extends StatelessWidget {
  const _SessionHeroCard({
    required this.session,
    required this.isTeacherOrAdmin,
    required this.teacherName,
    this.expanded = false,
    this.onRefresh,
    this.onCheckIn,
    this.onOpen,
    this.onClose,
  });

  final Session session;
  final bool isTeacherOrAdmin;
  final String teacherName;
  final bool expanded;
  final VoidCallback? onRefresh;
  final VoidCallback? onCheckIn;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final isActive = _sessionIsActive(session);
    final isClosed = _sessionIsClosed(session);
    final statusLabel = _sessionStatusLabel(session);

    final actionButton = _buildActionButton(
      isActive: isActive,
      isClosed: isClosed,
    );

    String timeSlotStr = 'Chưa cập nhật';
    if (session.timeSlotName != null) {
      final now = DateTime.now();
      final isToday = session.startTime.year == now.year &&
          session.startTime.month == now.month &&
          session.startTime.day == now.day;

      if (isToday) {
        timeSlotStr = 'Hôm nay - ${session.timeSlotName}';
      } else if (session.dayOfWeek != null) {
        final dow = session.dayOfWeek!;
        final dowStr = (dow == 1 || dow == 8) ? 'Chủ nhật' : 'Thứ $dow';
        timeSlotStr = '$dowStr - ${session.timeSlotName}';
      } else {
        timeSlotStr = session.timeSlotName!;
      }
    }

    final double collapsedHeight = actionButton != null ? 250 : 220;

    final double radius = expanded ? 28 : 24;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: expanded ? 320 : collapsedHeight,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: AppColors.fintechCardLight.withOpacity(0.28),
              blurRadius: expanded ? 34 : 24,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: AppColors.fintechCardDark.withOpacity(0.30),
              blurRadius: 50,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: [0.0, 0.48, 1.0],
                      colors: [
                        AppColors.fintechCardDark,
                        AppColors.fintechCardMedium,
                        AppColors.fintechCardLight,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Image.asset(
                  AssetImages.imgCardImage,
                  fit: BoxFit.cover,
                  colorBlendMode: BlendMode.screen,
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.45, 0.35),
                      radius: 0.95,
                      colors: [
                        Colors.white.withOpacity(0.13),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [
                        Colors.black.withOpacity(0.08),
                        Colors.transparent,
                        Colors.white.withOpacity(0.08),
                      ],
                    ),
                  ),
                ),
              ),
              // ── Main card content ──────────────────────────
              SizedBox(
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final padding = EdgeInsets.symmetric(
                      horizontal: expanded ? 28 : 22,
                      vertical: expanded ? 24 : 20,
                    );
                    final title =
                        '${session.courseName?.isNotEmpty == true ? session.courseName : 'Chưa cập nhật'} (${session.courseCode ?? 'N/A'})';

                    Widget buildHeader() {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _OutlinePill(
                              text: session.formattedCheckinWindow,
                              trailingText: statusLabel,
                              fontSize: expanded ? 15 : 13,
                              horizontal: 14,
                              vertical: 7,
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (onRefresh != null)
                            GestureDetector(
                              onTap: onRefresh,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.13),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.28),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                  size: 17,
                                ),
                              ),
                            ),
                        ],
                      );
                    }

                    Widget buildBody() {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: expanded ? null : 2,
                            overflow: expanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: expanded ? 22 : 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildFeatureCheck(
                              Icons.co_present, 'Giáo viên: $teacherName'),
                          const SizedBox(height: 8),
                          _buildFeatureCheck(Icons.schedule, timeSlotStr),
                          const SizedBox(height: 8),
                          _buildFeatureCheck(
                            Icons.meeting_room,
                            'Phòng: ${session.roomName ?? 'Chưa cập nhật'}',
                          ),
                          if (expanded) ...[
                            const SizedBox(height: 8),
                            _buildFeatureCheck(
                              Icons.people_outline,
                              'Sĩ số: ${session.enrolledCount} sinh viên',
                            ),
                            const SizedBox(height: 8),
                            _buildFeatureCheck(
                              Icons.settings_outlined,
                              'Chế độ: ${session.attendanceMode?.label ?? 'N/A'}',
                            ),
                            if (session.checkinWindowStart != null ||
                                session.checkinWindowEnd != null) ...[
                              const SizedBox(height: 8),
                              _buildFeatureCheck(
                                Icons.how_to_reg_outlined,
                                'Cửa sổ điểm danh: ${session.formattedCheckinWindow}',
                              ),
                            ],
                          ],
                        ],
                      );
                    }

                    Widget buildFooter() {
                      if (actionButton == null) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: EdgeInsets.zero,
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: actionButton,
                        ),
                      );
                    }

                    return Padding(
                      padding: padding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          buildHeader(),
                          SizedBox(height: expanded ? 32 : 16),
                          buildBody(),
                          if (actionButton != null)
                            SizedBox(height: expanded ? 32 : 16),
                          buildFooter(),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCheck(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.22),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 12,
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: expanded ? 15 : 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.95),
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildActionButton({
    required bool isActive,
    required bool isClosed,
  }) {
    String buttonText;
    VoidCallback? onPressed;

    if (isTeacherOrAdmin) {
      if (session.canOpen && !isActive && !isClosed) {
        buttonText = 'Mở phiên';
        onPressed = onOpen;
      } else if (session.canClose && isActive) {
        buttonText = 'Đóng phiên';
        onPressed = onClose;
      } else {
        return null;
      }
    } else {
      if (!isActive) return null;
      buttonText = 'Điểm danh';
      onPressed = onCheckIn;
    }

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: expanded ? 22 : 18,
          vertical: expanded ? 14 : 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.82),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              buttonText,
              style: TextStyle(
                fontSize: expanded ? 15 : 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlinePill extends StatelessWidget {
  const _OutlinePill({
    required this.text,
    required this.fontSize,
    this.trailingText,
    this.horizontal = 18,
    this.vertical = 8,
  });

  final String text;
  final String? trailingText;
  final double fontSize;
  final double horizontal;
  final double vertical;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontal,
        vertical: vertical,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.82),
          width: 1.15,
        ),
      ),
      child: trailingText == null
          ? Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.9),
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trailingText!,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
