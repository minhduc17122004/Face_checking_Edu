import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../common/resources/index.dart';
import '../../common/utils/widgets/spacing.dart';
import '../../data/local/local_service.dart';
import '../../di/injection.dart';
import '../widgets/default_app_bar.dart';

class PinAppPage extends StatefulWidget {
  const PinAppPage({super.key});

  @override
  State<PinAppPage> createState() => _PinAppPageState();
}

class _PinAppPageState extends State<PinAppPage> {
  late final LocalService _localService;
  
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirmMode = false;
  bool _isLoading = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    //force portrait
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _localService = getIt<LocalService>();
    _checkExistingPin();
  }
  @override
  void dispose() {
    super.dispose();
    //restore all orientations
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft,
     DeviceOrientation.portraitDown,
     ]);
  }
  Future<void> _checkExistingPin() async {
    final existingPin = await _localService.getPinApp();
    if (existingPin != null && existingPin.isNotEmpty && mounted) {
      _showPinExistsDialog();
    }
  }
  
  void _showPinExistsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Mã PIN đã tồn tại'),
        content: const Text('Bạn đã có mã PIN. Bạn có muốn thay đổi mã PIN hiện tại không?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _pin = '';
                _confirmPin = '';
                _isConfirmMode = false;
                _errorMessage = null;
              });
            },
            child: const Text('Thay đổi'),
          ),
        ],
      ),
    );
  }

  void _onNumberTap(String number) {
    if (_isLoading) return;
    
    HapticFeedback.lightImpact();
    
    setState(() {
      _errorMessage = null;
      if (_isConfirmMode) {
        if (_confirmPin.length < 6) {
          _confirmPin += number;
          if (_confirmPin.length == 6) {
            _validateAndSavePin();
          }
        }
      } else {
        if (_pin.length < 6) {
          _pin += number;
          if (_pin.length == 6) {
            _isConfirmMode = true;
          }
        }
      }
    });
  }

  void _onDeleteTap() {
    if (_isLoading) return;
    
    HapticFeedback.lightImpact();
    
    setState(() {
      _errorMessage = null;
      if (_isConfirmMode) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _isConfirmMode = false;
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  void _onClearTap() {
    if (_isLoading) return;
    
    HapticFeedback.mediumImpact();
    
    setState(() {
      _pin = '';
      _confirmPin = '';
      _isConfirmMode = false;
      _errorMessage = null;
    });
  }

  Future<void> _validateAndSavePin() async {
    if (_pin != _confirmPin) {
      setState(() {
        _errorMessage = 'Mã PIN không khớp. Vui lòng thử lại.';
        _confirmPin = '';
      });
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _localService.savePinApp(_pin);
      if (mounted) {
        HapticFeedback.heavyImpact();
        _showSuccessDialog();
      }
    } catch (e) {
      await pushLog('Error in _validateAndSavePin: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Có lỗi xảy ra khi lưu mã PIN. Vui lòng thử lại.';
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Thành công'),
        content: const Text('Mã PIN đã được thiết lập thành công!'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DefaultAppBar(
        titleText: 'Đặt mã PIN',
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacing(height: 32),
            
            // Title and instruction
            Text(
              _isConfirmMode ? 'Xác nhận mã PIN' : 'Tạo mã PIN mới',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ),
            const Spacing(height: 16),
            
            Text(
              _isConfirmMode 
                ? 'Nhập lại mã PIN để xác nhận'
                : 'Nhập 6 chữ số để tạo mã PIN bảo mật',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.gray200,
              ),
              textAlign: TextAlign.center,
            ),
            
            const Spacing(height: 48),
            
            // PIN dots display
            _PinDotsDisplay(
              pinLength: _isConfirmMode ? _confirmPin.length : _pin.length,
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
            
            const Spacer(),
            
            // PIN Keypad
            _PinKeypad(
              onNumberTap: _onNumberTap,
              onDeleteTap: _onDeleteTap,
              onClearTap: _onClearTap,
              isLoading: _isLoading,
            ),
            
            const Spacing(height: 32),
          ],
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
              boxShadow: isEnabled ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ] : null,
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
                        fontWeight: isTextButton ? FontWeight.w500 : FontWeight.w600,
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