class UserModel {
  final String uid;
  String? teamId;
  
  // YENİ ALANLAR (Sadece Google ile ilk girişte kullanılır)
  bool isProfileComplete;
  String? googleDisplayName;
  String? email;

  UserModel({
    required this.uid,
    this.teamId,
    this.isProfileComplete = true, // Varsayılan olarak profilin tam olduğunu varsay
    this.googleDisplayName,
    this.email,
  });
}