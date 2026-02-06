// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(_current != null,
        'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.');
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(instance != null,
        'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?');
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Opp! Có lỗi xảy ra, vui lòng thử lại.`
  String get somethingWentWrong {
    return Intl.message(
      'Opp! Có lỗi xảy ra, vui lòng thử lại.',
      name: 'somethingWentWrong',
      desc: '',
      args: [],
    );
  }

  /// `Lỗi kết nối. Vui lòng kiểm tra mạng và thử lại!`
  String get networkErrorMessage {
    return Intl.message(
      'Lỗi kết nối. Vui lòng kiểm tra mạng và thử lại!',
      name: 'networkErrorMessage',
      desc: '',
      args: [],
    );
  }

  /// `Not Found`
  String get notFound {
    return Intl.message(
      'Not Found',
      name: 'notFound',
      desc: '',
      args: [],
    );
  }

  /// `Forbidden`
  String get forbidden {
    return Intl.message(
      'Forbidden',
      name: 'forbidden',
      desc: '',
      args: [],
    );
  }

  /// `Unauthorized`
  String get unauthorized {
    return Intl.message(
      'Unauthorized',
      name: 'unauthorized',
      desc: '',
      args: [],
    );
  }

  /// `Bad Request`
  String get badRequest {
    return Intl.message(
      'Bad Request',
      name: 'badRequest',
      desc: '',
      args: [],
    );
  }

  /// `Email Already Exists`
  String get emailAlreadyExists {
    return Intl.message(
      'Email Already Exists',
      name: 'emailAlreadyExists',
      desc: '',
      args: [],
    );
  }

  /// `Email Does Not Exist`
  String get emailNotExists {
    return Intl.message(
      'Email Does Not Exist',
      name: 'emailNotExists',
      desc: '',
      args: [],
    );
  }

  /// `Log Not Found`
  String get logNotFound {
    return Intl.message(
      'Log Not Found',
      name: 'logNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Enter email address`
  String get enterEmailAddress {
    return Intl.message(
      'Enter email address',
      name: 'enterEmailAddress',
      desc: '',
      args: [],
    );
  }

  /// `Enter password`
  String get enterPassword {
    return Intl.message(
      'Enter password',
      name: 'enterPassword',
      desc: '',
      args: [],
    );
  }

  /// `Forgot Password?`
  String get forgotPassword {
    return Intl.message(
      'Forgot Password?',
      name: 'forgotPassword',
      desc: '',
      args: [],
    );
  }

  /// `Confirmation`
  String get confirmation {
    return Intl.message(
      'Confirmation',
      name: 'confirmation',
      desc: '',
      args: [],
    );
  }

  /// `Clear`
  String get clear {
    return Intl.message(
      'Clear',
      name: 'clear',
      desc: '',
      args: [],
    );
  }

  /// `Apply`
  String get apply {
    return Intl.message(
      'Apply',
      name: 'apply',
      desc: '',
      args: [],
    );
  }

  /// `Reset`
  String get reset {
    return Intl.message(
      'Reset',
      name: 'reset',
      desc: '',
      args: [],
    );
  }

  /// `Error!`
  String get error {
    return Intl.message(
      'Error!',
      name: 'error',
      desc: '',
      args: [],
    );
  }

  /// `Password`
  String get password {
    return Intl.message(
      'Password',
      name: 'password',
      desc: '',
      args: [],
    );
  }

  /// `Warning!`
  String get warning {
    return Intl.message(
      'Warning!',
      name: 'warning',
      desc: '',
      args: [],
    );
  }

  /// `Camera`
  String get camera {
    return Intl.message(
      'Camera',
      name: 'camera',
      desc: '',
      args: [],
    );
  }

  /// `Gallery`
  String get gallery {
    return Intl.message(
      'Gallery',
      name: 'gallery',
      desc: '',
      args: [],
    );
  }

  /// `The password is required`
  String get passwordIsRequired {
    return Intl.message(
      'The password is required',
      name: 'passwordIsRequired',
      desc: '',
      args: [],
    );
  }

  /// `Your password must be 6-16 Characters.`
  String get invalidPassword {
    return Intl.message(
      'Your password must be 6-16 Characters.',
      name: 'invalidPassword',
      desc: '',
      args: [],
    );
  }

  /// `Please enter address`
  String get requiredAddress {
    return Intl.message(
      'Please enter address',
      name: 'requiredAddress',
      desc: '',
      args: [],
    );
  }

  /// `Invalid email`
  String get invalidEmail {
    return Intl.message(
      'Invalid email',
      name: 'invalidEmail',
      desc: '',
      args: [],
    );
  }

  /// `The email is required`
  String get emailIsRequired {
    return Intl.message(
      'The email is required',
      name: 'emailIsRequired',
      desc: '',
      args: [],
    );
  }

  /// `Please enter phone number`
  String get requiredPhone {
    return Intl.message(
      'Please enter phone number',
      name: 'requiredPhone',
      desc: '',
      args: [],
    );
  }

  /// `Please enter valid mobile number`
  String get invalidPhone {
    return Intl.message(
      'Please enter valid mobile number',
      name: 'invalidPhone',
      desc: '',
      args: [],
    );
  }

  /// `Bluetooth phải được bật và xác thực để ứng dụng có thể tìm và kết nối với thiết bị của bạn.`
  String get bluetoothPermissionRequest {
    return Intl.message(
      'Bluetooth phải được bật và xác thực để ứng dụng có thể tìm và kết nối với thiết bị của bạn.',
      name: 'bluetoothPermissionRequest',
      desc: '',
      args: [],
    );
  }

  /// `Đồng ý`
  String get ok {
    return Intl.message(
      'Đồng ý',
      name: 'ok',
      desc: '',
      args: [],
    );
  }

  /// `Sự cố Bluetooth`
  String get bluetoothIssue {
    return Intl.message(
      'Sự cố Bluetooth',
      name: 'bluetoothIssue',
      desc: '',
      args: [],
    );
  }

  /// `Không sử dụng Bluetooth.`
  String get bluetoothTurnOnMessage {
    return Intl.message(
      'Không sử dụng Bluetooth.',
      name: 'bluetoothTurnOnMessage',
      desc: '',
      args: [],
    );
  }

  /// `Đóng`
  String get close {
    return Intl.message(
      'Đóng',
      name: 'close',
      desc: '',
      args: [],
    );
  }

  /// `CÂN THEO QUY TRÌNH`
  String get procedureScale {
    return Intl.message(
      'CÂN THEO QUY TRÌNH',
      name: 'procedureScale',
      desc: '',
      args: [],
    );
  }

  /// `Cân quy trình`
  String get procedureScaleSort {
    return Intl.message(
      'Cân quy trình',
      name: 'procedureScaleSort',
      desc: '',
      args: [],
    );
  }

  /// `Chưa có quy trình sản xuất mới.`
  String get procedureScaleEmpty {
    return Intl.message(
      'Chưa có quy trình sản xuất mới.',
      name: 'procedureScaleEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Thử lại`
  String get retry {
    return Intl.message(
      'Thử lại',
      name: 'retry',
      desc: '',
      args: [],
    );
  }

  /// `Kết thúc`
  String get finish {
    return Intl.message(
      'Kết thúc',
      name: 'finish',
      desc: '',
      args: [],
    );
  }

  /// `Cân thông thường`
  String get commonScale {
    return Intl.message(
      'Cân thông thường',
      name: 'commonScale',
      desc: '',
      args: [],
    );
  }

  /// `[✔] Nhập dữ liệu thành công!`
  String get scaleSuccess {
    return Intl.message(
      '[✔] Nhập dữ liệu thành công!',
      name: 'scaleSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Quy trình`
  String get procedure {
    return Intl.message(
      'Quy trình',
      name: 'procedure',
      desc: '',
      args: [],
    );
  }

  /// `KẾT NỐI MẠNG`
  String get internetConnection {
    return Intl.message(
      'KẾT NỐI MẠNG',
      name: 'internetConnection',
      desc: '',
      args: [],
    );
  }

  /// `KẾT NỐI MÁY CHỦ`
  String get serverConnection {
    return Intl.message(
      'KẾT NỐI MÁY CHỦ',
      name: 'serverConnection',
      desc: '',
      args: [],
    );
  }

  /// `KẾT NỐI CÂN`
  String get scaleConnection {
    return Intl.message(
      'KẾT NỐI CÂN',
      name: 'scaleConnection',
      desc: '',
      args: [],
    );
  }

  /// `KẾT NỐI RFID`
  String get rfidConnection {
    return Intl.message(
      'KẾT NỐI RFID',
      name: 'rfidConnection',
      desc: '',
      args: [],
    );
  }

  /// `TRẠNG THÁI`
  String get status {
    return Intl.message(
      'TRẠNG THÁI',
      name: 'status',
      desc: '',
      args: [],
    );
  }

  /// `ĐANG SẢN XUẤT`
  String get working {
    return Intl.message(
      'ĐANG SẢN XUẤT',
      name: 'working',
      desc: '',
      args: [],
    );
  }

  /// `TẠM DỪNG SẢN XUẤT`
  String get pauseWorking {
    return Intl.message(
      'TẠM DỪNG SẢN XUẤT',
      name: 'pauseWorking',
      desc: '',
      args: [],
    );
  }

  /// `Nhân viên`
  String get employee {
    return Intl.message(
      'Nhân viên',
      name: 'employee',
      desc: '',
      args: [],
    );
  }

  /// `Bạn có chắc chắn muốn tiếp tục không?`
  String get continueWorkingConfirmation {
    return Intl.message(
      'Bạn có chắc chắn muốn tiếp tục không?',
      name: 'continueWorkingConfirmation',
      desc: '',
      args: [],
    );
  }

  /// `Bạn có chắc chắn muốn tạm dừng không?`
  String get pauseWorkingConfirmation {
    return Intl.message(
      'Bạn có chắc chắn muốn tạm dừng không?',
      name: 'pauseWorkingConfirmation',
      desc: '',
      args: [],
    );
  }

  /// `Bạn có chắc chắn muốn kết thúc không?`
  String get finishWorkingConfirmation {
    return Intl.message(
      'Bạn có chắc chắn muốn kết thúc không?',
      name: 'finishWorkingConfirmation',
      desc: '',
      args: [],
    );
  }

  /// `Domain`
  String get domain {
    return Intl.message(
      'Domain',
      name: 'domain',
      desc: '',
      args: [],
    );
  }

  /// `Database`
  String get database {
    return Intl.message(
      'Database',
      name: 'database',
      desc: '',
      args: [],
    );
  }

  /// `Cài đặt`
  String get setting {
    return Intl.message(
      'Cài đặt',
      name: 'setting',
      desc: '',
      args: [],
    );
  }

  /// `Unknown`
  String get unknown {
    return Intl.message(
      'Unknown',
      name: 'unknown',
      desc: '',
      args: [],
    );
  }

  /// `Cập nhật thành công!`
  String get updateSuccess {
    return Intl.message(
      'Cập nhật thành công!',
      name: 'updateSuccess',
      desc: '',
      args: [],
    );
  }

  /// `RFID là mã duy nhất được liên kết với nhân viên.`
  String get rfidInfo {
    return Intl.message(
      'RFID là mã duy nhất được liên kết với nhân viên.',
      name: 'rfidInfo',
      desc: '',
      args: [],
    );
  }

  /// `Enter RFID`
  String get enterRfid {
    return Intl.message(
      'Enter RFID',
      name: 'enterRfid',
      desc: '',
      args: [],
    );
  }

  /// `Cập nhật`
  String get update {
    return Intl.message(
      'Cập nhật',
      name: 'update',
      desc: '',
      args: [],
    );
  }

  /// `RFID không được để trống!`
  String get validateRfidEmpty {
    return Intl.message(
      'RFID không được để trống!',
      name: 'validateRfidEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Bạn có chắc chắn muốn cập nhật?`
  String get updateConfirmation {
    return Intl.message(
      'Bạn có chắc chắn muốn cập nhật?',
      name: 'updateConfirmation',
      desc: '',
      args: [],
    );
  }

  /// `Tìm thiết bị...`
  String get scanDevice {
    return Intl.message(
      'Tìm thiết bị...',
      name: 'scanDevice',
      desc: '',
      args: [],
    );
  }

  /// `Nhập`
  String get enter {
    return Intl.message(
      'Nhập',
      name: 'enter',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
