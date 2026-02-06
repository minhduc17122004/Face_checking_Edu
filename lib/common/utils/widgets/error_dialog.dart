import 'package:flutter/material.dart';
import '../../resources/index.dart';
import 'flex_item.dart';
import 'spacing.dart';

class ErrorDialog extends StatelessWidget {
  const ErrorDialog({
    Key? key,
    this.title,
    this.description1,
    this.description2,
    this.acceptText,
    this.titleWidget,
  }) : super(key: key);

  final String? acceptText;
  final String? title;
  final String? description1;
  final String? description2;
  final Widget? titleWidget;

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
                            AssetImages.icAlert
                                .toSvg(color: AppColors.red200, width: 20, height: 20),
                            const TitleSpacing(),
                            Text(
                              title ?? Strings.localized.error,
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
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _onYes(context),
                      style:
                      ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, elevation: 0),
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
  }

  void _onYes(BuildContext context) {
    Navigator.pop(context);
  }
}

void showErrorDialog(
    BuildContext context, {
      String? acceptText,
      String? title,
      String? description1,
      String? description2,
      Widget? titleWidget,
    }) {
  showDialog<dynamic>(
    context: context,
    builder: (BuildContext context) => ErrorDialog(
      acceptText: acceptText,
      title: title,
      description1: description1,
      description2: description2,
      titleWidget: titleWidget,
    ),
  );
}
