import 'package:flutter/material.dart';
import '../profile_irrigation_logic.dart';
import '../zone_crop_plan_logic.dart';
import 'profile_irrigation_view.dart';
import 'stage_draft_tile.dart';
import '../../../core/utils/user_error.dart';

const _muted = Color(0xFF64748B);
const _ink = Color(0xFF0F172A);
const _green = Color(0xFF047857);

IconData _iconForCode(String code) {
  final c = code.toLowerCase();
  if (c.contains('temp')) return Icons.thermostat_rounded;
  if (c.contains('soil') || c.contains('moisture'))
    return Icons.water_drop_rounded;
  if (c.contains('air') || c.contains('humid')) return Icons.cloud_outlined;
  if (c.contains('ph')) return Icons.science_outlined;
  if (c.contains('light')) return Icons.wb_sunny_outlined;
  if (c.contains('ec') || c.contains('conduct'))
    return Icons.electric_bolt_rounded;
  return Icons.tune_rounded;
}

Color _colorForCode(String code) {
  final c = code.toLowerCase();
  if (c.contains('temp')) return const Color(0xFFEA580C);
  if (c.contains('soil') || c.contains('moisture'))
    return const Color(0xFF0284C7);
  if (c.contains('air') || c.contains('humid')) return const Color(0xFF0D9488);
  if (c.contains('ph')) return const Color(0xFF7C3AED);
  if (c.contains('light')) return const Color(0xFFD97706);
  if (c.contains('ec') || c.contains('conduct')) return const Color(0xFF4F46E5);
  return const Color(0xFF64748B);
}

/// Người dùng chọn gì sau khi xem chi tiết hồ sơ.
enum ProfileDetailResult {
  /// "Áp dụng profile này cho Zone" (dùng nguyên hồ sơ).
  apply,

  /// "Tạo bản sao riêng để chỉnh" (chỉ với hồ sơ hệ thống): sao chép rồi cho sửa bản sao.
  customize,
}

/// Màn XEM CHI TIẾT một hồ sơ canh tác trước khi chọn: tên, cây, giống, nguồn, giai đoạn + ngưỡng và lịch tưới theo giai đoạn.
/// Chỉ xem: không sửa gì. Hồ sơ hệ thống muốn chỉnh phải tạo bản sao riêng. Lịch tưới đọc từ backend và nói rõ
/// giai đoạn nào dùng lịch ĐÃ LƯU TRONG HỒ SƠ, giai đoạn nào chỉ là lịch mẫu của cây (tham khảo).
class ZoneProfileDetailPage extends StatefulWidget {
  final Map<String, dynamic> profile;
  final String cropName;
  final String? varietyName;
  final Future<Map<String, dynamic>> Function(String profileId) fetchIrrigation;

  const ZoneProfileDetailPage({
    super.key,
    required this.profile,
    required this.cropName,
    required this.fetchIrrigation,
    this.varietyName,
  });

  @override
  State<ZoneProfileDetailPage> createState() => _ZoneProfileDetailPageState();
}

class _ZoneProfileDetailPageState extends State<ZoneProfileDetailPage> {
  ProfileSchedule? _schedule;
  String? _error;
  bool _loading = true;

  String get _id => '${widget.profile['profileId']}';
  bool get _isSystem => widget.profile['isSystemDefined'] == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await widget.fetchIrrigation(_id);
      if (!mounted) return;
      setState(() => _schedule = ProfileSchedule.fromJson(json));
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<StageDraft> get _stages => [
    for (final s in (widget.profile['stages'] as List? ?? const []))
      if (s is Map) StageDraft.fromJson(Map<String, dynamic>.from(s)),
  ]..sort((a, b) => a.order.compareTo(b.order));

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final stages = _stages;
    final total = stages.fold<int>(0, (a, s) => a + s.durationDays);
    final desc = '${p['description'] ?? ''}'.trim();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Chi tiết hồ sơ canh tác',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size.fromHeight(48),
                  elevation: 0,
                ),
                onPressed: stages.isEmpty
                    ? null
                    : () => Navigator.pop(context, ProfileDetailResult.apply),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text(
                  'Áp dụng profile này cho Zone',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
              ),
              if (_isSystem) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _green,
                    side: const BorderSide(color: _green, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: stages.isEmpty
                      ? null
                      : () => Navigator.pop(
                          context,
                          ProfileDetailResult.customize,
                        ),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text(
                    'Tạo bản sao riêng để chỉnh',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: _muted),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Hồ sơ hệ thống không sửa trực tiếp. Muốn chỉnh giai đoạn, ngưỡng hoặc lịch tưới, hãy tạo bản sao của trang trại.',
                          style: TextStyle(
                            fontSize: 11,
                            color: _muted,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 4),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(38),
                  foregroundColor: const Color(0xFF475569),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Quay lại danh sách',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: _green,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p['name']}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _badge(
                                _isSystem
                                    ? 'Hồ sơ hệ thống (chỉ xem)'
                                    : 'Bản riêng của trang trại',
                                _isSystem ? const Color(0xFF0284C7) : _green,
                              ),
                              if (widget.varietyName != null)
                                _badge(
                                  'Giống ${widget.varietyName}',
                                  const Color(0xFF7C3AED),
                                ),
                              _badge(
                                '${stages.length} giai đoạn · tổng $total ngày',
                                const Color(0xFF475569),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                _row('Cây trồng', widget.cropName),
                _row('Giống', widget.varietyName ?? 'Dùng chung cho mọi giống'),
                _row(
                  'Nguồn',
                  _isSystem
                      ? 'Hồ sơ hệ thống (chỉ xem)'
                      : 'Bản riêng của trang trại',
                ),
                _row(
                  'Giai đoạn',
                  '${stages.length} giai đoạn · tổng $total ngày',
                ),
                if (desc.isNotEmpty) _row('Mô tả', desc),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.layers_outlined,
                  size: 16,
                  color: _green,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Giai đoạn và ngưỡng môi trường',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${stages.length} giai đoạn',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (stages.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hồ sơ này chưa có giai đoạn nào nên chưa thể áp dụng cho Zone.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                    ),
                  ),
                ],
              ),
            ),
          for (final st in stages)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
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
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Color(0xFFECFDF5),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${st.order}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _green,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${st.order}. ${st.name} · ${st.durationDays} ngày',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: _muted,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${st.durationDays} ngày',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (thresholdNotice(st) case final notice?)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: st.requirements.isEmpty
                            ? const Color(0xFFFFFBEB)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: st.requirements.isEmpty
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            st.requirements.isEmpty
                                ? Icons.warning_amber_rounded
                                : Icons.info_outline_rounded,
                            size: 14,
                            color: st.requirements.isEmpty
                                ? const Color(0xFFD97706)
                                : _muted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              notice,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: st.requirements.isEmpty
                                    ? const Color(0xFFB45309)
                                    : _muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (st.requirements.isNotEmpty) const SizedBox(height: 6),
                  for (final r in st.requirements)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _iconForCode(r.code),
                            size: 14,
                            color: _colorForCode(r.code),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              describeRequirementDraft(r),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  size: 16,
                  color: Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Lịch tưới theo giai đoạn',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: Color(0xFF0284C7),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '"Hồ sơ" = lịch tưới đã lưu trong hồ sơ này (dùng để đồng bộ xuống thiết bị). "Lịch mẫu của cây" = chỉ để '
                    'tham khảo, không phải dữ liệu của hồ sơ. Đây là lịch khuyến nghị, khác với lịch điều khiển đang chạy trên thiết bị.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF0369A1),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (_error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: Color(0xFFB91C1C),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Không tải được lịch tưới: $_error',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ],
              ),
            ),
          ] else if (_schedule != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ProfileIrrigationView(schedule: _schedule!),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.2), width: 0.8),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    ),
  );

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            k,
            style: const TextStyle(
              fontSize: 12,
              color: _muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Hộp thoại XÁC NHẬN trước khi gắn hồ sơ vào Zone: nhắc lại hồ sơ đã chọn. Trả true khi người dùng đồng ý.
Future<bool> confirmApplyProfile(
  BuildContext context, {
  required String zoneName,
  required String profileName,
  required String cropName,
  String? varietyName,
  required bool isSystem,
  required bool willClone,
  required int stageCount,
  String? currentProfileName,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: _green, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Gắn hồ sơ cho Zone?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Zone: $zoneName\n'
              'Hồ sơ: $profileName\n'
              'Cây: $cropName${varietyName == null ? ' (hồ sơ dùng chung cho mọi giống)' : ' · giống $varietyName'}\n'
              'Nguồn: ${willClone
                  ? 'bản sao riêng mới của trang trại, tạo từ hồ sơ hệ thống'
                  : isSystem
                  ? 'hồ sơ hệ thống'
                  : 'bản riêng của trang trại'} · $stageCount giai đoạn\n'
              '${currentProfileName == null ? '' : '\nZone đang dùng "$currentProfileName"; hồ sơ này sẽ được thay thế.\n'}'
              '\nChỉ gắn hồ sơ cho Zone, không tạo vụ trồng và không đổi cây của vụ đang chạy. '
              'Lịch điều khiển đã đồng bộ không tự đổi.',
              style: const TextStyle(fontSize: 13, height: 1.45, color: _ink),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Xác nhận gắn'),
        ),
      ],
    ),
  );
  return ok == true;
}
