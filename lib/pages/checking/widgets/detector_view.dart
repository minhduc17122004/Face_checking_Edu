import 'package:flutter_liveness_detection_randomized_plugin/index.dart';

import 'camera_view.dart';

class DetectorView extends StatefulWidget {
  const DetectorView({
    Key? key,
    required this.onImage,
    this.customPaint,
    this.initialCameraLensDirection = CameraLensDirection.back,
    this.onCameraFeedReady,
    this.onCameraLensDirectionChanged,
  }) : super(key: key);

  final CustomPaint? customPaint;
  final Function(InputImage inputImage) onImage;
  final Function()? onCameraFeedReady;
  final Function(CameraLensDirection direction)? onCameraLensDirectionChanged;
  final CameraLensDirection initialCameraLensDirection;

  @override
  State<DetectorView> createState() => DetectorViewState();
}

class DetectorViewState extends State<DetectorView> {
  final GlobalKey<CameraViewState> key = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CameraView(
        key: key,
        customPaint: widget.customPaint,
        onImage: widget.onImage,
        onCameraFeedReady: widget.onCameraFeedReady,
        initialCameraLensDirection: widget.initialCameraLensDirection,
        onCameraLensDirectionChanged: widget.onCameraLensDirectionChanged,
      ),
    );
  }

  Future<XFile?> capture() async {
    final file = await key.currentState?.capture();
    return file;
  }

  Future<void> switchCamera() async {
    await key.currentState?.switchCamera();
  }
}
