import 'dart:io';

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
      final token = _localService.getAuthToken().trim();
      final configuredDomain = _buildConfig.kBaseUrl.trim();
      final savedDomain = _localService.getServerUrl().trim();
      final recentDomains = _localService.getRecentDomains();

      final candidates = <String>[];
      void addCandidate(String value) {
        final normalized = value.trim();
        if (normalized.isEmpty || candidates.contains(normalized)) {
          return;
        }
        candidates.add(normalized);
      }

      addCandidate(configuredDomain);
      addCandidate(savedDomain);
      for (final url in recentDomains) {
        addCandidate(url);
      }

      var domain = '';
      for (final candidate in candidates) {
        final isHealthy = await _isServerReachable(candidate);
        if (isHealthy) {
          domain = candidate;
          break;
        }
      }

      debugPrint('🔵 Bootstrap: Candidates: $candidates');
      debugPrint('🔵 Bootstrap: Selected BaseUrl: $domain');

      if (domain.isEmpty) {
        final templateUrl = _pickScanTemplate(candidates);
        final scanned = await _scanSubnetForBackend(templateUrl);
        if (scanned.isNotEmpty) {
          domain = scanned;
          debugPrint('🟢 Bootstrap: Found backend via subnet scan: $domain');
        }
      }

      if (domain.isEmpty) {
        debugPrint(
            '⚪ Bootstrap: No reachable base URL, requesting domain update');
        emit(state.copyWith(status: BootstrapStatus.domainError));
        return;
      }

      // Always keep ApiClient aligned with configured backend URL.
      _buildConfig.setBaseUrl(domain);
      _localService.saveServerUrl(domain);
      _localService.saveRecentDomain(domain);

      debugPrint('🔵 Bootstrap: Using FastAPI base URL: $domain');

      final dbName = await _localService.getDatabaseName();
      if (dbName.isEmpty) {
        if (token.isNotEmpty) {
          const fallbackDbName = 'fastapi_db';
          await _localService.saveDatabaseName(fallbackDbName);
          await _configTenant(domain, fallbackDbName);
          emit(state.copyWith(status: BootstrapStatus.authenticated));
          return;
        }
        emit(state.copyWith(status: BootstrapStatus.unauthenticated));
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

  Future<bool> _isServerReachable(String baseUrl) async {
    final normalized = baseUrl.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse('$normalized/health');
    if (uri == null || !uri.hasAuthority || !uri.isAbsolute) {
      return false;
    }

    final httpClient = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await httpClient.getUrl(uri);
      request.followRedirects = false;
      final response =
          await request.close().timeout(const Duration(seconds: 3));

      // Any HTTP response (even 500) means the host is reachable.
      // The /health endpoint is optional — we only treat socket/timeout
      // as "unreachable". This is intentional: if the backend is up but
      // crashed (e.g. Migration 0014 left stale references), the app
      // should still pick it so the user sees a clear error instead
      // of being asked to re-enter the server URL.
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint(
            '🔵 Bootstrap: "$baseUrl" → reachable (HTTP ${response.statusCode})');
        return true;
      }
      // Non-2xx but the host responded → backend is up but unhealthy.
      // Treat as "reachable" so the user lands on the login page
      // instead of being redirected to the domain-entry screen.
      debugPrint(
          '⚠ Bootstrap: "$baseUrl" → backend responded but HTTP '
          '${response.statusCode} (backend may have an internal error). '
          'Treating as reachable to allow login attempt.');
      return true;
    } on SocketException {
      return false;
    } on HttpException {
      return false;
    } catch (_) {
      return false;
    } finally {
      httpClient.close(force: true);
    }
  }

  String _pickScanTemplate(List<String> candidates) {
    for (final candidate in candidates) {
      final uri = Uri.tryParse(candidate);
      if (uri != null && uri.hasAuthority && uri.isAbsolute) {
        return candidate;
      }
    }
    return 'http://127.0.0.1:8000';
  }

  Future<String> _scanSubnetForBackend(String templateUrl) async {
    final template = Uri.tryParse(templateUrl);
    if (template == null || !template.isAbsolute) {
      return '';
    }

    final localIp = await _getLocalPrivateIpv4();
    if (localIp == null) {
      return '';
    }

    final octets = localIp.split('.');
    if (octets.length != 4) {
      return '';
    }

    final subnetPrefix = '${octets[0]}.${octets[1]}.${octets[2]}';
    final ownHost = int.tryParse(octets[3]);

    final scheme = template.scheme.isNotEmpty ? template.scheme : 'http';
    final port =
        template.hasPort ? template.port : (scheme == 'https' ? 443 : 80);

    final hostRange = List<int>.generate(254, (index) => index + 1)
        .where((host) => host != ownHost)
        .toList(growable: false);

    const batchSize = 32;
    for (var i = 0; i < hostRange.length; i += batchSize) {
      final end =
          (i + batchSize < hostRange.length) ? i + batchSize : hostRange.length;
      final batch = hostRange.sublist(i, end);

      final probes = batch.map((host) async {
        final candidate = '$scheme://$subnetPrefix.$host:$port';
        if (await _isServerReachable(candidate)) {
          return candidate;
        }
        return '';
      });

      final results = await Future.wait(probes);
      for (final result in results) {
        if (result.isNotEmpty) {
          return result;
        }
      }
    }

    return '';
  }

  Future<String?> _getLocalPrivateIpv4() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      String? fallback;
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type != InternetAddressType.IPv4 || addr.isLoopback) {
            continue;
          }
          final ip = addr.address;
          if (_isPrivateIpv4(ip)) {
            return ip;
          }
          fallback ??= ip;
        }
      }
      return fallback;
    } catch (_) {
      return null;
    }
  }

  bool _isPrivateIpv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) {
      return false;
    }

    final octets = parts.map(int.tryParse).toList(growable: false);
    if (octets.any((part) => part == null)) {
      return false;
    }

    final o1 = octets[0]!;
    final o2 = octets[1]!;

    if (o1 == 10) {
      return true;
    }
    if (o1 == 172 && o2 >= 16 && o2 <= 31) {
      return true;
    }
    if (o1 == 192 && o2 == 168) {
      return true;
    }
    return false;
  }

  Future<void> _configTenant(String domain, String dbName) async {
    final tenantId =
        await _localService.getTenantIdOrSaveTenant(domain, dbName);
    await _localService.saveTenantId(tenantId);
    await FaceNative().initObjectBox(tenantId.toString());
    await getIt<HiveService>().init(tenantId.toString());
  }
}
