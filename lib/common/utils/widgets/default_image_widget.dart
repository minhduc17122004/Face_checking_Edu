// ignore_for_file: constant_identifier_names

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:face_time_keeping/data/local/keychain/shared_prefs_key.dart';
import 'package:flutter/material.dart';

import '../../../configs/build_config.dart';
import '../../../data/local/keychain/shared_prefs.dart';
import '../../../di/injection.dart';
import '../../resources/index.dart';

const int ImageLiveNum = 15;

class DefaultImageWidget extends StatelessWidget {
  const DefaultImageWidget(
    this.image, {
    Key? key,
    this.width,
    this.height,
    this.fit,
    this.radius,
    this.borderColor,
    this.defaultImage,
  }) : super(key: key);

  final String? image;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final double? radius;
  final Color? borderColor;
  final Widget? defaultImage;

  @override
  Widget build(BuildContext context) {
    _checkMemory();
    double? sizeRatio = width;
    if ((height != null) && ((height ?? 0) < (width ?? 0))) {
      sizeRatio = height;
    }
    final double? cacheWidth = width == sizeRatio ? sizeRatio : null;
    final double? cacheHeight = width != null ? null : sizeRatio;

    if ((image ?? '').isEmpty) {
      return Image.asset(
        AssetImages.imgDefault,
        width: width,
        height: height,
        fit: fit ?? BoxFit.cover,
      );
    }
    final sessionId =
        getIt<SharedPrefs>().get<String>(SharedPrefsKey.savedCookied);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius ?? 0),
        border: Border.all(
          color: borderColor ?? AppColors.transparent,
          width: borderColor != null ? 1 : 0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius ?? 0),
        child: CachedNetworkImage(
          imageUrl: _getImagePath(image ?? ''),
          width: width,
          height: height,
          fit: fit ?? BoxFit.cover,
          memCacheWidth: cacheWidth?.toInt(),
          memCacheHeight: cacheHeight?.toInt(),
          httpHeaders: {
            'Cookie': 'session_id=$sessionId;',
          },
          placeholder: (_, __) => Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  AssetImages.imgDefault,
                  width: width,
                  height: height,
                  fit: fit ?? BoxFit.cover,
                ),
              ),
              const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 1,
                  color: AppColors.primaryColor,
                ),
              )
            ],
          ),
          errorWidget: (_, __, dynamic error) => Image.file(
            File(image ?? ''),
            width: width,
            height: height,
            fit: fit ?? BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                defaultImage ??
                Image.asset(
                  AssetImages.imgDefault,
                  width: width,
                  height: height,
                  fit: fit ?? BoxFit.cover,
                ),
          ),
        ),
      ),
    );
  }

  void _checkMemory() {
    final ImageCache imageCache = PaintingBinding.instance.imageCache;
    if ((imageCache.liveImageCount) >= ImageLiveNum) {
      imageCache.clear();
      imageCache.clearLiveImages();
    }
  }

  String _getImagePath(String path) {
    final BuildConfig config = getIt<BuildConfig>();
    if (!path.contains('http')) {
      return config.kBaseImageUrl + path;
    }
    return path;
  }
}
