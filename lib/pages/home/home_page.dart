import 'dart:async';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/common/event/event_bus_event.dart';
import 'package:face_time_keeping/common/event/event_bus_mixin.dart';
import 'package:face_time_keeping/pages/checking/checking_page.dart';
import 'package:face_time_keeping/pages/setting/setting_page.dart';
import 'package:face_time_keeping/route/app_route.dart';
import 'package:face_time_keeping/route/navigator.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/common/resources/index.dart';
import 'package:face_time_keeping/common/utils/widgets/spacing.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with EventBusMixin {
  late final LocalService _localService;
  StreamSubscription<AvatarChangedEvent>? _avatarChangedSubscription;
  bool _showPinVerification = false;
  String _displayName = 'Người dùng';
  String _avatarPath = '';

  @override
  void initState() {
    super.initState();
    _localService = getIt<LocalService>();
    _localService.initDefaultData();
    _loadUserProfile();
    _avatarChangedSubscription =
        listenEvent<AvatarChangedEvent>(_onAvatarChanged);
  }

  void _onAvatarChanged(AvatarChangedEvent event) {
    if (!mounted) {
      return;
    }

    setState(() {
      _avatarPath = event.avatarPath;
    });
  }

  void _loadUserProfile() {
    final fullName = _localService.getUserFullName().trim();
    final email = _localService.getUserEmail().trim();

    final fallbackName =
        email.isNotEmpty ? email.split('@').first : 'Người dùng';
    setState(() {
      _displayName = fullName.isNotEmpty ? fullName : fallbackName;
      _avatarPath = _localService.getAvatarPath();
    });
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
    super.dispose();
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
                    const SizedBox(height: 8),
                    _buildCheckInCard(),
                    const SizedBox(height: 24),
                    _buildQuickAccess(),
                    const SizedBox(height: 24),
                    _buildRecentActivity(),
                    const SizedBox(height: 8),
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
        imageUrl: '$_avatarPath?t=${DateTime.now().millisecondsSinceEpoch}',
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
          // Notification button
          GestureDetector(
            onTap: () {
              // TODO: implement notifications
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.slate200.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.notifications_outlined,
                      size: 22, color: AppColors.slate900),
                  Positioned(
                    top: 8,
                    right: 9,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Check-in Hero Card ───────────────────────────────────
  Widget _buildCheckInCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // decorative circles
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -10,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.blue[300]!.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.face, color: Colors.white, size: 24),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.green300.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: AppColors.green300.withOpacity(0.3),
                        ),
                      ),
                      child: const Text(
                        'Đang diễn ra',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.green200,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Điểm danh ngay',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'CS101: Nhập môn trí tuệ nhân tạo',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue[100],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TRẠNG THÁI',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[200],
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Chưa ghi nhận',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        AppNavigator.pushNamed(RouterName.checking,
                            arguments: const CheckingArgs(isCheckIn: true));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.center_focus_strong, size: 18),
                      label: const Text(
                        'Quét khuôn mặt',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Access ─────────────────────────────────────────
  Widget _buildQuickAccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Truy cập nhanh',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.slate900,
          ),
        ),
        const SizedBox(height: 14),
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
            _QuickAccessCard(
              icon: Icons.description_outlined,
              title: 'Đơn xin phép',
              subtitle: 'Tạo và theo dõi đơn',
              iconBg: AppColors.teal50,
              iconColor: AppColors.teal600,
              onTap: () {},
            ),
            _QuickAccessCard(
              icon: Icons.face_retouching_natural,
              title: 'Đăng ký khuôn mặt',
              subtitle: 'Cập nhật sinh trắc học',
              iconBg: AppColors.blue50,
              iconColor: AppColors.blue600,
              onTap: () {
                AppNavigator.pushNamed(RouterName.registerFace);
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
          ],
        ),
      ],
    );
  }

  // ── Recent Activity ──────────────────────────────────────
  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Hoạt động gần đây',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.slate900,
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Xem tất cả',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ActivityItem(
          icon: Icons.check_circle,
          iconBg: AppColors.green100,
          iconColor: AppColors.green600,
          title: 'Phòng thí nghiệm Vật lý',
          subtitle: 'Đã điểm danh • 09:45',
          time: 'Hôm nay',
        ),
        const SizedBox(height: 10),
        _ActivityItem(
          icon: Icons.cancel,
          iconBg: AppColors.red100,
          iconColor: AppColors.red600,
          title: 'Toán 201',
          subtitle: 'Vắng mặt • Không quét',
          time: 'Hôm qua',
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
          dispose();
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

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.slate200.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.slate400,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.slate500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
