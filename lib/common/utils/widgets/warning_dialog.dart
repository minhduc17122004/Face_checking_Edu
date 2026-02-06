import 'package:flutter/material.dart';
import '../../resources/index.dart';
import 'flex_item.dart';
import 'spacing.dart';

class WarningDialog extends StatelessWidget {
  const WarningDialog({
    Key? key,
    this.title,
    this.description1,
    this.description2,
    this.acceptText,
    this.titleWidget,
    this.cancelTitle,
    required this.onYes,
    this.onCancel,
    this.onClose,
  }) : super(key: key);

  final String? acceptText;
  final String? title;
  final String? description1;
  final String? description2;
  final Widget? titleWidget;
  final String? cancelTitle;
  final Function()? onCancel;
  final Function() onYes;
  final Function()? onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: Center(
        child: Container(
          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.all(18),
          margin: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              titleWidget ??
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            AssetImages.icInfoFill
                                .toSvg(color: AppColors.yellow, width: 20, height: 20),
                            const TitleSpacing(),
                            Flexible(
                              child: Text(
                                title ?? Strings.localized.warning,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 20,
                                  color: AppColors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => _onBack(context),
                        child: AssetImages.icClose2.toSvg(color: AppColors.black),
                      )
                    ],
                  ),
              if ((description1 ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    description1 ?? '',
                    style: const TextStyle(fontSize: 14, color: AppColors.black),
                  ),
                ),
              if ((description2 ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    description2 ?? '',
                    style: const TextStyle(fontSize: 14, color: AppColors.gray200),
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
                            backgroundColor: AppColors.gray200, elevation: 0),
                        child: Text(cancelTitle ?? 'Cancel', style: TextStyles.whiteSmallSemiBold),
                      ),
                    ),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _onYes(context),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor, elevation: 0),
                      child: Text(acceptText ?? 'Close', style: TextStyles.whiteSmallSemiBold),
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
    onClose?.call();
  }

  void _onYes(BuildContext context) {
    Navigator.pop(context);
    onYes();
  }

  void _onCancel(BuildContext context) {
    Navigator.pop(context);
    onCancel?.call();
  }
}

void showWarningDialog(
  BuildContext context, {
  String? acceptText,
  String? title,
  String? description1,
  String? description2,
  Widget? titleWidget,
  required Function() onYes,
  String? cancelTitle,
  Function()? onCancel,
  Function()? onClose,
  WillPopCallback? onWillPop,
}) {
  showDialog<dynamic>(
    context: context,
    builder: (BuildContext context) => WillPopScope(
      onWillPop: onWillPop,
      child: WarningDialog(
        acceptText: acceptText,
        title: title,
        description1: description1,
        description2: description2,
        titleWidget: titleWidget,
        onYes: onYes,
        cancelTitle: cancelTitle,
        onCancel: onCancel,
        onClose: onClose,
      ),
    ),
  );
}
