import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/entities/check_in_out.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class CsvUtil {
  Future<File> exportCheckInOutToCsv(List<CheckInOut> entries) async {
    List<List<dynamic>> csvData = [
      ["Mã nhân sự", "Tên nhân sự", "Thời gian", "Hành động"],
      ...entries.map((e) => [
            e.pin,
            e.name,
            _formatDateTime(e.time),
            e.isCheckIn ? 'Checkin' : 'Checkout',
          ])
    ];

    final dir = await Directory.systemTemp.createTemp();
    final file = File(
        "${dir.path}/checkin_checkout_export_${_formatDateTime(DateTime.now())}.csv");
    String csv = const ListToCsvConverter().convert(csvData);
    return await file.writeAsString(csv);
  }

  Future<File> exportCheckInOutToExcel(List<CheckInOut> entries) async {
    try {
      final excel = Excel.createExcel();
      final sheetName = excel.getDefaultSheet() ?? 'CheckInOut';
      Sheet sheet = excel[sheetName];

      // Use the same header and data format as CSV export
      final headers = ["Mã nhân sự", "Tên nhân sự", "Thời gian", "Hành động"];
      sheet.appendRow(headers);

      for (final e in entries) {
        final row = [
          e.pin ?? '',
          e.name ?? '',
          _formatDateTime(e.time),
          e.isCheckIn ? 'Checkin' : 'Checkout',
        ];
        sheet.appendRow(row);
      }

      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Failed to encode Excel file');
      }

      final dir = await Directory.systemTemp.createTemp();
      final file = File(
          "${dir.path}/checkin_checkout_export_${_formatDateTime(DateTime.now())}.xlsx");
      return await file.writeAsBytes(bytes, flush: true);
    } catch (e, s) {
      pushLog('Error in exportCheckInOutToExcel (CsvUtil): $e\n$s');
      rethrow;
    }
  }

  String _formatDateTime(DateTime dt) {
    return dt.toIso8601String().split('.').first;
  }

  DateTime? _parseDateTime(String input) {
    try {
      return DateTime.parse(input);
    } catch (_) {
      pushLog('Error in _parseDateTime: $_');
      try {
        return null;
      } catch (_) {
        return null;
      }
    }
  }
}
