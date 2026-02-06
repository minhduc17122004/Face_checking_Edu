import 'package:flutter_liveness_detection_randomized_plugin/index.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HomeView(),
  ));
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  List<String?> capturedImages = [];
  String? imgPath;

  @override
  void initState() {
    super.initState();
  }

  Future<bool> _onLivenessSuccessStep(String? imagePath) async {
    debugPrint('Captured !!!');
    if (imagePath != null) {
      setState(() {
        debugPrint('Captured Image Path: $imagePath');
        capturedImages.add(imagePath);
      });
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
          child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(12),
        children: [
          if (imgPath != null || capturedImages.isNotEmpty) ...[
            const Text(
              'Result Liveness Detection',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (capturedImages.isNotEmpty) ...[
              const Text(
                'Captured Step Images:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: capturedImages.length,
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(capturedImages[index]!),
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
            if (imgPath != null) ...[
              const Text(
                'Final Result:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Align(
                child: SizedBox(
                  height: 120,
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      File(imgPath!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
          ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt_rounded),
              onPressed: () async {
                final String? response =
                    await FlutterLivenessDetectionRandomizedPlugin.instance
                        .livenessDetection(
                  onLivenessSuccessStep: _onLivenessSuccessStep,
                  context: context,
                  config: LivenessDetectionConfig(
                    imageQuality: 100, // adjust your image quality result
                    isEnableMaxBrightness:
                        true, // enable disable max brightness when taking face photo
                    durationLivenessVerify:
                        20, // default duration value is 45 second
                    showDurationUiText:
                        false, // show or hide duration remaining when perfoming liveness detection
                    startWithInfoScreen: true, // show or hide tutorial screen
                    useCustomizedLabel:
                        true, // set to true value for enable 'customizedLabel', set to false to use default label
                    // provide an empty string if you want to pass the liveness challenge
                    customizedLabel: LivenessDetectionLabelModel(
                      // smile: 'Cười',
                      // blink: 'Nhắm mắt',
                      // straightFace: 'Nhìn thẳng',
                      lookUp: 'Nhìn lên',
                      // lookDown: 'Nhìn xuống',
                      // lookLeft: 'Nhìn sang trái',
                      // lookRight: 'Nhìn sang phải',
                      straightFace: 'Nhìn thẳng',
                      smile: 'Cười',
                      blink: 'Nhắm mắt',
                    ),
                  ),
                  isEnableSnackBar:
                      true, // snackbar to notify either liveness is success or failed
                  shuffleListWithSmileLast:
                      false, // put 'smile' challenge always at the end of liveness challenge, if `useCustomizedLabel` is true, this automatically set to false
                  isDarkMode: false, // enable dark/light mode
                  showCurrentStep: true, // show number current step of liveness
                );
                if (mounted) {
                  setState(() {
                    imgPath = response; // result liveness
                  });
                }
              },
              label: const Text('Liveness Detection System')),
        ],
      )),
    );
  }
}
