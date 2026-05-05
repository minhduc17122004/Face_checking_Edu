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
  final String? processingRequestId;

  DevicePermissionState({
    this.requestStatus = RequestStatus.initial,
    this.myRequests = const [],
    this.allRequests = const [],
    this.selectedRequest,
    this.message,
    this.deviceCode,
    this.isCheckingAuthorization = false,
    this.processingRequestId,
  });

  DevicePermissionState copyWith({
    RequestStatus? requestStatus,
    List<DeviceRequest>? myRequests,
    List<DeviceRequest>? allRequests,
    DeviceRequest? selectedRequest,
    String? message,
    String? deviceCode,
    bool? isCheckingAuthorization,
    String? processingRequestId,
    bool clearSelectedRequest = false,
    bool clearProcessingRequest = false,
  }) {
    return DevicePermissionState(
      requestStatus: requestStatus ?? this.requestStatus,
      myRequests: myRequests ?? this.myRequests,
      allRequests: allRequests ?? this.allRequests,
      selectedRequest:
          clearSelectedRequest ? null : selectedRequest ?? this.selectedRequest,
      message: message,
      deviceCode: deviceCode ?? this.deviceCode,
      isCheckingAuthorization:
          isCheckingAuthorization ?? this.isCheckingAuthorization,
      processingRequestId: clearProcessingRequest
          ? null
          : processingRequestId ?? this.processingRequestId,
    );
  }

  bool get hasApprovedRequest => myRequests.any((r) => r.isApproved);

  bool get hasPendingRequest => myRequests.any((r) => r.isPending);

  bool get isAuthorized => hasApprovedRequest;

  DeviceRequest? get latestRequest =>
      myRequests.isEmpty ? null : myRequests.first;

  DeviceRequestStatus? get myLatestStatus => latestRequest?.status;

  bool get isProcessingAction => processingRequestId != null;
}
