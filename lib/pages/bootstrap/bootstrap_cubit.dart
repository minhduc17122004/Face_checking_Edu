import 'package:face_native/face_native.dart';
import 'package:face_time_keeping/configs/build_config.dart';
import 'package:face_time_keeping/data/local/hive_service.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/data/remote/authentication_service.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../common/api_client/data_state.dart';
import '../../common/event/event_bus_mixin.dart';
import 'bootstrap_state.dart';

@LazySingleton()
class BootstrapCubit extends Cubit<BootstrapState> with EventBusMixin {
  BootstrapCubit(
    this._localService,
    this._buildConfig,
    this._authenticationService,
  ) : super(const BootstrapState(status: BootstrapStatus.initial));

  final LocalService _localService;
  final BuildConfig _buildConfig;
  final AuthenticationService _authenticationService;

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
      final domain = _localService.getOdooDomain();

      debugPrint('🔵 Bootstrap: Domain: $domain');

      if (domain.isEmpty) {
        debugPrint('⚪ Bootstrap: No domain found, emitting unauthenticated');
        emit(state.copyWith(status: BootstrapStatus.offlineMode));
        await _configTenant('default', 'application_db');
        return;
      }

      // Validate domain if exists
      _buildConfig.setBaseUrl(domain);

      debugPrint('🔵 Bootstrap: Validating domain: $domain');

      // Add timeout to prevent infinite wait
      final result = await _authenticationService.getDatabaseList().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ Bootstrap: Domain validation timeout after 10s');
          return const DataFailed<List<String>>('Domain validation timeout');
        },
      );

      if (result.error != null) {
        final errorMsg = result.error!.toLowerCase();
        final isDomainError =
            errorMsg.contains('404') || errorMsg.contains('timeout');

        if (isDomainError) {
          debugPrint('🔴 Bootstrap: Domain validation failed: ${result.error}');
          emit(state.copyWith(status: BootstrapStatus.domainError));
          return;
        }
        debugPrint('🔴 Bootstrap: Unknown validation error: ${result.error}');
        emit(state.copyWith(status: BootstrapStatus.domainError));
        return;
      }
      debugPrint('🟢 Bootstrap: Domain validation successful');

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
