import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keyboard_actions/keyboard_actions.dart';

import '../../resources/index.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    Key? key,
    this.secure = false,
    this.onChanged,
    this.validator,
    this.initialValue,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines,
    this.maxLength,
    this.suffixIcon,
    this.prefixIcon,
    this.onTap,
    this.onSaved,
    this.controller,
    this.readOnly = false,
    this.autocorrect = true,
    this.enable = true,
    this.background,
    this.textInputAction,
    this.style,
    this.onUnFocus,
    this.textAlign,
    this.minPrefixWidth,
    this.minSuffixWidth,
    this.suffixText,
    this.enableAutoClear = true,
    this.inputContextPadding,
    this.outlinedColor,
    this.autofillHints,
    this.enableSuggestions = true,
  }) : super(key: key);

  final bool secure;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final String? initialValue;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? maxLength;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final GestureTapCallback? onTap;
  final FormFieldSetter<String>? onSaved;
  final TextEditingController? controller;
  final bool readOnly;
  final bool autocorrect;
  final bool enable;
  final Color? background;
  final TextInputAction? textInputAction;
  final TextStyle? style;
  final Function()? onUnFocus;
  final TextAlign? textAlign;
  final double? minPrefixWidth;
  final double? minSuffixWidth;
  final String? suffixText;
  final bool enableAutoClear;
  final EdgeInsetsGeometry? inputContextPadding;
  final Color? outlinedColor;
  final Iterable<String>? autofillHints;
  final bool enableSuggestions;

  @override
  _AppTextFieldState createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final FocusNode _focusNode = FocusNode();
  TextEditingController? _defaultController;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _defaultController = TextEditingController()..text = widget.initialValue ?? '';
    }
    if ((widget.initialValue?.isNotEmpty ?? false) &&
        widget.controller != null &&
        (widget.controller?.text.isEmpty ?? true)) {
      widget.controller!.text = widget.initialValue!;
    }

    Future.delayed(Duration.zero, () {
      _focusNode.addListener(() {
        if (!_focusNode.hasFocus) {
          widget.onUnFocus?.call();
        } else if ((widget.controller ?? _defaultController)?.text == '0' &&
            widget.enableAutoClear) {
          (widget.controller ?? _defaultController)?.clear();
        }
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _focusNode.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return IntrinsicHeight(
        child: KeyboardActions(
          disableScroll: true,
          config: _buildConfig(context),
          child: _buildTextFormField(),
        ),
      );
    }

    return _buildTextFormField();
  }

  Widget _buildTextFormField() {
    double scrollPadding = 100.0;
    // if (widget.keyboardType == TextInputType.number ||
    //     widget.keyboardType == TextInputType.phone ||
    //     widget.keyboardType == const TextInputType.numberWithOptions(decimal: true)) {
    //   scrollPadding = 100.0;
    // }

    return Theme(
      data: ThemeData(
          inputDecorationTheme: const InputDecorationTheme(
        errorStyle: TextStyles.redExtraSmallRegular,
      )),
      child: TextFormField(
        enabled: widget.enable,
        scrollPadding: EdgeInsets.all(scrollPadding),
        keyboardAppearance: Brightness.light,
        focusNode: _focusNode,
        textInputAction: widget.textInputAction ?? TextInputAction.done,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
        autofillHints: widget.autofillHints,
        enableSuggestions: widget.enableSuggestions,
        style: widget.style,
        textAlignVertical: TextAlignVertical.bottom,
        textAlign: widget.textAlign ?? TextAlign.start,
        decoration: InputDecoration(
          errorMaxLines: 2,
          hintText: widget.hintText,
          hintStyle: const TextStyle(color: AppColors.gray200, fontStyle: FontStyle.italic),
          filled: true,
          fillColor: widget.background ?? AppColors.white,
          prefixIcon: widget.prefixIcon,
          suffixIcon: widget.suffixIcon,
          prefixIconConstraints:
              BoxConstraints(minHeight: 24, minWidth: widget.minPrefixWidth ?? 35),
          suffixIconConstraints:
              BoxConstraints(minHeight: 24, minWidth: widget.minSuffixWidth ?? 35),
          suffixText: widget.suffixText,
          contentPadding: widget.inputContextPadding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: widget.outlinedColor ?? AppColors.gray200, width: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          disabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: widget.outlinedColor ?? AppColors.gray200, width: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: widget.outlinedColor ?? AppColors.gray200, width: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: widget.outlinedColor ?? AppColors.red200, width: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: widget.outlinedColor ?? AppColors.red200, width: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        obscureText: widget.secure,
        onChanged: widget.onChanged,
        validator: widget.validator,
        onTap: widget.onTap,
        onSaved: widget.onSaved,
        controller: widget.controller ?? _defaultController,
        readOnly: widget.readOnly,
        autocorrect: widget.autocorrect,
      ),
    );
  }

  KeyboardActionsConfig _buildConfig(BuildContext context) {
    bool displayDoneButton = false;
    if (widget.keyboardType == TextInputType.number ||
        widget.keyboardType == TextInputType.phone ||
        widget.keyboardType == const TextInputType.numberWithOptions(decimal: true)) {
      displayDoneButton = true;
    }
    return KeyboardActionsConfig(
      keyboardActionsPlatform: KeyboardActionsPlatform.ALL,
      keyboardBarColor: Colors.white,
      nextFocus: false,
      actions: <KeyboardActionsItem>[
        KeyboardActionsItem(
          focusNode: _focusNode,
          displayDoneButton: displayDoneButton,
          displayArrows: false,
          displayActionBar: displayDoneButton,
        ),
      ],
    );
  }
}
