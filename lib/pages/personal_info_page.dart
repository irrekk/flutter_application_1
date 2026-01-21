import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class PersonalInfoPage extends StatefulWidget {
  final String id;
  const PersonalInfoPage({super.key, required this.id});

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  final birthCtrl = TextEditingController();
  final idCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await AuthService.getUserById(widget.id);
    if (!mounted) return;
    birthCtrl.text = u?.birthday ?? '';
    idCtrl.text = u?.idNumber ?? '';
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    birthCtrl.dispose();
    idCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final birth = birthCtrl.text.trim();
    final idnum = idCtrl.text.trim();
    if (birth.isNotEmpty) {
      final y = int.tryParse(birth);
      final nowYear = DateTime.now().year;
      if (y == null || y < 1900 || y > nowYear) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入合法的西元年（例如 1990）')));
        return;
      }
    }

    final ok = await AuthService.setPersonalInfo(
      id: widget.id,
      birthday: birth.isEmpty ? null : birth,
      idNumber: idnum.isEmpty ? null : idnum,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新失敗')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已更新個人資料')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定/個人資料')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  TextField(
                    controller: birthCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '出生年（西元，例：1990）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: idCtrl,
                    decoration: const InputDecoration(
                      labelText: '身分證字號',
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

