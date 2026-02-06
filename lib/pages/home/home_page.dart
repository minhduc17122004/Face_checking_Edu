import 'dart:ffi';

import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/common/utils/sync_jobs_util.dart';
import 'package:face_time_keeping/data/remote/user_service.dart';
import 'package:face_time_keeping/entities/sync_face_schedule.dart';
import 'package:face_time_keeping/entities/sync_schedule.dart';
import 'package:face_time_keeping/pages/checking/checking_page.dart';
import 'package:face_time_keeping/pages/home/test/test_page.dart';

import 'package:face_time_keeping/pages/setting/setting_page.dart';
import 'package:face_time_keeping/route/app_route.dart';
import 'package:face_time_keeping/route/navigator.dart';
import 'package:face_time_keeping/pages/bloc/app_bloc.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/common/resources/index.dart';
import 'package:face_time_keeping/common/utils/widgets/spacing.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final LocalService _localService;
  bool _showPinVerification = false;

  @override
  void initState() {
    super.initState();
    _localService = getIt<LocalService>();
    _localService.initDefaultData();
  }

  Future<void> _onPinVerified() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (context) => const SettingPage()));

    setState(() {
      _showPinVerification = false;
    });
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 85,
        leading: IconButton(
          onPressed: () async {
            // check if pinApp !=null then open a dialog to input pin
            final String? pinApp = await _localService.getPinApp();
            if (pinApp != null) {
              setState(() {
                _showPinVerification = true;
              });
              return;
            } else {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const SettingPage()));
            }
          },
          icon: const Icon(Icons.menu, size: 50, color: Colors.black54),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Welcome Header with School Theme
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF42A5F5),
                        Color(0xFF1E88E5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Xin chào! 👋',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Học sinh thân mến',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // School Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.school,
                          size: 45,
                          color: Color(0xFF1E88E5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Info Cards
                Row(
                  children: [
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.calendar_today,
                        title: 'Hôm nay',
                        subtitle: 'Thứ 5, 06/02/2026',
                        color: const Color(0xFFFF7043),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.check_circle_outline,
                        title: 'Trạng thái',
                        subtitle: 'Sẵn sàng',
                        color: const Color(0xFF66BB6A),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 60),

                // Attendance Button
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 85,
                    child: ElevatedButton(
                      onPressed: () async {
                        AppNavigator.pushNamed(RouterName.checking,
                            arguments: const CheckingArgs(isCheckIn: true));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.fingerprint,
                            size: 32,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Điểm danh',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Check Out Button
                // SizedBox(
                //   width: double.infinity,
                //   height: 80,
                //   child: ElevatedButton(
                //     onPressed: () async {
                //       if (await getIt<AppBloc>().isExpiredLicenseKey()) {
                //         return;
                //       }
                //       AppNavigator.pushNamed(RouterName.checking,
                //           arguments: const CheckingArgs(isCheckIn: false));
                //     },
                //     style: ElevatedButton.styleFrom(
                //       backgroundColor: const Color(0xFFE57373),
                //       foregroundColor: Colors.white,
                //       elevation: 0,
                //       shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(35),
                //       ),
                //     ),
                //     child: const Text(
                //       'Check Out',
                //       style: TextStyle(
                //         fontSize: 24,
                //         fontWeight: FontWeight.w600,
                //       ),
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ),
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
      backgroundColor: const Color(0xFFF5F5F5),
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
              color: Colors.grey[600],
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
