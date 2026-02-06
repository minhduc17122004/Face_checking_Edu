import 'package:flutter/material.dart';
import '../../resources/index.dart';

class Spacing extends StatelessWidget {
  const Spacing({
    Key? key,
    this.height = 16,
    this.width = 16,
  }) : super(key: key);

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height, width: width);
  }
}

class DividerDetail extends StatelessWidget {
  const DividerDetail({Key? key, this.height = 32.0, this.color,}) : super(key: key);

  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.only(top: 4.0),
        child: Divider(color: color ?? AppColors.dividerColor, height: height));
  }
}

class TitleSpacing extends StatelessWidget {
  const TitleSpacing({
    Key? key,
    this.height = 6,
    this.width = 6,
  }) : super(key: key);

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height, width: width);
  }
}
