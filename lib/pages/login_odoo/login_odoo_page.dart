import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/utils/alerts.dart';
import 'package:face_time_keeping/common/utils/validator/validator.dart';
import 'package:face_time_keeping/common/utils/widgets/app_text_field.dart';
import 'package:face_time_keeping/common/utils/widgets/loading_indicator.dart';
import 'package:face_time_keeping/common/utils/widgets/password_field.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/pages/login_odoo/bloc/login_odoo_bloc.dart';
import 'package:face_time_keeping/pages/login_odoo/bloc/login_odoo_state.dart';
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
  final LoginOdooBloc _bloc = getIt();
  final GlobalKey<FormState> _key = GlobalKey();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _databaseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LoginOdooBloc>(
      create: (_) => _bloc,
      child: BlocConsumer<LoginOdooBloc, LoginOdooState>(
        listener: (_, state) {
          switch (state.requestStatus) {
            case RequestStatus.initial:
              break;
            case RequestStatus.requesting:
              IgnoreLoadingIndicator().show(context);
              break;
            case RequestStatus.success:
              IgnoreLoadingIndicator().hide(context);
              _showSyncEmployeesDialog();
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
          //     floatingActionButton: FloatingActionButton(
          //   onPressed: () {
          //     Navigator.push(context, MaterialPageRoute(builder: (context) => const TestPage()));
          //   },
          //   child: const Icon(Icons.file_present),
          // ),
          backgroundColor: Colors.white,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _key,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // User Avatar
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.blue[300],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Username TextField
                    AppTextField(
                      controller: _usernameController,
                      validator: Validator.nullOrEmptyValidation,
                      hintText: 'Username',
                      onChanged: (value) => _bloc.onChangeUsername(value),
                    ),
                    const SizedBox(height: 16),
                    // Password TextField

                    PasswordField(
                      controller: _passwordController,
                      validatePass: true,
                      onChanged: (value) => _bloc.onChangePass(value),
                    ),
                    const SizedBox(height: 24),
                    // Login Button
                    ElevatedButton(
                      onPressed: () => onSubmit(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.black,
                        minimumSize: const Size(200, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Đăng nhập',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
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

  void _showSyncEmployeesDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return BlocProvider.value(
          value: _bloc,
          child: BlocBuilder<LoginOdooBloc, LoginOdooState>(
            builder: (context, state) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.cloud_upload,
                        color: AppColors.blue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Đồng bộ dữ liệu học sinh',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Có dữ liệu học sinh chưa được đồng bộ lên server.',
                      style: TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.yellow.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.yellow.withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.orange,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Bạn có muốn đồng bộ ngay bây giờ không?',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      AppNavigator.pushNamedAndRemoveUntil(
                          RouterName.home, (_) => false);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.gray200,
                    ),
                    child: const Text('Để sau'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _bloc.syncLocalEmployeesToServer();
                      AppNavigator.pushNamedAndRemoveUntil(
                          RouterName.home, (_) => false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Đồng bộ ngay'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
