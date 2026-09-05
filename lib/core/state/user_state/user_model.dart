class UserModel {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String? profileImageUrl;

  UserModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.profileImageUrl,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      firstName: map['firstName'] ?? 'User',
      lastName: map['lastName'] ?? '',
      email: map['email'] ?? '',
      profileImageUrl: map['profileImage'] as String?,
    );
  }

  String get fullName => '$firstName $lastName'.trim();

  UserModel copyWith({
    String? uid,
    String? firstName,
    String? lastName,
    String? email,
    String? profileImageUrl,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}
