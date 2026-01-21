import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/announcement_service.dart';
import '../models/announcement.dart';
import 'login_page.dart';
import 'admin_page.dart';
import 'training_page.dart';
import 'name_page.dart';
import 'id_number_page.dart';
import 'birthdate_page.dart';
import 'announcement_create_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final me = AuthService.currentUser();

    final titleRight = me == null
        ? ''
        : (me.isAdmin
            ? '管理員'
            : ((me.displayName?.trim().isNotEmpty == true)
                ? me.displayName!.trim()
                : me.id));

    final pages = [
      const _HomeTab(), // 0 首頁（先空白）
      const TrainingPage(), // 1 訓練
      const _ProfileTab(), // 2 個人
      // ✅ 管理頁：非管理員顯示提示（即使被擋，也保險）
      (me != null && me.isAdmin)
          ? AdminPage(currentId: me.id)
          : const _NotAdminTab(),
    ];

    void onTapNav(int i) {
      // ✅ 擋非管理員點「管理」
      if (i == 3 && (me == null || !me.isAdmin)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('你不是管理員')),
        );
        return;
      }
      setState(() => index = i);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Spartans - $titleRight'),
        actions: [
          IconButton(
            tooltip: '登出',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (_) => false,
              );
            },
          ),
        ],
      ),
      body: pages[index],

      // ✅ 不要用 SizedBox 強制高度（避免 overflow）
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: index,
        onTap: onTapNav,

        iconSize: 22,
        selectedFontSize: 10,
        unselectedFontSize: 10,

        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首頁'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: '訓練'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '個人'),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: '管理'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  Future<void> _createAnnouncement(BuildContext context) async {
    final me = AuthService.currentUser();
    if (me == null || !me.isAdmin) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AnnouncementCreatePage()),
    );
  }

  String _fmtDateTime(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $hh:$mm';
  }

  Widget _announcementCard(BuildContext context, Announcement a) {
    
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700))),
              ],
            ),
            const SizedBox(height: 6),
            Text(a.body),
            const SizedBox(height: 10),
            Text(
              '${_fmtDateTime(a.createdAt)} · ${a.createdBy}',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = AuthService.currentUser();
    final isAdmin = me?.isAdmin ?? false;

    return Stack(
      children: [
        StreamBuilder<List<Announcement>>(
          stream: AnnouncementService.streamLatest(limit: 30),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('讀取公告失敗: ${snapshot.error}'));
            }

            final items = snapshot.data ?? <Announcement>[];
            if (items.isEmpty) {
              return const Center(
                child: Text('目前沒有公告', style: TextStyle(color: Colors.black54)),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final a = items[i];
                final me = AuthService.currentUser();
                final isAdminLocal = me?.isAdmin ?? false;
                return Dismissible(
                  key: ValueKey(a.id),
                  direction: isAdminLocal ? DismissDirection.endToStart : DismissDirection.none,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: Colors.redAccent,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    if (!isAdminLocal) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('只有管理員可刪除公告')));
                      return false;
                    }
                    final confirm = await showDialog<bool>(
                      context: ctx,
                      builder: (dctx) => AlertDialog(
                        title: const Text('刪除公告'),
                        content: const Text('確定要刪除此則公告？此動作無法復原。'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('取消')),
                          ElevatedButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('刪除')),
                        ],
                      ),
                    );
                    return confirm == true;
                  },
                  onDismissed: (direction) async {
                    try {
                      await AnnouncementService.delete(a.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已刪除公告')));
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('刪除失敗: $e')));
                    }
                  },
                  child: _announcementCard(ctx, a),
                );
              },
            );
          },
        ),
        if (isAdmin)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: () => _createAnnouncement(context),
              icon: const Icon(Icons.campaign),
              label: const Text('新增公告'),
            ),
          ),
      ],
    );
  }
}

class _NotAdminTab extends StatelessWidget {
  const _NotAdminTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '你不是管理員',
        style: TextStyle(color: Colors.black54),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final me = AuthService.currentUser();
    final currentLabel = me == null
        ? '—'
        : (me.isAdmin
            ? '管理員'
            : ((me.displayName?.trim().isNotEmpty == true)
                ? me.displayName!.trim()
                : me.id));

    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.badge),
          title: const Text('設定/修改中文姓名'),
          subtitle: Text('目前：$currentLabel'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            final u = AuthService.currentUser();
            if (u == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NamePage(id: u.id)),
            );
          },
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.cake),
          title: const Text('編輯出生日期'),
          subtitle: const Text('設定西元出生年月日'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            final u = AuthService.currentUser();
            if (u == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BirthdatePage(id: u.id)),
            );
          },
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.badge),
          title: const Text('編輯身分證字號'),
          subtitle: const Text('設定身分證字號'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            final u = AuthService.currentUser();
            if (u == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => IdNumberPage(id: u.id)),
            );
          },
        ),
        const Divider(height: 1),
      ],
    );
  }
}
