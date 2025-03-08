import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final bool isPremium;
  final DateTime? premiumExpiry;

  UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.isPremium,
    this.premiumExpiry,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'isPremium': isPremium,
      'premiumExpiry':
          premiumExpiry != null ? Timestamp.fromDate(premiumExpiry!) : null,
    };
  }

  static UserModel fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      isPremium: data['isPremium'] ?? false,
      premiumExpiry:
          data['premiumExpiry'] != null
              ? (data['premiumExpiry'] as Timestamp).toDate()
              : null,
    );
  }
}
