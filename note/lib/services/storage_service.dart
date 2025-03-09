import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Tải lên hình ảnh đại diện
  Future<String> uploadProfileImage(String userId, File imageFile) async {
    try {
      if (userId.isEmpty) {
        throw Exception('User ID is empty. Cannot upload.');
      }

      // Check if the file exists
      if (!imageFile.existsSync()) {
        throw Exception('Image file does not exist or is inaccessible.');
      }

      // Simplest possible approach - store directly at root with userId
      String fileName = 'profile_$userId${path.extension(imageFile.path)}';
      print('Uploading to: $fileName');

      // Direct reference to root location
      Reference ref = _storage.ref().child(fileName);
      print('Storage reference path: ${ref.fullPath}');

      // Create basic upload task with no metadata
      print('Starting file upload...');
      UploadTask uploadTask = ref.putFile(imageFile);
      print('Upload task created');

      // Wait for completion
      TaskSnapshot taskSnapshot = await uploadTask;
      print(
        'Upload complete: ${taskSnapshot.bytesTransferred} bytes transferred',
      );

      // Get download URL
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      print('Download URL obtained: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      throw Exception(
        'Failed to upload profile image. Please check your Firebase Storage rules and configuration.',
      );
    }
  }
}
