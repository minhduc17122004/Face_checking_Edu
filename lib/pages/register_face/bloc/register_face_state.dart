import 'dart:io';

import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/entities/employee.dart';

class RegisterFaceState {
  Employee? employee;
  File? image;
  RequestStatus requestStatus;
  String? message;
  bool isRegistered;
  List<int> oldImageIds;
  List<int> addedImageIds;

  RegisterFaceState copyWith({
    Employee? employee,
    File? image,
    RequestStatus? requestStatus,
    String? message,
    bool? isRegistered,
    List<int>? oldImageIds,
    List<int>? addedImageIds,
  }) {
    return RegisterFaceState(
      employee: employee ?? this.employee,
      image: image ?? this.image,
      requestStatus: requestStatus ?? this.requestStatus,
      message: message ?? this.message,
      isRegistered: isRegistered ?? this.isRegistered,
      oldImageIds: oldImageIds ?? this.oldImageIds,
      addedImageIds: addedImageIds ?? this.addedImageIds,
    );
  }

  RegisterFaceState({
    this.employee,
    this.image,
    this.requestStatus = RequestStatus.initial,
    this.message,
    this.isRegistered = false,
    this.oldImageIds = const [],
    this.addedImageIds = const [],
  });
}
