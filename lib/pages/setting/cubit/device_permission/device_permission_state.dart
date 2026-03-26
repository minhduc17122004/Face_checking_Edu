import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/entities/device_request.dart';

class DevicePermissionState {
  final RequestStatus requestStatus;
  final List<DeviceRequest> myRequests;
  final List<DeviceRequest> allRequests;
  final DeviceRequest? selectedRequest;
  final String? message;
  final String? deviceCode;
  final bool isCheckingAuthorization;

  DevicePermissionState({
    this.requestStatus = RequestStatus.initial,
    this.myRequests = const [],
    this.allRequests = const [],
    this.selectedRequest,
    this.message,
    this.deviceCode,
    this.isCheckingAuthorization = false,
  });

  DevicePermissionState copyWith({
    RequestStatus? requestStatus,
    List<DeviceRequest>? myRequests,
    List<DeviceRequest>? allRequests,
    DeviceRequest? selectedRequest,
    String? message,
    String? deviceCode,
    bool? isCheckingAuthorization,
  }) {
    return DevicePermissionState(
      requestStatus: requestStatus ?? this.requestStatus,
      myRequests: myRequests ?? this.myRequests,
      allRequests: allRequests ?? this.allRequests,
      selectedRequest: selectedRequest ?? this.selectedRequest,
      message: message,
      deviceCode: deviceCode ?? this.deviceCode,
      isCheckingAuthorization: isCheckingAuthorization ?? this.isCheckingAuthorization,
    );
  }

  bool get hasApprovedRequest =>
      myRequests.any((r) => r.isApproved);

  bool get hasPendingRequest =>
      myRequests.any((r) => r.isPending);

  bool get isAuthorized => hasApprovedRequest;

  DeviceRequest? get latestRequest =>
      myRequests.isEmpty ? null : myRequests.first;

  DeviceRequestStatus? get myLatestStatus => latestRequest?.status;
}
