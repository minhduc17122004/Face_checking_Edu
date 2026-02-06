import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:image_picker/image_picker.dart';

import '../../../entities/check_in.dart';
import '../../../entities/check_out.dart';

class CheckingState {
  RequestStatus requestStatus;
  RequestStatus checkingStatus;
  String? message;
  String? checkingMessage;
  CheckIn? checkIn;
  CheckOut? checkOut;
  bool isAllowCapture;

  CheckingState({
    this.requestStatus = RequestStatus.initial,
    this.checkingStatus = RequestStatus.initial,
    this.message,
    this.checkingMessage,
    this.checkIn,
    this.checkOut,
    this.isAllowCapture = true,
  });

  CheckingState copyWith({
    XFile? image,
    RequestStatus? requestStatus,
    RequestStatus? checkingStatus,
    String? message,
    String? checkingMessage,
    CheckIn? checkIn,
    CheckOut? checkOut,
    bool? isAllowCapture,
  }) {
    return CheckingState(
      requestStatus: requestStatus ?? RequestStatus.initial,
      checkingStatus: checkingStatus ?? RequestStatus.initial,
      message: message ?? this.message,
      checkingMessage: checkingMessage ?? this.checkingMessage,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      isAllowCapture: isAllowCapture ?? this.isAllowCapture,
    );
  }

  CheckingState updateCheckout({
    XFile? image,
    RequestStatus? requestStatus,
    RequestStatus? checkingStatus,
    String? message,
    String? checkingMessage,
    CheckIn? checkIn,
    CheckOut? checkOut,
    bool? isAllowCapture,
  }) {
    final value = CheckingState(
      requestStatus: requestStatus ?? RequestStatus.initial,
      checkingStatus: checkingStatus ?? RequestStatus.initial,
      message: message ?? this.message,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      isAllowCapture: isAllowCapture ?? this.isAllowCapture,
    );
    value.checkOut = checkOut;
    value.checkingMessage = checkingMessage;
    return value;
  }

  CheckingState updateCheckin({
    XFile? image,
    RequestStatus? requestStatus,
    RequestStatus? checkingStatus,
    String? message,
    String? checkingMessage,
    CheckIn? checkIn,
    CheckOut? checkOut,
    bool? isAllowCapture,
  }) {
    final value = CheckingState(
      requestStatus: requestStatus ?? RequestStatus.initial,
      checkingStatus: checkingStatus ?? RequestStatus.initial,
      message: message ?? this.message,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      isAllowCapture: isAllowCapture ?? this.isAllowCapture,
    );
    value.checkIn = checkIn;
    value.checkingMessage = checkingMessage;
    return value;
  }

  CheckingState refreshState() {
    return CheckingState(
      requestStatus: RequestStatus.initial,
      checkingStatus: checkingStatus,
      message: message,
      checkingMessage: checkingMessage,
      checkIn: checkIn,
      checkOut: checkOut,
      isAllowCapture: true,
    );
  }
}
