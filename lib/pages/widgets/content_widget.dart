import 'package:flutter/material.dart';

import '../../common/resources/index.dart';
import 'empty_state_widget.dart';

enum DataSourceStatus { initial, loading, refreshing, empty, success, failed, loadMore }

typedef RefreshCallback = Future<void> Function(BuildContext context);

class ContentBundle extends StatefulWidget {
  ContentBundle({
    Key? key,
    required Widget child,
    required this.status,
    required this.onRefresh,
    this.onLoadMore,
    this.emptyEnable = true,
    this.emptyBackground = Colors.white,
    this.emptyTitle,
    this.emptyActionTitle,
    this.emptyAction,
    this.showCustomEmptyTitle = false,
    this.currentScrollOffset,
  })  : child = _builderOrNull(child)!,
        super(key: key);

  final WidgetBuilder child;
  final DataSourceStatus? status;
  final RefreshCallback onRefresh;
  final RefreshCallback? onLoadMore;

  final bool emptyEnable;
  final Color emptyBackground;
  final String? emptyTitle;
  final String? emptyActionTitle;
  final Function(BuildContext)? emptyAction;
  final bool showCustomEmptyTitle;
  final Function(double offset)? currentScrollOffset;

  static WidgetBuilder? _builderOrNull(Widget? widget) {
    return widget == null ? null : ((_) => widget);
  }

  @override
  _ContentBundleState createState() => _ContentBundleState();
}

class _ContentBundleState extends State<ContentBundle> {
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      child: _buildContent(context),
      onNotification: (ScrollNotification value) => _onNotification(context, value),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (widget.status) {
      case DataSourceStatus.initial:
      case DataSourceStatus.loading:
        return _buildLoadingWidget();
      case DataSourceStatus.refreshing:
        return _buildRefreshingWidget(context);
      case DataSourceStatus.empty:
        return widget.emptyEnable ? _buildEmptyWidget(context) : Container();
      case DataSourceStatus.loadMore:
      case DataSourceStatus.success:
        return _buildSuccessWidget(context);
      case DataSourceStatus.failed:
      default:
        return _buildFailedWidget(context);
    }
  }

  Widget _buildFailedWidget(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => widget.onRefresh(context),
      child: widget.emptyEnable ? _buildEmptyWidget(context) : Container(),
    );
  }

  Widget _buildSuccessWidget(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => widget.onRefresh(context),
            color: AppColors.black,
            child: widget.child(context),
          ),
        ),
        Visibility(
          visible: widget.status == DataSourceStatus.loadMore && widget.onLoadMore != null,
          child: Container(
            height: 20,
            width: 20,
            margin: const EdgeInsets.all(8),
            child: const CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.black,
            ),
          ),
        )
      ],
    );
  }

  Widget _buildEmptyWidget(BuildContext context) {
    return EmptyStateWidget(
      background: widget.emptyBackground,
      onActionTapped: widget.emptyAction,
      titleAction: widget.emptyActionTitle ?? Strings.localized.retry,
      title: widget.showCustomEmptyTitle ? widget.emptyTitle : null,
    );
  }

  Widget _buildRefreshingWidget(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child(context),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LinearProgressIndicator(
            minHeight: 2.0,
            color: AppColors.black,
            backgroundColor: AppColors.transparent,
          ),
        ),
      ],
    );
  }

  Center _buildLoadingWidget() => const Center(
          child: CircularProgressIndicator(
        color: AppColors.black,
      ));

  bool _onNotification(BuildContext context, ScrollNotification scrollInfo) {
    if (scrollInfo is ScrollEndNotification) {
      widget.currentScrollOffset?.call(scrollInfo.metrics.pixels);
      if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
        widget.onLoadMore?.call(context);
      }
    }
    return true;
  }
}
