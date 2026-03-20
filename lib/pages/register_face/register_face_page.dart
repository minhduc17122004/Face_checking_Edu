import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/utils/alerts.dart';
import 'package:face_time_keeping/common/utils/extensions/buildcontext_extension.dart';
import 'package:face_time_keeping/common/utils/widgets/loading_indicator.dart';
import 'package:face_time_keeping/di/injection.dart';

import 'package:face_time_keeping/pages/register_face/bloc/register_face_bloc.dart';
import 'package:face_time_keeping/pages/register_face/bloc/register_face_state.dart';
import 'package:face_time_keeping/pages/widgets/default_app_bar.dart';

import 'package:face_time_keeping/route/navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_liveness_detection_randomized_plugin/index.dart';

import '../../common/resources/index.dart';

class RegisterFacePage extends StatefulWidget {
  const RegisterFacePage({super.key});

  @override
  State<RegisterFacePage> createState() => _RegisterFacePageState();
}

class _RegisterFacePageState extends State<RegisterFacePage> {
  final RegisterFaceBloc _bloc = getIt();

  String? imgPath;
  List<int> oldImageIds = []; // only use for update face

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final student = context.getRouteArguments();
      _bloc.init(student);
    });
  }

  Future<void> _onResetSteps() async {
    await _bloc.onLivenessResetStep();
  }

  Future<bool> _onLivenessSuccessStep(String? imagePath) async {
    debugPrint('Captured !!!');
    return _bloc.onLivenessSuccessStep(imagePath);
  }

  @override
  Widget build(BuildContext context) {
    // Student entity from route arguments (Education system)
    return BlocProvider<RegisterFaceBloc>(
      create: (_) => _bloc,
      child: Scaffold(
        appBar: DefaultAppBar(
          titleText: 'HỌC SINH',
        ),
        body: BlocConsumer<RegisterFaceBloc, RegisterFaceState>(
          listener: (_, state) {
            switch (state.requestStatus) {
              case RequestStatus.initial:
                break;
              case RequestStatus.requesting:
                IgnoreLoadingIndicator().show(context);
                break;
              case RequestStatus.success:
                IgnoreLoadingIndicator().hide(context);
                if (state.message?.isNotEmpty ?? false) {
                  showTopAlert(context,
                      title: state.message, type: AlertType.success);
                  AppNavigator.pop();
                }
                break;
              case RequestStatus.failed:
                IgnoreLoadingIndicator().hide(context);
                if (state.message?.isNotEmpty ?? false) {
                  showTopAlert(context,
                      title: state.message, type: AlertType.error);
                }
                break;
            }
          },
          builder: (_, state) => Center(
            child: TextButton(
              onPressed: () async {
                if (state.student?.pin == null) {
                  showTopAlert(context,
                      title: 'Cảnh báo chưa có mã học sinh',
                      type: AlertType.warning);
                  return;
                }
                final String? response =
                    await FlutterLivenessDetectionRandomizedPlugin.instance
                        .livenessDetection(
                  onLivenessSuccessStep: _onLivenessSuccessStep,
                  onLivenessResetStep: _onResetSteps,
                  context: context,
                  config: LivenessDetectionConfig(
                    imageQuality: 100,
                    isEnableMaxBrightness: true,
                    durationLivenessVerify: 100,
                    showDurationUiText: false,
                    startWithInfoScreen: false,
                    useCustomizedLabel: true,
                    customizedLabel: LivenessDetectionLabelModel(
                      smile: 'Vui lòng mỉm cười',
                      blink: 'Vui lòng chớp mắt',
                      straightFace: 'Giữ khuôn mặt thẳng',
                      lookUp: 'Ngẩng nhẹ khuôn mặt',
                      lookDown: 'Cúi nhẹ khuôn mặt',
                      lookLeft: 'Quay nhẹ sang trái',
                      lookRight: 'Quay nhẹ sang phải',
                    ),
                  ),
                  isEnableSnackBar: true,
                  shuffleListWithSmileLast: false,
                  isDarkMode: false,
                  showCurrentStep: true,
                );
                if (mounted) {
                  setState(() {
                    imgPath = response;
                    if (imgPath != null) {
                      if (state.isRegistered) {
                        _bloc.updateFace();
                      } else {
                        _bloc.registerFace();
                      }
                    } else {
                      _bloc.removeAddedImageIds();
                      showTopAlert(context,
                          title: 'Quá trình đăng ký đã bị hủy',
                          type: AlertType.error);
                    }
                  });
                }
              },
              style: TextButton.styleFrom(backgroundColor: AppColors.black),
              child: Text(
                (state.isRegistered)
                    ? 'Cập nhật khuôn mặt'
                    : 'Đăng ký khuôn mặt',
                style: TextStyles.blackNormalRegular
                    .copyWith(color: AppColors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
