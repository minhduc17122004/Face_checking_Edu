import 'dart:io';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/entities/check_in_out.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:share_plus/share_plus.dart';
import 'cubit/attendance_report_cubit.dart';

class AttendanceReport extends StatefulWidget {
  const AttendanceReport({super.key});

  @override
  State<AttendanceReport> createState() => _AttendanceReportState();
}

class _AttendanceReportState extends State<AttendanceReport> {
  DateTime selectedDate = DateTime.now();
  NavigatorState? _navigator;
  ScaffoldMessengerState? _scaffoldMessenger;
  late final AttendanceReportCubit _cubit;
  @override
  void initState() {
    super.initState();
    _cubit = getIt<AttendanceReportCubit>();
    _cubit.loadAttendanceReport();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigator = Navigator.of(context);
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Báo Cáo Điểm Danh'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          actions: [
            IconButton(
              onPressed: () => _showExportDialog(context),
              icon:
                  const Icon(Icons.file_download, size: 24, color: Colors.blue),
              tooltip: 'Xuất CSV/Excel',
            ),
          ],
        ),
        backgroundColor: const Color(0xFFF5F5F5),
        body: BlocBuilder<AttendanceReportCubit, AttendanceReportState>(
          builder: (context, state) {
            return Column(
              children: [
                _buildDateFilter(context, state),
                Expanded(child: _buildContent(state)),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDateFilter(BuildContext context, AttendanceReportState state) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ngày lọc',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy')
                      .format(state.filterDate ?? DateTime.now()),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _selectDate(context),
            icon: const Icon(Icons.edit_calendar, size: 18),
            label: const Text('Chọn ngày'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade50,
              foregroundColor: Colors.blue,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AttendanceReportState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: _buildTableContent(state),
      ),
    );
  }

  Widget _buildTableContent(AttendanceReportState state) {
    if (state.status == RequestStatus.requesting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang tải dữ liệu...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (state.status == RequestStatus.failed) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Có lỗi xảy ra',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              state.message,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () =>
                  context.read<AttendanceReportCubit>().loadAttendanceReport(),
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
              ),
            ),
          ],
        ),
      );
    }

    if (state.checkInOuts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Không có dữ liệu điểm danh',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Chưa có bản ghi điểm danh nào trong ngày ${DateFormat('dd/MM/yyyy').format(state.filterDate ?? DateTime.now())}',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    final width = MediaQuery.of(context).size.width;
    final isWideScreen = width > 600;
    return Column(
      children: [
        _buildTableHeader(isWideScreen),
        ...state.checkInOuts
            .map((checkInOut) => _buildTableRow(checkInOut, isWideScreen)),
      ],
    );
  }

  Widget _buildTableHeader(bool isWideScreen) {
    const headerStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 12);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            flex: 3,
            child: Text(
              'Tên Học Sinh',
              style: headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'Thời gian',
              style: headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'Hành động',
              style: headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
          if (isWideScreen)
            const Expanded(
              flex: 1,
              child: const Text(
                'Đồng Bộ',
                style: headerStyle,
                textAlign: TextAlign.center,
              ),
            ),
          const Expanded(
            flex: 2,
            child: Text(
              'Hình Ảnh',
              style: headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(CheckInOut checkInOut, bool isWideScreen) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        children: [
          // Tên Học Sinh
          Expanded(
            flex: 3,
            child: Text(
              textAlign: TextAlign.center,
              checkInOut.name,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Check In Time
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                DateFormat('HH:mm').format(checkInOut.time),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Hành động
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                checkInOut.isCheckIn ? 'CheckIn' : 'CheckOut',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: checkInOut.isCheckIn
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Sync Status
          if (isWideScreen)
            Expanded(
              flex: 1,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: checkInOut.isSynced
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: checkInOut.isSynced
                            ? Colors.green.shade200
                            : Colors.orange.shade200,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        checkInOut.isSynced
                            ? Icons.cloud_done
                            : Icons.cloud_off,
                        size: 18,
                        color: checkInOut.isSynced
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Hình Ảnh
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: InkWell(
                onTap: () => checkInOut.imagePath != null &&
                        checkInOut.imagePath!.isNotEmpty
                    ? _showImageDialog(checkInOut.imagePath!)
                    : null,
                child: Container(
                  width: 40,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: checkInOut.imagePath != null &&
                            checkInOut.imagePath!.isNotEmpty
                        ? _buildFileImage(checkInOut.imagePath!)
                        : Container(
                            color: Colors.grey.shade100,
                            child: Icon(
                              Icons.person,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileImage(String imagePath) {
    final File imageFile = File(imagePath);

    // Check if file exists
    if (!imageFile.existsSync()) {
      return Container(
        color: Colors.grey.shade100,
        child: Icon(
          Icons.broken_image,
          color: Colors.grey.shade400,
          size: 20,
        ),
      );
    }

    return Image.file(
      imageFile,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey.shade100,
          child: Icon(
            Icons.person,
            color: Colors.grey.shade400,
            size: 20,
          ),
        );
      },
    );
  }

  Widget _buildFileImageDialog(String imagePath) {
    final File imageFile = File(imagePath);

    // Check if file exists
    if (!imageFile.existsSync()) {
      return Container(
        height: 200,
        color: Colors.grey.shade100,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('File không tồn tại'),
            ],
          ),
        ),
      );
    }

    return Image.file(
      imageFile,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 200,
          color: Colors.grey.shade100,
          child: const Center(
            child: Text('Không thể tải hình ảnh'),
          ),
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });

      if (context.mounted) {
        context.read<AttendanceReportCubit>().filterCheckInOuts(picked);
      }
    }
  }

  void _showImageDialog(String imagePath) {
    if (imagePath.isEmpty) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Hình ảnh học sinh'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildFileImageDialog(imagePath),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLoadingSnackBar() {
    if (!mounted || _scaffoldMessenger == null) return;
    _scaffoldMessenger!.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('Đang xuất dữ liệu...'),
          ],
        ),
        duration: Duration(minutes: 1), // Long duration for loading
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xuất dữ liệu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Chọn tùy chọn xuất dữ liệu:'),
              const SizedBox(height: 16),
              // CSV - All
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _exportAllData(context);
                  },
                  icon: const Icon(Icons.all_inclusive),
                  label: const Text('Xuất tất cả (CSV)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // CSV - From date
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showDateSelectionForExport(context, false);
                  },
                  icon: const Icon(Icons.date_range),
                  label: const Text('Xuất từ ngày cụ thể (CSV)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade50,
                    foregroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Excel - All
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _exportAllExcel(context);
                  },
                  icon: const Icon(Icons.grid_on),
                  label: const Text('Xuất tất cả (Excel)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade50,
                    foregroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Excel - From date
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showDateSelectionForExport(context, true);
                  },
                  icon: const Icon(Icons.date_range),
                  label: const Text('Xuất từ ngày cụ thể (Excel)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade50,
                    foregroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDateSelectionForExport(
      BuildContext context, bool excel) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: excel ? Colors.orange : Colors.green,
            ),
          ),
          child: child!,
        );
      },
      helpText: 'Chọn ngày bắt đầu xuất',
      confirmText: 'Xuất',
      cancelText: 'Hủy',
    );

    if (picked != null) {
      if (!mounted) return;
      if (excel) {
        await _exportExcelFromDate(context, picked);
      } else {
        await _exportDataFromDate(context, picked);
      }
    }
  }

  Future<void> _exportAllData(BuildContext context) async {
    await _performExport(context, null, 'tất cả dữ liệu');
  }

  Future<void> _exportDataFromDate(BuildContext context, DateTime date) async {
    try {
      final dateStr = DateFormat('dd/MM/yyyy').format(date);
      await _performExport(context, date, 'dữ liệu từ ngày $dateStr');
    } catch (e) {
      await pushLog('Error in _exportDataFromDate: $e');
      if (!mounted || _scaffoldMessenger == null) return;
      _scaffoldMessenger!.showSnackBar(
        SnackBar(
          content: SelectableText.rich(
            TextSpan(
              text: 'Lỗi khi xuất dữ liệu: ',
              style: const TextStyle(color: Colors.white),
              children: [
                TextSpan(
                  text: e.toString(),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  // New: Export Excel - all
  Future<void> _exportAllExcel(BuildContext context) async {
    await _performExportExcel(context, null, 'tất cả dữ liệu (Excel)');
  }

  // New: Export Excel - from date
  Future<void> _exportExcelFromDate(BuildContext context, DateTime date) async {
    try {
      final dateStr = DateFormat('dd/MM/yyyy').format(date);
      await _performExportExcel(
          context, date, 'dữ liệu từ ngày $dateStr (Excel)');
    } catch (e) {
      await pushLog('Error in _exportExcelFromDate: $e');
      if (!mounted || _scaffoldMessenger == null) return;
      _scaffoldMessenger!.showSnackBar(
        SnackBar(
          content: SelectableText.rich(
            TextSpan(
              text: 'Lỗi khi xuất Excel: ',
              style: const TextStyle(color: Colors.white),
              children: [
                TextSpan(
                  text: e.toString(),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  // New: perform export for Excel (expects LocalService.exportCheckInOutToExcel)
  Future<void> _performExportExcel(
      BuildContext context, DateTime? fromDate, String description) async {
    if (!mounted) return;
    final scaffoldMessenger = _scaffoldMessenger;
    if (scaffoldMessenger == null) return;

    try {
      _showLoadingSnackBar();
      final localService = getIt<LocalService>();

      // Assumes LocalService has exportCheckInOutToExcel(DateTime?) returning a File
      final file = await localService.exportCheckInOutToExcel(fromDate);

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Dữ liệu CheckInOut (Excel), vui lòng kiểm tra file đính kèm.',
          subject: 'Backup CheckInOut Excel',
        ),
      );
      if (!mounted) return;

      scaffoldMessenger.clearSnackBars();
      if (result.status == ShareResultStatus.success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Đã xuất $description thành công'),
                const SizedBox(height: 4),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      await pushLog('Error in _performExportExcel: $e');
      if (!mounted || _scaffoldMessenger == null) return;
      _scaffoldMessenger!.clearSnackBars();
      _scaffoldMessenger!.showSnackBar(
        SnackBar(
          content: Text('Lỗi khi xuất Excel: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Future<void> _performExport(
      BuildContext context, DateTime? fromDate, String description) async {
    if (!mounted) return;
    final navigator = _navigator;
    final scaffoldMessenger = _scaffoldMessenger;

    if (navigator == null || scaffoldMessenger == null) {
      return;
    }
    try {
      _showLoadingSnackBar();
      final localService = getIt<LocalService>();
      final file = await localService.exportCheckInOutToCsv(fromDate);
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Dữ liệu CheckInOut, vui lòng kiểm tra file CSV đính kèm.',
          subject: 'Backup CheckInOut CSV',
        ),
      );
      if (!mounted) {
        return;
      }

      // Clear any existing snackbars
      scaffoldMessenger.clearSnackBars();
      if (!mounted) return;

      if (result.status == ShareResultStatus.success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Đã xuất $description thành công'),
                const SizedBox(height: 4),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      await pushLog('Error in _performExport: $e');
      if (!mounted) {
        return;
      }
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Lỗi khi xuất dữ liệu: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }
}
