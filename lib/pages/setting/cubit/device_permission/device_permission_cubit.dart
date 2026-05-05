import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/data/remote/device_request_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'device_permission_state.dart';

@injectable
class DevicePermissionCubit extends Cubit<DevicePermissionState> {
  DevicePermissionCubit(this._deviceRequestService, this._localService)
      : super(DevicePermissionState());

  final DeviceRequestService _deviceRequestService;
  final LocalService _localService;
  String? _currentFilterStatus;

  Future<void> checkDeviceAuthorization() async {
    emit(state.copyWith(isCheckingAuthorization: true));
    try {
      final deviceCode = await _localService.getDeviceCode();
      final result = await _deviceRequestService.getMyRequests(deviceCode);
      if (result.isSuccess) {
        emit(state.copyWith(
          isCheckingAuthorization: false,
          deviceCode: deviceCode,
          myRequests: result.data ?? [],
          requestStatus: RequestStatus.success,
          clearSelectedRequest: true,
        ));
      } else {
        emit(state.copyWith(
          isCheckingAuthorization: false,
          deviceCode: deviceCode,
          requestStatus: RequestStatus.failed,
          message: result.error ?? 'Không thể kiểm tra quyền thiết bị',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isCheckingAuthorization: false,
        requestStatus: RequestStatus.failed,
        message: e.toString(),
      ));
    }
  }

  Future<void> loadMyRequests(String deviceCode) async {
    emit(state.copyWith(
      requestStatus: RequestStatus.requesting,
      clearSelectedRequest: true,
    ));
    final result = await _deviceRequestService.getMyRequests(deviceCode);
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        myRequests: result.data ?? [],
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Không thể tải danh sách yêu cầu',
      ));
    }
  }

  Future<void> loadAllRequests({String? status}) async {
    _currentFilterStatus = status;
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _deviceRequestService.getAllRequests(status: status);
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        allRequests: result.data ?? [],
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Không thể tải danh sách yêu cầu',
      ));
    }
  }

  Future<void> submitRequest({
    String? deviceCode,
    String? deviceName,
    String? roomId,
  }) async {
    final code =
        deviceCode ?? state.deviceCode ?? await _localService.getDeviceCode();
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _deviceRequestService.submitRequest(
      deviceCode: code,
      deviceName: deviceName,
      roomId: roomId,
    );
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        selectedRequest: result.data,
      ));
      await checkDeviceAuthorization();
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Không thể gửi yêu cầu cấp quyền',
      ));
    }
  }

  Future<void> approveRequest(String requestId, {String? adminNote}) async {
    emit(state.copyWith(
      requestStatus: RequestStatus.requesting,
      processingRequestId: requestId,
    ));
    final result = await _deviceRequestService.approveRequest(
      requestId,
      adminNote: adminNote,
    );
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        selectedRequest: result.data,
        clearProcessingRequest: true,
      ));
      await loadAllRequests(status: _currentFilterStatus);
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Không thể duyệt yêu cầu thiết bị',
        clearProcessingRequest: true,
      ));
    }
  }

  Future<void> rejectRequest(String requestId, {String? adminNote}) async {
    emit(state.copyWith(
      requestStatus: RequestStatus.requesting,
      processingRequestId: requestId,
    ));
    final result = await _deviceRequestService.rejectRequest(
      requestId,
      adminNote: adminNote,
    );
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        selectedRequest: result.data,
        clearProcessingRequest: true,
      ));
      await loadAllRequests(status: _currentFilterStatus);
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Không thể từ chối yêu cầu thiết bị',
        clearProcessingRequest: true,
      ));
    }
  }

  void reset() {
    emit(DevicePermissionState());
  }
}
