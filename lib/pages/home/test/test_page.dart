// import 'dart:io';
// import 'package:face_native/face_native.dart';
// import 'package:face_native/face_native_method_channel.dart';
// import 'package:face_time_keeping/common/api_client/data_state.dart';
// import 'package:face_time_keeping/common/utils/location_util.dart';
// import 'package:face_time_keeping/common/utils/rsa_util.dart';
// import 'package:face_time_keeping/data/local/hive_service.dart';
// import 'package:face_time_keeping/data/local/local_service.dart';
// import 'package:face_time_keeping/data/remote/user_service.dart';
// import 'package:face_time_keeping/data/remote/authentication_service.dart';
// import 'package:face_time_keeping/entities/bulk_user.dart';
// import 'package:face_native/models/face_image_record.dart';
// import 'package:face_time_keeping/di/injection.dart';
// import 'package:face_time_keeping/pages/bloc/app_bloc.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:file_picker/file_picker.dart';

// class TestPage extends StatefulWidget {
//   const TestPage({super.key});

//   @override
//   State<TestPage> createState() => _TestPageState();
// }

// class _TestPageState extends State<TestPage> {
//   late final HiveService _hiveService;
//   late final LocalService _localService;
//   late final UserService _userService;
//   late final AuthenticationService _authService;
//   late final FaceNative _faceNative;
//   late final AppBloc _appBloc;
//   final ImagePicker _imagePicker = ImagePicker();
//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _numImagesController = TextEditingController();
//   final TextEditingController _empIdController = TextEditingController();
//   final TextEditingController _employeeCodeController = TextEditingController();
//   final TextEditingController _imageUriController = TextEditingController();
//   final TextEditingController _plainTextController = TextEditingController();
//   final TextEditingController _publicKeyController = TextEditingController();
//   final TextEditingController _privateKeyController = TextEditingController();
//   final TextEditingController _importFilePathController = TextEditingController();
//   final TextEditingController _dbUserController = TextEditingController();
//   final TextEditingController _dbPassController = TextEditingController();
//   final TextEditingController _dbNameController = TextEditingController();

//   String _result = '';
//   bool _isLoading = false;
//   File? _selectedImage;
//   List<RecognitionResult> _recognitionResults = [];
//   RecognitionMetrics? _metrics;
//   List<BulkUser> _bulkUsers = [];
//   List<FaceImageRecord> _allImages = [];

//   @override
//   void initState() {
//     super.initState();
//     _hiveService = getIt<HiveService>();
//     _localService = getIt<LocalService>();
//     _userService = getIt<UserService>();
//     _authService = getIt<AuthenticationService>();
//     _faceNative = FaceNative();
//     _appBloc = getIt<AppBloc>();
//     // Set default values for RSA testing
//     _plainTextController.text = 'Hello, this is a test message for RSA encryption!';
//     _dbUserController.text = 'admin';
//     _dbPassController.text = 'admin';
//     _dbNameController.text = 'odoo18_phuman_db';
//     // Keys will be loaded from assets using button 18
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _numImagesController.dispose();
//     _empIdController.dispose();
//     _employeeCodeController.dispose();
//     _imageUriController.dispose();
//     _plainTextController.dispose();
//     _publicKeyController.dispose();
//     _privateKeyController.dispose();
//     _importFilePathController.dispose();
//     _dbUserController.dispose();
//     _dbPassController.dispose();
//     _dbNameController.dispose();
//     super.dispose();
//   }

//   void _setLoading(bool loading) {
//     setState(() {
//       _isLoading = loading;
//     });
//   }

//   void _setResult(String result) {
//     setState(() {
//       _result = result;
//     });
//   }

//   void _clearResult() {
//     setState(() {
//       _result = '';
//       _recognitionResults.clear();
//       _metrics = null;
//       _bulkUsers.clear();
//       _allImages.clear();
//     });
//   }

//   Future<void> _pickImage() async {
//     try {
//       final XFile? image = await _imagePicker.pickImage(
//         source: ImageSource.gallery,
//         imageQuality: 80,
//       );

//       if (image != null) {
//         setState(() {
//           _selectedImage = File(image.path);
//           _imageUriController.text = image.path;
//         });
//       }
//     } catch (e) {
//       _setResult('Failed to pick image: $e');
//     }
//   }

//   Future<void> _testAddPerson() async {
//     _clearResult();

//     if (_nameController.text.isEmpty ||
//         _numImagesController.text.isEmpty ||
//         _empIdController.text.isEmpty) {
//       _setResult('Please fill in all fields (name, numImages, empId)');
//       return;
//     }

//     _setLoading(true);

//     try {
//       final personId = await _faceNative.addPerson(
//         _nameController.text,
//         int.parse(_numImagesController.text),
//         int.parse(_empIdController.text),
//       );
//       _setResult('Person added successfully! Person ID: $personId');
//     } catch (e) {
//       _setResult('Error: $e');
//     } finally {
//       _setLoading(false);
//     }
//   }

//   Future<void> _testAddImage() async {
//     _clearResult();

//     if (_empIdController.text.isEmpty ||
//         _nameController.text.isEmpty ||
//         _employeeCodeController.text.isEmpty ||
//         _imageUriController.text.isEmpty) {
//       _setResult('Please fill in all fields (empId, name, employeeCode, imageUri)');
//       return;
//     }

//     _setLoading(true);

//     try {
//       final success = await _faceNative.addImage(
//         empId: int.parse(_empIdController.text),
//         personName: _nameController.text,
//         pin: _employeeCodeController.text,
//         imageUri: _imageUriController.text,
//       );
//       _setResult('Image added: $success');
//     } catch (e) {
//       _setResult('Error: $e');
//     } finally {
//       _setLoading(false);
//     }
//   }

//   Future<void> _testGetCount() async {
//     _clearResult();
//     _setLoading(true);
//     try {
//       final count = await _faceNative.getCount();
//       _setResult('Total images in database: $count');
//     } catch (e) {
//       _setResult('Error: $e');
//     } finally {
//       _setLoading(false);
//     }
//   }

//   Future<void> _testGetDatabaseSize() async {
//     _clearResult();
//     _setLoading(true);
//     try {
//       final sizeInBytes = await _faceNative.getDatabaseSizeInBytes();
//       _setResult('Database size: $sizeInBytes bytes');
//     } catch (e) {
//       _setResult('Error: $e');
//     } finally {
//       _setLoading(false);
//     }
//   }

//   Future<void> _testGetAllImages() async {
//     _clearResult();
//     _setLoading(true);
//     try {
//       final images = await _faceNative.getAllImages();

//       setState(() {
//         _allImages = images;
//       });

//       if (images.isEmpty) {
//         _setResult('No images found in database');
//       } else {
//         _setResult('Found ${images.length} image(s) in database');
//       }
//     } catch (e) {
//       _setResult('Error: $e');
//     } finally {
//       _setLoading(false);
//     }
//   }

//   Future<void> _testGetDatabaseList() async {
//     _clearResult();
//     _setLoading(true);
//     try {
//       final response = await _authService.getDatabaseList();
//       if (response.isSuccess) {
//         final dbs = response.data ?? <String>[];
//         _setResult('Databases (${dbs.length}):\n- ' + dbs.join('\n- '));
//       } else {
//         _setResult('Failed to get database list: ${response.error}');
//       }
//     } catch (e) {
//       _setResult('Error: $e');
//     } finally {
//       _setLoading(false);
//     }
//   }

//   Future<void> _testImportFromJsonFile() async {
//     _clearResult();
//     _setLoading(true);

//     try {
//       // Use file picker to select JSON file
//       FilePickerResult? result = await FilePicker.platform.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: ['json'],
//         allowMultiple: false,
//       );

//       if (result == null || result.files.isEmpty) {
//         _setResult('No file selected for import');
//         return;
//       }

//       final file = result.files.first;
//       final filePath = file.path;

//       if (filePath == null) {
//         _setResult('Unable to get file path');
//         return;
//       }

//       // Update the text field with selected file path
//       _importFilePathController.text = filePath;

//       // Import the file
//       final importedImages = await _localService.importFromJsonFile(filePath);

//       setState(() {
//         _allImages = importedImages;
//       });

//       _setResult('''
// 📁 Import from JSON File - SUCCESS!

// ✅ Successfully imported ${importedImages.length} image record(s) from:
// $filePath

// 📊 Import Details:
// - File name: ${file.name}
// - File size: ${file.size} bytes
// - File path: $filePath
// - Records imported: ${importedImages.length}
// - Data loaded into memory for review

// 💡 Note: This only loads the data for review. 
// To actually add these images to the database, you would need to call addImage for each record.
//       ''');
//     } catch (e) {
//       _setResult('''
// ❌ Import from JSON File - FAILED!

// Error: $e

// 📋 Troubleshooting:
// 1. Check if file is a valid JSON format
// 2. Ensure file contains valid FaceImageRecord data
// 3. Verify file is not corrupted
// 4. Check file permissions
// 5. Make sure the JSON structure matches FaceImageRecord format
//       ''');
//     } finally {
//       _setLoading(false);
//     }
//   }

//   Future<void> _testClearAllImages() async {
//     _clearResult();
//     _setLoading(true);
//     try {
//       final success = await _faceNative.clearAllImages();
//       _setResult('All images cleared: $success');
//     } catch (e) {
//       _setResult('Error: $e');
//     } finally {
//       _setLoading(false);
//     }
//   }

//   Future<void> _testRecognizeFace() async {
//     _clearResult();

//     if (_selectedImage == null) {
//       _setResult('Please select an image first');
//       return;
//     }

//     _setLoading(true);

//     try {
//       final imageBytes = await _selectedImage!.readAsBytes();
//       final response = await _faceNative.recognizeFace(imageBytes: imageBytes);

//       setState(() {
//         _recognitionResults = [response.result];
//         _metrics = response.metrics;
//       });

//       if (response.result.personName == 'Not_recognized') {
//         _setResult('No faces detected in the image');
//       } else {
//         _setResult('Found ${response.result.personName}');
//       }
//     } catch (e) {
//       _setResult('Error: $e');
//     } finally {
//       _setLoading(false);
//     }
//   }

//   Future<void> _testGetCroppedFace() async {
//     _clearResult();

//     if (_imageUriController.text.isEmpty && _selectedImage == null) {
//       _setResult(
//         'Please select an image first or enter an image URI',
//       );
//       return;
//     }

//     _setLoading(true);

//     try {
//       final imageUri = _selectedImage?.path ?? _imageUriController.text;

//       final success = await _faceNative.testGetCroppedFace(imageUri);

//       if (success) {
//         _setResult('''
// 🎯 Get Cropped Face Test - SUCCESS!

// ✅ Successfully detected and cropped face from image.

// 📊 Details:
// - Image URI: $imageUri
// - Face Detection: ✅ PASSED
// - Face Cropping: ✅ COMPLETED
// - Status: SUCCESS

// 💡 The cropped face image has been saved to the app's 
// documents directory for debugging purposes.

// 📝 Note: This method:
// 1. Loads the image from the provided URI
// 2. Detects faces using ML Kit Face Detection
// 3. Validates that exactly one face is present
// 4. Crops the face from the image
// 5. Saves the cropped image for debugging
// 6. Returns true if successful

// 🔍 Check the app logs or documents directory to see 
// the saved cropped face image.
//         ''');
//       } else {
//         _setResult('''
// ⚠️ Get Cropped Face Test - FAILED!

// The method returned false. Possible reasons:
// - No face detected in the image
// - Multiple faces detected (only single face allowed)
// - Face bounding box invalid
// - Image loading failed
// - Face detection error

// 📋 Troubleshooting:
// 1. Ensure image contains exactly one face
// 2. Check image quality and lighting
// 3. Verify face is clearly visible
// 4. Try a different image
// 5. Check app logs for detailed error messages
//         ''');
//       }
//     } catch (e) {
//       _setResult('''
// ❌ Get Cropped Face Test - ERROR!

// Error: $e

// 📋 Troubleshooting:
// 1. Check if the image URI is valid
// 2. Ensure ML Kit Face Detection is initialized
// 3. Verify image file exists and is accessible
// 4. Check if image format is supported (JPEG, PNG)
// 5. Ensure required permissions are granted
// 6. Check app logs for detailed error stack trace

// 💡 Common issues:
// - File not found at the specified URI
// - Invalid image format
// - Corrupted image file
// - Insufficient permissions to read file
// - ML Kit initialization failed
//         ''');
//     } finally {
//       _setLoading(false);
//     }
//   }

//   Future<void> _testRemoveImages() async {
//     _clearResult();

//     if (_empIdController.text.isEmpty) {
//       _setResult('Please enter an Employee ID');
//       return;
//     }

//     _setLoading(true);

//     try {
//       final success = await _faceNative.removeImages(
//         int.parse(_empIdController.text),
//       );
//       _setResult('Images removed: $success');
//     } catch (e) {
//       _setResult('Error: $e');
//     } finally {
//       _setLoading(false);
//     }
//   }

//   Future<void> _testSyncCheckInOutData() async {
//     _clearResult();
//     _setLoading(true);

//     try {
//       final result = await _userService.syncCheckInOutData();

//       if (result.isSuccess) {
//         _setResult('Sync completed successfully! Data has been uploaded to server.');
//       } else {
//         _setResult('Sync failed: ${result.error}');
//       }
//     } catch (e) {
//       _setResult('Error during sync: $e');
//     } finally {
//       _setLoading(false);
//     }
//   }

//   Future<void> _testRSAEncryption() async {
//     _clearResult();

//     if (_plainTextController.text.isEmpty) {
//       _setResult('Please enter plain text to encrypt');
//       return;
//     }

//     if (_publicKeyController.text.isEmpty) {
//       _setResult('Please enter RSA public key');
//       return;
//     }

//     _setLoading(true);

//     try {
//       final plainText = _plainTextController.text;
//       final publicKeyPem = _publicKeyController.text;

//       // Create RSA utility with public key only
//       final rsaUtil = RSAUtil.fromPemStrings(publicPem: publicKeyPem);

//       // Encrypt the text
//       final encryptedBase64 = rsaUtil.encryptToBase64(plainText);

//       _setResult('''
// 🔐 RSA Encryption Test Result:

// 📝 Original Text: $plainText
// 🔒 Encrypted (Base64): 
// ${encryptedBase64.substring(0, 100)}...

// 📊 Details:
// - Original Length: ${plainText.length} chars
// - Encrypted Length: ${encryptedBase64.length} chars
// - Encryption Algorithm: RSA-OAEP with SHA-256
// - Status: ✅ SUCCESS

// 💡 Note: Use the decryption test with your private key to decrypt this data.
//       ''');
//     } catch (e) {
//       _setResult('❌ RSA encryption test failed: $e');
//     } finally {
//       _setLoading(false);
//     }
//   }

//   Future<void> _testRSADecryption() async {
//     _clearResult();

//     if (_privateKeyController.text.isEmpty) {
//       _setResult('Please enter RSA private key');
//       return;
//     }

//     _setLoading(true);

//     try {
//       final privateKeyPem = _privateKeyController.text;

//       // First encrypt some test data
//       final testText = _plainTextController.text.isEmpty
//           ? 'Test message for RSA decryption'
//           : _plainTextController.text;

//       // If we have both keys, do a full encrypt/decrypt cycle
//       if (_publicKeyController.text.isNotEmpty) {
//         final rsaUtilFull = RSAUtil.fromPemStrings(
//           publicPem: _publicKeyController.text,
//           privatePem: privateKeyPem,
//         );

//         // Encrypt with public key
//         final encrypted = rsaUtilFull.encryptToBase64(testText);

//         // Decrypt with private key
//         final decrypted = rsaUtilFull.decryptFromBase64(encrypted);

//         final isValid = testText == decrypted;

//         _setResult('''
// 🔓 RSA Decryption Test Result:

// 📝 Original Text: $testText
// 🔒 Encrypted: ${encrypted.substring(0, 50)}...
// 🔓 Decrypted Text: $decrypted
// ✅ Encryption/Decryption Valid: $isValid

// 📊 Details:
// - Original Length: ${testText.length} chars
// - Encrypted Length: ${encrypted.length} chars
// - Decrypted Length: ${decrypted.length} chars
// - Algorithm: RSA-OAEP with SHA-256
// - Match: ${isValid ? "✅ SUCCESS" : "❌ FAILED"}
//         ''');
//       } else {
//         _setResult('❌ Need both public and private keys for full encrypt/decrypt test');
//       }
//     } catch (e) {
//       _setResult('❌ RSA decryption test failed: $e');
//     } finally {
//       _setLoading(false);
//     }
//   }

//   Future<void> _testRSAFromAssets() async {
//     _clearResult();
//     _setLoading(true);

//     try {
//       // Load RSA keys from assets
//       final rsaUtil = await RSAUtil.fromAsset(
//         publicAssetPath: 'assets/public.pem',
//         privateAssetPath: 'assets/private.pem',
//       );

//       // Test message
//       final testMessage = _plainTextController.text.isEmpty
//           ? 'Hello from assets RSA test!'
//           : _plainTextController.text;

//       // Encrypt with public key from assets
//       final encrypted = rsaUtil.encryptToBase64(testMessage);

//       // Decrypt with private key from assets
//       final decrypted = rsaUtil.decryptFromBase64(encrypted);

//       // Verify the process
//       final isValid = testMessage == decrypted;

//       _setResult('''
// 📁 RSA Assets Loading Test Result:

// ✅ Successfully loaded keys from assets:
// - Public Key: assets/public.pem
// - Private Key: assets/private.pem

// 🔐 Encryption/Decryption Test:
// 📝 Original Text: $testMessage
// 🔒 Encrypted (Base64): ${encrypted.substring(0, 50)}...
// 🔓 Decrypted Text: $decrypted
// ✅ Validation: $isValid

// 📊 Details:
// - Original Length: ${testMessage.length} chars
// - Encrypted Length: ${encrypted.length} chars
// - Decrypted Length: ${decrypted.length} chars
// - Algorithm: RSA-OAEP with SHA-256
// - Match: ${isValid ? "✅ SUCCESS" : "❌ FAILED"}

// 💡 Assets are now properly configured in pubspec.yaml!
//       ''');
//     } catch (e) {
//       _setResult('''
// ❌ RSA assets test failed: $e

// 📋 Troubleshooting:
// 1. Make sure assets/public.pem and assets/private.pem exist
// 2. Check that pubspec.yaml includes these assets
// 3. Run 'flutter pub get' after updating pubspec.yaml
// 4. Ensure PEM files have correct format

// Current pubspec.yaml assets should include:
// - assets/public.pem  
// - assets/private.pem
//       ''');
//     } finally {
//       _setLoading(false);
//     }
//   }

//   Future<void> _loadKeysFromAssets() async {
//     _clearResult();
//     _setLoading(true);

//     try {
//       // Load the actual PEM content from assets
//       final publicKeyContent = await rootBundle.loadString('assets/public.pem');
//       final privateKeyContent = await rootBundle.loadString('assets/private.pem');

//       setState(() {
//         _publicKeyController.text = publicKeyContent;
//         _privateKeyController.text = privateKeyContent;
//       });

//       _setResult('''
// 📁 RSA Keys Loaded from Assets:

// ✅ Successfully loaded and populated text fields:
// - Public Key: Loaded from assets/public.pem
// - Private Key: Loaded from assets/private.pem

// 📝 The text fields above have been updated with the actual key content.
// You can now use the other RSA test buttons with these keys!

// 💡 Keys are ready for encryption/decryption testing.
//       ''');
//     } catch (e) {
//       _setResult('''
// ❌ Failed to load keys from assets: $e

// 📋 Make sure:
// 1. assets/public.pem and assets/private.pem exist
// 2. pubspec.yaml includes these assets
// 3. Run 'flutter pub get' after updating pubspec.yaml
//       ''');
//     } finally {
//       _setLoading(false);
//     }
//   }

//   Future<void> _testClearPersons() async {
//     _clearResult();
//     _setLoading(true);

//     try {
//       await _hiveService.clearPersons();
//       _setResult('''
// 🗑️ Clear Persons Test - SUCCESS!

// ✅ Successfully cleared all persons from Hive database.

// 📊 Details:
// - Operation: Clear all persons
// - Database: Hive local storage
// - Status: ✅ COMPLETED

// 💡 All person records have been removed from the local database.
//       ''');
//     } catch (e) {
//       _setResult('''
// ❌ Clear Persons Test - FAILED!

// Error: $e

// 📋 Troubleshooting:
// 1. Check if Hive database is properly initialized
// 2. Verify person box is accessible
// 3. Check database permissions
// 4. Ensure Hive service is working correctly
//       ''');
//     } finally {
//       _setLoading(false);
//     }
//   }

//   Future<void> _testGetAllPersons() async {
//     _clearResult();
//     _setLoading(true);

//     try {
//       final persons = await _hiveService.getAllPersons();

//       final details =
//           persons.asMap().entries.map((entry) => '${entry.key + 1}. ${entry.value}').join('\n');

//       _setResult('''
// 👥 Get All Persons - SUCCESS!

// Total persons: ${persons.length}

// Top ${persons.length} entr${persons.length == 1 ? 'y' : 'ies'}:
// $details
//       ''');
//     } catch (e) {
//       _setResult('''
// ❌ Get All Persons - FAILED!

// Error: $e
//       ''');
//     } finally {
//       _setLoading(false);
//     }
//   }

//   Future<void> _testResetBothLatestTime() async {
//     _clearResult();
//     _setLoading(true);

//     try {
//       await _localService.resetBothLatestTime();
//       _setResult('''
// 🔄 Reset Both Latest Time Test - SUCCESS!

// ✅ Successfully reset both latest time values in SharedPreferences.

// 📊 Details:
// - Operation: Reset both latest time values
// - Keys Reset:
//   - latestTimePullFaceData
//   - latestTimePushFaceData
// - Storage: SharedPreferences
// - Status: ✅ COMPLETED

// 💡 Both face data sync timestamps have been cleared and will be reset on next sync.
//       ''');
//     } catch (e) {
//       _setResult('''
// ❌ Reset Both Latest Time Test - FAILED!

// Error: $e

// 📋 Troubleshooting:
// 1. Check if SharedPreferences is properly initialized
// 2. Verify LocalService is accessible
// 3. Check storage permissions
// 4. Ensure tenant ID formatting is working correctly
//       ''');
//     } finally {
//       _setLoading(false);
//     }
//   }

//   Future<void> _testResetIsInitializedDefaultData() async {
//     _clearResult();
//     _setLoading(true);

//     try {
//       await _localService.saveIsInitializedDefaultData(false);
//       _setResult('''
// 🔄 Reset Is Initialized Default Data Test - SUCCESS!

// ✅ Successfully reset isInitializedDefaultData flag in SharedPreferences.

// 📊 Details:
// - Operation: Reset isInitializedDefaultData flag
// - Key Reset: isInitializedDefaultData
// - New Value: false
// - Storage: SharedPreferences
// - Status: ✅ COMPLETED

// 💡 The app will now treat this as a fresh installation and may reinitialize default data on next startup.
//       ''');
//     } catch (e) {
//       _setResult('''
// ❌ Reset Is Initialized Default Data Test - FAILED!

// Error: $e

// 📋 Troubleshooting:
// 1. Check if SharedPreferences is properly initialized
// 2. Verify LocalService is accessible
// 3. Check storage permissions
// 4. Ensure the saveIsInitializedDefaultData method is working correctly
//       ''');
//     } finally {
//       _setLoading(false);
//     }
//   }

//   Future<void> _testGetCurrentPosition() async {
//     _clearResult();
//     _setLoading(true);

//     try {
//       // Trigger the AppBloc to fetch current position
//       await LocationUtil.getCurrentPosition();

//       // Wait a bit for the position to be fetched
//       await Future.delayed(const Duration(seconds: 2));

//       // Get the position from AppBloc state
//       final position = _appBloc.state.position;

//       if (position != null) {
//         _setResult('''
// 📍 Get Current Position Test - SUCCESS!

// ✅ Successfully retrieved current position from AppBloc.

// 📊 Position Details:
// - Latitude: ${position.latitude}
// - Longitude: ${position.longitude}
// - Accuracy: ${position.accuracy} meters
// - Altitude: ${position.altitude} meters
// - Speed: ${position.speed} m/s
// - Heading: ${position.heading}°
// - Timestamp: ${position.timestamp}

// 🔧 Technical Info:
// - Speed Accuracy: ${position.speedAccuracy} m/s
// - Heading Accuracy: ${position.headingAccuracy}°
// - Altitude Accuracy: ${position.altitudeAccuracy} meters

// 💡 This position is automatically updated every 30 seconds in the background.
//         ''');
//       } else {
//         _setResult('''
// ⚠️ Get Current Position Test - NO POSITION YET

// The position is still being fetched. Please try again in a moment.

// 📋 Possible reasons:
// 1. GPS is still acquiring signal
// 2. Location permission not granted
// 3. Location services disabled
// 4. Waiting for initial position update
//         ''');
//       }
//     } catch (e) {
//       _setResult('''
// ❌ Get Current Position Test - FAILED!

// Error: $e

// 📋 Troubleshooting:
// 1. Check if location permissions are granted
// 2. Ensure location services are enabled
// 3. Check if GPS is available
// 4. Verify AppBloc is properly initialized
// 5. Try enabling high accuracy mode in device settings
//       ''');
//     } finally {
//       _setLoading(false);
//     }
//   }

//   Widget _buildTextField({
//     required TextEditingController controller,
//     required String label,
//     TextInputType? keyboardType,
//     String? hint,
//     int? maxLines,
//     bool readOnly = false,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4.0),
//       child: TextField(
//         controller: controller,
//         keyboardType: keyboardType,
//         maxLines: maxLines ?? 1,
//         readOnly: readOnly,
//         decoration: InputDecoration(
//           labelText: label,
//           hintText: hint,
//           border: const OutlineInputBorder(),
//           contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//         ),
//       ),
//     );
//   }

//   Widget _buildTestButton({
//     required String title,
//     required VoidCallback onPressed,
//     Color? color,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4.0),
//       child: SizedBox(
//         width: double.infinity,
//         child: ElevatedButton(
//           onPressed: _isLoading ? null : onPressed,
//           style: ElevatedButton.styleFrom(
//             backgroundColor: color,
//             padding: const EdgeInsets.symmetric(vertical: 12),
//           ),
//           child: Text(
//             title,
//             style: const TextStyle(fontSize: 16),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildRecognitionResults() {
//     if (_recognitionResults.isEmpty && _metrics == null) return const SizedBox.shrink();

//     return Card(
//       margin: const EdgeInsets.symmetric(vertical: 8),
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Recognition Results:',
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 8),

//             // Display metrics if available
//             if (_metrics != null) ...[
//               Text('Performance Metrics:', style: TextStyle(fontWeight: FontWeight.w600)),
//               Text('Face Detection: ${_metrics!.timeFaceDetection}ms'),
//               Text('Face Embedding: ${_metrics!.timeFaceEmbedding}ms'),
//               Text('Vector Search: ${_metrics!.timeVectorSearch}ms'),
//               Text('Spoof Detection: ${_metrics!.timeFaceSpoofDetection}ms'),
//               Text('Total Time: ${_metrics!.totalTime}ms'),
//               const Divider(),
//             ],

//             // Display recognition results
//             if (_recognitionResults.isNotEmpty) ...[
//               Text('Detected Faces:', style: TextStyle(fontWeight: FontWeight.w600)),
//               ...(_recognitionResults.asMap().entries.map((entry) {
//                 final index = entry.key;
//                 final result = entry.value;
//                 return Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 4),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text('Face ${index + 1}:'),
//                       Text('  Person: ${result.personName}'),
//                       Text('  PIN Code: ${result.pin}'),
//                       Text(
//                           '  Bounding Box: (${result.boundingBox.left.toStringAsFixed(1)}, ${result.boundingBox.top.toStringAsFixed(1)}) - (${result.boundingBox.right.toStringAsFixed(1)}, ${result.boundingBox.bottom.toStringAsFixed(1)})'),
//                       Text(
//                           '  Size: ${result.boundingBox.width.toStringAsFixed(1)} x ${result.boundingBox.height.toStringAsFixed(1)}'),
//                       if (result.spoofResult != null) ...[
//                         Text(
//                             '  Spoof Detection: ${result.spoofResult!.isSpoof ? "SPOOF" : "REAL"}'),
//                         Text('  Spoof Score: ${result.spoofResult!.score.toStringAsFixed(3)}'),
//                         Text('  Spoof Time: ${result.spoofResult!.timeMillis}ms'),
//                       ],
//                     ],
//                   ),
//                 );
//               })),
//             ],
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildAllImagesResults() {
//     if (_allImages.isEmpty) return const SizedBox.shrink();

//     return Card(
//       margin: const EdgeInsets.symmetric(vertical: 8),
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'All Images in Database:',
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 8),

//             // Display all images
//             ...(_allImages.asMap().entries.map((entry) {
//               final index = entry.key;
//               final imageRecord = entry.value;
//               return Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 8),
//                 child: Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade50,
//                     borderRadius: BorderRadius.circular(8),
//                     border: Border.all(color: Colors.grey.shade300),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'Image ${index + 1}:',
//                         style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
//                       ),
//                       Text('Employee ID: ${imageRecord.empId}'),
//                       Text('Person Name: ${imageRecord.personName}'),
//                       Text(
//                           'Face Embedding: ${imageRecord.faceEmbedding.map((e) => e.toString()).join(', ')}'),
//                       const SizedBox(height: 4),
//                     ],
//                   ),
//                 ),
//               );
//             })),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Face Detection Service Test'),
//         backgroundColor: Colors.blue,
//         foregroundColor: Colors.white,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Input fields section
//             Card(
//               child: Padding(
//                 padding: const EdgeInsets.all(12),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Test Parameters:',
//                       style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                     ),
//                     const SizedBox(height: 8),
//                     _buildTextField(
//                       controller: _nameController,
//                       label: 'Person Name',
//                       hint: 'Enter person name',
//                     ),
//                     _buildTextField(
//                       controller: _numImagesController,
//                       label: 'Number of Images',
//                       keyboardType: TextInputType.number,
//                       hint: 'Enter number of images',
//                     ),
//                     _buildTextField(
//                       controller: _empIdController,
//                       label: 'Employee ID',
//                       keyboardType: TextInputType.number,
//                       hint: 'Enter employee ID',
//                     ),

//                     _buildTextField(
//                       controller: _employeeCodeController,
//                       label: 'Employee Code',
//                       hint: 'Enter employee code',
//                     ),

//                     _buildTextField(
//                       controller: _imageUriController,
//                       label: 'Image URI',
//                       hint: 'Select image or enter URI',
//                     ),

//                     _buildTextField(
//                       controller: _plainTextController,
//                       label: 'Plain Text (for RSA encryption)',
//                       hint: 'Enter text to encrypt/decrypt',
//                     ),

//                     _buildTextField(
//                       controller: _publicKeyController,
//                       label: 'RSA Public Key (PEM format)',
//                       hint: 'Paste your RSA public key',
//                       maxLines: 5,
//                     ),

//                     _buildTextField(
//                       controller: _privateKeyController,
//                       label: 'RSA Private Key (PEM format)',
//                       hint: 'Paste your RSA private key',
//                       maxLines: 5,
//                     ),

//                     const SizedBox(height: 8),
//                     const Text(
//                       'Authentication Test Parameters:',
//                       style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//                     ),
//                     const SizedBox(height: 4),
//                     _buildTextField(
//                       controller: _dbUserController,
//                       label: 'DB Username',
//                       hint: 'Enter username',
//                     ),
//                     _buildTextField(
//                       controller: _dbPassController,
//                       label: 'DB Password',
//                       hint: 'Enter password',
//                       keyboardType: TextInputType.visiblePassword,
//                     ),
//                     _buildTextField(
//                       controller: _dbNameController,
//                       label: 'Database Name',
//                       hint: 'Enter database name',
//                     ),

//                     _buildTextField(
//                       controller: _importFilePathController,
//                       label: 'Import File Path (Auto-filled by file picker)',
//                       hint: 'File path will be set when you select a file',
//                       readOnly: true,
//                     ),
//                     const SizedBox(height: 8),

//                     // Image picker section
//                     Row(
//                       children: [
//                         Expanded(
//                           child: ElevatedButton.icon(
//                             onPressed: _pickImage,
//                             icon: const Icon(Icons.image),
//                             label: const Text('Pick Image'),
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         if (_selectedImage != null)
//                           Container(
//                             width: 60,
//                             height: 60,
//                             decoration: BoxDecoration(
//                               border: Border.all(color: Colors.grey),
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             child: ClipRRect(
//                               borderRadius: BorderRadius.circular(8),
//                               child: Image.file(
//                                 _selectedImage!,
//                                 fit: BoxFit.cover,
//                               ),
//                             ),
//                           ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),

//             const SizedBox(height: 16),

//             // Test buttons section
//             Card(
//               child: Padding(
//                 padding: const EdgeInsets.all(12),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Test Methods:',
//                       style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                     ),
//                     const SizedBox(height: 8),
//                     _buildTestButton(
//                       title: '2. Add Person',
//                       onPressed: _testAddPerson,
//                       color: Colors.green,
//                     ),
//                     _buildTestButton(
//                       title: '5. Add Image',
//                       onPressed: _testAddImage,
//                       color: Colors.purple,
//                     ),
//                     _buildTestButton(
//                       title: '6. Recognize Face',
//                       onPressed: _testRecognizeFace,
//                       color: Colors.indigo,
//                     ),
//                     _buildTestButton(
//                       title: '6.1. Test Get Cropped Face',
//                       onPressed: _testGetCroppedFace,
//                       color: Colors.teal,
//                     ),
//                     _buildTestButton(
//                       title: '7. Remove Images',
//                       onPressed: _testRemoveImages,
//                       color: Colors.brown,
//                     ),
//                     _buildTestButton(
//                       title: '8. Clear All Images',
//                       onPressed: _testClearAllImages,
//                       color: Colors.brown,
//                     ),
//                     _buildTestButton(
//                       title: '9. Get Count',
//                       onPressed: _testGetCount,
//                       color: Colors.brown,
//                     ),
//                     _buildTestButton(
//                       title: '11. Clear All',
//                       onPressed: _hiveService.clearCheckInOut,
//                       color: Colors.brown,
//                     ),
//                     _buildTestButton(
//                       title: '12. Clear Persons',
//                       onPressed: _testClearPersons,
//                       color: Colors.red,
//                     ),
//                     _buildTestButton(
//                       title: '23. Get All Persons',
//                       onPressed: _testGetAllPersons,
//                       color: Colors.blueGrey,
//                     ),
//                     _buildTestButton(
//                       title: '13. Reset Both Latest Time',
//                       onPressed: _testResetBothLatestTime,
//                       color: Colors.orange,
//                     ),
//                     _buildTestButton(
//                       title: '24. Reset Is Initialized Default Data',
//                       onPressed: _testResetIsInitializedDefaultData,
//                       color: Colors.redAccent,
//                     ),
//                     _buildTestButton(
//                       title: '25. Get Current Position',
//                       onPressed: _testGetCurrentPosition,
//                       color: Colors.green,
//                     ),
//                     _buildTestButton(
//                       title: '10. Get Database Size',
//                       onPressed: _testGetDatabaseSize,
//                       color: Colors.teal,
//                     ),
//                     _buildTestButton(
//                       title: '11. Get All Images',
//                       onPressed: _testGetAllImages,
//                       color: Colors.deepOrange,
//                     ),
//                     _buildTestButton(
//                       title: '13. Sync Check In/Out Data',
//                       onPressed: _testSyncCheckInOutData,
//                       color: Colors.deepPurple,
//                     ),
//                     _buildTestButton(
//                       title: '16. Test RSA Encryption',
//                       onPressed: _testRSAEncryption,
//                       color: Colors.amber,
//                     ),
//                     _buildTestButton(
//                       title: '17. Test RSA Decryption (Full Cycle)',
//                       onPressed: _testRSADecryption,
//                       color: Colors.orange,
//                     ),
//                     _buildTestButton(
//                       title: '18. Load Keys from Assets',
//                       onPressed: _loadKeysFromAssets,
//                       color: Colors.teal,
//                     ),
//                     _buildTestButton(
//                       title: '19. Test RSA from Assets (Direct)',
//                       onPressed: _testRSAFromAssets,
//                       color: Colors.cyan,
//                     ),
//                     _buildTestButton(
//                       title: '21. Import from JSON File',
//                       onPressed: _testImportFromJsonFile,
//                       color: Colors.blue,
//                     ),
//                     _buildTestButton(
//                       title: '22. Get Database List',
//                       onPressed: _testGetDatabaseList,
//                       color: Colors.deepPurpleAccent,
//                     ),
//                     if (_isLoading)
//                       const Padding(
//                         padding: EdgeInsets.all(16),
//                         child: Center(
//                           child: CircularProgressIndicator(),
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             ),

//             const SizedBox(height: 16),

//             // Results section
//             if (_result.isNotEmpty)
//               Card(
//                 child: Padding(
//                   padding: const EdgeInsets.all(12),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           const Text(
//                             'Result:',
//                             style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                           ),
//                           IconButton(
//                             onPressed: _clearResult,
//                             icon: const Icon(Icons.clear),
//                             tooltip: 'Clear result',
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 8),
//                       Container(
//                         width: double.infinity,
//                         padding: const EdgeInsets.all(12),
//                         decoration: BoxDecoration(
//                           color: Colors.grey[100],
//                           borderRadius: BorderRadius.circular(8),
//                           border: Border.all(color: Colors.grey[300]!),
//                         ),
//                         child: Text(
//                           _result,
//                           style: const TextStyle(fontFamily: 'monospace'),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),

//             // Recognition results display
//             _buildRecognitionResults(),

//             // All images results display
//             _buildAllImagesResults(),

//             const SizedBox(height: 20),
//           ],
//         ),
//       ),
//     );
//   }
// }
