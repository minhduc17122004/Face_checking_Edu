import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/common/utils/alerts.dart';
import 'package:face_time_keeping/pages/login_odoo/bloc/login_odoo_bloc.dart';
import 'package:face_time_keeping/route/navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/utils/validator/validator.dart';
import '../../common/utils/widgets/app_text_field.dart';
import '../../common/utils/widgets/password_field.dart';
import '../../di/injection.dart';
import 'bloc/login_odoo_state.dart';

class LoginConfirmWidget extends StatefulWidget {
  const LoginConfirmWidget({super.key});

  @override
  State<LoginConfirmWidget> createState() => _LoginConfirmWidgetState();
}

class _LoginConfirmWidgetState extends State<LoginConfirmWidget> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final LoginOdooBloc _bloc = getIt();
  final GlobalKey<FormState> _key = GlobalKey();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
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
              break;
            case RequestStatus.success:
              AppNavigator.pop(true);
              break;
            case RequestStatus.failed:
              if (state.message?.isNotEmpty ?? false) {
                showTopAlert(context,
                    title: state.message, type: AlertType.error);
              }
              break;
          }
        },
        builder: (_, state) => Scaffold(
          backgroundColor: Colors.white,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _key,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () {
                        AppNavigator.pop();
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  // Username TextField
                  AppTextField(
                    controller: _usernameController,
                    validator: Validator.nullOrEmptyValidation,
                    hintText: 'Admin username',
                    onChanged: (value) => _bloc.onChangeUsername(value),
                  ),
                  const SizedBox(height: 16),
                  // Password TextField
                  PasswordField(
                    controller: _passwordController,
                    validatePass: true,
                    onChanged: (value) => _bloc.onChangePass(value),
                    placeHolder: 'Mật khẩu',
                  ),
                  const SizedBox(height: 24),
                  // Login Button
                  if (state.requestStatus == RequestStatus.requesting)
                    const CircularProgressIndicator()
                  else
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
    );
  }

  void onSubmit() {
    if (_key.currentState?.validate() ?? false) {
      _bloc.onLogin();
    }
  }
}
