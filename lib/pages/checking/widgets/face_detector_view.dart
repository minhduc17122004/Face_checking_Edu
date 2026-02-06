import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:debounce_throttle/debounce_throttle.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'detector_view.dart';
import 'coordinates_translator.dart';

class FaceDetectorView extends StatefulWidget {
  final Function(XFile? file)? onCapture;
  final bool allowCapture;
  final bool isPortrait;
  // Make frame size adjustable
  final double centerFrameRatio; // Ratio of screen width (0.0 to 1.0)
  const FaceDetectorView({
    super.key,
    this.onCapture,
    this.allowCapture = true,
    this.centerFrameRatio = 0.4, // Default 70% of screen width
    this.isPortrait = false,
  });

  @override
  State<FaceDetectorView> createState() => FaceDetectorViewState();
}

class FaceDetectorViewState extends State<FaceDetectorView> {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      minFaceSize: 0.3,
    ),
  );
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  var _cameraLensDirection = CameraLensDirection.front;
  final GlobalKey<DetectorViewState> key = GlobalKey();
  Timer? _timer;
  int _timeCount = 0;
  // Center frame parameters
  Rect? _centerFrame;
  bool _isFaceCentered = false;
  InputImageRotation? _currentRotation;
  CameraLensDirection? _currentLensDirection;
  late final Throttle<InputImage> _throttledProcessor;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _timeCount += 1;
    });
    _throttledProcessor = Throttle<InputImage>(
      const Duration(milliseconds: 500),
      initialValue: InputImage.fromBytes(
        bytes: Uint8List(0),
        metadata: InputImageMetadata(
          size: Size.zero,
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 0,
        ),
      ),
      onChanged: (inputImage) => _handleThrottledProcess(inputImage),
    );
  }

  @override
  void dispose() {
    _canProcess = false;
    _faceDetector.close();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        // Update center frame based on parent constraints
        _updateCenterFrame(Size(constraints.maxWidth, constraints.maxHeight));
        return Stack(
          fit: StackFit.expand,
          children: [
            DetectorView(
              key: key,
              customPaint: _customPaint,
              onImage: _processImage,
              initialCameraLensDirection: _cameraLensDirection,
              onCameraLensDirectionChanged: (value) =>
                  _cameraLensDirection = value,
            ),
            // Center Frame Guide
            if (_centerFrame != null)
              CustomPaint(
                painter: CenterFramePainter(
                  centerFrame: _centerFrame!,
                  isFaceCentered: _isFaceCentered,
                ),
              ),

            // Optional: Status Indicator
            if (!_isFaceCentered)
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isFaceCentered ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Di chuyển khuôn mặt vào khung đỏ',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _processImage(InputImage inputImage) {
    _throttledProcessor.value = inputImage;
  }

  Future<void> _handleThrottledProcess(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    final imageSize =
        Size(inputImage.metadata!.size.width, inputImage.metadata!.size.height);
    _currentRotation = inputImage.metadata?.rotation;
    _currentLensDirection = _cameraLensDirection;
    RenderBox? renderBox;
    if (!mounted) return;
    renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      _isBusy = false;
      return;
    }
    final Size parentSize = renderBox.size;
    // Process full image but only check faces in center frame region
    final faces = await _faceDetector.processImage(inputImage);

    if (faces.isNotEmpty) {
      // Filter faces that are within the center frame
      final facesInCenterFrame = faces
          .where((face) => _isFaceInCenterFrame(
                face: face,
                imageSize: imageSize,
                parentSize: parentSize,
              ))
          .toList();

      final bool isCentered = facesInCenterFrame.isNotEmpty;
      setState(() {
        _isFaceCentered = isCentered;
      });

      if (isCentered && facesInCenterFrame.length == 1) {
        if (widget.allowCapture && _timeCount >= 2) {
          final file = await key.currentState?.capture();
          widget.onCapture?.call(file);
          _timeCount = 0;
        }
      }
    } else {
      setState(() {
        _isFaceCentered = false;
      });
    }
    _isBusy = false;

    if (!mounted) return;
    setState(() {});
  }

  bool _isFaceInCenterFrame({
    required Face face,
    required Size imageSize,
    required Size parentSize,
  }) {
    if (_centerFrame == null) {
      return false;
    }
    // Convert face coordinates from image to screen space
    final Rect faceRect = _convertRect(
      face.boundingBox,
      imageSize,
      parentSize,
    );
    final result = _centerFrame!.contains(faceRect.center) &&
        (widget.isPortrait ? faceRect.height.abs() : faceRect.width.abs()) <=
            _centerFrame!.width * 0.9 && // Face not too big
        faceRect.width.abs() >= _centerFrame!.width * 0.3; //;
    return result;
  }

  Rect _convertRect(Rect rect, Size imageSize, Size screenSize) {
    // Use proper coordinate translation if rotation and lens direction are available
    if (_currentRotation != null && _currentLensDirection != null) {
      final left = translateX(
        rect.left,
        screenSize,
        imageSize,
        _currentRotation!,
        _currentLensDirection!,
      );
      final top = translateY(
        rect.top,
        screenSize,
        imageSize,
        _currentRotation!,
        _currentLensDirection!,
      );
      final right = translateX(
        rect.right,
        screenSize,
        imageSize,
        _currentRotation!,
        _currentLensDirection!,
      );
      final bottom = translateY(
        rect.bottom,
        screenSize,
        imageSize,
        _currentRotation!,
        _currentLensDirection!,
      );

      return Rect.fromLTRB(left, top, right, bottom);
    }

    final double scaleX = screenSize.width / imageSize.width;
    final double scaleY = screenSize.height / imageSize.height;

    return Rect.fromLTWH(
      rect.left * scaleX,
      rect.top * scaleY,
      rect.width * scaleX,
      rect.height * scaleY,
    );
  }

  void _updateCenterFrame(Size screenSize) {
    final double frameSize = screenSize.width * widget.centerFrameRatio;
    final double left = (screenSize.width - frameSize) / 2;
    final double top = (screenSize.height - frameSize) / 2;

    _centerFrame = Rect.fromLTWH(left, top, frameSize, frameSize);
  }

  Future<void> switchCamera() async {
    await key.currentState?.switchCamera();
  }
}

// Custom Painter for the center frame
class CenterFramePainter extends CustomPainter {
  final Rect centerFrame;
  final bool isFaceCentered;
  CenterFramePainter({
    required this.centerFrame,
    required this.isFaceCentered,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = isFaceCentered ? Colors.green : Colors.red;

    // Draw the main frame
    canvas.drawRect(centerFrame, paint);

    // Draw corner indicators
    final double cornerSize = centerFrame.width * 0.001;
    final List<Rect> corners = [
      // Top-left corner
      Rect.fromLTWH(
        centerFrame.left,
        centerFrame.top,
        cornerSize,
        cornerSize,
      ),
      // Top-right corner
      Rect.fromLTWH(
        centerFrame.right - cornerSize,
        centerFrame.top,
        cornerSize,
        cornerSize,
      ),
      // Bottom-left corner
      Rect.fromLTWH(
        centerFrame.left,
        centerFrame.bottom - cornerSize,
        cornerSize,
        cornerSize,
      ),
      // Bottom-right corner
      Rect.fromLTWH(
        centerFrame.right - cornerSize,
        centerFrame.bottom - cornerSize,
        cornerSize,
        cornerSize,
      ),
    ];

    // Draw corners
    for (final corner in corners) {
      canvas.drawRect(corner, paint..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(CenterFramePainter oldDelegate) =>
      oldDelegate.isFaceCentered != isFaceCentered;
}
