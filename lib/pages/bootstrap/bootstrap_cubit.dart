import 'package:face_native/face_native.dart';
import 'package:face_time_keeping/configs/build_config.dart';
import 'package:face_time_keeping/data/local/hive_service.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../common/event/event_bus_mixin.dart';
import 'bootstrap_state.dart';

@LazySingleton()
class BootstrapCubit extends Cubit<BootstrapState> with EventBusMixin {
  BootstrapCubit(
    this._localService,
    this._buildConfig,
  ) : super(const BootstrapState(status: BootstrapStatus.initial));

  final LocalService _localService;
  final BuildConfig _buildConfig;

  @override
  void emit(BootstrapState state) {
    if (isClosed) {
      return;
    }
    super.emit(state);
  }

  Future<void> initData() async {
    try {
      final token = _localService.getOdooToken();
      var domain = _buildConfig.kBaseUrl.trim();
      if (domain.isEmpty) {
        domain = _localService.getOdooDomain().trim();
      }

      debugPrint('🔵 Bootstrap: BaseUrl: $domain');

      if (domain.isEmpty) {
        debugPrint('⚪ Bootstrap: No base URL found, emitting unauthenticated');
        emit(state.copyWith(status: BootstrapStatus.offlineMode));
        await _configTenant('default', 'application_db');
        return;
      }

      // Always keep ApiClient aligned with configured backend URL.
      _buildConfig.setBaseUrl(domain);
      _localService.saveOdooDomain(domain);

      debugPrint('🔵 Bootstrap: Using FastAPI base URL: $domain');

      final dbName = await _localService.getOdooDbName();
      if (dbName.isEmpty) {
        emit(state.copyWith(status: BootstrapStatus.offlineMode));
        return;
      }
      await _configTenant(domain, dbName);

      if (token.isEmpty) {
        emit(state.copyWith(status: BootstrapStatus.unauthenticated));
        return;
      }
      emit(state.copyWith(status: BootstrapStatus.authenticated));
    } catch (e, stackTrace) {
      debugPrint('🔴 Bootstrap: Error in initData: $e');
      debugPrint('🔴 Bootstrap: StackTrace: $stackTrace');

      final errorMsg = e.toString().toLowerCase();
      final isDomainError = errorMsg.contains('404') ||
          errorMsg.contains('failed host lookup') ||
          errorMsg.contains('connection refused') ||
          errorMsg.contains('network error') ||
          errorMsg.contains('socketexception') ||
          errorMsg.contains('format') ||
          errorMsg.contains('uri');

      if (isDomainError) {
        debugPrint('🔴 Bootstrap: Emitting domainError status');
        emit(state.copyWith(status: BootstrapStatus.domainError));
      } else {
        debugPrint('🔴 Bootstrap: Non-domain error, emitting unauthenticated');
        emit(state.copyWith(status: BootstrapStatus.offlineMode));
      }
    }
  }

  Future<void> _configTenant(String domain, String dbName) async {
    final tenantId =
        await _localService.getTenantIdOrSaveTenant(domain, dbName);
    await _localService.saveTenantId(tenantId);
    await FaceNative().initObjectBox(tenantId.toString());
    await getIt<HiveService>().init(tenantId.toString());
  }
}
