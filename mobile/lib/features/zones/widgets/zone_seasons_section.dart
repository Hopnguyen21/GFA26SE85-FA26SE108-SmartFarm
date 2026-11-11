import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/services/api_service.dart';
import '../../crops/widgets/create_season_sheet.dart';
import '../../irrigation/season_irrigation_calendar_screen.dart';
import '../zone_operations_screens.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _green = Color(0xFF059669);

const _statusVi = {
  'Planned': ('Dự kiến', Color(0xFF0284C7)),
  'InProgress': ('Đang canh tác', _green),
  'Completed': ('Đã thu hoạch', Color(0xFF7C3AED)),
  'Cancelled': ('Đã hủy', _muted),
};

/// null, rỗng hoặc chuỗi "null" (do nội suy chuỗi) đều là ID thiếu.
String? validId(Object? v) {
  final t = '${v ?? ''}'.trim();
  return t.isEmpty || t.toLowerCase() == 'null' ? null : t;
}

/// Danh sách vụ trồng (PlantingSeason) của ĐÚNG Zone đang mở, ngay trong Zone Detail. Không có mùa vụ chung/farmingSeasonId.
/// Từ mỗi vụ mở các thao tác phù hợp trạng thái: giai đoạn, lịch tưới theo ngày, ghi/sửa sản lượng, kết thúc vụ.
class ZoneSeasonsSection extends StatefulWidget {
  final ZoneModel zone;

  /// Tăng để tải lại từ bên ngoài.
  final int version;

  /// Gọi sau khi một thao tác làm đổi dữ liệu (tạo vụ, ghi sản lượng...) để màn cha tải lại Zone.
  final Future<void> Function()? onChanged;
  const ZoneSeasonsSection({super.key, required this.zone, this.version = 0, this.onChanged});

  @override
  State<ZoneSeasonsSection> createState() => _ZoneSeasonsSectionState();
}

class _ZoneSeasonsSectionState extends State<ZoneSeasonsSection> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _seasons = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ZoneSeasonsSection old) {
    super.didUpdateWidget(old);
    if (old.version != widget.version || old.zone.zoneId != widget.zone.zoneId) _load();
  }

  Future<void> _load() async {
    final zoneId = widget.zone.zoneId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await CropApi.getPlantingSeasons(zoneId: zoneId);
      if (!mounted || widget.zone.zoneId != zoneId) return;
      // Phòng thủ: chỉ giữ vụ thuộc đúng Zone này.
      setState(() {
        _seasons = [
          for (final s in all)
            if ('${s['zoneId'] ?? zoneId}'.toLowerCase() == zoneId.toLowerCase()) s,
        ]..sort((a, b) => '${b['startDate']}'.compareTo('${a['startDate']}'));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _changed() async {
    await widget.onChanged?.call();
    if (mounted) await _load();
  }

  Future<void> _create() async {
    final created = await showCreateSeasonSheet(context, widget.zone);
    if (created == true) await _changed();
  }

  @override
  Widget build(BuildContext context) {
    final role = context.read<FarmProvider>().currentRole;
    final isOwner = role == 'OWNER';
    final canYield = role == 'OWNER' || role == 'FARMER';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco_outlined, size: 16, color: _green),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'VỤ TRỒNG CỦA ZONE NÀY',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _green, letterSpacing: 0.4),
                ),
              ),
              IconButton(
                tooltip: 'Tải lại',
                visualDensity: VisualDensity.compact,
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          if (_loading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator(minHeight: 2))
          else if (_error != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Không tải được vụ trồng: $_error',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                  ),
                ),
                TextButton(onPressed: _load, child: const Text('Thử lại')),
              ],
            )
          else if (_seasons.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Zone chưa có vụ trồng nào.', style: TextStyle(fontSize: 12, color: _muted)),
            )
          else
            for (final s in _seasons) _card(s, canYield: canYield),
          if (isOwner)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _create,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tạo vụ trồng cho Zone này'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, Object? value) {
    final v = validId(value) ?? '—';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 11.5, color: _muted)),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: v == '—' ? _muted : _ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> s, {required bool canYield}) {
    final statusCode = '${s['status']}';
    final status = _statusVi[statusCode] ?? (statusCode, _muted);
    final open = statusCode == 'InProgress' || statusCode == 'Planned';
    final seasonId = validId(s['seasonId'] ?? s['plantingSeasonId']);
    final profileId = validId(s['growthProfileId']);
    final yieldKg = s['actualYieldKg'];
    final canRecord = canYield && (statusCode == 'InProgress' || statusCode == 'Completed') && seasonId != null;
    final progress = s['progressPercent'] ?? s['progress'];
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${s['name'] ?? '—'}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _ink),
                ),
              ),
              Text(
                status.$1,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: status.$2),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _row(
            'Cây / giống',
            '${s['cropName'] ?? '—'}${validId(s['varietyName']) != null ? ' · ${s['varietyName']}' : ''}',
          ),
          _row('Hồ sơ của vụ', s['growthProfileName']),
          _row('Giai đoạn hiện tại', s['currentGrowthStageName']),
          _row('Bắt đầu', s['startDate']),
          _row('Dự kiến kết thúc', s['expectedEndDate']),
          if (validId(s['actualEndDate']) != null) _row('Kết thúc thực tế', s['actualEndDate']),
          if (progress != null) _row('Tiến độ', '$progress%'),
          if (yieldKg != null) _row('Sản lượng', '$yieldKg kg'),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.timeline, size: 16),
                label: Text(profileId == null ? 'Giai đoạn (thiếu hồ sơ)' : 'Giai đoạn'),
                onPressed: profileId == null
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GrowthStagesScreen(
                            profileId: profileId,
                            title: '${s['growthProfileName'] ?? s['cropName'] ?? 'Hồ sơ sinh trưởng'}',
                            currentStageId: validId(s['currentGrowthStageId']),
                          ),
                        ),
                      ),
              ),
              if (open && seasonId != null)
                TextButton.icon(
                  icon: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: const Text('Lịch tưới theo ngày'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SeasonIrrigationCalendarScreen(zone: widget.zone, seasonId: seasonId),
                    ),
                  ),
                ),
              if (canRecord)
                TextButton.icon(
                  icon: const Icon(Icons.scale_outlined, size: 16),
                  label: Text(yieldKg == null ? 'Ghi sản lượng' : 'Sửa sản lượng'),
                  onPressed: () async {
                    final ok = await showRecordYieldDialog(context, widget.zone.zoneId, s);
                    if (ok == true) await _changed();
                  },
                ),
            ],
          ),
          if (statusCode == 'InProgress' && canYield)
            const Text(
              'Kết thúc vụ: dùng "Ghi sản lượng" và tích "Kết thúc vụ".',
              style: TextStyle(fontSize: 10.5, color: _muted),
            ),
        ],
      ),
    );
  }
}
