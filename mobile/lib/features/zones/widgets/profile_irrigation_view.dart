import 'package:flutter/material.dart';
import '../profile_irrigation_logic.dart';

const _muted = Color(0xFF64748B);

/// Kết quả hộp thoại sửa ca tưới của một giai đoạn.
class StageSessionsEdit {
  final List<ProfileSession> sessions;
  final bool applyToAllStages;
  const StageSessionsEdit(this.sessions, this.applyToAllStages);
}

/// Hiển thị lịch tưới KHUYẾN NGHỊ của hồ sơ theo giai đoạn (dữ liệu từ backend). Nói rõ nguồn của từng giai đoạn:
/// "Hồ sơ" (đã lưu trong hồ sơ) hoặc "Lịch mẫu của cây" (hồ sơ chưa có ca riêng, chỉ đọc). Sửa được khi `onEdit != null`
/// (hồ sơ riêng của trang trại); hồ sơ hệ thống chỉ xem.
class ProfileIrrigationView extends StatelessWidget {
  final ProfileSchedule schedule;
  final bool busy;
  final void Function(StageSchedule stage)? onEdit;
  const ProfileIrrigationView({
    super.key,
    required this.schedule,
    this.busy = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final s = schedule;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hồ sơ "${s.profileName}" · ${s.isSystemDefined ? 'hệ thống (chỉ xem)' : 'riêng của trang trại'} · '
          'lặp hằng ngày, giờ theo múi giờ ${s.timeZone.isEmpty ? 'của trang trại' : s.timeZone}',
          style: const TextStyle(fontSize: 11, color: _muted, height: 1.35),
        ),
        if (!s.hasAnySessions)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Hồ sơ này chưa có ca tưới nào và cây cũng chưa có lịch mẫu, nên chưa có gì để đồng bộ.',
              style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
            ),
          ),
        for (final st in s.stages)
          Card(
            margin: const EdgeInsets.only(top: 6),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${st.order}. ${st.name} · ${st.durationDays} ngày',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        st.fromProfile
                            ? 'Hồ sơ'
                            : st.fromCrop
                            ? 'Lịch mẫu của cây'
                            : 'Chưa có',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: st.fromProfile
                              ? const Color(0xFF059669)
                              : _muted,
                        ),
                      ),
                    ],
                  ),
                  if (st.sessions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Chưa có ca tưới.',
                        style: TextStyle(fontSize: 11.5, color: _muted),
                      ),
                    )
                  else
                    for (final x in st.sessions)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          '${x.enabled ? '•' : '◦'} ${describeProfileSession(x)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: x.enabled ? const Color(0xFF0F172A) : _muted,
                          ),
                        ),
                      ),
                  if (st.fromCrop)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Đây là lịch mẫu chung của cây, chưa lưu trong hồ sơ. Lưu ca riêng để hồ sơ có lịch của mình.',
                        style: TextStyle(fontSize: 10.5, color: _muted),
                      ),
                    ),
                  if (onEdit != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: busy ? null : () => onEdit!(st),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text(
                          st.fromProfile ? 'Sửa ca tưới' : 'Lưu ca tưới riêng',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (onEdit == null && s.isSystemDefined)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Hồ sơ hệ thống và lịch mẫu của cây không sửa trực tiếp. Muốn chỉnh lịch tưới: tạo bản sao riêng '
              '(Đổi hồ sơ → Tùy chỉnh bản sao) rồi sửa bản sao đó.',
              style: TextStyle(fontSize: 11, color: _muted, height: 1.35),
            ),
          ),
      ],
    );
  }
}

/// Hộp thoại sửa các ca tưới của MỘT giai đoạn (cùng trường và giới hạn với API). Trả null nếu hủy.
Future<StageSessionsEdit?> showStageSessionsEditor(
  BuildContext context,
  StageSchedule stage, {
  required bool canApplyAll,
  String? title,
  String? hint,
  String? applyAllLabel,
}) {
  final rows = [for (final s in stage.sessions) _Row.from(s)];
  var applyAll = false;
  String? error;
  return showDialog<StageSessionsEdit>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(
          title ?? 'Ca tưới · ${stage.name}',
          style: const TextStyle(fontSize: 15),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hint ??
                      'Lặp hằng ngày trong giai đoạn. Giờ HH:mm theo múi giờ trang trại. Mỗi ca tối đa 30 phút.',
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
                for (var i = 0; i < rows.length; i++)
                  Container(
                    key: ValueKey('row_$i'),
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: rows[i].title,
                          decoration: const InputDecoration(
                            labelText: 'Tên ca',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: rows[i].time,
                                decoration: const InputDecoration(
                                  labelText: 'Giờ (HH:mm)',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: rows[i].minutes,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Phút',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: rows[i].method,
                                decoration: const InputDecoration(
                                  labelText: 'Phương thức',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: rows[i].water,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'ml/gốc',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Switch(
                              value: rows[i].enabled,
                              onChanged: (v) =>
                                  setLocal(() => rows[i].enabled = v),
                            ),
                            const Text('Bật', style: TextStyle(fontSize: 12)),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Xóa ca',
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () =>
                                  setLocal(() => rows.removeAt(i).dispose()),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => setLocal(() => rows.add(_Row.empty())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Thêm ca tưới'),
                ),
                if (canApplyAll)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: applyAll,
                    onChanged: (v) => setLocal(() => applyAll = v == true),
                    title: Text(
                      applyAllLabel ?? 'Áp dụng cho mọi giai đoạn của hồ sơ',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                if (error != null)
                  Text(
                    error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = <ProfileSession>[];
              for (final r in rows) {
                final p = r.toSession();
                if (p == null) {
                  setLocal(
                    () => error = 'Thời lượng (phút) và ml/gốc phải là số.',
                  );
                  return;
                }
                parsed.add(p);
              }
              final e = validateStageSessions(parsed);
              if (e != null) {
                setLocal(() => error = e);
                return;
              }
              Navigator.pop(ctx, StageSessionsEdit(parsed, applyAll));
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    ),
  ).whenComplete(() {
    // Giải phóng muộn để hiệu ứng đóng hộp thoại không dùng controller đã dispose.
    Future.delayed(const Duration(milliseconds: 600), () {
      for (final r in rows) {
        r.dispose();
      }
    });
  });
}

class _Row {
  final TextEditingController title;
  final TextEditingController time;
  final TextEditingController minutes;
  final TextEditingController method;
  final TextEditingController water;
  bool enabled;

  _Row({
    required this.title,
    required this.time,
    required this.minutes,
    required this.method,
    required this.water,
    this.enabled = true,
  });

  factory _Row.empty() => _Row(
    title: TextEditingController(),
    time: TextEditingController(),
    minutes: TextEditingController(),
    method: TextEditingController(),
    water: TextEditingController(),
  );

  factory _Row.from(ProfileSession s) => _Row(
    title: TextEditingController(text: s.title),
    time: TextEditingController(text: s.startTime),
    minutes: TextEditingController(
      text: s.durationMinutes == s.durationMinutes.roundToDouble()
          ? '${s.durationMinutes.round()}'
          : '${s.durationMinutes}',
    ),
    method: TextEditingController(text: s.method ?? ''),
    water: TextEditingController(text: s.waterPerPlantMl?.toString() ?? ''),
    enabled: s.enabled,
  );

  /// null nếu số không đọc được.
  ProfileSession? toSession() {
    final min = double.tryParse(minutes.text.trim().replaceAll(',', '.'));
    final w = water.text.trim().isEmpty
        ? null
        : int.tryParse(water.text.trim());
    if (min == null || (water.text.trim().isNotEmpty && w == null)) return null;
    return ProfileSession(
      title: title.text,
      startTime: time.text.trim(),
      durationSeconds: (min * 60).round(),
      enabled: enabled,
      method: method.text.trim().isEmpty ? null : method.text.trim(),
      waterPerPlantMl: w,
    );
  }

  void dispose() {
    title.dispose();
    time.dispose();
    minutes.dispose();
    method.dispose();
    water.dispose();
  }
}
