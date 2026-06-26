class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? profilePictureUrl;
  final String? profilePictureBase64;
  final DateTime? lastSeen;
  final bool isOnline;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.profilePictureUrl,
    this.profilePictureBase64,
    this.lastSeen,
    this.isOnline = false,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      uid: id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      profilePictureUrl: data['profilePictureUrl'],
      profilePictureBase64: data['profilePictureBase64'],
      lastSeen: data['lastSeen']?.toDate(),
      isOnline: data['isOnline'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'profilePictureUrl': profilePictureUrl,
      'profilePictureBase64': profilePictureBase64,
      'lastSeen': lastSeen,
      'isOnline': isOnline,
    };
  }

  String get displayNameOrEmail => displayName ?? email.split('@')[0];
}
