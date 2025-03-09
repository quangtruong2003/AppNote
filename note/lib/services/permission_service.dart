import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  // Kiểm tra và yêu cầu quyền truy cập camera
  static Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.request();

    if (status.isDenied || status.isPermanentlyDenied) {
      if (context.mounted) {
        _showPermissionDialog(
          context,
          'Quyền truy cập máy ảnh',
          'Ứng dụng cần quyền truy cập máy ảnh để chụp ảnh. Vui lòng cấp quyền trong cài đặt ứng dụng.',
        );
      }
      return false;
    }

    return status.isGranted;
  }

  // Kiểm tra và yêu cầu quyền truy cập thư viện ảnh
  static Future<bool> requestPhotosPermission(BuildContext context) async {
    final status = await Permission.photos.request();

    if (status.isDenied || status.isPermanentlyDenied) {
      if (context.mounted) {
        _showPermissionDialog(
          context,
          'Quyền truy cập thư viện ảnh',
          'Ứng dụng cần quyền truy cập thư viện ảnh để lưu ảnh. Vui lòng cấp quyền trong cài đặt ứng dụng.',
        );
      }
      return false;
    }

    return status.isGranted;
  }

  // Kiểm tra và yêu cầu quyền truy cập bộ nhớ
  static Future<bool> requestStoragePermission(BuildContext context) async {
    final status = await Permission.storage.request();

    if (status.isDenied || status.isPermanentlyDenied) {
      if (context.mounted) {
        _showPermissionDialog(
          context,
          'Quyền truy cập bộ nhớ',
          'Ứng dụng cần quyền truy cập bộ nhớ để lưu và đọc tập tin. Vui lòng cấp quyền trong cài đặt ứng dụng.',
        );
      }
      return false;
    }

    return status.isGranted;
  }

  // Hiển thị dialog khi quyền bị từ chối
  static void _showPermissionDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Để sau'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                child: const Text('Mở cài đặt'),
              ),
            ],
          ),
    );
  }
}
