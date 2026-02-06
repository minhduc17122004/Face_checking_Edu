import 'dart:async';

import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/utils/extensions/buildcontext_extension.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/pages/checking/bloc/checking_bloc.dart';
import 'package:face_time_keeping/pages/checking/widgets/checkout_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/resources/index.dart';
import '../../common/utils/widgets/spacing.dart';
import '../../route/navigator.dart';
import 'bloc/checking_state.dart';
import 'widgets/check_in_widget.dart';
import 'widgets/face_detector_view.dart';

class CheckingArgs {
  final bool isCheckIn;

  const CheckingArgs({
    required this.isCheckIn,
  });
}

class CheckingPage extends StatefulWidget {
  const CheckingPage({super.key});

  @override
  State<CheckingPage> createState() => _CheckingPageState();
}

class _CheckingPageState extends State<CheckingPage> {
  final CheckingBloc _bloc = getIt<CheckingBloc>();
  final GlobalKey<FaceDetectorViewState> _faceDetectorKey = GlobalKey();
  final Duration _timeNotFoundFace = const Duration(minutes: 3);
  Timer? _faceNotFoundTimer;

  @override
  void initState() {
    super.initState();
    _resetFaceNotFoundTimer();
  }

  @override
  void dispose() {
    _faceNotFoundTimer?.cancel();
    super.dispose();
  }

  void _resetFaceNotFoundTimer() {
    debugPrint('resetFaceNotFoundTimer');
    _faceNotFoundTimer?.cancel();
    _faceNotFoundTimer = Timer(_timeNotFoundFace, () {
      if (mounted) {
        debugPrint('time not found face');
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final CheckingArgs? args = context.getRouteArguments();
    return FutureBuilder<void>(
      future: _bloc.init(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Đang lấy dữ liệu vị trí',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SelectableText.rich(
                  TextSpan(
                    text: 'Lỗi quyền vị trí: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return BlocProvider<CheckingBloc>(
          create: (_) => _bloc,
          child: BlocConsumer<CheckingBloc, CheckingState>(
            listener: (_, state) {
              switch (state.requestStatus) {
                case RequestStatus.initial:
                  break;
                case RequestStatus.requesting:
                  _bloc.setAllowCapture(false);
                  break;
                case RequestStatus.success:
                  _bloc.setAllowCapture(false);
                  break;
                case RequestStatus.failed:
                  _bloc.setAllowCapture(true);
                  break;
              }
            },
            builder: (_, state) => Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildResponsiveLayout(context, state, args),
                ),
              ),
              floatingActionButton: _buildCameraSwitchButton(),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerTop,
            ),
          ),
        );
      },
    );
  }

  Widget _buildResponsiveLayout(
    BuildContext context,
    CheckingState state,
    CheckingArgs? args,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = context.isLandscape();
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        if (isLandscape) {
          return _buildLandscapeLayout(
              context, state, args, screenWidth, screenHeight);
        } else {
          return _buildPortraitLayout(
              context, state, args, screenWidth, screenHeight);
        }
      },
    );
  }

  Widget _buildLandscapeLayout(
    BuildContext context,
    CheckingState state,
    CheckingArgs? args,
    double screenWidth,
    double screenHeight,
  ) {
    return Row(
      children: [
        // Camera section takes more space in landscape
        Expanded(
          flex: 3,
          child: FaceDetectorView(
            key: _faceDetectorKey,
            allowCapture: state.isAllowCapture,
            onCapture: (file) {
              _bloc.verify(file, args?.isCheckIn ?? false);
              _resetFaceNotFoundTimer();
            },
          ),
        ),
        const Spacing(),
        // Control panel
        Expanded(
          flex: 2,
          child: _buildControlPanel(context, state, args, isLandscape: true),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout(
    BuildContext context,
    CheckingState state,
    CheckingArgs? args,
    double screenWidth,
    double screenHeight,
  ) {
    return Column(
      children: [
        // Camera section
        const Spacing(),
        Expanded(
          flex: 3,
          child: FaceDetectorView(
            key: _faceDetectorKey,
            isPortrait: true,
            allowCapture: state.isAllowCapture,
            onCapture: (file) {
              _bloc.verify(file, args?.isCheckIn ?? false);
              _resetFaceNotFoundTimer();
            },
          ),
        ),
        const Spacing(),
        // Control panel
        Expanded(
          flex: 2,
          child: _buildControlPanel(context, state, args, isLandscape: false),
        ),
      ],
    );
  }

  Widget _buildControlPanel(
    BuildContext context,
    CheckingState state,
    CheckingArgs? args, {
    required bool isLandscape,
  }) {
    if (isLandscape) {
      return SingleChildScrollView(
        child: Column(
          children: [
            if (state.requestStatus == RequestStatus.requesting)
              _buildLoadingIndicator(isLandscape),
            if (state.checkingStatus == RequestStatus.requesting)
              _buildLoadingIndicator(isLandscape)
            else if (state.checkIn != null)
              _buildCheckInSection(state, isLandscape)
            else if (state.checkOut != null)
              _buildCheckOutSection(state, isLandscape)
            else if ((state.checkingMessage?.isNotEmpty ?? false) ||
                (state.message?.isNotEmpty ?? false))
              _buildErrorMessage(state, isLandscape),
            const SizedBox(height: 16),
            _buildBackButton(isLandscape),
          ],
        ),
      );
    } else {
      // Portrait layout with proper spacing
      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (state.requestStatus == RequestStatus.requesting)
                    _buildLoadingIndicator(isLandscape),
                  if (state.checkingStatus == RequestStatus.requesting)
                    _buildLoadingIndicator(isLandscape)
                  else if ((state.checkingMessage?.isNotEmpty ?? false) ||
                      (state.message?.isNotEmpty ?? false))
                    _buildErrorMessage(state, isLandscape)
                  else if (state.checkIn != null)
                    _buildCheckInSection(state, isLandscape)
                  else if (state.checkOut != null)
                    _buildCheckOutSection(state, isLandscape)
                ],
              ),
            ),
          ),
          // Back button always at bottom in portrait
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _buildBackButton(isLandscape),
          ),
        ],
      );
    }
  }

  Widget _buildLoadingIndicator(bool isLandscape) {
    final size = isLandscape ? 40.0 : 60.0;
    return SizedBox(
      height: size,
      width: size,
      child: const CircularProgressIndicator(),
    );
  }

  Widget _buildCheckInSection(CheckingState state, bool isLandscape) {
    return SizedBox(
      width: double.infinity,
      child: CheckInWidget(
        checkInData: state.checkIn,
      ),
    );
  }

  Widget _buildCheckOutSection(CheckingState state, bool isLandscape) {
    return SizedBox(
      width: double.infinity,
      child: CheckOutWidget(
        checkOut: state.checkOut,
      ),
    );
  }

  Widget _buildErrorMessage(CheckingState state, bool isLandscape) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 8 : 16,
        vertical: 8,
      ),
      child: Text(
        state.checkingMessage ?? state.message ?? '',
        style: TextStyles.blackNormalRegular.copyWith(
          color: AppColors.red,
          fontSize: 20,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBackButton(bool isLandscape) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () {
          AppNavigator.pop();
        },
        style: TextButton.styleFrom(
          backgroundColor: AppColors.black,
          padding: EdgeInsets.symmetric(
            vertical: isLandscape ? 12 : 16,
          ),
        ),
        child: Text(
          'Quay lại',
          style: TextStyles.blackNormalRegular.copyWith(
            color: AppColors.white,
            fontSize: isLandscape ? 14 : 16,
          ),
        ),
      ),
    );
  }

  Widget _buildCameraSwitchButton() {
    return FloatingActionButton(
      heroTag: "cameraSwitchButton",
      onPressed: () async {
        debugPrint('Switch camera button pressed');
        await _faceDetectorKey.currentState?.switchCamera();
      },
      backgroundColor: AppColors.black.withOpacity(0.7),
      child: const Icon(
        Icons.flip_camera_ios_outlined,
        color: AppColors.white,
        size: 28,
      ),
    );
  }

  // Future<void> _reset() async {
  //   await _bloc.reset();
  //   await Future.delayed(const Duration(seconds: 2));
  //   if (mounted) {
  //     setState(() {
  //       _allowCapture = true;
  //     });
  //   }
  // }
}
