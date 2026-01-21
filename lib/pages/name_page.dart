import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

class NamePage extends StatefulWidget {
  final String id;
  const NamePage({super.key, required this.id});

  @override
  State<NamePage> createState() => _NamePageState();
}

class _NamePageState extends State<NamePage> {
  final ctrl = TextEditingController();

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = ctrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入中文姓名')));
      return;
    }

    final ok = await AuthService.setDisplayName(id: widget.id, displayName: name);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('管理員不能設定姓名')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已更新')),
    );
    Navigator.pop(context);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = (data?.text ?? '').trim();
    if (text.isEmpty) return;
    ctrl.text = text;
    ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定/修改中文姓名')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: ctrl,
              enableInteractiveSelection: false,
              decoration: InputDecoration(
                labelText: '中文姓名',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: '貼上',
                  icon: const Icon(Icons.content_paste),
                  onPressed: _pasteFromClipboard,
                ),
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
