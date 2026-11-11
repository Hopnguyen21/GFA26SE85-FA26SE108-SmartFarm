part of '../zone_operations_screens.dart';

/// Danh sách giai đoạn sinh trưởng và yêu cầu môi trường của một hồ sơ.
/// Owner chỉnh được số ngày và ngưỡng môi trường (như GrowthProfilesManager trên Web). Sửa ngưỡng của hồ sơ
/// hệ thống thì backend tạo bản sao riêng cho trang trại; số ngày chỉ đổi được trên bản sao.
class GrowthStagesScreen extends StatefulWidget {
  final String profileId;
  final String title;
  final String? currentStageId;
  const GrowthStagesScreen({super.key, required this.profileId, required this.title, this.currentStageId});

  @override
  State<GrowthStagesScreen> createState() => _GrowthStagesScreenState();
}

class _GrowthStagesScreenState extends State<GrowthStagesScreen> {
  late String _profileId = widget.profileId;
  int _version = 0; // đổi key để _AsyncList tải lại

  static const _units = {
    'SoilMoisture': '%',
    'Temperature': '°C',
    'AirHumidity': '%',
    'LightIntensity': 'lux',
    'Ph': 'pH',
    'Ec': 'mS/cm',
  };

  Future<void> _editDuration(Map<String, dynamic> st) async {
    final c = TextEditingController(text: '${st['durationDays']}');
    final days = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Số ngày · ${st['name']}', style: const TextStyle(fontSize: 15)),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Số ngày (1–365)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(c.text.trim());
              if (v == null || v < 1 || v > 365) {
                _toast(d, 'Số ngày từ 1 đến 365.', error: true);
                return;
              }
              Navigator.pop(d, v);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    c.dispose();
    if (days == null || !mounted) return;
    try {
      await CropApi.updateStageDuration('${st['stageId']}', days);
      if (!mounted) return;
      _toast(context, 'Đã cập nhật số ngày.');
      setState(() => _version++);
    } catch (e) {
      if (mounted) {
        _toast(
          context,
          '${_err(e)}\nVới hồ sơ hệ thống, hãy sửa ngưỡng trước để tạo bản sao riêng của trang trại.',
          error: true,
        );
      }
    }
  }

  Future<void> _editRequirements(Map<String, dynamic> st) async {
    final rows = <_ReqRow>[
      for (final r in StageDraft.fromJson(st).requirements)
        _ReqRow(r.code, r.unit.isEmpty ? (_units[r.code] ?? '') : r.unit, '${r.min}', '${r.target}', '${r.max}'),
    ];
    final payload = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final missing = _units.keys.where((k) => !rows.any((r) => r.code == k)).toList();
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ngưỡng môi trường · ${st['name']}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  for (final r in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              '${ZoneNodesScreen._paramVi[r.code] ?? r.code}\n(${r.unit})',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          for (final (c, label) in [(r.min, 'Min'), (r.target, 'Mục tiêu'), (r.max, 'Max')])
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: TextField(
                                  controller: c,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                  decoration: InputDecoration(
                                    labelText: label,
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ),
                          IconButton(
                            tooltip: 'Đóng',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setLocal(() => rows.remove(r)),
                          ),
                        ],
                      ),
                    ),
                  if (missing.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final code in missing)
                          ActionChip(
                            label: Text(
                              '+ ${ZoneNodesScreen._paramVi[code] ?? code}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () => setLocal(() => rows.add(_ReqRow(code, _units[code] ?? '', '', '', ''))),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () {
                      final out = <Map<String, dynamic>>[];
                      for (final r in rows) {
                        final json = r.toJson();
                        if (json == null) {
                          _toast(
                            ctx,
                            '${ZoneNodesScreen._paramVi[r.code] ?? r.code}: cần Min ≤ Mục tiêu ≤ Max.',
                            error: true,
                          );
                          return;
                        }
                        out.add(json);
                      }
                      if (out.isEmpty) {
                        _toast(ctx, 'Cần ít nhất một thông số.', error: true);
                        return;
                      }
                      Navigator.pop(ctx, out);
                    },
                    child: const Text('Lưu ngưỡng'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    for (final r in rows) {
      r.dispose();
    }
    if (payload == null || !mounted) return;
    try {
      final res = await CropApi.updateStageRequirements('${st['stageId']}', payload);
      if (!mounted) return;
      final cloned = res['clonedFromSystem'] == true;
      setState(() {
        if (cloned && res['effectiveProfileId'] != null) _profileId = '${res['effectiveProfileId']}';
        _version++;
      });
      _toast(context, cloned ? 'Đã tạo bản sao hồ sơ cho trang trại và lưu ngưỡng.' : 'Đã lưu ngưỡng.');
    } catch (e) {
      if (mounted) _toast(context, _err(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = context.read<FarmProvider>().currentRole == 'OWNER';
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, style: const TextStyle(fontSize: 15))),
      body: _AsyncList<List<Map<String, dynamic>>>(
        key: ValueKey('$_profileId-$_version'),
        load: () => CropApi.getGrowthStages(_profileId),
        builder: (context, stages, _) {
          if (stages.isEmpty) return _empty('Hồ sơ chưa có giai đoạn.', Icons.timeline);
          stages.sort((a, b) => ((a['stageOrder'] as num?) ?? 0).compareTo((b['stageOrder'] as num?) ?? 0));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: stages.length,
            itemBuilder: (context, i) {
              final st = stages[i];
              final current = '${st['stageId']}'.toLowerCase() == (widget.currentStageId ?? '').toLowerCase();
              final draft = StageDraft.fromJson(st);
              return Card(
                elevation: 0,
                color: current ? const Color(0xFFECFDF5) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: current ? _green : const Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${st['stageOrder']}. ${st['name']} · ${st['durationDays']} ngày${current ? ' (hiện tại)' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      if ((st['description'] ?? '').toString().isNotEmpty)
                        Text('${st['description']}', style: const TextStyle(fontSize: 12, color: _muted)),
                      if (thresholdNotice(draft) case final notice?)
                        Text(notice, style: const TextStyle(fontSize: 11, color: Color(0xFFB45309))),
                      for (final r in draft.requirements)
                        Text(
                          '• ${ZoneNodesScreen._paramVi[r.code] ?? describeRequirementDraft(r).split(':').first}: '
                          '${r.min} – ${r.max} ${r.unit} (mục tiêu ${r.target})',
                          style: const TextStyle(fontSize: 11, color: _ink),
                        ),
                      if (st['fertilizerAction'] != null)
                        Text(
                          'Bón phân: ${st['fertilizerAction']}',
                          style: const TextStyle(fontSize: 11, color: _muted),
                        ),
                      if (st['ipmAction'] != null)
                        Text('IPM: ${st['ipmAction']}', style: const TextStyle(fontSize: 11, color: _muted)),
                      if (isOwner)
                        Wrap(
                          spacing: 4,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.schedule, size: 16),
                              label: const Text('Số ngày'),
                              onPressed: () => _editDuration(st),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.tune, size: 16),
                              label: const Text('Ngưỡng'),
                              onPressed: () => _editRequirements(st),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ReqRow {
  final String code;
  final String unit;
  final TextEditingController min, target, max;
  _ReqRow(this.code, this.unit, String min, String target, String max)
    : min = TextEditingController(text: min),
      target = TextEditingController(text: target),
      max = TextEditingController(text: max);

  /// null nếu không hợp lệ (cần Min ≤ Mục tiêu ≤ Max).
  Map<String, dynamic>? toJson() {
    double? v(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));
    final lo = v(min), t = v(target), hi = v(max);
    if (lo == null || t == null || hi == null || lo > t || t > hi) return null;
    return {'parameterCode': code, 'minValue': lo, 'maxValue': hi, 'targetValue': t, 'unit': unit};
  }

  void dispose() {
    min.dispose();
    target.dispose();
    max.dispose();
  }
}
