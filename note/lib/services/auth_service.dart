import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create a new document for the user in Firestore
      await _createUserInFirestore(result.user!);

      // Send email verification
      await result.user!.sendEmailVerification();

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if email is verified
      if (!result.user!.emailVerified) {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'email-not-verified',
          message: 'Please verify your email before signing in.',
        );
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'sign-in-cancelled',
          message: 'Google sign in was cancelled',
        );
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);

      // Create or update user in Firestore
      await _createUserInFirestore(result.user!);

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Create user in Firestore
  Future<void> _createUserInFirestore(User user) async {
    UserModel userModel = UserModel(
      id: user.uid,
      email: user.email!,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      isPremium: false,
    );

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(userModel.toMap(), SetOptions(merge: true));
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    return await _auth.signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    return await _auth.sendPasswordResetEmail(email: email);
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData() async {
    try {
      if (currentUser == null) return null;

      DocumentSnapshot doc =
          await _firestore.collection('users').doc(currentUser!.uid).get();
      return UserModel.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }
}
