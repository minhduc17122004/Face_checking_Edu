import 'dart:async';

import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/common/utils/extensions/buildcontext_extension.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/room_session.dart';
import 'package:face_time_keeping/pages/checking/widgets/face_detector_view.dart';
import 'package:face_time_keeping/pages/edu_checking/bloc/edu_checking_bloc.dart';
import 'package:face_time_keeping/pages/edu_checking/bloc/edu_checking_state.dart';
import 'package:face_time_keeping/pages/edu_checking/widgets/edu_check_in_result_widget.dart';
import 'package:face_time_keeping/route/navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EduCheckingArgs {
  final RoomSession session;

  const EduCheckingArgs({required this.session});
}

class EduCheckingPage extends StatefulWidget {
  final EduCheckingArgs args;

  const EduCheckingPage({super.key, required this.args});

  @override
  State<EduCheckingPage> createState() => _EduCheckingPageState();
}

class _EduCheckingPageState extends State<EduCheckingPage> {
  late final EduCheckingBloc _bloc;
  late final Future<void> _initFuture;
  final GlobalKey<FaceDetectorViewState> _faceDetectorKey = GlobalKey();
  final Duration _timeoutDuration = const Duration(minutes: 3);
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<EduCheckingBloc>();
    _initFuture = _bloc.init(widget.args.session.id);
    _resetTimeout();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _resetTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_timeoutDuration, () {
      if (mounted) AppNavigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Lỗi khởi động: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return BlocProvider.value(
          value: _bloc,
          child: BlocConsumer<EduCheckingBloc, EduCheckingState>(
            listener: (_, state) {
              switch (state.faceStatus) {
                case RequestStatus.requesting:
                  _bloc.setAllowCapture(false);
                  break;
                case RequestStatus.failed:
                  _bloc.setAllowCapture(true);
                  break;
                default:
                  break;
              }
            },
            builder: (_, state) => Scaffold(
              backgroundColor: AppColors.backgroundLight,
              appBar: _buildAppBar(),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      if (ctx.isLandscape()) {
                        return _buildLandscape(state);
                      }
                      return _buildPortrait(state);
                    },
                  ),
                ),
              ),
              floatingActionButton: FloatingActionButton(
                heroTag: 'eduCameraSwitchBtn',
                mini: true,
                backgroundColor: Colors.black54,
                onPressed: () => _faceDetectorKey.currentState?.switchCamera(),
                child: const Icon(Icons.flip_camera_ios_outlined,
                    color: Colors.white),
              ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerTop,
            ),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      centerTitle: true,
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.slate900),
        onPressed: () => AppNavigator.pop(),
      ),
      title: Column(
        children: [
          Text(
            widget.args.session.courseName,
            style: const TextStyle(
              color: AppColors.slate900,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          Text(
            '${widget.args.session.formattedDate} • ${widget.args.session.formattedStartTime}',
            style: const TextStyle(color: AppColors.slate500, fontSize: 11),
          ),
        ],
      ),
      actions: [
        BlocBuilder<EduCheckingBloc, EduCheckingState>(
          builder: (_, state) {
            if (!state.hasPendingSync) return const SizedBox.shrink();
            return const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Tooltip(
                message: 'Có bản ghi chờ đồng bộ',
                child: Icon(Icons.cloud_upload, color: Colors.amber),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLandscape(EduCheckingState state) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _buildCamera(state),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _buildControlPanel(state),
        ),
      ],
    );
  }

  Widget _buildPortrait(EduCheckingState state) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: _buildCamera(state),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: _buildControlPanel(state),
          ),
        ),
      ],
    );
  }

  Widget _buildCamera(EduCheckingState state) {
    return FaceDetectorView(
      key: _faceDetectorKey,
      isPortrait: true,
      allowCapture: state.isAllowCapture,
      onCapture: (file) {
        _bloc.verify(file);
        _resetTimeout();
      },
    );
  }

  Widget _buildControlPanel(EduCheckingState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Summary card
        if (state.summary != null) _buildSummaryRow(state),
        const SizedBox(height: 8),
        // Result / loading / error
        if (state.faceStatus == RequestStatus.requesting ||
            state.checkinStatus == RequestStatus.requesting)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          )
        else if (state.lastCheckIn != null)
          EduCheckInResultWidget(checkIn: state.lastCheckIn!)
        else if (state.errorMessage != null && state.errorMessage!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              state.errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Hướng khuôn mặt vào camera',
              style: TextStyle(color: AppColors.slate500, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        // Back button
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => AppNavigator.pop(),
            child: const Text('Quay lại',
                style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(EduCheckingState state) {
    final s = state.summary!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Sớm', '${s.early}', const Color(0xFF0D9488)),
          _statItem('Đúng giờ', '${s.onTime}', Colors.green),
          _statItem('Trễ', '${s.late}', Colors.orange),
          _statItem('Vắng', '${s.absent}', Colors.red),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: AppColors.slate500, fontSize: 11)),
      ],
    );
  }
}
