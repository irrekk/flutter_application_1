enum UserRole { admin, coach, player }

class AppUser {
  final String id; // 登入帳號
  final UserRole role;
  String? displayName; // 中文姓名（admin 永遠不用）
  String? idNumber; // 身分證字號
  String? birthday; // 西元年（四位數），存為字串方便空值處理
  String password;
  bool mustChangePassword;

  AppUser({
    required this.id,
    required this.role,
    required this.password,
    this.displayName,
    this.idNumber,
    this.birthday,
    this.mustChangePassword = true,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isCoach => role == UserRole.coach;
  bool get isPlayer => role == UserRole.player;

  String get roleLabel {
    switch (role) {
      case UserRole.admin:
        return '管理員';
      case UserRole.coach:
        return '教練';
      case UserRole.player:
        return '球員';
    }
  }

  /// 畫面上顯示用名字（admin 永遠顯示「管理員」）
  String get titleName {
    if (isAdmin) return '管理員';
    final name = (displayName ?? '').trim();
    return name.isEmpty ? '未設定' : name;
  }

  /// Firestore 轉 Map（存到 users collection 用）
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'role': switch (role) {
        UserRole.admin => 'admin',
        UserRole.coach => 'coach',
        UserRole.player => 'player',
      },
      'displayName': displayName,
      'idNumber': idNumber,
      'birthday': birthday,
      'password': password,
      'mustChangePassword': mustChangePassword,
    };
  }

  /// 從 Firestore 取回 Map 建立 AppUser
  factory AppUser.fromMap(String id, Map<String, dynamic> data) {
    final roleStr = (data['role'] as String? ?? 'player').toLowerCase();
    final role = switch (roleStr) {
      'admin' => UserRole.admin,
      'coach' => UserRole.coach,
      _ => UserRole.player,
    };

    return AppUser(
      id: id,
      role: role,
      password: (data['password'] as String?) ?? '',
      displayName: data['displayName'] as String?,
      idNumber: data['idNumber'] as String?,
      birthday: data['birthday'] as String?,
      mustChangePassword: (data['mustChangePassword'] as bool?) ?? true,
    );
  }
}
