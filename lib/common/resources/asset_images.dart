import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AssetImages {
  static const String videoSplash = 'assets/images/gif/vi_splash.gif';
  static const String imgDefault = 'assets/images/img_default.png';
  static const String icBack = 'assets/images/svg/ic_back.svg';
  static const String icEyeOff = 'assets/images/svg/ic_eye_off.svg';
  static const String icEye = 'assets/images/svg/ic_eye.svg';
  static const String icInfoFill = 'assets/images/svg/ic_info_fill.svg';
  static const String icInfo = 'assets/images/svg/ic_info.svg';
  static const String icChecked = 'assets/images/svg/ic_checked.svg';
  static const String icSearch = 'assets/images/svg/ic_search.svg';
  static const String icClose2 = 'assets/images/svg/ic_close_2.svg';
  static const String icAlert = 'assets/images/svg/ic_alert.svg';
  static const String icWarning = 'assets/images/svg/ic_warning.svg';
  static const String icInfoError = 'assets/images/svg/ic_info_error.svg';
  static const String icCheckFill = 'assets/images/svg/ic_check_fill.svg';
  static const String icIds = 'assets/images/svg/ic_ids.svg';
  static const String imgHomeBackground =
      'assets/images/png/img_home_background.png';
  static const String imgUltraMaText = 'assets/images/svg/img_ultra_ma.svg';
  static const String icPlay = 'assets/images/svg/ic_play.svg';
  static const String icClose = 'assets/images/svg/ic_close.svg';
  static const String icMusic = 'assets/images/svg/ic_music.svg';
  static const String icMode = 'assets/images/svg/ic_mode.svg';
  static const String icHome = 'assets/images/svg/ic_home.svg';
  static const String icTime = 'assets/images/svg/ic_time.svg';
  static const String icClock = 'assets/images/svg/ic_clock.svg';
  static const String icClock2 = 'assets/images/svg/ic_clock2.svg';
  static const String icSignal = 'assets/images/svg/ic_signal.svg';
  static const String icHistoryPlay = 'assets/images/svg/ic_history_play.svg';
  static const String icHistoryPause = 'assets/images/svg/ic_history_pause.svg';
  static const String imgUltraMaDevice = 'assets/images/png/img_ultrama.png';
  static const String imgSplash = 'assets/images/png/img_splash.png';
}

extension ConvertToImage on String {
  Widget toSvg({
    BuildContext? context,
    double width = 24,
    double? height,
    double padding = 0,
    Color? color,
    BoxFit fit = BoxFit.contain,
  }) {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: SvgPicture.asset(
        this,
        width: width,
        height: height ?? width,
        color: color,
        cacheColorFilter: true,
        fit: fit,
      ),
    );
  }

  AssetImage toImage({
    double width = 24,
    double? height,
  }) {
    return AssetImage(this);
  }
}
