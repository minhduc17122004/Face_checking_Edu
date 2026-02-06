import 'package:flutter/cupertino.dart';
import '../resources/index.dart';
import 'widgets/top_snack_bar.dart';

enum AlertType { success, info, warning, error }

extension AlertTypeX on AlertType {
  String get icon {
    switch (this) {
      case AlertType.success:
        return AssetImages.icCheckFill;
      case AlertType.info:
        return AssetImages.icInfo;
      case AlertType.warning:
        return AssetImages.icWarning;
      case AlertType.error:
        return AssetImages.icInfoError;
    }
  }

  Color get color {
    switch (this) {
      case AlertType.success:
        return AppColors.primaryColor;
      case AlertType.info:
        return AppColors.blue;
      case AlertType.warning:
        return AppColors.orange;
      case AlertType.error:
        return AppColors.red;
    }
  }
}

Future<void> showTopAlert(BuildContext context, {String? title, AlertType type = AlertType.info}) async {
  return showTopSnackBar(
    context,
    additionalTopPadding: 0,
    showOutAnimationDuration: const Duration(milliseconds: 1000),
    Container(
      decoration: BoxDecoration(
        color: type.color,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // ClipRRect(
          //   borderRadius: BorderRadius.circular(20),
          //   child: SizedBox(
          //     height: 40,
          //     width: 40,
          //     child: Stack(
          //       children: [
          //         Container(
          //           color: AppColors.white.withOpacity(0.3),
          //         ),
          //         // Center(
          //         //   child: type.icon.toSvg(
          //         //     height: 20,
          //         //     width: 20,
          //         //     color: AppColors.white,
          //         //   ),
          //         // )
          //       ],
          //     ),
          //   ),
          // ),
          // const Spacing(),
          Flexible(
            child: Text(
              title ?? '',
              style: TextStyles.whiteSmallRegular,
            ),
          ),
        ],
      ),
    ),
  );
}
