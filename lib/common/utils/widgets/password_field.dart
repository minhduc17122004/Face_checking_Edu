import 'package:flutter/material.dart';
import '../../resources/index.dart';
import '../validator/validator.dart';
import 'app_text_field.dart';

class PasswordField extends StatefulWidget {
  const PasswordField({
    Key? key,
    this.onChanged,
    this.initialValue,
    this.validatePass = true,
    this.placeHolder,
    this.controller,
    this.validator,
  }) : super(key: key);

  final ValueChanged<String>? onChanged;
  final String? initialValue;
  final bool validatePass;
  final String? placeHolder;
  final TextEditingController? controller;
  final String? Function(String? password)? validator;

  @override
  _PasswordFieldState createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool secure = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      maxLines: 1,
      controller: widget.controller,
      initialValue: widget.initialValue,
      hintText: widget.placeHolder ?? Strings.localized.password,
      secure: secure,
      validator: widget.validatePass
          ? (String? value) =>
              (widget.validator?.call(value) ?? Validator.passwordValidation(value))
          : null,
      onChanged: widget.onChanged,
      autofillHints: const [
        AutofillHints.password,
      ],
      suffixIcon: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: _onShowTapped,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: (secure
              ? const Icon(
                  Icons.remove_red_eye_rounded,
                  color: AppColors.gray200,
                )
              : const Icon(
                  Icons.remove_red_eye_outlined,
                  color: AppColors.gray200,
                )),
        ),
      ),
    );
  }

  void _onShowTapped() {
    setState(() {
      secure = !secure;
    });
  }
}
