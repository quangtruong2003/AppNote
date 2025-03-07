import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:note/models/user_model.dart';
import 'package:note/screens/auth/login_screen.dart';
import 'package:note/screens/home_screen.dart';
import 'package:note/services/auth_service.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamProvider<UserModel?>.value(
      value: AuthService().authStateChanges,
      initialData: null,
      child: MaterialApp(
        title: 'Note App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);
    return user == null ? const LoginScreen() : const HomeScreen();
  }
}
