import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:provider/provider.dart';
import 'package:note/providers/auth_provider.dart';
import 'package:note/providers/note_provider.dart';
import 'package:note/providers/theme_provider.dart';
import 'package:note/config/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

void main() {
  // Catch any errors that occur during initialization
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      try {
        // Initialize Firebase
        await Firebase.initializeApp();
        debugPrint('Firebase initialized successfully');

        // Request permissions when app starts
        if (!kIsWeb) {
          await _requestPermissions();
        }

        // Set persistence for Firebase Auth only on web platforms
        // This feature is only available on web
        if (kIsWeb) {
          await firebase_auth.FirebaseAuth.instance.setPersistence(
            firebase_auth.Persistence.LOCAL,
          );
          debugPrint('Firebase Auth persistence set successfully');
        }

        // Check if user has seen onboarding
        final prefs = await SharedPreferences.getInstance();
        final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
        debugPrint('Seen onboarding: $seenOnboarding');

        runApp(MyApp(seenOnboarding: seenOnboarding));
      } catch (e, stackTrace) {
        debugPrint('Initialization error: $e');
        debugPrint('Stack trace: $stackTrace');
        // Show a more helpful error message
        runApp(ErrorApp(errorMessage: e.toString()));
      }
    },
    (error, stack) {
      debugPrint('Uncaught error: $error');
      debugPrint('Stack trace: $stack');
    },
  );
}

// Function to request permissions
Future<void> _requestPermissions() async {
  // Request storage and camera permissions
  await [Permission.storage, Permission.camera, Permission.photos].request();

  // Không cần đợi người dùng cấp quyền, ứng dụng vẫn tiếp tục chạy
  // Các màn hình cụ thể sẽ kiểm tra quyền khi cần thiết
}

// Widget to display when there's an initialization error
class ErrorApp extends StatelessWidget {
  final String? errorMessage;

  const ErrorApp({super.key, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Đã xảy ra lỗi khi khởi động ứng dụng',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Vui lòng thử khởi động lại ứng dụng',
                textAlign: TextAlign.center,
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Chi tiết lỗi: $errorMessage',
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Try restarting the app
                  main();
                },
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final bool seenOnboarding;

  const MyApp({super.key, this.seenOnboarding = false});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NoteProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              return MaterialApp(
                title: 'Note App',
                // Sửa lỗi theme ở đây - đảm bảo sử dụng đúng theme cho dark/light mode
                theme:
                    themeProvider.isDarkMode
                        ? themeProvider
                            .darkTheme // Sử dụng dark theme
                        : themeProvider.lightTheme, // Sử dụng light theme
                onGenerateRoute: Routes.generateRoute,
                initialRoute: _determineInitialRoute(
                  authProvider,
                  seenOnboarding,
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _determineInitialRoute(
    AuthProvider authProvider,
    bool seenOnboarding,
  ) {
    try {
      // Check if Firebase has a current user first (handles persistence)
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
      debugPrint('Current user: ${currentUser?.email}');

      if (!seenOnboarding) {
        debugPrint('Redirecting to onboarding');
        return Routes.onboarding;
      } else if (currentUser != null || authProvider.isAuthenticated) {
        debugPrint('User is authenticated, redirecting to notes');
        return Routes.notes;
      } else {
        debugPrint('User is not authenticated, redirecting to login');
        return Routes.login;
      }
    } catch (e) {
      // If anything goes wrong, default to login screen
      debugPrint('Error determining initial route: $e');
      return Routes.login;
    }
  }
}
