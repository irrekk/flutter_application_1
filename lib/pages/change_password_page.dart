import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_page.dart';

class ChangePasswordPage extends StatefulWidget {
  final String id;
  const ChangePasswordPage({super.key, required this.id});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final pwd1 = TextEditingController();
  final pwd2 = TextEditingController();

  @override
  void dispose() {
    pwd1.dispose();
    pwd2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final a = pwd1.text;
    final b = pwd2.text;

    if (a.isEmpty || b.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請輸入新密碼')));
      return;
    }
    if (a != b) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('兩次密碼不一致')));
      return;
    }

    final ok = await AuthService.changePassword(id: widget.id, newPassword: a);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('修改失敗')));
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('請先修改密碼')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: pwd1,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '新密碼',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pwd2,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '再次輸入新密碼',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(onPressed: _save, child: const Text('儲存')),
            ),
          ],
        ),
      ),
    );
  }
}
