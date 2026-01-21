import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class IdNumberPage extends StatefulWidget {
  final String id;
  const IdNumberPage({super.key, required this.id});

  @override
  State<IdNumberPage> createState() => _IdNumberPageState();
}

class _IdNumberPageState extends State<IdNumberPage> {
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
    idCtrl.text = u?.idNumber ?? '';
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    idCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final idnum = idCtrl.text.trim();
    final ok = await AuthService.setPersonalInfo(
      id: widget.id,
      idNumber: idnum.isEmpty ? null : idnum,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新失敗')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已更新身分證字號')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定/身分證字號')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
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

