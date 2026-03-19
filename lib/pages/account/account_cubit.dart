import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:face_time_keeping/common/api_client/api_client.dart';
import 'package:face_time_keeping/common/event/event_bus_event.dart';
import 'package:face_time_keeping/common/event/event_bus_mixin.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/data/remote/api_endpoint.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'account_state.dart';

@injectable
class AccountCubit extends Cubit<AccountState> with EventBusMixin {
  AccountCubit(this._localService, this._apiClient)
      : super(const AccountState());

  final LocalService _localService;
  final ApiClient _apiClient;

  void loadUserProfile() {
    final fullName = _localService.getUserFullName().trim();
    final email = _localService.getUserEmail().trim();
    final avatarPath = _localService.getAvatarPath();

    final fallbackName =
        email.isNotEmpty ? email.split('@').first : 'Nguoi dung';
    emit(
      state.copyWith(
        displayName: fullName.isNotEmpty ? fullName : fallbackName,
        displayEmail: email.isNotEmpty ? email : 'user@example.com',
        avatarPath: avatarPath,
      ),
    );
  }

  Future<void> updateAvatar(String pickedPath) async {
    emit(
      state.copyWith(
        isUploadingAvatar: true,
        avatarUpdateStatus: AccountAvatarUpdateStatus.initial,
      ),
    );

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final avatarDir = Directory(p.join(appDir.path, 'avatars'));
      if (!avatarDir.existsSync()) {
        avatarDir.createSync(recursive: true);
      }

      final ext =
          p.extension(pickedPath).isNotEmpty ? p.extension(pickedPath) : '.jpg';
      _deletePreviousLocalAvatarIfNeeded(state.avatarPath);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeEmail =
          state.displayEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final savedFile =
          File(p.join(avatarDir.path, 'avatar_${safeEmail}_$timestamp$ext'));
      await File(pickedPath).copy(savedFile.path);

      var newAvatarPath = savedFile.path;
      var backendSuccess = false;

      try {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            savedFile.path,
            filename: 'avatar$ext',
          ),
        });

        final response = await _apiClient.dio.post(
          ApiEndpoint.uploadUserAvatar,
          data: formData,
          options: Options(
            contentType: 'multipart/form-data',
            sendTimeout: 120000,
            receiveTimeout: 120000,
          ),
        );

        backendSuccess = response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300;

        if (backendSuccess &&
            response.data != null &&
            response.data['avatar_url'] != null) {
          final baseUrl = _apiClient.dio.options.baseUrl;
          var urlSuffix = response.data['avatar_url'] as String;
          if (baseUrl.endsWith('/') && urlSuffix.startsWith('/')) {
            urlSuffix = urlSuffix.substring(1);
          }
          newAvatarPath = (baseUrl.endsWith('/') ? baseUrl : '$baseUrl/') +
              (urlSuffix.startsWith('/') ? urlSuffix.substring(1) : urlSuffix);
        }
      } catch (_) {
        // Local avatar is preserved when upload fails.
      }

      _localService.saveAvatarPath(newAvatarPath);
      shareEvent(AvatarChangedEvent(avatarPath: newAvatarPath));
      emit(
        state.copyWith(
          avatarPath: newAvatarPath,
          isUploadingAvatar: false,
          avatarUpdateStatus: AccountAvatarUpdateStatus.success,
          backendSynced: backendSuccess,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isUploadingAvatar: false,
          avatarUpdateStatus: AccountAvatarUpdateStatus.failure,
        ),
      );
    }
  }

  void resetAvatarStatus() {
    emit(state.copyWith(avatarUpdateStatus: AccountAvatarUpdateStatus.initial));
  }

  void _deletePreviousLocalAvatarIfNeeded(String avatarPath) {
    if (avatarPath.isEmpty || _isNetworkAvatar(avatarPath)) {
      return;
    }

    final oldFile = File(avatarPath);
    if (!oldFile.existsSync()) {
      return;
    }

    try {
      oldFile.deleteSync();
    } catch (_) {
      // Ignore delete errors for stale avatar files.
    }
  }

  bool _isNetworkAvatar(String avatarPath) {
    return avatarPath.startsWith('http://') ||
        avatarPath.startsWith('https://');
  }
}
