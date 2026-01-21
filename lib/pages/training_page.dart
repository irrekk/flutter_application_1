import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/training.dart';
import '../services/auth_service.dart';
import '../services/training_service.dart';
import 'training_edit_sheet.dart';

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key});

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selected =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  Widget build(BuildContext context) {
    final me = AuthService.currentUser();
    final canEdit =
        me != null && (me.role == UserRole.admin || me.role == UserRole.coach);
    final isPlayer = me != null && me.role == UserRole.player;

    return StreamBuilder<List<AppUser>>(
      stream: AuthService.listUsersStreamSorted(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (userSnapshot.hasError) {
          return Center(child: Text('讀取使用者資料失敗: ${userSnapshot.error}'));
        }

        final users = userSnapshot.data ?? <AppUser>[];
        final coaches = users.where((u) => u.role == UserRole.coach).toList();
        final players = users.where((u) => u.role == UserRole.player).toList();

        final coachNameOf = <String, String>{};
        for (final c in coaches) {
          final dn = (c.displayName ?? '').trim();
          coachNameOf[c.id] = dn.isEmpty ? c.id : dn;
        }

        final playerNameOf = <String, String>{};
        for (final p in players) {
          final dn = (p.displayName ?? '').trim();
          playerNameOf[p.id] = dn.isEmpty ? p.id : dn;
        }

        return StreamBuilder<TrainingDay>(
          stream: TrainingService.dayStream(_selected),
          builder: (context, trainingSnapshot) {
            if (trainingSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (trainingSnapshot.hasError) {
              return Center(
                child: Text('讀取訓練時段資料失敗: ${trainingSnapshot.error}'),
              );
            }

            final day = trainingSnapshot.data ??
                TrainingDay(slots: <TrainingSlot>[], participantIds: <String>{});
            final slots = [...day.slots]
              ..sort((a, b) => a.startMin.compareTo(b.startMin));

            return LayoutBuilder(
              builder: (context, c) {
                final detailHeight = (c.maxHeight * 0.42).clamp(220.0, 360.0);

                return Column(
                  children: [
                    _buildMonthHeader(),
                    _buildWeekHeader(),
                    Expanded(
                      child: _buildCalendarGrid(
                        month: _month,
                        selected: _selected,
                        onSelect: (d) => setState(() => _selected = d),
                      ),
                    ),
                    const Divider(height: 1),
                    SizedBox(
                      height: detailHeight,
                      child: SafeArea(
                        top: false,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '選擇日期：${_selected.year}/${_selected.month}/${_selected.day}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: canEdit ? '編輯' : '只有教練/管理員可編輯',
                                    onPressed: !canEdit
                                        ? null
                                        : () async {
                                            await showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              builder: (_) => TrainingEditSheet(
                                                date: _selected,
                                                coaches: coaches,
                                              ),
                                            );
                                            if (!mounted) return;
                                            setState(() {});
                                          },
                                    icon: const Icon(Icons.edit),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              if (slots.isEmpty)
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('（今天尚未建立任何時段）'),
                                )
                              else
                                for (final s in slots) ...[
                                  _slotCard(
                                    me: me,
                                    slot: s,
                                    isPlayer: isPlayer,
                                    coachText: s.type == TrainingType.training
                                        ? (s.coachIds.isEmpty
                                            ? '（尚未指定）'
                                            : s.coachIds
                                                .map((id) =>
                                                    coachNameOf[id] ?? id)
                                                .join('、'))
                                        : '（不需要）',
                                    participantText: s.participantIds.isEmpty
                                        ? '（尚未有人登記）'
                                        : (s.participantIds
                                                  .map((id) =>
                                                      playerNameOf[id] ?? id)
                                                  .toList()
                                                ..sort())
                                            .join('、'),
                                    onPlayerRegister: (me == null)
                                        ? null
                                        : () async {
                                            if (s.type == TrainingType.none) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content:
                                                        Text('此時段未開放登記')),
                                              );
                                              return;
                                            }

                                            final joinedNow =
                                                await TrainingService
                                                    .toggleSlotParticipant(
                                              date: _selected,
                                              slotId: s.id,
                                              playerId: me.id,
                                            );

                                            if (!mounted) return;
                                            setState(() {});

                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  joinedNow
                                                      ? '已登記：${s.title}'
                                                      : '已取消：${s.title}',
                                                ),
                                              ),
                                            );
                                          },
                                  ),
                                  const SizedBox(height: 10),
                                ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _slotCard({
    required AppUser? me,
    required TrainingSlot slot,
    required bool isPlayer,
    required String coachText,
    required String participantText,
    required VoidCallback? onPlayerRegister,
  }) {
    final canRegister = isPlayer && slot.type != TrainingType.none;
    final isJoined = (me != null) && slot.participantIds.contains(me.id);

    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
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
                  '${_fmtTime(slot.startMin)}–${_fmtTime(slot.endMin)}  ${slot.title}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),

              // ✅ 球員登記：空格/打勾（紫底白勾）
              if (canRegister)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onPlayerRegister,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: primary, width: 2),
                      color: isJoined ? primary : Colors.transparent,
                    ),
                    child: isJoined
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _infoRow('類別', _typeLabel(slot.type)),
          _infoRow('教練', coachText),
          _infoRow('參加球員', participantText),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() {
              _month = DateTime(_month.year, _month.month - 1, 1);
              _selected = DateTime(_month.year, _month.month, 1);
            }),
          ),
          Expanded(
            child: Center(
              child: Text(
                '${_month.year} / ${_month.month}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() {
              _month = DateTime(_month.year, _month.month + 1, 1);
              _selected = DateTime(_month.year, _month.month, 1);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekHeader() {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          for (final t in labels)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(t,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid({
    required DateTime month,
    required DateTime selected,
    required ValueChanged<DateTime> onSelect,
  }) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingEmpty = first.weekday - DateTime.monday;

    final cells = <Widget>[];
    for (int i = 0; i < leadingEmpty; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final d = DateTime(month.year, month.month, day);
      final isSelected = d.year == selected.year &&
          d.month == selected.month &&
          d.day == selected.day;

      cells.add(
        FutureBuilder<bool>(
          future: TrainingService.hasAnyPlan(d), // 非同步檢查當天是否有訓練計畫
          builder: (context, snapshot) {
            final hasPlan = snapshot.data ?? false;
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onSelect(d),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black12,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(child: Text('$day')),
                    if (hasPlan)
                      Positioned(
                        right: 8,
                        bottom: 6,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: GridView.count(
        crossAxisCount: 7,
        children: cells,
      ),
    );
  }


  Widget _infoRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$k：', style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  String _typeLabel(TrainingType t) {
    switch (t) {
      case TrainingType.training:
        return '訓練';
      case TrainingType.selfTraining:
        return '自主訓練';
      case TrainingType.none:
        return '放假 / 無訓練';
    }
  }

  String _fmtTime(int min) {
    final h = min ~/ 60;
    final m = min % 60;
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
