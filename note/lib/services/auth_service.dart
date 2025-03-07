import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:note/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Lấy thông tin người dùng hiện tại
  UserModel? get currentUser {
    return _auth.currentUser != null 
        ? UserModel.fromFirebaseUser(_auth.currentUser) 
        : null;
  }

  // Stream trạng thái xác thực
  Stream<UserModel?> get authStateChanges {
    return _auth.authStateChanges().map((User? user) {
      return user != null ? UserModel.fromFirebaseUser(user) : null;
    });
  }

  // Đăng ký bằng email và mật khẩu
  Future<UserModel?> registerWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      return UserModel.fromFirebaseUser(result.user);
    } on FirebaseAuthException catch (e) {
      print('Lỗi đăng ký: ${e.message}');
      rethrow;
    }
  }

  // Đăng nhập bằng email và mật khẩu
  Future<UserModel?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      return UserModel.fromFirebaseUser(result.user);
    } on FirebaseAuthException catch (e) {
      print('Lỗi đăng nhập: ${e.message}');
      rethrow;
    }
  }

  // Đăng nhập bằng Google
  Future<UserModel?> signInWithGoogle() async {
    try {
      // Bắt đầu quy trình xác thực
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) return null;

      // Lấy thông tin xác thực từ request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Tạo thông tin xác thực mới
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Đăng nhập với Firebase
      UserCredential result = await _auth.signInWithCredential(credential);
      
      return UserModel.fromFirebaseUser(result.user);
    } on FirebaseAuthException catch (e) {
      print('Lỗi đăng nhập Google: ${e.message}');
      rethrow;
    }
  }

  // Đăng xuất
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      return await _auth.signOut();
    } catch (e) {
      print('Lỗi đăng xuất: $e');
      rethrow;
    }
  }
}
