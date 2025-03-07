import 'package:flutter/material.dart';
import 'package:note/models/user_model.dart';
import 'package:note/services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  late UserModel? _user;

  @override
  void initState() {
    super.initState();
    _user = _authService.currentUser;
  }

  void _signOut() async {
    await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang Chủ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_user?.photoURL != null)
              CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(_user!.photoURL!),
              )
            else
              const CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
            const SizedBox(height: 20),
            Text(
              'Chào mừng${_user?.displayName != null ? ', ${_user!.displayName}' : ''}!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Email: ${_user?.email ?? 'N/A'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            const Text(
              'Đây là trang chủ của ứng dụng Note.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 10),
            const Text(
              'Bạn đã đăng nhập thành công!',
              style: TextStyle(fontSize: 18, color: Colors.green),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Thêm ghi chú mới
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chức năng thêm ghi chú đang được phát triển')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
