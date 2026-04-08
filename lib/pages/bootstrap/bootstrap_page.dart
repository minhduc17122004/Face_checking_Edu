import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/resources/index.dart';
import '../../common/utils/widgets/spacing.dart';

import '../../di/injection.dart';
import '../../route/app_route.dart';
import '../../route/navigator.dart';
import 'bootstrap_cubit.dart';
import 'bootstrap_state.dart';

class BootstrapPage extends StatefulWidget {
  const BootstrapPage({Key? key}) : super(key: key);

  @override
  State<BootstrapPage> createState() => _BootstrapPageState();
}

class _BootstrapPageState extends State<BootstrapPage> {
  final BootstrapCubit _bloc = getIt<BootstrapCubit>();

  Future<String> _resolvePostAuthRoute() async {
    return RouterName.home;
  }

  void _navigateAfterAuth() {
    Future.delayed(const Duration(seconds: 1)).then((_) async {
      final targetRoute = await _resolvePostAuthRoute();
      AppNavigator.pushNamedAndRemoveUntil(targetRoute, (_) => false);
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _bloc.initData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppColors.white,
        child: Center(
          child: BlocProvider<BootstrapCubit>(
            create: (_) => _bloc,
            child: BlocConsumer<BootstrapCubit, BootstrapState>(
              listener: _handleStateListener,
              builder: (BuildContext context, BootstrapState state) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        textAlign: TextAlign.center,
                        'Vedura',
                        style: TextStyles.blackBigBold.copyWith(fontSize: 50),
                      ),
                      const Spacing(),
                      Text(
                        textAlign: TextAlign.center,
                        'Hệ thống điểm danh thông minh',
                        style: TextStyles.blackBigBold.copyWith(fontSize: 35),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _handleStateListener(BuildContext context, BootstrapState state) {
    switch (state.status) {
      case BootstrapStatus.authenticated:
      case BootstrapStatus.offlineMode:
        _navigateAfterAuth();
        break;
      case BootstrapStatus.unauthenticated:
        Future.delayed(const Duration(seconds: 4)).then((value) {
          AppNavigator.pushNamedAndRemoveUntil(RouterName.login, (_) => false);
        });
        break;
      case BootstrapStatus.domainError:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Không kết nối được server đã lưu (có thể do đổi mạng). Vui lòng cập nhật URL server.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        Future.delayed(const Duration(seconds: 1)).then((value) {
          AppNavigator.pushNamedAndRemoveUntil(RouterName.domain, (_) => false);
        });
        break;
      case BootstrapStatus.initial:
        break;
    }
  }
}
