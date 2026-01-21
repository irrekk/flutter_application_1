import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/training.dart';
import '../services/training_service.dart';

class TrainingEditSheet extends StatefulWidget {
  final DateTime date;
  final List<AppUser> coaches;

  const TrainingEditSheet({
    super.key,
    required this.date,
    required this.coaches,
  });

  @override
  State<TrainingEditSheet> createState() => _TrainingEditSheetState();
}

class _TrainingEditSheetState extends State<TrainingEditSheet> {
  @override
  Widget build(BuildContext context) {
    final coachName = <String, String>{
      for (final c in widget.coaches)
        c.id: (c.displayName?.trim().isNotEmpty == true ? c.displayName!.trim() : c.id),
    };

    return FutureBuilder<TrainingDay>(
      future: TrainingService.getDay(widget.date),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('讀取訓練時段資料失敗: ${snapshot.error}'));
        }

        final day =
            snapshot.data ?? TrainingDay(slots: <TrainingSlot>[], participantIds: <String>{});
        final slots = [...day.slots]..sort((a, b) => a.startMin.compareTo(b.startMin));

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.date.year}/${widget.date.month}/${widget.date.day}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),

                // ✅ 新增自訂時段
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('新增時段'),
                        onPressed: () async {
                          final r = await _addSlotDialog(context);
                          if (r == null) return;

                          await TrainingService.addCustomSlot(
                            date: widget.date,
                            title: r.title,
                            startMin: r.startMin,
                            endMin: r.endMin,
                          );
                          if (!mounted) return;
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (slots.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('（今天尚未建立任何時段）'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: slots.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final s = slots[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${_fmtTime(s.startMin)}–${_fmtTime(s.endMin)}  ${s.title}',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '刪除時段',
                                    onPressed: () async {
                                      await TrainingService.removeSlot(
                                        date: widget.date,
                                        slotId: s.id,
                                      );
                                      if (!mounted) return;
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),
                              DropdownButtonFormField<TrainingType>(
                                value: s.type,
                                decoration: const InputDecoration(
                                  labelText: '類別',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: TrainingType.training,
                                    child: Text('訓練'),
                                  ),
                                  DropdownMenuItem(
                                    value: TrainingType.selfTraining,
                                    child: Text('自主訓練'),
                                  ),
                                  DropdownMenuItem(
                                    value: TrainingType.none,
                                    child: Text('放假 / 無訓練'),
                                  ),
                                ],
                                onChanged: (v) async {
                                  if (v == null) return;
                                  await TrainingService.setSlotType(
                                    date: widget.date,
                                    slotId: s.id,
                                    type: v,
                                  );
                                  if (!mounted) return;
                                  setState(() {});
                                },
                              ),

                              if (s.type == TrainingType.training) ...[
                                const SizedBox(height: 12),
                                const Text('教練（可複選）',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                for (final c in widget.coaches)
                                  CheckboxListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(coachName[c.id] ?? c.id),
                                    value: s.coachIds.contains(c.id),
                                    onChanged: (v) async {
                                      final next = [...s.coachIds];
                                      if (v == true) {
                                        if (!next.contains(c.id)) next.add(c.id);
                                      } else {
                                        next.remove(c.id);
                                      }

                                      await TrainingService.setSlotCoaches(
                                        date: widget.date,
                                        slotId: s.id,
                                        coachIds: next,
                                      );
                                      if (!mounted) return;
                                      setState(() {});
                                    },
                                  ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('完成'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _fmtTime(int min) {
    final h = min ~/ 60;
    final m = min % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<_SlotDraft?> _addSlotDialog(BuildContext context) async {
    final titleCtrl = TextEditingController(text: '自訂');
    final startCtrl = TextEditingController(text: '18:00');
    final endCtrl = TextEditingController(text: '20:00');

    int? parseHHMM(String s) {
      final t = s.trim();
      final parts = t.split(':');
      if (parts.length != 2) return null;
      final hh = int.tryParse(parts[0]);
      final mm = int.tryParse(parts[1]);
      if (hh == null || mm == null) return null;
      if (hh < 0 || hh > 23) return null;
      if (mm < 0 || mm > 59) return null;
      return hh * 60 + mm;
    }

    final r = await showDialog<_SlotDraft>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('新增時段'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: '名稱（例：晚上）'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: startCtrl,
              decoration: const InputDecoration(labelText: '開始時間（HH:MM）'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: endCtrl,
              decoration: const InputDecoration(labelText: '結束時間（HH:MM）'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final s = parseHHMM(startCtrl.text);
              final e = parseHHMM(endCtrl.text);
              if (s == null || e == null || e <= s) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('時間格式錯誤，或結束必須大於開始')),
                );
                return;
              }
              Navigator.pop(
                context,
                _SlotDraft(title: titleCtrl.text, startMin: s, endMin: e),
              );
            },
            child: const Text('新增'),
          ),
        ],
      ),
    );

    titleCtrl.dispose();
    startCtrl.dispose();
    endCtrl.dispose();
    return r;
  }
}

class _SlotDraft {
  final String title;
  final int startMin;
  final int endMin;

  _SlotDraft({
    required this.title,
    required this.startMin,
    required this.endMin,
  });
}
