import 'package:flutter/material.dart';
import 'package:note/screens/auth/register_screen.dart';
import 'package:note/services/auth_service.dart';
import 'package:note/widgets/auth_button.dart';
import 'package:note/widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _signInWithEmailAndPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đăng nhập thất bại: ${e.toString()}')),
        );
      }
    }
  }

  void _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng nhập Google thất bại: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng Nhập'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 50),
                    const Icon(
                      Icons.note_alt,
                      size: 100,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Ứng Dụng Ghi Chú',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 40),
                    CustomTextField(
                      controller: _emailController,
                      labelText: 'Email',
                      hintText: 'Nhập email của bạn',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Vui lòng nhập email hợp lệ';
                        }
                        return null;
                      },
                    ),
                    CustomTextField(
                      controller: _passwordController,
                      labelText: 'Mật khẩu',
                      hintText: 'Nhập mật khẩu của bạn',
                      isPassword: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập mật khẩu';
                        }
                        if (value.length < 6) {
                          return 'Mật khẩu phải có ít nhất 6 ký tự';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    AuthButton(
                      text: 'Đăng Nhập',
                      onPressed: _signInWithEmailAndPassword,
                      color: Colors.blue,
                      icon: Icons.login,
                    ),
                    const SizedBox(height: 20),
                    AuthButton(
                      text: 'Đăng Nhập với Google',
                      onPressed: _signInWithGoogle,
                      color: Colors.white,
                      textColor: Colors.black,
                      icon: Icons.g_mobiledata,
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text('Chưa có tài khoản? Đăng ký'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
