import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Color;
import 'package:flutter/material.dart' as material show Color;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class TestImagePage extends StatefulWidget {
  const TestImagePage({super.key});

  @override
  State<TestImagePage> createState() => _TestImagePageState();
}

class _TestImagePageState extends State<TestImagePage> {
  File? _originalImageFile;
  img.Image? _originalImage;
  Uint8List? _adjustedImageBytes;
  bool _isProcessing = false;

  // Numeric parameters
  double _contrast = 1.0;
  double _saturation = 1.0;
  double _brightness = 1.0;
  double _gamma = 1.0;
  double _exposure = 0.0;
  double _hue = 0.0;
  double _amount = 1.0;

  // Color parameters (using Material Color for UI)
  material.Color? _blacksUI;
  material.Color? _whitesUI;
  material.Color? _midsUI;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (image != null) {
        final file = File(image.path);
        final bytes = await file.readAsBytes();
        final decodedImage = img.decodeImage(bytes);

        if (decodedImage != null) {
          setState(() {
            _originalImageFile = file;
            _originalImage = decodedImage;
            _adjustedImageBytes = null;
          });
          _applyAdjustments();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  // Convert Material Color to Image package Color
  img.Color? _convertColor(material.Color? color) {
    if (color == null) return null;
    return img.ColorRgb8(color.red, color.green, color.blue);
  }

  Future<void> _applyAdjustments() async {
    if (_originalImage == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Create a copy of the original image
      final imageCopy = img.Image.from(_originalImage!);

      // Apply adjustments
      final adjusted = img.adjustColor(
        imageCopy,
        blacks: _convertColor(_blacksUI),
        whites: _convertColor(_whitesUI),
        mids: _convertColor(_midsUI),
        contrast: _contrast,
        saturation: _saturation,
        brightness: _brightness,
        gamma: _gamma,
        exposure: _exposure,
        hue: _hue,
        amount: _amount,
      );

      // Encode to bytes for display
      final encoded = img.encodePng(adjusted);

      setState(() {
        _adjustedImageBytes = Uint8List.fromList(encoded);
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing image: $e')),
        );
      }
    }
  }

  void _resetParameters() {
    setState(() {
      _contrast = 1.0;
      _saturation = 1.0;
      _brightness = 1.0;
      _gamma = 1.0;
      _exposure = 0.0;
      _hue = 0.0;
      _amount = 1.0;
      _blacksUI = null;
      _whitesUI = null;
      _midsUI = null;
    });
    _applyAdjustments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Color Adjustment Test'),
        actions: [
          if (_originalImage != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetParameters,
              tooltip: 'Reset Parameters',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildImageDisplay(),
          ),
          if (_originalImage != null)
            Expanded(
              child: _buildControlsPanel(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickImage,
        child: const Icon(Icons.add_photo_alternate),
      ),
    );
  }

  Widget _buildImageDisplay() {
    if (_originalImage == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 100,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Tap + to select an image',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        if (_adjustedImageBytes != null)
          InteractiveViewer(
            child: Center(
              child: Image.memory(
                _adjustedImageBytes!,
                fit: BoxFit.contain,
              ),
            ),
          )
        else if (_originalImageFile != null)
          InteractiveViewer(
            child: Center(
              child: Image.file(
                _originalImageFile!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        if (_isProcessing)
          Container(
            color: Colors.black26,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildControlsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSlider(
            'Contrast',
            _contrast,
            0.0,
            2.0,
            (value) => setState(() => _contrast = value),
            (_) => _applyAdjustments(),
          ),
          _buildSlider(
            'Saturation',
            _saturation,
            0.0,
            2.0,
            (value) => setState(() => _saturation = value),
            (_) => _applyAdjustments(),
          ),
          _buildSlider(
            'Brightness',
            _brightness,
            0.0,
            2.0,
            (value) => setState(() => _brightness = value),
            (_) => _applyAdjustments(),
          ),
          _buildSlider(
            'Gamma',
            _gamma,
            0.0,
            3.0,
            (value) => setState(() => _gamma = value),
            (_) => _applyAdjustments(),
          ),
          _buildSlider(
            'Exposure',
            _exposure,
            -2.0,
            2.0,
            (value) => setState(() => _exposure = value),
            (_) => _applyAdjustments(),
          ),
          _buildSlider(
            'Hue',
            _hue,
            -180.0,
            180.0,
            (value) => setState(() => _hue = value),
            (_) => _applyAdjustments(),
          ),
          _buildSlider(
            'Amount',
            _amount,
            0.0,
            1.0,
            (value) => setState(() => _amount = value),
            (_) => _applyAdjustments(),
          ),
          const Divider(height: 32),
          _buildColorRow(
            'Blacks',
            _blacksUI,
            (color) {
              setState(() => _blacksUI = color);
              _applyAdjustments();
            },
          ),
          _buildColorRow(
            'Whites',
            _whitesUI,
            (color) {
              setState(() => _whitesUI = color);
              _applyAdjustments();
            },
          ),
          _buildColorRow(
            'Mids',
            _midsUI,
            (color) {
              setState(() => _midsUI = color);
              _applyAdjustments();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value.toStringAsFixed(2),
                style: TextStyle(
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
    );
  }

  Widget _buildColorRow(
    String label,
    material.Color? color,
    ValueChanged<material.Color?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (color != null) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => onChanged(null),
              tooltip: 'Clear',
            ),
          ] else
            ElevatedButton(
              onPressed: () => _showColorPicker(label, onChanged),
              child: const Text('Set Color'),
            ),
        ],
      ),
    );
  }

  Future<void> _showColorPicker(
    String label,
    ValueChanged<material.Color?> onChanged,
  ) async {
    material.Color selectedColor = Colors.grey;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select $label Color'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ColorSliders(
                initialColor: selectedColor,
                onColorChanged: (color) {
                  selectedColor = color;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onChanged(selectedColor);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _ColorSliders extends StatefulWidget {
  final material.Color initialColor;
  final ValueChanged<material.Color> onColorChanged;

  const _ColorSliders({
    required this.initialColor,
    required this.onColorChanged,
  });

  @override
  State<_ColorSliders> createState() => _ColorSlidersState();
}

class _ColorSlidersState extends State<_ColorSliders> {
  late double _red;
  late double _green;
  late double _blue;

  @override
  void initState() {
    super.initState();
    _red = widget.initialColor.red.toDouble();
    _green = widget.initialColor.green.toDouble();
    _blue = widget.initialColor.blue.toDouble();
  }

  void _updateColor() {
    widget.onColorChanged(
      material.Color.fromARGB(
        255,
        _red.toInt(),
        _green.toInt(),
        _blue.toInt(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = material.Color.fromARGB(
      255,
      _red.toInt(),
      _green.toInt(),
      _blue.toInt(),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: currentColor,
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 16),
        _buildColorSlider('Red', _red, Colors.red, (value) {
          setState(() => _red = value);
          _updateColor();
        }),
        _buildColorSlider('Green', _green, Colors.green, (value) {
          setState(() => _green = value);
          _updateColor();
        }),
        _buildColorSlider('Blue', _blue, Colors.blue, (value) {
          setState(() => _blue = value);
          _updateColor();
        }),
      ],
    );
  }

  Widget _buildColorSlider(
    String label,
    double value,
    material.Color color,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value.toInt().toString()),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: 255,
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
