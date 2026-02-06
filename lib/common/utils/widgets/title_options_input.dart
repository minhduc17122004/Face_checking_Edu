import 'package:flutter/material.dart';
import '../../resources/index.dart';
import 'task_option_modal.dart';
import 'title_text_field.dart';

class TitleOptionsInput extends StatefulWidget {
  const TitleOptionsInput({
    Key? key,
    required this.title,
    required this.options,
    this.enable = true,
    this.initialValue,
    this.onChanged,
    this.controller,
    this.showOnly = false,
  }) : super(key: key);

  final String title;
  final bool enable;
  final String? initialValue;
  final ValueChanged<int>? onChanged;
  final List<String> options;
  final TextEditingController? controller;
  final bool showOnly;

  @override
  State<TitleOptionsInput> createState() => TitleOptionsInputState();
}

class TitleOptionsInputState extends State<TitleOptionsInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = widget.controller ?? TextEditingController(text: widget.initialValue);
  }

  @override
  Widget build(BuildContext context) {
    return TitleTextField(
      title: widget.title,
      enable: widget.enable,
      controller: _controller,
      readOnly: true,
      autocorrect: false,
      onTap: () => _onTapped(context),
      suffixIcon: UnconstrainedBox(
        child: Padding(
          padding: const EdgeInsets.only(right: 8.0, left: 8),
          child: Icon(
            Icons.keyboard_arrow_down,
            color: widget.enable ? AppColors.black : AppColors.gray200,
          ),
        ),
      ),
    );
  }

  void updateValue(int value) {
    _controller.text = widget.options[value];
  }

  void _onTapped(BuildContext context) {
    showModalBottomSheet<dynamic>(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return TaskOptionsModal(
          enable: !widget.showOnly,
          onPress: (BuildContext context, int index) {
            _controller.text = widget.options[index];
            widget.onChanged?.call(index);
          },
          options: widget.options,
        );
      },
    );
  }
}
