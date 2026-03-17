import 'package:face_time_keeping/common/enums/request_status.dart';

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
    final url = _normalizeDomainInput(domain);
    if (url.isNotEmpty) {
      _localService.saveOdooDomain(url);
      _localService.clearOdooDomainRelatedData();
      buildConfig.setBaseUrl(url);
      emit(state.copyWith(
        cachedDomain: url,
        message: '',
        requestStatus: RequestStatus.requesting,
      ));

      // Giả lập cho FastAPI server (không cần list databases)
      Future.delayed(const Duration(milliseconds: 500), () {
        emit(state.copyWith(
          dbNames: ['default'],
          message: '',
          requestStatus: RequestStatus.success,
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

  String _normalizeDomainInput(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final withScheme = trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : 'http://$trimmed';

    return withScheme.endsWith('/')
        ? withScheme.substring(0, withScheme.length - 1)
        : withScheme;
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
