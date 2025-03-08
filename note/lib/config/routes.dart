import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/notes/notes_list_screen.dart';
import '../screens/notes/note_detail_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/premium/premium_screen.dart';

class Routes {
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String notes = '/notes';
  static const String noteDetail = '/note-detail';
  static const String onboarding = '/onboarding';
  static const String profile = '/profile';
  static const String premium = '/premium';
  static const String initial = notes; // Define initial route as notes screen

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case notes:
        return MaterialPageRoute(builder: (_) => const NotesListScreen());
      case noteDetail:
        return MaterialPageRoute(
          builder: (_) => const NoteDetailScreen(),
          settings: settings,
        );
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case premium:
        return MaterialPageRoute(builder: (_) => const PremiumScreen());
      default:
        return MaterialPageRoute(
          builder:
              (_) => Scaffold(
                body: Center(
                  child: Text('Không tìm thấy route cho ${settings.name}'),
                ),
              ),
        );
    }
  }

  // Biến để lưu thời điểm nhấn nút back lần cuối
  static DateTime? _lastBackPressTime;

  // Phương thức xử lý khi nhấn nút back ở màn hình chính
  static Future<bool> onWillPop(BuildContext context) async {
    final DateTime now = DateTime.now();

    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      // Lưu thời điểm nhấn back
      _lastBackPressTime = now;

      // Hiển thị thông báo kiểu "Toast"
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nhấn một lần nữa để thoát'),
          duration: Duration(seconds: 2),
        ),
      );

      // Không thoát ứng dụng ở lần nhấn đầu tiên
      return false;
    }

    // Thoát ứng dụng nhưng không làm load lại app
    SystemNavigator.pop();
    return true;
  }
}
