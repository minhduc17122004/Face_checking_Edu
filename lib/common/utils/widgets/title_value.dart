import 'package:flutter/material.dart';

import '../../resources/index.dart';

class TitleValue extends StatefulWidget {
  const TitleValue({
    Key? key,
    required this.title,
    this.value,
    this.valueStyle
  }) : super(key: key);

  final String title;
  final String? value;
  final TextStyle? valueStyle;

  @override
  _TitleValueState createState() => _TitleValueState();
}

class _TitleValueState extends State<TitleValue> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(widget.title, style: TextStyles.blackSmallSemiBold),
          ),
          Text(widget.value ?? '', style: TextStyles.greySmallRegular)
      ],
    );
  }
}
