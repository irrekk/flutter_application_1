import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class BirthdatePage extends StatefulWidget {
  final String id;
  const BirthdatePage({super.key, required this.id});

  @override
  State<BirthdatePage> createState() => _BirthdatePageState();
}

class _BirthdatePageState extends State<BirthdatePage> {
  DateTime? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await AuthService.getUserById(widget.id);
    if (!mounted) return;
    final b = u?.birthday;
    if (b != null && b.isNotEmpty) {
      try {
        _selected = DateTime.parse(b);
      } catch (_) {
        _selected = null;
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(1900);
    final initial = _selected ?? DateTime(now.year - 20, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _selected = picked);
  }

  Future<void> _save() async {
    final iso = _selected == null ? null : _selected!.toIso8601String().split('T').first;
    final ok = await AuthService.setPersonalInfo(
      id: widget.id,
      birthday: iso,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新失敗')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已更新生日')));
    Navigator.pop(context);
  }

  String _fmt(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定/出生日期')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '出生日期',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_selected == null ? '尚未設定' : _fmt(_selected!)),
                          const Icon(Icons.calendar_today),
                        ],
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

