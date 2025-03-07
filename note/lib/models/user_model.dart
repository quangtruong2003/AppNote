class UserModel {
  final String? uid;
  final String? email;
  final String? displayName;
  final String? photoURL;

  UserModel({this.uid, this.email, this.displayName, this.photoURL});

  factory UserModel.fromFirebaseUser(dynamic user) {
    return UserModel(
      uid: user?.uid,
      email: user?.email,
      displayName: user?.displayName,
      photoURL: user?.photoURL,
    );
  }
}
