import 'package:face_time_keeping/common/utils/widgets/spacing.dart';
import 'package:flutter/material.dart';
import '../../resources/index.dart';
import 'flex_item.dart';

class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    Key? key,
    this.title,
    this.description1,
    this.description2,
    this.acceptText,
    this.cancelText,
    this.titleWidget,
    this.acceptColor,
    required this.onYes,
    this.onCancel,
    this.icon,
    this.showClose = true,
  }) : super(key: key);

  final String? cancelText;
  final String? acceptText;
  final String? title;
  final String? description1;
  final String? description2;
  final Widget? titleWidget;
  final Function()? onYes;
  final Function()? onCancel;
  final Color? acceptColor;
  final Widget? icon;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: Center(
        child: Container(
          decoration: BoxDecoration(
              color: AppColors.white, borderRadius: BorderRadius.circular(15)),
          padding: const EdgeInsets.all(18),
          margin: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              titleWidget ??
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            icon ??
                                AssetImages.icInfoFill.toSvg(
                                    color: AppColors.blue,
                                    width: 20,
                                    height: 20),
                            const TitleSpacing(),
                            Text(
                              title ?? Strings.localized.confirmation,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 20,
                                color: AppColors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showClose)
                        InkWell(
                          onTap: () => _onBack(context),
                          child: AssetImages.icClose2
                              .toSvg(color: AppColors.black),
                        )
                    ],
                  ),
              if ((description1 ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    description1 ?? '',
                    style:
                        const TextStyle(fontSize: 14, color: AppColors.black),
                  ),
                ),
              if ((description2 ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    description2 ?? '',
                    style:
                        const TextStyle(fontSize: 14, color: AppColors.gray200),
                  ),
                ),
              const SizedBox(height: 16),
              RowFlex(
                children: <Widget>[
                  if (onCancel != null)
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => _onCancel(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gray,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(cancelText ?? 'No',
                            style: TextStyles.blackSmallSemiBold),
                      ),
                    ),
                  if (onYes != null)
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => _onYes(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              acceptColor ?? AppColors.primaryColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                        ),
                        child: Text(acceptText ?? 'Yes',
                            style: TextStyles.whiteSmallSemiBold),
                      ),
                    ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _onBack(BuildContext context) {
    Navigator.pop(context);
    onCancel?.call();
  }

  void _onCancel(BuildContext context) {
    Navigator.pop(context);
    onCancel?.call();
  }

  void _onYes(BuildContext context) {
    Navigator.pop(context);
    onYes?.call();
  }
}

void showConfirmDialog(
  BuildContext context, {
  String? cancelText,
  String? acceptText,
  String? title,
  String? description1,
  String? description2,
  Widget? titleWidget,
  Color? acceptColor,
  Widget? icon,
  bool showClose = true,
  Function()? onYes,
  Function()? onCancel,
}) {
  showDialog<dynamic>(
    context: context,
    builder: (BuildContext context) => ConfirmDialog(
      cancelText: cancelText,
      acceptText: acceptText,
      acceptColor: acceptColor,
      title: title,
      description1: description1,
      description2: description2,
      titleWidget: titleWidget,
      showClose: showClose,
      icon: icon,
      onYes: onYes,
      onCancel: onCancel,
    ),
  );
}
