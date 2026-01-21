import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';
import 'name_page.dart';

class AdminPage extends StatefulWidget {
  final String currentId; // 目前登入者 id（例如 spartans0101）
  const AdminPage({super.key, required this.currentId});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final TextEditingController newIdCtrl = TextEditingController();
  UserRole newRole = UserRole.player;

  final TextEditingController searchCtrl = TextEditingController();

  @override
  void dispose() {
    newIdCtrl.dispose();
    searchCtrl.dispose();
    super.dispose();
  }

  bool get _isAdmin => AuthService.currentUser()?.isAdmin ?? false;

  Future<void> _editName(AppUser user) async {
    if (!_isAdmin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('只有管理員可以修改姓名')),
      );
      return;
    }
    if (user.isAdmin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('管理員姓名固定為「管理員」')),
      );
      return;
    }

    // Use full page editor (NamePage) instead of AlertDialog to avoid emulator
    // selection/paste issues that can cause framework assertions.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NamePage(id: user.id)),
    );
    if (!mounted) return;
    // NamePage shows its own SnackBars on save; refresh list after return.
    setState(() {});
  }

  Future<void> _createUser() async {
    if (!_isAdmin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('只有管理員可以新增帳號')),
      );
      return;
    }

    final id = newIdCtrl.text.trim().toLowerCase();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入新帳號')),
      );
      return;
    }

    final ok = await AuthService.adminCreateUser(newId: id, role: newRole);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '已新增帳號（初始密碼 20260101）' : '新增失敗：帳號可能已存在'),
      ),
    );

    if (ok) {
      newIdCtrl.clear();
      setState(() {});
    }
  }

  Future<void> _resetPwd(String id) async {
    if (!_isAdmin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('只有管理員可以重設密碼')),
      );
      return;
    }

    final ok = await AuthService.adminResetPassword(id: id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '已重設 $id 密碼為 20260101' : '重設失敗')),
    );
    setState(() {});
  }

  Future<void> _deleteUser(String id) async {
    if (!_isAdmin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('只有管理員可以刪除帳號')),
      );
      return;
    }

    final ok = await AuthService.adminDeleteUser(id: id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '已刪除 $id' : '刪除失敗')),
    );
    setState(() {});
  }

  bool _matchQuery(AppUser u, String q) {
    if (q.isEmpty) return true;
    final id = u.id.toLowerCase();
    final name = (u.displayName ?? '').toLowerCase();
    return id.contains(q) || name.contains(q);
  }

  String _nameLine(AppUser u) {
    // 管理員固定顯示「管理員」，不要顯示姓名設定
    if (u.role == UserRole.admin) return '管理員';
    final dn = (u.displayName ?? '').trim();
    return dn.isEmpty ? u.id : dn;
  }

  @override
  Widget build(BuildContext context) {
    final me = AuthService.currentUser();
    final isAdmin = me?.isAdmin ?? false;

    // 依你的規則：管理員 > 教練 > 球員
    int rank(UserRole r) {
      switch (r) {
        case UserRole.admin:
          return 0;
        case UserRole.coach:
          return 1;
        case UserRole.player:
          return 2;
      }
    }

    Widget userTile(AppUser u) {
      final isAdminUser = u.role == UserRole.admin;

      return ListTile(
        title: Text('${_nameLine(u)} (${u.roleLabel})'),
        subtitle: Text(u.id),
        trailing: (isAdminUser || !isAdmin)
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '編輯姓名',
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editName(u),
                  ),
                  IconButton(
                    tooltip: '重設密碼',
                    icon: const Icon(Icons.restart_alt),
                    onPressed: () => _resetPwd(u.id),
                  ),
                  IconButton(
                    tooltip: '刪除',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteUser(u.id),
                  ),
                ],
              ),
      );
    }

    return StreamBuilder<List<AppUser>>(
      stream: AuthService.listUsersStreamSorted(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('讀取資料失敗: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // 如果是第一次使用，Firestore 預設沒有資料，讓 Admin 可以直接新增
          if (isAdmin) {
            return _buildAdminControls(isAdmin, [], [], [], rank, userTile);
          }
          return const Center(child: Text('目前沒有任何使用者'));
        }

        final allUsers = snapshot.data!;
        final q = searchCtrl.text.trim().toLowerCase();
        final filtered = allUsers.where((u) => _matchQuery(u, q)).toList();

        final admins = filtered.where((u) => u.role == UserRole.admin).toList();
        final coaches = filtered.where((u) => u.role == UserRole.coach).toList();
        final players = filtered.where((u) => u.role == UserRole.player).toList();

        return _buildAdminControls(
            isAdmin,
            admins,
            coaches,
            players,
            rank,
            userTile,
        );
      },
    );
  }

  Widget _buildAdminControls(
    bool isAdmin,
    List<AppUser> admins,
    List<AppUser> coaches,
    List<AppUser> players,
    int Function(UserRole) rank,
    Widget Function(AppUser) userTile,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!isAdmin)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              '⚠️ 只有管理員可以新增/刪除/重設密碼。你目前不是管理員。',
              style: TextStyle(color: Colors.deepOrange),
            ),
          ),

        // ✅ 搜尋（姓名 / id）
        TextField(
          controller: searchCtrl,
          decoration: const InputDecoration(
            labelText: '搜尋（姓名或 ID）',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),

        // ✅ 新增帳號列（左輸入、右下拉）
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: newIdCtrl,
                enabled: isAdmin,
                decoration: const InputDecoration(
                  labelText: '新帳號',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<UserRole>(
              value: newRole,
              items: const [
                DropdownMenuItem(value: UserRole.player, child: Text('球員')),
                DropdownMenuItem(value: UserRole.coach, child: Text('教練')),
              ],
              onChanged: !isAdmin
                  ? null
                  : (v) {
                      if (v == null) return;
                      setState(() => newRole = v);
                    },
            ),
          ],
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: isAdmin ? _createUser : null,
            child: const Text('新增帳號（初始密碼 20260101）'),
          ),
        ),

        const SizedBox(height: 12),
        const Divider(),

        // ✅ 管理員（固定在最上）
        ...admins.map(userTile),

        if (admins.isNotEmpty) const Divider(),

        // ✅ 教練下拉
        ExpansionTile(
          initiallyExpanded: true,
          title: Text('教練 (${coaches.length})'),
          children: coaches.isEmpty
              ? const [ListTile(title: Text('沒有教練'))]
              : coaches.map(userTile).toList(),
        ),

        const Divider(),

        // ✅ 球員下拉
        ExpansionTile(
          initiallyExpanded: true,
          title: Text('球員 (${players.length})'),
          children: players.isEmpty
              ? const [ListTile(title: Text('沒有球員'))]
              : players.map(userTile).toList(),
        ),
      ],
    );
  }
}
