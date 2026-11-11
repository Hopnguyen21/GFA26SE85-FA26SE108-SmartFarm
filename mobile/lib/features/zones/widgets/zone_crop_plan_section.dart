import 'package:flutter/material.dart';
import '../../../core/widgets/form_section.dart';
import '../zone_crop_plan_controller.dart';
import '../zone_crop_plan_logic.dart';
import 'profile_irrigation_view.dart';
import 'stage_draft_tile.dart';
import 'zone_profile_detail_page.dart';

const _muted = Color(0xFF64748B);
const _ink = Color(0xFF0F172A);
const _green = Color(0xFF059669);

/// Phần "Cây trồng & hồ sơ canh tác" của form Zone: chọn cây, giống, hồ sơ hệ thống, tùy chỉnh bản sao
/// (giai đoạn, ngưỡng, lịch tưới) hoặc không áp dụng. Mọi dữ liệu đến từ API.
class ZoneCropPlanSection extends StatefulWidget {
  final ZoneCropPlanController controller;

  /// Chỉ cho xem (vd. Zone đang có vụ chạy: backend không đổi hồ sơ của vụ đang chạy).
  final String? lockedReason;
  const ZoneCropPlanSection({super.key, required this.controller, this.lockedReason});

  @override
  State<ZoneCropPlanSection> createState() => _ZoneCropPlanSectionState();
}

class _ZoneCropPlanSectionState extends State<ZoneCropPlanSection> {
  ZoneCropPlanController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    if (c.crops.isEmpty && !c.loadingCrops) c.loadCrops();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final s = c.selection;
        return FormSection(
          title: 'Cây trồng & hồ sơ canh tác',
          icon: Icons.spa_outlined,
          subtitle:
              'Hồ sơ gắn trực tiếp cho Zone, không tạo vụ trồng. Hồ sơ hệ thống không bị sửa: khi tùy chỉnh, hệ thống tạo bản sao riêng cho trang trại.',
          children: [
            if (widget.lockedReason != null)
              Text(widget.lockedReason!, style: const TextStyle(fontSize: 12, color: Color(0xFFB45309), height: 1.4))
            else ...[
              _modeChips(s),
              if (s.mode != ZoneProfileMode.none) ..._body(context, s),
            ],
          ],
        );
      },
    );
  }

  Widget _modeChips(ZoneCropSelection s) {
    Widget chip(String label, ZoneProfileMode m, {bool enabled = true}) => ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: s.mode == m,
      onSelected: enabled
          ? (_) {
              c.setMode(m);
              if (m != ZoneProfileMode.none && s.cropId == null && c.crops.isEmpty && !c.loadingCrops) c.loadCrops();
            }
          : null,
    );
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        chip('Không áp dụng', ZoneProfileMode.none),
        chip('Dùng hồ sơ có sẵn', ZoneProfileMode.system),
        chip('Tùy chỉnh bản sao', ZoneProfileMode.custom, enabled: s.cropId == null || c.currentProfileIsSystem),
      ],
    );
  }

  List<Widget> _body(BuildContext context, ZoneCropSelection s) {
    if (c.loadingCrops) {
      return const [Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator(minHeight: 2))];
    }
    if (c.cropsError != null) {
      return [
        const SizedBox(height: 8),
        Text(
          'Không tải được danh sách cây trồng: ${c.cropsError}',
          style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
        ),
        TextButton(onPressed: c.loadCrops, child: const Text('Thử lại')),
      ];
    }
    if (c.crops.isEmpty) {
      return const [
        SizedBox(height: 8),
        Text(
          'Hệ thống chưa có cây trồng nào để chọn. Bạn có thể tạo Zone không áp dụng hồ sơ.',
          style: TextStyle(fontSize: 12, color: _muted),
        ),
      ];
    }
    final profiles = c.profiles;
    return [
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: s.cropId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Cây trồng *', prefixIcon: Icon(Icons.grass, size: 20)),
        items: [
          for (final cr in c.crops)
            DropdownMenuItem(
              value: '${cr['cropId']}',
              child: Text('${cr['name']}', overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: c.chooseCrop,
      ),
      if (s.cropId != null) ...[
        if (c.loadingDetail)
          const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator(minHeight: 2))
        else if (c.detailError != null) ...[
          const SizedBox(height: 8),
          Text(
            'Không tải được giống/hồ sơ: ${c.detailError}',
            style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
          ),
          TextButton(onPressed: () => c.chooseCrop(s.cropId), child: const Text('Thử lại')),
        ] else ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: s.varietyId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Giống (không bắt buộc)',
              prefixIcon: Icon(Icons.local_florist_outlined, size: 20),
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Không chọn giống')),
              for (final v in c.varieties)
                DropdownMenuItem<String?>(value: '${v['varietyId']}', child: Text('${v['name']}')),
            ],
            onChanged: c.chooseVariety,
          ),
          const SizedBox(height: 10),
          if (profiles.isEmpty)
            const Text(
              'Cây/giống này chưa có hồ sơ canh tác nào trên hệ thống nên chưa thể áp dụng. '
              'Hãy chọn giống khác, cây khác hoặc "Không áp dụng".',
              style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
            )
          else ...[
            const Text(
              'Chọn hồ sơ canh tác: bấm "Xem chi tiết" để xem giai đoạn, ngưỡng và lịch tưới trước khi áp dụng.',
              style: TextStyle(fontSize: 11.5, color: _muted, height: 1.35),
            ),
            const SizedBox(height: 6),
            for (final p in profiles) _profileCard(context, s, p),
            if (s.profileId == null)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Chưa chọn hồ sơ nào. Hệ thống không tự áp dụng hồ sơ đầu tiên.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
                ),
              ),
            if (s.profileId != null) ...[const SizedBox(height: 10), ..._profileDetail(context, s)],
          ],
        ],
      ],
    ];
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
    child: Text(
      text,
      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
    ),
  );

  Widget _profileCard(BuildContext context, ZoneCropSelection s, Map<String, dynamic> p) {
    final id = '${p['profileId']}';
    final selected = s.profileId == id;
    final system = p['isSystemDefined'] == true;
    final vName = c.varietyNameOf(p);
    final stages = (p['stages'] as List? ?? const []).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? _green : const Color(0xFFE2E8F0), width: selected ? 1.6 : 1),
      ),
      child: Row(
        children: [
          Icon(selected ? Icons.check_circle : Icons.menu_book_outlined, size: 22, color: selected ? _green : _muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p['name']}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _badge(system ? 'Hệ thống' : 'Của trang trại', system ? const Color(0xFF0284C7) : _green),
                    _badge(vName == null ? 'Dùng chung mọi giống' : 'Giống $vName', const Color(0xFF7C3AED)),
                    _badge('$stages giai đoạn', _muted),
                    if (selected) _badge('Đã chọn', _green),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () => _openDetail(context, p),
            child: const Text('Xem chi tiết', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, Map<String, dynamic> p) async {
    final result = await Navigator.of(context).push<ProfileDetailResult>(
      MaterialPageRoute(
        builder: (_) => ZoneProfileDetailPage(
          profile: p,
          cropName: '${c.currentCrop?['name'] ?? p['cropName'] ?? ''}',
          varietyName: c.varietyNameOf(p),
          fetchIrrigation: c.fetchIrrigation,
        ),
      ),
    );
    if (result == null) return;
    c.chooseProfile('${p['profileId']}');
    c.setMode(result == ProfileDetailResult.customize ? ZoneProfileMode.custom : ZoneProfileMode.system);
  }

  List<Widget> _profileDetail(BuildContext context, ZoneCropSelection s) {
    final custom = s.mode == ZoneProfileMode.custom;
    final profile = c.currentProfile;
    final crop = c.currentCrop;
    final variety = c.varieties.where((v) => '${v['varietyId']}' == s.varietyId).firstOrNull;
    return [
      if (c.genericProfileDropsVariety)
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text(
            'Hồ sơ dùng chung cho mọi giống: Zone sẽ được gắn hồ sơ này và không ghi nhận giống cụ thể đã chọn.',
            style: TextStyle(fontSize: 11, color: Color(0xFFB45309), height: 1.3),
          ),
        ),
      Text(
        '${profile?['name'] ?? 'Hồ sơ canh tác'} · ${profile?['isSystemDefined'] == true ? 'hệ thống' : 'của trang trại'}',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink),
      ),
      const SizedBox(height: 2),
      Text(
        '${crop?['name'] ?? ''}${variety == null ? '' : ' · giống ${variety['name']}'}',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _ink),
      ),
      Text(
        '${s.stages.length} giai đoạn · tổng ${s.totalDays} ngày'
        '${profile?['description'] == null ? '' : '\n${profile!['description']}'}',
        style: const TextStyle(fontSize: 11, color: _muted, height: 1.35),
      ),
      if (custom) ...[
        const SizedBox(height: 10),
        TextFormField(
          key: ValueKey('custom_name_${s.profileId}'),
          initialValue: s.customName,
          onChanged: c.setCustomName,
          decoration: const InputDecoration(
            labelText: 'Tên hồ sơ tùy chỉnh *',
            helperText: 'Tạo bản sao riêng; hồ sơ hệ thống giữ nguyên.',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('custom_desc_${s.profileId}'),
          initialValue: s.customDescription,
          onChanged: c.setCustomDescription,
          maxLines: 2,
          maxLength: 4000,
          decoration: const InputDecoration(
            labelText: 'Mô tả (không bắt buộc)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
      const SizedBox(height: 8),
      for (var i = 0; i < s.stages.length; i++)
        StageDraftTile(
          stage: s.stages[i],
          editable: custom,
          onDuration: (n) => c.setStageDuration(i, n),
          onRequirement: (code, {min, max, target}) => c.setRequirement(i, code, min: min, max: max, target: target),
        ),
      const SizedBox(height: 10),
      _irrigation(context, custom),
    ];
  }

  Widget _irrigation(BuildContext context, bool custom) {
    final ps = c.irrigation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.water_drop_outlined, size: 16, color: Color(0xFF0284C7)),
            SizedBox(width: 6),
            Expanded(
              child: Text('Lịch tưới của hồ sơ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        if (c.loadingIrrigation)
          const Padding(padding: EdgeInsets.only(top: 6), child: LinearProgressIndicator(minHeight: 2))
        else if (c.irrigationError != null)
          Text(
            'Không tải được lịch tưới: ${c.irrigationError}',
            style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
          )
        else if (ps != null)
          ProfileIrrigationView(schedule: ps),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            custom
                ? 'Bản sao sẽ chép luôn lịch tưới này. Sau khi gắn hồ sơ cho Zone, bạn sửa lịch tưới của bản sao ở mục "Lịch tưới".'
                : 'Hồ sơ có sẵn chỉ để xem; muốn chỉnh lịch tưới hãy chọn "Tùy chỉnh bản sao".',
            style: const TextStyle(fontSize: 10.5, color: _muted, height: 1.3),
          ),
        ),
      ],
    );
  }
}
