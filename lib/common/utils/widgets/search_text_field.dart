import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';

import '../../resources/index.dart';

class SearchTextField extends StatefulWidget {
  const SearchTextField({
    Key? key,
    this.hintText,
    this.onChanged,
    this.prefixIcon,
    this.initializedValue,
    this.filled,
    this.filledColor,
    this.enable = true,
    this.onTapped,
    this.suffixIcon,
    this.suffixWidth,
    this.suffixHeight,
    this.controller,
    this.readOnly = false,
    this.onFieldSubmitted,
    this.textInputAction = TextInputAction.search,
  }) : super(key: key);

  final String? initializedValue;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;
  final bool? filled;
  final Color? filledColor;
  final bool enable;
  final Function()? onTapped;
  final Widget? suffixIcon;
  final double? suffixWidth;
  final double? suffixHeight;
  final TextEditingController? controller;
  final bool readOnly;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction textInputAction;

  @override
  State<SearchTextField> createState() => _SearchTextFieldState();
}

class _SearchTextFieldState extends State<SearchTextField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController(text: widget.initializedValue);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      enabled: widget.enable,
      onTap: widget.onTapped,
      readOnly: widget.readOnly,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: TextStyles.greySmallRegular,
        prefixIcon: widget.prefixIcon,
        filled: widget.filled,
        fillColor: widget.filledColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIconConstraints: const BoxConstraints(minHeight: 24, minWidth: 35),
        suffixIconConstraints: BoxConstraints(minHeight: 24, minWidth: widget.suffixWidth ?? 35),
        suffixIcon: widget.suffixIcon,
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primaryColor),
          borderRadius: BorderRadius.circular(6),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: widget.filledColor ?? AppColors.gray200, width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        disabledBorder: !(widget.filled ?? false)
            ? null
            : OutlineInputBorder(
          borderSide: BorderSide(color: widget.filledColor ?? AppColors.transparent),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onChanged: _onChange,
    );
  }

  void _onChange(String text) {
    EasyDebounce.debounce('search-widget-debounce', const Duration(milliseconds: 500), () {
      widget.onChanged?.call(text);
    });
  }

}
