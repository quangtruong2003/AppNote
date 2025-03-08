import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isPremium = false;
  String? _premiumType;
  DateTime? _premiumExpiryDate;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isPremium => _isPremium;
  String? get premiumType => _premiumType;
  DateTime? get premiumExpiryDate => _premiumExpiryDate;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    // Set loading to true while initializing
    _isLoading = true;
    notifyListeners();

    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      if (user != null) {
        await _loadUserPremiumStatus(user.uid);
      } else {
        _isPremium = false;
        _premiumType = null;
        _premiumExpiryDate = null;
      }

      // Set loading to false after initialization
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> _loadUserPremiumStatus(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          _isPremium = data['isPremium'] ?? false;
          _premiumType = data['premiumType'];
          _premiumExpiryDate = data['premiumExpiry'] != null
              ? (data['premiumExpiry'] as Timestamp).toDate()
              : null;

          // Check if premium has expired
          if (_isPremium &&
              _premiumExpiryDate != null &&
              _premiumExpiryDate!.isBefore(DateTime.now())) {
            _isPremium = false;
            await _firestore.collection('users').doc(userId).update({
              'isPremium': false,
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading premium status: $e');
      // Don't set error here to avoid showing permission errors to users
      // For permission errors, we'll just continue without premium features
    }
    notifyListeners();
  }

  // Sign in with email and password
  Future<void> signIn(String email, String password) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = userCredential.user;

      if (_user != null) {
        // Update last login timestamp
        await _firestore.collection('users').doc(_user!.uid).update({
          'lastLoginAt': Timestamp.now(),
        });

        await _loadUserPremiumStatus(_user!.uid);
      }
    } on FirebaseAuthException catch (e) {
      _error = _getFirebaseAuthErrorMessage(e.code);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Register with email and password
  Future<void> register(String email, String password, String name) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = userCredential.user;

      if (_user != null) {
        // Update user profile
        await _user!.updateDisplayName(name);

        // Create user document in Firestore
        await _firestore.collection('users').doc(_user!.uid).set({
          'email': email,
          'name': name,
          'isPremium': false,
          'notesCount': 0,
          'createdAt': Timestamp.now(),
          'lastLoginAt': Timestamp.now(),
        });
      }
    } on FirebaseAuthException catch (e) {
      _error = _getFirebaseAuthErrorMessage(e.code);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign in with Google
  Future<bool> loginWithGoogle() async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      // Begin interactive sign in process
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.signIn();
      } catch (e) {
        debugPrint('Google SignIn internal error: $e');
        _isLoading = false;
        _error = 'Google Sign In failed. Please try again.';
        notifyListeners();
        return false;
      }

      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return false; // User canceled sign in
      }

      // Obtain auth details from request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with credential
      final userCredential = await _auth.signInWithCredential(credential);
      _user = userCredential.user;

      // Update user data in Firestore with error handling for permissions
      if (_user != null) {
        try {
          // Check if user already exists in Firestore
          final docRef = _firestore.collection('users').doc(_user!.uid);
          final doc = await docRef.get();

          if (!doc.exists) {
            // Create new user document in Firestore
            try {
              await docRef.set({
                'email': _user!.email,
                'name': _user!.displayName,
                'photoUrl': _user!.photoURL,
                'isPremium': false,
                'notesCount': 0,
                'createdAt': Timestamp.now(),
                'lastLoginAt': Timestamp.now(),
              });
            } catch (firestoreError) {
              debugPrint('Firestore create document error: $firestoreError');
              // Continue even if this fails - user is still authenticated
            }
          } else {
            // Update last login timestamp
            try {
              await docRef.update({
                'lastLoginAt': Timestamp.now(),
                'name': _user!.displayName,
                'photoUrl': _user!.photoURL,
              });
            } catch (firestoreError) {
              debugPrint('Firestore update document error: $firestoreError');
              // Continue even if this fails - user is still authenticated
            }
          }

          try {
            await _loadUserPremiumStatus(_user!.uid);
          } catch (premiumError) {
            debugPrint('Error loading premium status: $premiumError');
            // Continue without premium status
          }
        } catch (firestoreError) {
          debugPrint('Firestore operations error: $firestoreError');
          // The user is still authenticated with Firebase Auth, so we continue
        }
      }

      _isLoading = false;
      notifyListeners();
      return true; // Authentication successful even if Firestore operations failed
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      _error = 'Authentication failed. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      _user = null;
      _isPremium = false;
      _premiumType = null;
      _premiumExpiryDate = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      _error = _getFirebaseAuthErrorMessage(e.code);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Delete user data from Firestore
        await _firestore.collection('users').doc(user.uid).delete();

        // Delete user account
        await user.delete();
        _user = null;
      }
    } on FirebaseAuthException catch (e) {
      _error = _getFirebaseAuthErrorMessage(e.code);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Activate premium
  Future<void> activatePremium(String productId, String purchaseId) async {
    if (_user == null) return;

    try {
      final String premiumType;
      final DateTime expiryDate;

      if (productId.contains('lifetime')) {
        premiumType = 'Lifetime';
        expiryDate = DateTime(2099, 12, 31); // Far future date
      } else if (productId.contains('yearly')) {
        premiumType = 'Yearly';
        expiryDate = DateTime.now().add(const Duration(days: 365));
      } else {
        premiumType = 'Monthly';
        expiryDate = DateTime.now().add(const Duration(days: 30));
      }

      await _firestore.collection('users').doc(_user!.uid).update({
        'isPremium': true,
        'premiumType': premiumType,
        'premiumExpiry': Timestamp.fromDate(expiryDate),
        'purchaseId': purchaseId,
        'updatedAt': Timestamp.now(),
      });

      _isPremium = true;
      _premiumType = premiumType;
      _premiumExpiryDate = expiryDate;

      notifyListeners();
    } catch (e) {
      debugPrint('Error activating premium: $e');
    }
  }

  // Helper method to get user-friendly error messages
  String _getFirebaseAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'operation-not-allowed':
        return 'This operation is not allowed. Contact support.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'requires-recent-login':
        return 'This operation requires recent authentication. Please log in again.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
