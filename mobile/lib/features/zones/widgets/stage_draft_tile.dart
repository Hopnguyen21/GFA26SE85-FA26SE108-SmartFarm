import 'package:flutter/material.dart';
import '../zone_crop_plan_logic.dart';

String requirementLabel(String code) => switch (code) {
  'Temperature' => 'Nhiệt độ',
  'SoilMoisture' => 'Độ ẩm đất',
  'AirHumidity' => 'Độ ẩm không khí',
  'Ph' => 'pH',
  'LightIntensity' => 'Ánh sáng',
  'Ec' => 'EC',
  _ => code,
};

/// Một dòng ngưỡng để hiển thị/chia sẻ giữa các màn: tên, khoảng min–max, mục tiêu và đơn vị.
String describeRequirementDraft(RequirementDraft r) =>
    '${requirementLabel(r.code)}: ${fmtNumber(r.min)}–${fmtNumber(r.max)} ${r.unit} (mục tiêu ${fmtNumber(r.target)})'
        .replaceAll('  ', ' ');

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF475569);

/// Thông báo khi giai đoạn không có ngưỡng đọc được (không bao giờ để trống).
String? thresholdNotice(StageDraft st) {
  if (st.requirements.isEmpty) {
    return st.unreadableRequirements > 0
        ? 'Không đọc được ${st.unreadableRequirements} ngưỡng của giai đoạn này (dữ liệu thiếu hoặc sai định dạng).'
        : 'Chưa có dữ liệu ngưỡng.';
  }
  if (st.unreadableRequirements > 0)
    return 'Có ${st.unreadableRequirements} ngưỡng không đọc được nên không hiển thị.';
  return null;
}

String fmtNumber(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toString();

/// Một giai đoạn của hồ sơ: chỉ xem (chip ngưỡng) hoặc sửa được số ngày và 3 ngưỡng (thấp nhất/mục tiêu/cao nhất) theo API.
class StageDraftTile extends StatelessWidget {
  final StageDraft stage;
  final bool editable;
  final ValueChanged<int>? onDuration;
  final void Function(String code, {double? min, double? max, double? target})?
  onRequirement;
  const StageDraftTile({
    super.key,
    required this.stage,
    this.editable = false,
    this.onDuration,
    this.onRequirement,
  });

  @override
  Widget build(BuildContext context) {
    final st = stage;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${st.order}. ${st.name}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ),
              if (editable)
                SizedBox(
                  width: 92,
                  child: TextFormField(
                    key: ValueKey('dur_${st.stageId}'),
                    initialValue: '${st.durationDays}',
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: const InputDecoration(
                      suffixText: 'ngày',
                      suffixStyle: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v.trim());
                      if (n != null) onDuration?.call(n);
                    },
                  ),
                )
              else
                Text(
                  '${st.durationDays} ngày',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (thresholdNotice(st) case final notice?)
            Text(
              notice,
              style: TextStyle(
                fontSize: 11.5,
                color: st.requirements.isEmpty
                    ? const Color(0xFFB45309)
                    : _muted,
                height: 1.3,
              ),
            ),
          if (editable)
            for (final r in st.requirements) _editor(st, r)
          else
            for (final r in st.requirements)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  describeRequirementDraft(r),
                  style: const TextStyle(fontSize: 11.5, color: _ink),
                ),
              ),
        ],
      ),
    );
  }

  Widget _editor(StageDraft st, RequirementDraft r) {
    Widget field(String label, double value, void Function(double) set) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: TextFormField(
              key: ValueKey('req_${st.stageId}_${r.code}_$label'),
              initialValue: fmtNumber(value),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              style: const TextStyle(fontSize: 12.5, color: _ink),
              decoration: InputDecoration(
                labelText: label,
                suffixText: r.unit.isEmpty ? null : r.unit,
                suffixStyle: const TextStyle(fontSize: 10, color: _muted),
                labelStyle: const TextStyle(fontSize: 11, color: _muted),
                floatingLabelStyle: const TextStyle(
                  fontSize: 11,
                  color: _muted,
                ),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) {
                final n = double.tryParse(v.trim().replaceAll(',', '.'));
                if (n != null) set(n);
              },
            ),
          ),
        );
    final err = r.validate();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${requirementLabel(r.code)} (${r.unit})',
            style: const TextStyle(fontSize: 11.5, color: _muted),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              field(
                'Thấp nhất',
                r.min,
                (v) => onRequirement?.call(r.code, min: v),
              ),
              field(
                'Mục tiêu',
                r.target,
                (v) => onRequirement?.call(r.code, target: v),
              ),
              field(
                'Cao nhất',
                r.max,
                (v) => onRequirement?.call(r.code, max: v),
              ),
            ],
          ),
          if (err != null)
            Text(
              err,
              style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
            ),
        ],
      ),
    );
  }
}
