import 'package:flutter/material.dart';

class RowFlex extends StatelessWidget {
  const RowFlex({
    Key? key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.textBaseline,
    this.spacing = 16.0,
    this.flexItems = const <int>[],
  }) : super(key: key);

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final TextBaseline? textBaseline;
  final double spacing;
  final List<int> flexItems;

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = <Widget>[];
    children.asMap().forEach((int index, Widget value) {
      items.add(Expanded(
        flex: index < flexItems.length ? flexItems[index] : 1,
        child: value,
      ));
      if (index < children.length - 1) {
        items.add(SizedBox(width: spacing));
      }
    });
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      textBaseline: textBaseline,
      children: items,
    );
  }
}

class ColumnFlex extends StatelessWidget {
  const ColumnFlex({
    Key? key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.spacing = 16.0,
    this.flexItems = const <int>[],
  }) : super(key: key);

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;
  final List<int> flexItems;

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = <Widget>[];
    children.asMap().forEach((int index, Widget value) {
      items.add(Expanded(
        flex: index < flexItems.length ? flexItems[index] : 1,
        child: value,
      ));
      if (index < children.length - 1) {
        items.add(SizedBox(width: spacing));
      }
    });
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: items,
    );
  }
}
