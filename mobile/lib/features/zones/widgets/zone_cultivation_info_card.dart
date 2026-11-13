import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/utils/profile_name.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _green = Color(0xFF059669);

String _val(Object? v) {
  final s = '${v ?? ''}'.trim();
  return s.isEmpty || s == 'null' ? '—' : s;
}

/// Thông tin canh tác của Zone, lấy HOÀN TOÀN từ API và tách rõ nguồn dữ liệu:
///  - THUỘC ZONE: cây hiện tại, vị trí, diện tích (Zone API);
///  - HỒ SƠ CANH TÁC: profile gắn trực tiếp cho Zone (Zone.GrowthProfileId), không phụ thuộc vụ;
///  - VỤ TRỒNG: vụ đang canh tác (hoặc dự kiến) của Zone (PlantingSeason).
/// Không có chu kỳ/ngày/tiêu chuẩn/mật độ viết cứng: trường nào API không có thì hiện "—".
class ZoneCultivationInfoCard extends StatefulWidget {
  final ZoneModel zone;

  /// Tăng giá trị này để buộc tải lại (sau khi gắn profile, tạo/đóng vụ...).
  final int version;
  const ZoneCultivationInfoCard({
    super.key,
    required this.zone,
    this.version = 0,
  });

  @override
  State<ZoneCultivationInfoCard> createState() =>
      _ZoneCultivationInfoCardState();
}

class _ZoneCultivationInfoCardState extends State<ZoneCultivationInfoCard> {
  bool _loading = true;
  String? _profileError;
  String? _seasonError;
  Map<String, dynamic>? _profile;
  // Vụ trồng hiện tại của Zone: vụ đang canh tác, nếu không có thì vụ dự kiến. null = chưa có.
  Map<String, dynamic>? _season;

  String _err(Object e) => e.toString().replaceFirst('Exception: ', '');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ZoneCultivationInfoCard old) {
    super.didUpdateWidget(old);
    if (old.version != widget.version ||
        old.zone.zoneId != widget.zone.zoneId ||
        old.zone.growthProfileId != widget.zone.growthProfileId) {
      _load();
    }
  }

  Future<void> _load() async {
    final zoneId = widget.zone.zoneId;
    final profileId = widget.zone.growthProfileId;
    setState(() {
      _loading = true;
      _profileError = null;
      _seasonError = null;
    });
    // Mỗi nguồn tải độc lập: một nguồn lỗi không làm mất nguồn còn lại.
    final results = await Future.wait<Object?>([
      if (profileId != null)
        CropApi.getGrowthProfiles()
            .then<Object?>((v) => v)
            .catchError((Object e) => e)
      else
        Future<Object?>.value(null),
      CropApi.getPlantingSeasons(
        zoneId: zoneId,
      ).then<Object?>((v) => v).catchError((Object e) => e),
    ]);
    if (!mounted || widget.zone.zoneId != zoneId) return;
    setState(() {
      final s = results[1];
      _season = null;
      if (s is List<Map<String, dynamic>>) {
        // Chỉ giữ vụ của đúng Zone này (API có thể trả thêm vụ của Zone khác).
        final mine = [
          for (final x in s)
            if ('${x['zoneId'] ?? zoneId}'.toLowerCase() ==
                zoneId.toLowerCase())
              x,
        ];
        _season =
            mine.where((x) => '${x['status']}' == 'InProgress').firstOrNull ??
            mine.where((x) => '${x['status']}' == 'Planned').firstOrNull;
      } else if (s != null) {
        _seasonError = _err(s);
      }
      final p = results[0];
      _profile = null;
      if (p is List<Map<String, dynamic>>) {
        _profile = p
            .where(
              (x) =>
                  '${x['profileId']}'.toLowerCase() == profileId!.toLowerCase(),
            )
            .firstOrNull;
        if (_profile == null)
          _profileError =
              'Không đọc được chi tiết hồ sơ (có thể hồ sơ không còn hiển thị).';
      } else if (p != null) {
        _profileError = _err(p);
      }
      _loading = false;
    });
  }

  Widget _section(
    String title,
    IconData icon,
    List<Widget> children,
  ) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
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
            Icon(icon, size: 15, color: _green),
            const SizedBox(width: 6),
            // Expanded: tiêu đề dài (vd. "HỒ SƠ CANH TÁC (gắn trực tiếp cho Zone)") xuống dòng thay vì tràn ở màn hẹp/chữ lớn.
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _green,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );

  Widget _row(String label, Object? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
        ),
        Expanded(
          child: Text(
            _val(value),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _val(value) == '—' ? _muted : _ink,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _error(String text, VoidCallback retry) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
          ),
        ),
        TextButton(onPressed: retry, child: const Text('Thử lại')),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final zone = widget.zone;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    final stages = [
      for (final s in jsonList(jsonField(_profile ?? const {}, 'stages')))
        if (s is Map) Map<String, dynamic>.from(s),
    ];
    final totalDays = stages.fold<int>(
      0,
      (a, s) => a + (jsonNumber(jsonField(s, 'durationDays'))?.toInt() ?? 0),
    );
    final hasCrop = !zone.currentCrop.startsWith('Chưa gán cây');
    final season = _season;
    final seasonCrop = _val(season?['cropName']);
    // Zone chưa có cây thì lấy cây từ vụ đang canh tác (vụ gán cây cho Zone); không suy đoán từ nguồn nào khác.
    final zoneCrop = hasCrop
        ? zone.currentCrop
        : ('${season?['status']}' == 'InProgress' && seasonCrop != '—'
              ? seasonCrop
              : 'Chưa gán cây');
    const statusVi = {
      'Planned': 'Dự kiến',
      'InProgress': 'Đang canh tác',
      'Completed': 'Đã thu hoạch',
      'Cancelled': 'Đã hủy',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('THUỘC ZONE', Icons.crop_square_outlined, [
          _row('Trang trại', zone.farmName),
          _row('Lô đất', zone.fieldName),
          _row(
            'Diện tích',
            zone.areaM2 > 0 ? '${zone.areaM2.toInt()} m²' : null,
          ),
          _row('Cây của Zone', zoneCrop),
        ]),
        _section(
          'HỒ SƠ CANH TÁC (gắn trực tiếp cho Zone)',
          Icons.menu_book_outlined,
          [
            if (zone.growthProfileId == null)
              const Text(
                'Zone chưa gắn hồ sơ canh tác. Gắn hồ sơ không tạo vụ trồng; vụ trồng tạo riêng ở mục "Vụ trồng".',
                style: TextStyle(fontSize: 12, color: _muted, height: 1.4),
              )
            else ...[
              _row(
                'Hồ sơ',
                displayProfileNameOrNull(
                      '${_profile?['name'] ?? ''}'.trim().isEmpty
                          ? null
                          : '${_profile!['name']}',
                      zoneName: zone.name,
                    ) ??
                    zone.growthProfileName,
              ),
              _row(
                'Nguồn',
                (_profile?['isSystemDefined'] ?? zone.growthProfileIsSystem) ==
                        null
                    ? null
                    : ((_profile?['isSystemDefined'] ??
                                  zone.growthProfileIsSystem) ==
                              true
                          ? 'Hồ sơ hệ thống (chỉ xem)'
                          : 'Bản riêng của trang trại'),
              ),
              _row(
                'Cây / giống',
                _profile == null
                    ? null
                    : '${_profile!['cropName'] ?? '—'} · ${_profile!['varietyName'] ?? 'dùng chung'}',
              ),
              _row(
                'Số giai đoạn',
                _profile == null ? null : '${stages.length}',
              ),
              _row(
                'Tổng thời gian giai đoạn',
                _profile == null || stages.isEmpty
                    ? null
                    : '$totalDays ngày (theo hồ sơ)',
              ),
              if (_profileError != null) _error(_profileError!, _load),
            ],
          ],
        ),
        _section('VỤ TRỒNG', Icons.eco_outlined, [
          if (_seasonError != null)
            _error('Không tải được vụ trồng: $_seasonError', _load)
          else if (season == null)
            const Text(
              'Zone chưa có vụ trồng. Tạo vụ ở mục "Vụ trồng của Zone này" bên dưới; cây của Zone được gán khi tạo vụ.',
              style: TextStyle(fontSize: 12, color: _muted, height: 1.4),
            )
          else ...[
            _row('Tên vụ', season['name']),
            _row(
              'Trạng thái',
              statusVi['${season['status']}'] ?? season['status'],
            ),
            _row(
              'Cây / giống',
              _val(season['varietyName']) == '—'
                  ? season['cropName']
                  : '${_val(season['cropName'])} · ${season['varietyName']}',
            ),
            _row('Giai đoạn hiện tại', season['currentGrowthStageName']),
            _row('Bắt đầu', season['startDate']),
            _row('Dự kiến kết thúc', season['expectedEndDate']),
          ],
        ]),
      ],
    );
  }
}
