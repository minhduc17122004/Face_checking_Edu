// ============================================================
// DEPRECATED: This file is no longer needed
// Image loading is now handled by FaceNative SDK
// ============================================================

// import 'dart:io';
// import 'dart:typed_data';
// import 'dart:convert';
// import 'package:flutter/services.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:path/path.dart' as path;
// import 'package:face_time_keeping/utils/face_detection_service.dart';

// class LoadMultiImages {
//   static Future<void> loadAllImagesIntoVectorDatabase() async {
//     try {
//       // Load CSV data to get student information
//       final String csvData = await rootBundle.loadString('assets/faces.csv');
//       final List<String> lines = csvData.split('\n');

//       // Skip header and parse CSV rows
//       final Map<String, Map<String, dynamic>> imageToStudentMap = {};

//       for (int i = 1; i < lines.length; i++) {
//         if (lines[i].trim().isEmpty) continue;

//         final List<String> parts = lines[i].split(',');
//         if (parts.length >= 2) {
//           final String imageName = parts[0].trim();
//           // For this demo, we'll create synthetic student data
//           // In production, you'd have a proper mapping
//           final int studentId = imageName.hashCode % 10000; // Generate unique ID from filename
//           final String studentCode = 'STU${studentId.toString().padLeft(4, '0')}';
//           final String personName = 'Student ${studentId}';

//           imageToStudentMap[imageName] = {
//             'studentId': studentId,
//             'studentCode': studentCode,
//             'personName': personName,
//           };
//         }
//       }

//       // Get list of all JPG images in assets
//       final manifestContent = await rootBundle.loadString('AssetManifest.json');
//       final Map<String, dynamic> manifestMap = json.decode(manifestContent);

//       final List<String> imageAssets = manifestMap.keys
//           .where((String key) => key.startsWith('assets/images/') && key.endsWith('.jpg'))
//           .toList();

//       print('Found ${imageAssets.length} images to process');

//       // Process each image
//       int successCount = 0;
//       int errorCount = 0;

//       for (String assetPath in imageAssets) {
//         try {
//           final String imageName = path.basename(assetPath);

//           // Get student info for this image
//           final studentInfo = imageToStudentMap[imageName];
//           if (studentInfo == null) {
//             print('No student info found for $imageName, skipping...');
//             continue;
//           }

//           // Copy asset to temporary directory
//           final ByteData imageData = await rootBundle.load(assetPath);
//           final Directory tempDir = await getTemporaryDirectory();
//           final String tempPath = '${tempDir.path}/$imageName';
//           final File tempFile = File(tempPath);
//           await tempFile.writeAsBytes(imageData.buffer.asUint8List());

//           // Add image to vector database
//           final bool success = await FaceDetectionService.addImage(
//             studentId: studentInfo['studentId'] as int,
//             personName: studentInfo['personName'] as String,
//             studentCode: studentInfo['studentCode'] as String,
//             imageUri: tempPath,
//           );

//           if (success) {
//             successCount++;
//             print('Successfully added $imageName');
//           } else {
//             errorCount++;
//             print('Failed to add $imageName');
//           }

//           // Clean up temporary file
//           if (await tempFile.exists()) {
//             await tempFile.delete();
//           }

//         } catch (e) {
//           errorCount++;
//           print('Error processing $assetPath: $e');
//         }
//       }

//       print('Image loading completed: $successCount successful, $errorCount failed');

//     } catch (e) {
//       print('Error in loadAllImagesIntoVectorDatabase: $e');
//     }
//   }
// }
