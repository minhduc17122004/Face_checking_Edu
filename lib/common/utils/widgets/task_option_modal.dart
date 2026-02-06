import 'package:flutter/material.dart';

import '../../../common/resources/index.dart';
import '../../../common/utils/widgets/spacing.dart';

class TaskOptionsModal extends StatelessWidget {
  const TaskOptionsModal({
    Key? key,
    required this.onPress,
    required this.options,
    this.enable = true,
  }) : super(key: key);

  final List<String> options;
  final Function(BuildContext, int index) onPress;
  final bool enable;

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Material(
                    color: AppColors.transparent,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _onClosePressed(context),
                    ),
                  ),
                ),
              ),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ...options.asMap().entries.map((option) {
                      return Material(
                        color: AppColors.transparent,
                        child: InkWell(
                          onTap: !enable ? null : () {
                            onPress(context, option.key);
                            Navigator.pop(context);
                          },
                          child: Ink(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              children: <Widget>[
                                const Spacing(),
                                Text(
                                  option.value,
                                  style: TextStyles.blackNormalRegular,
                                ),
                                const Spacing(),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const Spacing(),
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  void _onClosePressed(BuildContext context) {
    Navigator.pop(context);
  }
}
