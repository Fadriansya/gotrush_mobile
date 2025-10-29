class UserModel {
  String uid;
  String name;
  String email;
  String phone;
  String role;
  String? fcmToken;
  String? status;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.fcmToken,
    this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'fcm_token': fcmToken,
      'status': status ?? 'offline',
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'],
      name: map['name'],
      email: map['email'],
      phone: map['phone'],
      role: map['role'],
      fcmToken: map['fcm_token'],
      status: map['status'],
    );
  }
}
