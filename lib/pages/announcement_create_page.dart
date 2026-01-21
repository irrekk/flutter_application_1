import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/announcement_service.dart';

class AnnouncementCreatePage extends StatefulWidget {
  const AnnouncementCreatePage({super.key});

  @override
  State<AnnouncementCreatePage> createState() => _AnnouncementCreatePageState();
}

class _AnnouncementCreatePageState extends State<AnnouncementCreatePage> {
  final titleCtrl = TextEditingController();
  final bodyCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    titleCtrl.dispose();
    bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final me = AuthService.currentUser();
    if (me == null || !me.isAdmin) return;

    final title = titleCtrl.text.trim();
    final body = bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入標題與內容')));
      return;
    }

    setState(() => _saving = true);
    try {
      await AnnouncementService.create(
        title: title,
        body: body,
        createdBy: me.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已發布公告')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('發佈失敗: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新增公告')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: '標題',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyCtrl,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: '內容',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? '發佈中...' : '發佈'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

