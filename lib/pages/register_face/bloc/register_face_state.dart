import 'dart:io';

import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/entities/student.dart';

class RegisterFaceState {
  Student? student;
  File? image;
  RequestStatus requestStatus;
  String? message;
  bool isRegistered;
  List<int> oldImageIds;
  List<int> addedImageIds;

  RegisterFaceState copyWith({
    Student? student,
    File? image,
    RequestStatus? requestStatus,
    String? message,
    bool? isRegistered,
    List<int>? oldImageIds,
    List<int>? addedImageIds,
  }) {
    return RegisterFaceState(
      student: student ?? this.student,
      image: image ?? this.image,
      requestStatus: requestStatus ?? this.requestStatus,
      message: message ?? this.message,
      isRegistered: isRegistered ?? this.isRegistered,
      oldImageIds: oldImageIds ?? this.oldImageIds,
      addedImageIds: addedImageIds ?? this.addedImageIds,
    );
  }

  RegisterFaceState({
    this.student,
    this.image,
    this.requestStatus = RequestStatus.initial,
    this.message,
    this.isRegistered = false,
    this.oldImageIds = const [],
    this.addedImageIds = const [],
  });
}
