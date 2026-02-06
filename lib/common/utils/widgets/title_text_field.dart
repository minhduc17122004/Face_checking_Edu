import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../resources/index.dart';
import 'app_text_field.dart';

class TitleTextField extends StatefulWidget {
  const TitleTextField(
      {Key? key,
      required this.title,
      this.secure = false,
      this.onChanged,
      this.validator,
      this.initialValue,
      this.hintText,
      this.keyboardType,
      this.inputFormatters,
      this.maxLines = 1,
      this.prefixIcon,
      this.suffixIcon,
      this.background,
      this.outlinedColor,
      this.onTap,
      this.onSaved,
      this.controller,
      this.readOnly = false,
      this.autocorrect = true,
      this.enable = true,
      this.mandatory = false,
      this.style,
      this.onUnFocus,
      this.minPrefixWidth,
      this.minSuffixWidth,
      this.suffixText,
      this.titleStyle,
      this.enableAutoClear = true})
      : super(key: key);

  final String title;
  final bool secure;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final String? initialValue;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Color? background;
  final Color? outlinedColor;
  final GestureTapCallback? onTap;
  final FormFieldSetter<String>? onSaved;
  final TextEditingController? controller;
  final bool readOnly;
  final bool autocorrect;
  final bool enable;
  final bool mandatory;
  final TextStyle? style;
  final Function()? onUnFocus;
  final double? minPrefixWidth;
  final double? minSuffixWidth;
  final String? suffixText;
  final TextStyle? titleStyle;
  final bool enableAutoClear;

  @override
  _TitleTextFieldState createState() => _TitleTextFieldState();
}

class _TitleTextFieldState extends State<TitleTextField> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: RichText(
              text: TextSpan(
                  text: widget.title,
                  style: widget.titleStyle ?? TextStyles.blackExtraSmallSemiBold,
                  children: <TextSpan>[
                    if (widget.mandatory)
                      const TextSpan(
                        text: ' *',
                        style: TextStyles.blackExtraSmallSemiBold,
                      )
                    else
                      const TextSpan(),
                  ]),
            ),
          ),
        AppTextField(
          style: widget.style,
          enable: widget.enable,
          keyboardType: widget.keyboardType,
          initialValue: widget.initialValue,
          inputFormatters: widget.inputFormatters,
          hintText: widget.hintText,
          secure: widget.secure,
          onChanged: widget.onChanged,
          validator: widget.validator,
          maxLines: widget.maxLines,
          prefixIcon: widget.prefixIcon,
          suffixIcon: widget.suffixIcon,
          background: widget.enable ? widget.background : AppColors.gray,
          outlinedColor: widget.enable ? widget.outlinedColor : AppColors.gray,
          onTap: widget.onTap,
          onSaved: widget.onSaved,
          controller: widget.controller,
          readOnly: widget.readOnly,
          autocorrect: widget.autocorrect,
          onUnFocus: widget.onUnFocus,
          minSuffixWidth: widget.minSuffixWidth,
          minPrefixWidth: widget.minPrefixWidth,
          suffixText: widget.suffixText,
          enableAutoClear: widget.enableAutoClear,
        ),
      ],
    );
  }
}
