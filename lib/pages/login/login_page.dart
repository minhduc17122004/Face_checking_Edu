import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/utils/alerts.dart';
import 'package:face_time_keeping/common/utils/validator/validator.dart';
import 'package:face_time_keeping/common/utils/widgets/app_text_field.dart';
import 'package:face_time_keeping/common/utils/widgets/loading_indicator.dart';
import 'package:face_time_keeping/common/utils/widgets/password_field.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/pages/login/bloc/login_bloc.dart';
import 'package:face_time_keeping/pages/login/bloc/login_state.dart';
import 'package:face_time_keeping/route/app_route.dart';
import 'package:face_time_keeping/route/navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/resources/index.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _databaseController = TextEditingController();
  final LoginBloc _bloc = getIt();
  final GlobalKey<FormState> _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Khởi tạo mặc định admin
    _fillDemoAccount('admin@test.com', 'admin123');
  }

  void _fillDemoAccount(String username, String password) {
    _usernameController.text = username;
    _passwordController.text = password;
    _bloc.onChangeUsername(username);
    _bloc.onChangePass(password);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _databaseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LoginBloc>(
      create: (_) => _bloc,
      child: BlocConsumer<LoginBloc, LoginState>(
        listener: (_, state) {
          switch (state.requestStatus) {
            case RequestStatus.initial:
              break;
            case RequestStatus.requesting:
              IgnoreLoadingIndicator().show(context);
              break;
            case RequestStatus.success:
              IgnoreLoadingIndicator().hide(context);
              AppNavigator.pushNamedAndRemoveUntil(
                  RouterName.home, (_) => false);
              break;
            case RequestStatus.failed:
              IgnoreLoadingIndicator().hide(context);
              if (state.message?.isNotEmpty ?? false) {
                showTopAlert(context,
                    title: state.message, type: AlertType.error);
              }
              break;
          }
        },
        builder: (_, state) => Scaffold(
          backgroundColor: AppColors.backgroundLight,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 24,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _key,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Logo Section ──
                        Padding(
                          padding: const EdgeInsets.only(top: 48, bottom: 16),
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.school,
                                  size: 36,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Vedura',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── Hero Image ──
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              height: 160,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    'https://lh3.googleusercontent.com/aida-public/AB6AXuDAmMV-Xcmb97rxzqnXDHY8oOMshIZhl5Y1QxrJfu5x4NS_hxggDxVwwA8j2z1-6X-Rc7yADWEBrMw_W2xBKK20w4j0cHN3-N3J3KQ8CIR-T3famtci1GJSTUFRj763wI7Q9C5df1_i1NAIzslfWbkPaVzV3NBLkhfLY7qsJULwGY2tPgKH7QJqeGV0YkFmNf8DWk823ZFVzHPf6-0TDRX62GTw9HoEdwpPhgUjwTxl05MC_yVnP9_ufD65exKj1QlKDzVonqa4F-Q',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.image,
                                          size: 48, color: Colors.grey),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          AppColors.primary.withOpacity(0.25),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Login Form ──
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Student ID label
                              const Padding(
                                padding: EdgeInsets.only(left: 4, bottom: 6),
                                child: Text(
                                  'Email',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                              AppTextField(
                                controller: _usernameController,
                                validator: Validator.nullOrEmptyValidation,
                                hintText: 'Enter your ID',
                                onChanged: (value) =>
                                    _bloc.onChangeUsername(value),
                                background: const Color(0xFFF8FAFC),
                                outlinedColor: const Color(0xFFE2E8F0),
                                prefixIcon: Icon(
                                  Icons.badge_outlined,
                                  size: 20,
                                  color: Colors.grey[400],
                                ),
                                inputContextPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Password label
                              const Padding(
                                padding: EdgeInsets.only(left: 4, bottom: 6),
                                child: Text(
                                  'Mật khẩu',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                              PasswordField(
                                controller: _passwordController,
                                validatePass: true,
                                onChanged: (value) => _bloc.onChangePass(value),
                              ),
                              const SizedBox(height: 6),

                              // Forgot Password
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    // TODO: Implement forgot password
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Quên mật khẩu?',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // ── Primary Login Button ──
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: () => onSubmit(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 4,
                                    shadowColor:
                                        AppColors.primary.withOpacity(0.3),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Đăng nhập',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void onSubmit() {
    if (_key.currentState?.validate() ?? false) {
      _bloc.onLogin();
    }
  }

  // void _showSyncStudentsDialog() {
  // showDialog(
  // context: context,
  // barrierDismissible: false,
  // builder: (BuildContext dialogContext) {
  // return BlocProvider.value(
  // value: _bloc,
  // child: BlocBuilder<LoginBloc, LoginState>(
  // builder: (context, state) {
  // return AlertDialog(
  // shape: RoundedRectangleBorder(
  // borderRadius: BorderRadius.circular(16),
  // ),
  // title: Row(
  // children: [
  // Container(
  // padding: const EdgeInsets.all(8),
  // decoration: BoxDecoration(
  // color: AppColors.blue.withOpacity(0.1),
  // borderRadius: BorderRadius.circular(8),
  // ),
  // child: const Icon(
  // Icons.cloud_upload,
  // color: AppColors.blue,
  // size: 24,
  // ),
  // ),
  // const SizedBox(width: 12),
  // const Expanded(
  // child: Text(
  // 'Đồng bộ dữ liệu học sinh',
  // style: TextStyle(
  // fontSize: 18,
  // fontWeight: FontWeight.bold,
  // ),
  // ),
  // ),
  // ],
  // ),
  // content: Column(
  // mainAxisSize: MainAxisSize.min,
  // crossAxisAlignment: CrossAxisAlignment.start,
  // children: [
  // const Text(
  // 'Có dữ liệu học sinh chưa được đồng bộ lên server.',
  // style: TextStyle(fontSize: 15),
  // ),
  // const SizedBox(height: 12),
  // Container(
  // padding: const EdgeInsets.all(12),
  // decoration: BoxDecoration(
  // color: AppColors.yellow.withOpacity(0.1),
  // borderRadius: BorderRadius.circular(8),
  // border: Border.all(
  // color: AppColors.yellow.withOpacity(0.3),
  // ),
  // ),
  // child: const Row(
  // children: [
  // Icon(
  // Icons.info_outline,
  // color: AppColors.orange,
  // size: 20,
  // ),
  // SizedBox(width: 8),
  // Expanded(
  // child: Text(
  // 'Bạn có muốn đồng bộ ngay bây giờ không?',
  // style: TextStyle(
  // fontSize: 14,
  // color: AppColors.orange,
  // ),
  // ),
  // ),
  // ],
  // ),
  // ),
  // ],
  // ),
  // actions: [
  // TextButton(
  // onPressed: () {
  // Navigator.of(dialogContext).pop();
  // AppNavigator.pushNamedAndRemoveUntil(
  // RouterName.home, (_) => false);
  // },
  // style: TextButton.styleFrom(
  // foregroundColor: AppColors.gray200,
  // ),
  // child: const Text('Để sau'),
  // ),
  // ElevatedButton(
  // onPressed: () async {
  // await _bloc.syncLocalStudentsToServer();
  // AppNavigator.pushNamedAndRemoveUntil(
  // RouterName.home, (_) => false);
  // },
  // style: ElevatedButton.styleFrom(
  // backgroundColor: AppColors.blue,
  // foregroundColor: Colors.white,
  // shape: RoundedRectangleBorder(
  // borderRadius: BorderRadius.circular(8),
  // ),
  // ),
  // child: const Text('Đồng bộ ngay'),
  // ),
  // ],
  // );
  // },
  // ),
  // );
  // },
  // );
  // }
}
