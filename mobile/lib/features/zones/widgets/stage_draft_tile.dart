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

IconData _paramIcon(String code) => switch (code) {
  'Temperature' => Icons.thermostat_rounded,
  'SoilMoisture' => Icons.water_drop_rounded,
  'AirHumidity' => Icons.cloud_outlined,
  'Ph' => Icons.science_outlined,
  'LightIntensity' => Icons.wb_sunny_outlined,
  'Ec' => Icons.electric_bolt_rounded,
  _ => Icons.sensors_outlined,
};

Color _paramColor(String code) => switch (code) {
  'Temperature' => const Color(0xFFD97706),
  'SoilMoisture' => const Color(0xFF2563EB),
  'AirHumidity' => const Color(0xFF0284C7),
  'Ph' => const Color(0xFF7C3AED),
  'LightIntensity' => const Color(0xFFB45309),
  'Ec' => const Color(0xFF059669),
  _ => const Color(0xFF64748B),
};

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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Center(
                  child: Text(
                    '${st.order}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${st.order}. ${st.name}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: Color(0xFF475569),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${st.durationDays} ngày',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (thresholdNotice(st) case final notice?)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: st.requirements.isEmpty
                        ? const Color(0xFFB45309)
                        : const Color(0xFF475569),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      notice,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: st.requirements.isEmpty
                            ? const Color(0xFFB45309)
                            : _muted,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (editable)
            for (final r in st.requirements) _editor(st, r)
          else
            for (final r in st.requirements)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _paramColor(r.code).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          _paramIcon(r.code),
                          size: 14,
                          color: _paramColor(r.code),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          describeRequirementDraft(r),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                      ),
                    ],
                  ),
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
