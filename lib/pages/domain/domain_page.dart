import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/utils/widgets/app_text_field.dart';
import 'package:face_time_keeping/pages/domain/bloc/domain_bloc.dart';
import 'package:face_time_keeping/pages/widgets/default_app_bar.dart';
import 'package:face_time_keeping/route/app_route.dart';
import 'package:face_time_keeping/route/navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/resources/index.dart';
import '../../di/injection.dart';

import 'bloc/domain_state.dart';

class DomainPage extends StatefulWidget {
  const DomainPage({super.key});

  @override
  State<DomainPage> createState() => _DomainPageState();
}

class _DomainPageState extends State<DomainPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final DomainBloc _bloc = getIt<DomainBloc>();

  final TextEditingController _domainController = TextEditingController();

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _bloc.initDomain();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DomainBloc>(
      create: (_) => _bloc,
      child: BlocConsumer<DomainBloc, DomainState>(
        listener: _handleStateListener,
        builder: (context, state) => Scaffold(
          backgroundColor: AppColors.white,
          resizeToAvoidBottomInset: true,
          appBar: DefaultAppBar(
            backgroundColor: AppColors.white,
            titleText: "URL",
          ),
          body: _buildBody(context, state),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, DomainState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final orientation = MediaQuery.of(context).orientation;
        final isLandscape = orientation == Orientation.landscape;
        final isWide = constraints.maxWidth > 800;

        final double maxContentWidth =
            isLandscape ? (isWide ? 900 : 720) : (isWide ? 720 : 560);

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxContentWidth,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 24 : 24,
                  ),
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              vertical: 24.0,
                            ).copyWith(bottom: 100),
                            child: _buildForm(
                              context,
                              state,
                              constraints,
                              isLandscape: isLandscape,
                            ),
                          ),
                        ),
                        _buildSubmitButton(state, constraints),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm(
    BuildContext context,
    DomainState state,
    BoxConstraints constraints, {
    required bool isLandscape,
  }) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          if (!isLandscape) ...[
            _buildDomainField(state),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildDomainField(state)),
              ],
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDomainField(DomainState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Url',
          style: TextStyles.blackNormalRegular.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        AppTextField(
          maxLines: 1,
          hintText: 'http://192.168.x.x:8000',
          style: TextStyles.blackNormalRegular.copyWith(
            overflow: TextOverflow.ellipsis,
            color: AppColors.black,
          ),
          controller: _domainController,
          onChanged: (String text) => _bloc.onChangedDomain(text),
          suffixIcon: _buildClearIcon(
            isVisible: (state.cachedDomain ?? '').isEmpty &&
                _domainController.text.isNotEmpty,
            onTap: () {
              _bloc.onChangedDomain("");
              _domainController.clear();
            },
          ),
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
        ),
      ],
    );
  }

  Widget? _buildClearIcon(
      {required bool isVisible, required VoidCallback onTap}) {
    if (!isVisible) return null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Icon(
          Icons.clear,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildSubmitButton(DomainState state, BoxConstraints constraints) {
    final buttonWidth = constraints.maxWidth > 600 ? 300.0 : double.infinity;
    final isLoading = state.requestStatus == RequestStatus.requesting;

    return SizedBox(
      width: buttonWidth,
      child: ElevatedButton(
        onPressed: isLoading ? null : () => _onSubmit(state),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.black,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Future<void> _handleStateListener(
      BuildContext context, DomainState state) async {
    if (state.domain != null &&
        state.domain!.isNotEmpty &&
        _domainController.text.isEmpty) {
      _domainController.text = state.domain!;
    } else if (state.domain?.isEmpty ?? false) {
      _domainController.clear();
    }

    // Show error message if exists
    if (state.message != null && state.message!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message!),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    if (state.dbNames.isNotEmpty) {
      AppNavigator.pushNamed(RouterName.chooseDb, arguments: state.dbNames);
    }
  }

  Future<void> _onSubmit(DomainState state) async {
    _bloc.onAccessDomain();
    await Future.delayed(const Duration(milliseconds: 500));
    // AppNavigator.pushNamedAndRemoveUntil(RouterName.login, (_) => false);
  }
}
