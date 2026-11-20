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
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE0F2FE),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.water_drop_rounded,
                          size: 12,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${st.order}. ${st.name} · ${st.durationDays} ngày',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: st.fromProfile
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: st.fromProfile
                              ? const Color(0xFFA7F3D0)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        st.fromProfile
                            ? 'Hồ sơ'
                            : st.fromCrop
                            ? 'Lịch mẫu của cây'
                            : 'Chưa có',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: st.fromProfile
                              ? const Color(0xFF047857)
                              : _muted,
                        ),
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
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: x.enabled
                            ? (x.title.toLowerCase().contains('sáng')
                                  ? const Color(0xFFFFFBEB)
                                  : x.title.toLowerCase().contains('trưa')
                                  ? const Color(0xFFFFF1F2)
                                  : const Color(0xFFEEF2FF))
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: x.enabled
                              ? (x.title.toLowerCase().contains('sáng')
                                    ? const Color(0xFFFDE68A)
                                    : x.title.toLowerCase().contains('trưa')
                                    ? const Color(0xFFFECDD3)
                                    : const Color(0xFFC7D2FE))
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            x.title.toLowerCase().contains('sáng')
                                ? Icons.wb_twilight
                                : x.title.toLowerCase().contains('trưa')
                                ? Icons.wb_sunny
                                : Icons.nights_stay,
                            size: 13,
                            color: x.enabled
                                ? (x.title.toLowerCase().contains('sáng')
                                      ? const Color(0xFFD97706)
                                      : x.title.toLowerCase().contains('trưa')
                                      ? const Color(0xFFE11D48)
                                      : const Color(0xFF4F46E5))
                                : _muted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              describeProfileSession(x),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: x.enabled
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: x.enabled
                                    ? const Color(0xFF0F172A)
                                    : _muted,
                              ),
                            ),
                          ),
                          if (!x.enabled)
                            const Text(
                              'Tắt',
                              style: TextStyle(fontSize: 10, color: _muted),
                            ),
                        ],
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
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF047857),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                      ),
                      onPressed: busy ? null : () => onEdit!(st),
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: Text(
                        st.fromProfile ? 'Sửa ca tưới' : 'Lưu ca tưới riêng',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.water_drop_rounded,
                size: 18,
                color: Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title ?? 'Ca tưới · ${stage.name}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 13,
                        color: _muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hint ??
                              'Lặp hằng ngày trong giai đoạn. Giờ HH:mm theo múi giờ trang trại. Mỗi ca tối đa 30 phút.',
                          style: const TextStyle(fontSize: 11, color: _muted),
                        ),
                      ),
                    ],
                  ),
                ),
                for (var i = 0; i < rows.length; i++)
                  Container(
                    key: ValueKey('row_$i'),
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: rows[i].title,
                          decoration: InputDecoration(
                            labelText: 'Tên ca',
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: rows[i].time,
                                decoration: InputDecoration(
                                  labelText: 'Giờ (HH:mm)',
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
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
                                decoration: InputDecoration(
                                  labelText: 'Phút',
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
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
                                decoration: InputDecoration(
                                  labelText: 'Phương thức',
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: rows[i].water,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'ml/gốc',
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Switch(
                              value: rows[i].enabled,
                              activeThumbColor: const Color(0xFF047857),
                              onChanged: (v) =>
                                  setLocal(() => rows[i].enabled = v),
                            ),
                            const Text(
                              'Bật',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Xóa ca',
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Color(0xFFDC2626),
                              ),
                              onPressed: () =>
                                  setLocal(() => rows.removeAt(i).dispose()),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF047857),
                    side: const BorderSide(color: Color(0xFF047857)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    minimumSize: const Size.fromHeight(40),
                  ),
                  onPressed: () => setLocal(() => rows.add(_Row.empty())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'Thêm ca tưới',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (canApplyAll)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: const Color(0xFF047857),
                    value: applyAll,
                    onChanged: (v) => setLocal(() => applyAll = v == true),
                    title: Text(
                      applyAllLabel ?? 'Áp dụng cho mọi giai đoạn của hồ sơ',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                if (error != null)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 14,
                          color: Color(0xFFB91C1C),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            error!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
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
