import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/app_user.dart';

class LoginResult {
  final bool ok;
  final String message;
  final AppUser? user;

  const LoginResult({
    required this.ok,
    required this.message,
    required this.user,
  });

  bool get isAdmin => user?.isAdmin ?? false;
  bool get mustChangePassword => user?.mustChangePassword ?? false;
}

class AuthService {
  static const String defaultPwd = '20260101';
  // secure storage for saved credentials
  static const _storageId = 'auth_saved_id';
  static const _storagePwd = 'auth_saved_pwd';
  static const _storageSavedAt = 'auth_saved_at';
  static const _storageRemember = 'auth_saved_remember';
  static final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  // session durations
  static final Duration _shortSession = const Duration(days: 1);
  static final Duration _longSession = const Duration(days: 30);

  // Helper to rank roles for sorting
  static int _rankRole(UserRole r) {
    switch (r) {
      case UserRole.admin: return 0;
      case UserRole.coach: return 1;
      case UserRole.player: return 2;
    }
  }

  static String? _currentUserId;

  static String _keyOf(String id) => id.trim().toLowerCase();

  static final _usersRef =
      FirebaseFirestore.instance.collection('users').withConverter<AppUser>(
            fromFirestore: (snap, _) =>
                AppUser.fromMap(snap.id, snap.data() ?? const <String, dynamic>{}),
            toFirestore: (user, _) => user.toMap(),
          );

  static AppUser? _currentUserCache;

  static AppUser? currentUser() => _currentUserCache;

  static Future<AppUser?> _loadUser(String id) async {
    final doc = await _usersRef.doc(_keyOf(id)).get();
    return doc.data();
  }

  /// Public helper to fetch a user by id
  static Future<AppUser?> getUserById(String id) async {
    return await _loadUser(id);
  }

  static Future<LoginResult> login({
    required String id,
    required String password,
  }) async {
    final u = await _loadUser(id);

    if (u == null) {
      return const LoginResult(ok: false, message: '帳號不存在', user: null);
    }
    if (u.password != password) {
      return const LoginResult(ok: false, message: '密碼錯誤', user: null);
    }

    _currentUserId = u.id;
    _currentUserCache = u;
    return LoginResult(ok: true, message: '登入成功', user: u);
  }

  /// Save credentials securely. remember == true => long session.
  static Future<void> saveCredentials({
    required String id,
    required String password,
    required bool remember,
  }) async {
    await _secureStorage.write(key: _storageId, value: _keyOf(id));
    await _secureStorage.write(key: _storagePwd, value: password);
    await _secureStorage.write(key: _storageSavedAt, value: DateTime.now().millisecondsSinceEpoch.toString());
    await _secureStorage.write(key: _storageRemember, value: remember ? '1' : '0');
  }

  static Future<void> clearSavedCredentials() async {
    await _secureStorage.delete(key: _storageId);
    await _secureStorage.delete(key: _storagePwd);
    await _secureStorage.delete(key: _storageSavedAt);
    await _secureStorage.delete(key: _storageRemember);
  }

  /// Attempt auto-login using saved credentials. Returns true if login succeeded.
  static Future<bool> tryAutoLogin() async {
    try {
      final id = await _secureStorage.read(key: _storageId);
      final pwd = await _secureStorage.read(key: _storagePwd);
      final at = await _secureStorage.read(key: _storageSavedAt);
      final rem = await _secureStorage.read(key: _storageRemember);
      if (id == null || pwd == null || at == null || rem == null) return false;
      final savedAt = int.tryParse(at);
      if (savedAt == null) {
        await clearSavedCredentials();
        return false;
      }
      final remember = rem == '1';
      final expiry = remember ? _longSession : _shortSession;
      final savedDate = DateTime.fromMillisecondsSinceEpoch(savedAt);
      if (DateTime.now().difference(savedDate) > expiry) {
        await clearSavedCredentials();
        return false;
      }
      final res = await login(id: id, password: pwd);
      if (!res.ok) {
        await clearSavedCredentials();
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> logout() async {
    _currentUserId = null;
    _currentUserCache = null;
    // Clear saved credentials on logout for security
    await clearSavedCredentials();
  }

  static Future<bool> changePassword({
    required String id,
    required String newPassword,
  }) async {
    final docRef = _usersRef.doc(_keyOf(id));
    final snap = await docRef.get();
    final u = snap.data();
    if (u == null) return false;

    await docRef.update({
      'password': newPassword,
      'mustChangePassword': false,
    });

    if (_currentUserCache?.id == u.id) {
      _currentUserCache = AppUser(
        id: u.id,
        role: u.role,
        password: newPassword,
        displayName: u.displayName,
        mustChangePassword: false,
      );
    }

    return true;
  }

  /// 只有非 admin 才能改中文名；admin 永遠顯示「管理員」
  static Future<bool> setDisplayName({
    required String id,
    required String displayName,
  }) async {
    final docRef = _usersRef.doc(_keyOf(id));
    final snap = await docRef.get();
    final u = snap.data();
    if (u == null || u.isAdmin) return false;

    final name = displayName.trim();
    await docRef.update({'displayName': name});

    if (_currentUserCache?.id == u.id) {
      _currentUserCache = AppUser(
        id: u.id,
        role: u.role,
        password: u.password,
        displayName: name,
        mustChangePassword: u.mustChangePassword,
      );
    }

    return true;
  }

  /// 管理員修改任意非管理員的中文姓名
  static Future<bool> adminSetDisplayName({
    required String targetId,
    required String displayName,
  }) async {
    final me = currentUser();
    if (me == null || !me.isAdmin) return false;

    final key = _keyOf(targetId);
    final docRef = _usersRef.doc(key);
    final snap = await docRef.get();
    final u = snap.data();
    if (u == null) return false;
    if (u.isAdmin) return false;

    final name = displayName.trim();
    if (name.isEmpty) return false;

    await docRef.update({'displayName': name});

    if (_currentUserCache?.id == u.id) {
      _currentUserCache = AppUser(
        id: u.id,
        role: u.role,
        password: u.password,
        displayName: name,
        mustChangePassword: u.mustChangePassword,
      );
    }

    return true;
  }

  /// Update personal info (displayName, birthday, idNumber) for a user.
  /// Only non-admins can update their own displayName via setDisplayName/setPersonalInfo.
  static Future<bool> setPersonalInfo({
    required String id,
    String? displayName,
    String? birthday,
    String? idNumber,
  }) async {
    final key = _keyOf(id);
    final docRef = _usersRef.doc(key);
    final snap = await docRef.get();
    final u = snap.data();
    if (u == null) return false;

    final Map<String, dynamic> update = <String, dynamic>{};
    if (displayName != null) update['displayName'] = displayName.trim();
    if (birthday != null) update['birthday'] = birthday.trim();
    if (idNumber != null) update['idNumber'] = idNumber.trim();

    if (update.isEmpty) return false;

    await docRef.update(update);

    // update cache if same user
    if (_currentUserCache?.id == u.id) {
      _currentUserCache = AppUser(
        id: u.id,
        role: u.role,
        password: u.password,
        displayName: update.containsKey('displayName') ? update['displayName'] as String? : u.displayName,
        idNumber: update.containsKey('idNumber') ? update['idNumber'] as String? : u.idNumber,
        birthday: update.containsKey('birthday') ? update['birthday'] as String? : u.birthday,
        mustChangePassword: u.mustChangePassword,
      );
    }

    return true;
  }

  static Stream<List<AppUser>> listUsersStreamSorted() {
    return _usersRef.snapshots().map((snapshot) {
      final users = snapshot.docs.map((doc) => doc.data()).toList();
      // Sort users by role (admin > coach > player) and then by id
      users.sort((a, b) {
        final rankA = _rankRole(a.role);
        final rankB = _rankRole(b.role);
        if (rankA != rankB) return rankA.compareTo(rankB);
        return a.id.compareTo(b.id);
      });
      return users;
    });
  }

  static Future<bool> adminCreateUser({
    required String newId,
    required UserRole role,
  }) async {
    final me = currentUser();
    if (me == null || !me.isAdmin) return false;

    final key = _keyOf(newId);
    if (key.isEmpty) return false;
    final docRef = _usersRef.doc(key);
    final existing = await docRef.get();
    if (existing.exists) return false;

    final user = AppUser(
      id: key,
      role: role,
      password: defaultPwd,
      mustChangePassword: true,
    );
    await docRef.set(user);
    return true;
  }

  static Future<bool> adminDeleteUser({required String id}) async {
    final me = currentUser();
    if (me == null || !me.isAdmin) return false;

    final key = _keyOf(id);
    final docRef = _usersRef.doc(key);
    final snap = await docRef.get();
    final u = snap.data();
    if (u == null) return false;
    if (u.isAdmin) return false; // 不刪管理員

    await docRef.delete();
    if (_currentUserId == u.id) {
      _currentUserId = null;
      _currentUserCache = null;
    }
    return true;
  }

  static Future<bool> adminResetPassword({required String id}) async {
    final me = currentUser();
    if (me == null || !me.isAdmin) return false;

    final key = _keyOf(id);
    final docRef = _usersRef.doc(key);
    final snap = await docRef.get();
    final u = snap.data();
    if (u == null) return false;
    if (u.isAdmin) return false;

    await docRef.update({
      'password': defaultPwd,
      'mustChangePassword': true,
    });

    if (_currentUserCache?.id == u.id) {
      _currentUserCache = AppUser(
        id: u.id,
        role: u.role,
        password: defaultPwd,
        displayName: u.displayName,
        mustChangePassword: true,
      );
    }
    return true;
  }
}
