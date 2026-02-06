import 'package:flutter/material.dart';

import '../../resources/index.dart';
import 'spacing.dart';

class DetailOption<K> {
  DetailOption({
    required this.key,
    required this.title,
    this.icon,
    this.color = AppColors.black,
  });

  final K key;
  final String title;
  final Widget? icon;
  final Color color;
}

class TaskEditOptionsModal<K> extends StatelessWidget {
  const TaskEditOptionsModal({
    Key? key,
    required this.onPress,
    required this.options,
    this.currentOption,
    this.onReset,
    this.title,
  }) : super(key: key);

  final List<DetailOption<K>> options;
  final Function(BuildContext, DetailOption<K>) onPress;
  final K? currentOption;
  final Function()? onReset;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (onReset != null)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onReset?.call();
                      },
                      child: Text(
                        Strings.localized.reset,
                        style: TextStyles.blackNormalSemiBold,
                      ),
                    )
                  else
                    const SizedBox(),
                  if (title != null)
                    Text(
                      title!,
                      style: TextStyles.blackNormalSemiBold,
                    ),
                  Align(
                    alignment: Alignment.topRight,
                    child: Material(
                      color: AppColors.transparent,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => _onClosePressed(context),
                      ),
                    ),
                  ),
                ],
              ),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ...options.map((DetailOption<K> option) {
                      return Material(
                        color: AppColors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            onPress(context, option);
                          },
                          child: Ink(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                                color: option.key == currentOption
                                    ? AppColors.gray
                                    : AppColors.transparent),
                            child: Row(
                              children: <Widget>[
                                if (option.icon != null) option.icon!,
                                const Spacing(),
                                Text(
                                  option.title,
                                  style:
                                      TextStyles.blackSmallMedium.copyWith(color: option.color),
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
