import 'package:flutter/material.dart';
import '../profile_irrigation_logic.dart';
import '../zone_crop_plan_logic.dart';
import 'profile_irrigation_view.dart';
import 'stage_draft_tile.dart';

const _muted = Color(0xFF64748B);
const _ink = Color(0xFF0F172A);

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
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
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
      appBar: AppBar(title: const Text('Chi tiết hồ sơ canh tác', style: TextStyle(fontSize: 16))),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: stages.isEmpty ? null : () => Navigator.pop(context, ProfileDetailResult.apply),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Áp dụng profile này cho Zone'),
              ),
              if (_isSystem) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: stages.isEmpty ? null : () => Navigator.pop(context, ProfileDetailResult.customize),
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('Tạo bản sao riêng để chỉnh'),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Hồ sơ hệ thống không sửa trực tiếp. Muốn chỉnh giai đoạn, ngưỡng hoặc lịch tưới, hãy tạo bản sao của trang trại.',
                    style: TextStyle(fontSize: 11, color: _muted, height: 1.35),
                  ),
                ),
              ],
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Quay lại danh sách')),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${p['name']}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _ink),
          ),
          const SizedBox(height: 6),
          _row('Cây trồng', widget.cropName),
          _row('Giống', widget.varietyName ?? 'Dùng chung cho mọi giống'),
          _row('Nguồn', _isSystem ? 'Hồ sơ hệ thống (chỉ xem)' : 'Bản riêng của trang trại'),
          _row('Giai đoạn', '${stages.length} giai đoạn · tổng $total ngày'),
          if (desc.isNotEmpty) _row('Mô tả', desc),
          const SizedBox(height: 14),
          const Text('Giai đoạn và ngưỡng môi trường', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (stages.isEmpty)
            const Text(
              'Hồ sơ này chưa có giai đoạn nào nên chưa thể áp dụng cho Zone.',
              style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
            ),
          for (final st in stages)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${st.order}. ${st.name} · ${st.durationDays} ngày',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink),
                    ),
                    if (thresholdNotice(st) case final notice?)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          notice,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: st.requirements.isEmpty ? const Color(0xFFB45309) : _muted,
                          ),
                        ),
                      ),
                    for (final r in st.requirements)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(describeRequirementDraft(r), style: const TextStyle(fontSize: 11.5, color: _ink)),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(Icons.water_drop_outlined, size: 18, color: Color(0xFF0284C7)),
              SizedBox(width: 6),
              Text('Lịch tưới theo giai đoạn', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '"Hồ sơ" = lịch tưới đã lưu trong hồ sơ này (dùng để đồng bộ xuống thiết bị). "Lịch mẫu của cây" = chỉ để '
            'tham khảo, không phải dữ liệu của hồ sơ. Đây là lịch khuyến nghị, khác với lịch điều khiển đang chạy trên thiết bị.',
            style: TextStyle(fontSize: 11, color: _muted, height: 1.35),
          ),
          if (_loading)
            const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator(minHeight: 2))
          else if (_error != null) ...[
            const SizedBox(height: 6),
            Text('Không tải được lịch tưới: $_error', style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ] else if (_schedule != null)
            ProfileIrrigationView(schedule: _schedule!),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(k, style: const TextStyle(fontSize: 12, color: _muted)),
        ),
        Expanded(
          child: Text(v, style: const TextStyle(fontSize: 12.5, color: _ink)),
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
      title: const Text('Gắn hồ sơ cho Zone?', style: TextStyle(fontSize: 15)),
      content: SingleChildScrollView(
        child: Text(
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
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xác nhận gắn')),
      ],
    ),
  );
  return ok == true;
}
