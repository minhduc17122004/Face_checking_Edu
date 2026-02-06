// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'en';

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "apply": MessageLookupByLibrary.simpleMessage("Apply"),
        "badRequest": MessageLookupByLibrary.simpleMessage("Bad Request"),
        "bluetoothIssue":
            MessageLookupByLibrary.simpleMessage("Sự cố Bluetooth"),
        "bluetoothPermissionRequest": MessageLookupByLibrary.simpleMessage(
            "Bluetooth phải được bật và xác thực để ứng dụng có thể tìm và kết nối với thiết bị của bạn."),
        "bluetoothTurnOnMessage":
            MessageLookupByLibrary.simpleMessage("Không sử dụng Bluetooth."),
        "camera": MessageLookupByLibrary.simpleMessage("Camera"),
        "clear": MessageLookupByLibrary.simpleMessage("Clear"),
        "close": MessageLookupByLibrary.simpleMessage("Đóng"),
        "commonScale": MessageLookupByLibrary.simpleMessage("Cân thông thường"),
        "confirmation": MessageLookupByLibrary.simpleMessage("Confirmation"),
        "continueWorkingConfirmation": MessageLookupByLibrary.simpleMessage(
            "Bạn có chắc chắn muốn tiếp tục không?"),
        "database": MessageLookupByLibrary.simpleMessage("Database"),
        "domain": MessageLookupByLibrary.simpleMessage("Domain"),
        "emailAlreadyExists":
            MessageLookupByLibrary.simpleMessage("Email Already Exists"),
        "emailIsRequired":
            MessageLookupByLibrary.simpleMessage("The email is required"),
        "emailNotExists":
            MessageLookupByLibrary.simpleMessage("Email Does Not Exist"),
        "employee": MessageLookupByLibrary.simpleMessage("Nhân viên"),
        "enter": MessageLookupByLibrary.simpleMessage("Nhập"),
        "enterEmailAddress":
            MessageLookupByLibrary.simpleMessage("Enter email address"),
        "enterPassword": MessageLookupByLibrary.simpleMessage("Enter password"),
        "enterRfid": MessageLookupByLibrary.simpleMessage("Enter RFID"),
        "error": MessageLookupByLibrary.simpleMessage("Error!"),
        "finish": MessageLookupByLibrary.simpleMessage("Kết thúc"),
        "finishWorkingConfirmation": MessageLookupByLibrary.simpleMessage(
            "Bạn có chắc chắn muốn kết thúc không?"),
        "forbidden": MessageLookupByLibrary.simpleMessage("Forbidden"),
        "forgotPassword":
            MessageLookupByLibrary.simpleMessage("Forgot Password?"),
        "gallery": MessageLookupByLibrary.simpleMessage("Gallery"),
        "internetConnection":
            MessageLookupByLibrary.simpleMessage("KẾT NỐI MẠNG"),
        "invalidEmail": MessageLookupByLibrary.simpleMessage("Invalid email"),
        "invalidPassword": MessageLookupByLibrary.simpleMessage(
            "Your password must be 6-16 Characters."),
        "invalidPhone": MessageLookupByLibrary.simpleMessage(
            "Please enter valid mobile number"),
        "logNotFound": MessageLookupByLibrary.simpleMessage("Log Not Found"),
        "networkErrorMessage": MessageLookupByLibrary.simpleMessage(
            "Lỗi kết nối. Vui lòng kiểm tra mạng và thử lại!"),
        "notFound": MessageLookupByLibrary.simpleMessage("Not Found"),
        "ok": MessageLookupByLibrary.simpleMessage("Đồng ý"),
        "password": MessageLookupByLibrary.simpleMessage("Password"),
        "passwordIsRequired":
            MessageLookupByLibrary.simpleMessage("The password is required"),
        "pauseWorking":
            MessageLookupByLibrary.simpleMessage("TẠM DỪNG SẢN XUẤT"),
        "pauseWorkingConfirmation": MessageLookupByLibrary.simpleMessage(
            "Bạn có chắc chắn muốn tạm dừng không?"),
        "procedure": MessageLookupByLibrary.simpleMessage("Quy trình"),
        "procedureScale":
            MessageLookupByLibrary.simpleMessage("CÂN THEO QUY TRÌNH"),
        "procedureScaleEmpty": MessageLookupByLibrary.simpleMessage(
            "Chưa có quy trình sản xuất mới."),
        "procedureScaleSort":
            MessageLookupByLibrary.simpleMessage("Cân quy trình"),
        "requiredAddress":
            MessageLookupByLibrary.simpleMessage("Please enter address"),
        "requiredPhone":
            MessageLookupByLibrary.simpleMessage("Please enter phone number"),
        "reset": MessageLookupByLibrary.simpleMessage("Reset"),
        "retry": MessageLookupByLibrary.simpleMessage("Thử lại"),
        "rfidConnection": MessageLookupByLibrary.simpleMessage("KẾT NỐI RFID"),
        "rfidInfo": MessageLookupByLibrary.simpleMessage(
            "RFID là mã duy nhất được liên kết với nhân viên."),
        "scaleConnection": MessageLookupByLibrary.simpleMessage("KẾT NỐI CÂN"),
        "scaleSuccess": MessageLookupByLibrary.simpleMessage(
            "[✔] Nhập dữ liệu thành công!"),
        "scanDevice": MessageLookupByLibrary.simpleMessage("Tìm thiết bị..."),
        "serverConnection":
            MessageLookupByLibrary.simpleMessage("KẾT NỐI MÁY CHỦ"),
        "setting": MessageLookupByLibrary.simpleMessage("Cài đặt"),
        "somethingWentWrong": MessageLookupByLibrary.simpleMessage(
            "Opp! Có lỗi xảy ra, vui lòng thử lại."),
        "status": MessageLookupByLibrary.simpleMessage("TRẠNG THÁI"),
        "unauthorized": MessageLookupByLibrary.simpleMessage("Unauthorized"),
        "unknown": MessageLookupByLibrary.simpleMessage("Unknown"),
        "update": MessageLookupByLibrary.simpleMessage("Cập nhật"),
        "updateConfirmation": MessageLookupByLibrary.simpleMessage(
            "Bạn có chắc chắn muốn cập nhật?"),
        "updateSuccess":
            MessageLookupByLibrary.simpleMessage("Cập nhật thành công!"),
        "validateRfidEmpty":
            MessageLookupByLibrary.simpleMessage("RFID không được để trống!"),
        "warning": MessageLookupByLibrary.simpleMessage("Warning!"),
        "working": MessageLookupByLibrary.simpleMessage("ĐANG SẢN XUẤT")
      };
}
