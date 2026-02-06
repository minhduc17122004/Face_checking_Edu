import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/data/remote/authentication_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../configs/build_config.dart';
import '../../../data/local/local_service.dart';
import '../../../di/injection.dart';
import 'domain_state.dart';

@injectable
class DomainBloc extends Cubit<DomainState> {
  DomainBloc(
    this._localService,
  ) : super(const DomainState());

  final LocalService _localService;
  final BuildConfig buildConfig = getIt<BuildConfig>();
  final AuthenticationService _authenticationService =
      getIt<AuthenticationService>();

  @override
  void emit(DomainState state) {
    if (isClosed) {
      return;
    }
    super.emit(state);
  }

  void onChangedDomain(String domain) {
    emit(state.copyWith(domain: domain, message: ''));
  }

  void _saveDomain(String domain) {
    final newDomain = domain.replaceAll('https://', '');
    String url = "https://$newDomain";
    if (newDomain.isNotEmpty) {
      _localService.saveOdooDomain(url);
      _localService.clearOdooDomainRelatedData();
      buildConfig.setBaseUrl(url);
      emit(state.copyWith(
        cachedDomain: url,
        message: '',
        requestStatus: RequestStatus.requesting,
      ));

      _authenticationService.getDatabaseList().then((value) {
        if (value.error != null) {
          final errorMsg = value.error!.toLowerCase();
          if (errorMsg.contains('404')) {
            emit(state.copyWith(
              message: 'Domain không tồn tại hoặc đã thay đổi.',
              requestStatus: RequestStatus.failed,
            ));
          } else if (errorMsg.contains('network') ||
              errorMsg.contains('connection')) {
            emit(state.copyWith(
              message:
                  'Không thể kết nối tới server. Vui lòng kiểm tra domain.',
              requestStatus: RequestStatus.failed,
            ));
          } else {
            emit(state.copyWith(
              message: value.error,
              requestStatus: RequestStatus.failed,
            ));
          }
          return;
        }

        if (value.data == null || value.data!.isEmpty) {
          emit(state.copyWith(
            message: 'Không tìm thấy database',
            requestStatus: RequestStatus.failed,
          ));
          return;
        }
        emit(state.copyWith(
          dbNames: value.data!,
          message: '',
          requestStatus: RequestStatus.success,
        ));
      }).catchError((error) {
        emit(state.copyWith(
          message: 'Lỗi khi kiểm tra domain: $error',
          requestStatus: RequestStatus.failed,
        ));
      });
    } else {
      _localService.saveOdooDomain("");
      buildConfig.setBaseUrl("");
      emit(state.copyWith(
        cachedDomain: '',
        message: '',
        requestStatus: RequestStatus.initial,
      ));
    }
  }

  void onChangedAutoLogin(bool? value) {
    emit(state.copyWith(autoLogin: value));
  }

  void initDomain() {
    final String domain = _localService.getOdooDomain();
    buildConfig.setBaseUrl(domain);
    emit(state.copyWith(
      cachedDomain: domain,
      domain: domain,
    ));
  }

  void onAccessDomain() {
    _saveDomain(state.domain ?? '');
    _localService.saveOdooToken('');
  }
}
