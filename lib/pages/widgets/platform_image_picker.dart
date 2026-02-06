import 'dart:developer';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../common/resources/index.dart';
import '../../common/utils/widgets/spacing.dart';


// ignore_for_file: always_specify_types
// ignore: avoid_classes_with_only_static_members
class PlatformImagePicker {
  static Future<XFile?> show(BuildContext context, {String? fileId}) async {
    final ImageSource? imageSource = await _showImageSourceActionSheet(context, fileId);
    final ImagePicker picker = ImagePicker();
    try {
      if (imageSource != null) {
        return picker.pickImage(source: imageSource, imageQuality: 100);
      } else {
        return null;
      }
    } on Exception catch (e) {
      log(e.toString());
      return null;
    }
  }

  static Future<ImageSource?> _showImageSourceActionSheet(
      BuildContext context, String? fileId) async {
    return showModalBottomSheet<ImageSource>(
      useSafeArea: true,
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: AppColors.black),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        child: Wrap(
          children: <Widget>[
            ListTile(
              // leading: const Icon(Icons.camera_alt),
              title: Text('Mở camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              // leading: const Icon(Icons.photo_album),
              title: Text('Thư viện ảnh'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const Spacing()
          ],
        ),
      ),
    );
  }
}
