import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'home_page.dart';
import 'change_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final idCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  bool remember = true;

  @override
  void dispose() {
    idCtrl.dispose();
    pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final id = idCtrl.text.trim().toLowerCase();
    final pwd = pwdCtrl.text;

    if (id.isEmpty || pwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入帳號與密碼')),
      );
      return;
    }

    final result = await AuthService.login(id: id, password: pwd);
    if (!mounted) return;

    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }

    final me = result.user; // 登入成功一定有 user
    if (me == null) return;

    // ✅ 登入成功就初始化通知（訂閱 topic + Android 13 權限）
    await NotificationService.ensureInitialized();

    // Save credentials locally if requested (do not block login on storage errors)
    if (remember) {
      try {
        await AuthService.saveCredentials(id: id, password: pwd, remember: remember);
      } catch (e) {
        // ignore storage errors but log for debugging
        // ignore: avoid_print
        print('saveCredentials failed: $e');
      }
    } else {
      // if not remembering, ensure any previous saved creds are cleared
      try {
        await AuthService.clearSavedCredentials();
      } catch (_) {}
    }

    // ✅ 教練/球員：第一次登入或被重設 -> 立刻改密碼；管理員不用
    if (me.mustChangePassword && !me.isAdmin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ChangePasswordPage(id: me.id)),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隊員登入')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: idCtrl,
              decoration: const InputDecoration(
                labelText: '帳號',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pwdCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密碼',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: remember,
                  onChanged: (v) => setState(() => remember = v ?? true),
                ),
                const Text('記住我（在裝置上保留登入）'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _login,
                child: const Text('登入'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
