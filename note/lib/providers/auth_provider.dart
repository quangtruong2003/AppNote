import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../services/storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _loading = false;
  UserModel? _user;
  bool _isPremium = false;
  String? _profileImageUrl;
  String? _error;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    _loading = true;
    notifyListeners();
    try {
      await checkCurrentUser();
    } catch (e) {
      debugPrint('Init error: $e');
    }
    _loading = false;
    notifyListeners();
  }

  // Getters
  bool get loading => _loading;
  bool get isLoading => _loading; // Thêm alias cho loading để tương thích
  User? get user => _authService.currentUser;
  UserModel? get userModel => _user;
  bool get isPremium => _isPremium;
  bool get isLoggedIn => _authService.currentUser != null;
  bool get isAuthenticated =>
      _authService.currentUser != null; // Thêm alias cho isLoggedIn
  String? get profileImageUrl => _profileImageUrl;
  String? get error => _error; // Thêm getter cho error

  // Kiểm tra xem người dùng có đăng nhập bằng Google không
  bool get isGoogleSignIn {
    final user = _authService.currentUser;
    if (user == null) return false;

    // Kiểm tra các provider ID để xác định phương thức đăng nhập
    for (final providerProfile in user.providerData) {
      if (providerProfile.providerId == 'google.com') {
        return true;
      }
    }
    return false;
  }

  // Xử lý và lưu lỗi
  void _setError(dynamic e) {
    if (e is FirebaseAuthException) {
      _error = e.message;
    } else {
      _error = e.toString();
    }
    notifyListeners();
  }

  // Xóa thông báo lỗi
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Kiểm tra người dùng hiện tại
  Future<void> checkCurrentUser() async {
    final user = _authService.currentUser;
    if (user != null) {
      _user = await _authService.getUserData();
      _isPremium = _user?.isPremium ?? false;
      _profileImageUrl = _user?.photoUrl;
      notifyListeners();
    }
  }

  // Đăng ký với email và mật khẩu
  Future<void> registerWithEmailAndPassword(
    String email,
    String password,
  ) async {
    _loading = true;
    notifyListeners();
    try {
      await _authService.registerWithEmailAndPassword(email, password);
    } catch (e) {
      _setError(e);
      _loading = false;
      notifyListeners();
      rethrow;
    }
    _loading = false;
    notifyListeners();
  }

  // Phương thức đăng ký (alias cho registerWithEmailAndPassword)
  Future<void> register(String email, String password) async {
    await registerWithEmailAndPassword(email, password);
  }

  // Đăng nhập với email và mật khẩu
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.signInWithEmailAndPassword(email, password);
      await checkCurrentUser();
    } catch (e) {
      _setError(e);
      _loading = false;
      notifyListeners();
      rethrow;
    }
    _loading = false;
    notifyListeners();
  }

  // Phương thức đăng nhập (alias cho signInWithEmailAndPassword)
  Future<void> signIn(String email, String password) async {
    await signInWithEmailAndPassword(email, password);
  }

  // Đăng nhập với Google
  Future<void> signInWithGoogle() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.signInWithGoogle();
      await checkCurrentUser();
    } catch (e) {
      _setError(e);
      _loading = false;
      notifyListeners();
      rethrow;
    }
    _loading = false;
    notifyListeners();
  }

  // Phương thức đăng nhập với Google (alias cho signInWithGoogle)
  Future<void> loginWithGoogle() async {
    await signInWithGoogle();
  }

  // Đăng xuất
  Future<void> signOut() async {
    _loading = true;
    notifyListeners();
    try {
      await _authService.signOut();
      _user = null;
      _isPremium = false;
      _profileImageUrl = null;
    } catch (e) {
      _setError(e);
      _loading = false;
      notifyListeners();
      rethrow;
    }
    _loading = false;
    notifyListeners();
  }

  // Xóa tài khoản
  Future<void> deleteAccount() async {
    _loading = true;
    notifyListeners();
    try {
      await _authService.deleteAccount();
      _user = null;
      _isPremium = false;
      _profileImageUrl = null;
    } catch (e) {
      _setError(e);
      _loading = false;
      notifyListeners();
      rethrow;
    }
    _loading = false;
    notifyListeners();
  }

  // Đặt lại mật khẩu
  Future<void> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
    } catch (e) {
      _setError(e);
      rethrow;
    }
  }

  // Thay đổi mật khẩu
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    _loading = true;
    notifyListeners();
    try {
      await _authService.changePassword(currentPassword, newPassword);
    } catch (e) {
      _setError(e);
      _loading = false;
      notifyListeners();
      rethrow;
    }
    _loading = false;
    notifyListeners();
  }

  // Cập nhật thông tin hồ sơ người dùng với xử lý tải ảnh lên cải tiến
  Future<void> updateProfile(String displayName, {File? photoFile}) async {
    _loading = true;
    notifyListeners();

    try {
      if (_authService.currentUser == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }

      // Cập nhật ảnh đại diện nếu có
      String? photoURL = _authService.currentUser?.photoURL;
      if (photoFile != null) {
        try {
          // Tạo reference cho storage với đường dẫn đúng
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('user_avatars')
              .child(
                '${_authService.currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
              );

          // Thiết lập metadata cho ảnh
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {'userId': _authService.currentUser!.uid},
          );

          // Tải ảnh lên với metadata
          final uploadTask = storageRef.putFile(photoFile, metadata);

          // Theo dõi tiến trình tải lên (tùy chọn)
          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            debugPrint(
              'Tiến trình tải lên: ${(progress * 100).toStringAsFixed(1)}%',
            );
          });

          // Đợi tải lên hoàn tất
          final snapshot = await uploadTask;

          // Lấy URL download
          photoURL = await snapshot.ref.getDownloadURL();
          debugPrint('Tải ảnh đại diện lên thành công: $photoURL');
        } catch (e) {
          debugPrint('Lỗi khi tải ảnh lên Firebase Storage: $e');
          // Nếu lỗi tải lên ảnh, vẫn tiếp tục cập nhật tên
          // không throw exception ở đây để người dùng vẫn cập nhật được tên
        }
      }

      // Cập nhật thông tin người dùng
      await _authService.currentUser!.updateDisplayName(displayName);
      if (photoURL != null) {
        await _authService.currentUser!.updatePhotoURL(photoURL);
      }

      // Cập nhật thông tin trong Firestore
      if (_authService.currentUser != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_authService.currentUser!.uid)
              .set({
                'displayName': displayName,
                'photoURL': photoURL,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Lỗi khi cập nhật Firestore: $e');
          // Không throw exception ở đây
        }
      }

      // Làm mới thông tin người dùng
      await reloadUser();
    } catch (e) {
      _setError(e);
      _loading = false;
      notifyListeners();
      rethrow;
    }

    _loading = false;
    notifyListeners();
  }

  // Tải lại thông tin người dùng
  Future<void> reloadUser() async {
    _loading = true;
    notifyListeners();
    try {
      await _authService.reloadUser();
      await checkCurrentUser();
    } catch (e) {
      _setError(e);
      _loading = false;
      notifyListeners();
      rethrow;
    }
    _loading = false;
    notifyListeners();
  }

  // Gửi lại email xác thực
  Future<void> resendVerificationEmail() async {
    _loading = true;
    notifyListeners();
    try {
      await _authService.sendVerificationEmail();
    } catch (e) {
      _setError(e);
      _loading = false;
      notifyListeners();
      rethrow;
    }
    _loading = false;
    notifyListeners();
  }

  // Đổi tên hàm này để tránh trùng lặp
  Future<void> registerWithDisplayName(
    String email,
    String password, [
    String? displayName,
  ]) async {
    _loading = true;
    notifyListeners();
    try {
      await _authService.registerWithEmailAndPassword(email, password);

      // Cập nhật tên hiển thị nếu được cung cấp
      if (displayName != null &&
          displayName.isNotEmpty &&
          _authService.currentUser != null) {
        await _authService.updateUserProfile(displayName, null);
      }
    } catch (e) {
      _setError(e);
      _loading = false;
      notifyListeners();
      rethrow;
    }
    _loading = false;
    notifyListeners();
  }

  // Các thuộc tính và phương thức liên quan đến premium
  String? _premiumType;
  DateTime? _premiumExpiryDate;

  String? get premiumType => _premiumType;
  DateTime? get premiumExpiryDate => _premiumExpiryDate;

  // Kích hoạt tính năng premium
  Future<void> activatePremium(String productId, String purchaseId) async {
    _loading = true;
    notifyListeners();
    try {
      // Thiết lập kiểu premium dựa trên sản phẩm đã mua
      if (productId.contains('monthly')) {
        _premiumType = 'Monthly';
        _premiumExpiryDate = DateTime.now().add(const Duration(days: 30));
      } else if (productId.contains('yearly')) {
        _premiumType = 'Yearly';
        _premiumExpiryDate = DateTime.now().add(const Duration(days: 365));
      } else if (productId.contains('lifetime')) {
        _premiumType = 'Lifetime';
        _premiumExpiryDate = null; // Không hết hạn
      }

      // Cập nhật trạng thái premium
      _isPremium = true;

      // Cập nhật thông tin trong Firestore
      if (user != null) {
        await _firestore.collection('users').doc(user!.uid).update({
          'isPremium': true,
          'premiumType': _premiumType,
          'premiumExpiryDate': _premiumExpiryDate?.toIso8601String(),
          'purchaseId': purchaseId,
        });
      }
    } catch (e) {
      _setError(e);
      _loading = false;
      notifyListeners();
      rethrow;
    }
    _loading = false;
    notifyListeners();
  }
}
