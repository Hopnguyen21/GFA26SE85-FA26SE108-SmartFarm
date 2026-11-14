part of '../zone_operations_screens.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 3. Vụ trồng của Zone: sản lượng, giai đoạn sinh trưởng, xuất Excel tổng kết
// ═══════════════════════════════════════════════════════════════════════════
class ZonePlantingSeasonsScreen extends StatefulWidget {
  final ZoneModel zone;
  const ZonePlantingSeasonsScreen({super.key, required this.zone});

  @override
  State<ZonePlantingSeasonsScreen> createState() =>
      _ZonePlantingSeasonsScreenState();
}

class _ZonePlantingSeasonsScreenState extends State<ZonePlantingSeasonsScreen> {
  ZoneModel get zone => widget.zone;
  int _version = 0; // đổi để tải lại danh sách sau khi tạo vụ
  bool _hasRunning = false; // Zone đã có vụ đang canh tác: không tạo thêm vụ

  static const _statusVi = {
    'Planned': ('Dự kiến', Color(0xFF0284C7)),
    'InProgress': ('Đang canh tác', _green),
    'Completed': ('Đã thu hoạch', Color(0xFF7C3AED)),
    'Cancelled': ('Đã hủy', _muted),
  };

  /// null, rỗng hoặc chuỗi "null" (do nội suy chuỗi) đều là ID thiếu.
  static String? _validId(Object? v) {
    final t = '${v ?? ''}'.trim();
    return t.isEmpty || t.toLowerCase() == 'null' ? null : t;
  }

  Future<void> _export(BuildContext context) async {
    try {
      final bytes = await CropApi.downloadSeasonSummaryExcel(zone.zoneId);
      await saveAndShareFile(
        safeFileName('SmartFarm_TongKetVu_${zone.name}.xlsx'),
        bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } catch (e) {
      if (context.mounted)
        _toast(context, 'Xuất Excel thất bại: ${_err(e)}', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.read<FarmProvider>().currentRole;
    final canRecordYield = role == 'OWNER' || role == 'FARMER';
    final isOwner = role == 'OWNER';
    return Scaffold(
      floatingActionButton: isOwner && !_hasRunning
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF062326),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Tạo vụ trồng'),
              onPressed: () async {
                final created = await showCreateSeasonSheet(context, zone);
                if (created == true && context.mounted) {
                  await context.read<FarmProvider>().fetchFromApi();
                  if (mounted) setState(() => _version++);
                }
              },
            )
          : null,
      appBar: AppBar(
        title: Text(
          'Vụ trồng · ${zone.name}',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          IconButton(
            tooltip: 'Xuất Excel tổng kết vụ',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => _export(context),
          ),
        ],
      ),
      body: _AsyncList<List<Map<String, dynamic>>>(
        key: ValueKey('seasons_$_version'),
        load: () async {
          final list = await CropApi.getPlantingSeasons(zoneId: zone.zoneId);
          final running = hasRunningSeason(list);
          if (running != _hasRunning) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _hasRunning = running);
            });
          }
          return list;
        },
        builder: (context, seasons, reload) {
          if (seasons.isEmpty) {
            return _empty(
              isOwner
                  ? 'Zone chưa có vụ trồng nào. Bấm "Tạo vụ trồng" để tạo vụ cho Zone này.'
                  : 'Zone chưa có vụ trồng nào.',
              Icons.eco_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: seasons.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final s = seasons[i];
              final status =
                  _statusVi['${s['status']}'] ?? ('${s['status']}', _muted);
              final yieldKg = s['actualYieldKg'];
              final statusCode = '${s['status']}';
              final open =
                  statusCode == 'InProgress' || statusCode == 'Planned';
              final profileId = _validId(s['growthProfileId']);
              final seasonId = _validId(s['seasonId'] ?? s['plantingSeasonId']);
              // Sản lượng chỉ ghi cho vụ đang canh tác hoặc đã thu hoạch; vụ dự kiến/đã hủy chưa có sản lượng.
              final canYield =
                  statusCode == 'InProgress' || statusCode == 'Completed';
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                            '${s['name']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _ink,
                            ),
                          ),
                        ),
                        Text(
                          status.$1,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: status.$2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${seasonCropLabel(s, zone.currentCrop)}${s['varietyName'] != null ? ' · giống ${s['varietyName']}' : ''}',
                      style: const TextStyle(fontSize: 12, color: _ink),
                    ),
                    Text(
                      '${s['startDate']} → ${s['actualEndDate'] ?? s['expectedEndDate']}'
                      ' · Giai đoạn: ${s['currentGrowthStageName'] ?? '—'}',
                      style: const TextStyle(fontSize: 11, color: _muted),
                    ),
                    if (yieldKg != null)
                      Text(
                        'Sản lượng: $yieldKg kg',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _green,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.timeline, size: 16),
                          label: Text(
                            profileId == null
                                ? 'Giai đoạn (thiếu hồ sơ)'
                                : 'Giai đoạn',
                          ),
                          onPressed: profileId == null
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => GrowthStagesScreen(
                                      profileId: profileId,
                                      title:
                                          '${s['growthProfileName'] ?? s['cropName'] ?? 'Hồ sơ sinh trưởng'}',
                                      currentStageId: _validId(
                                        s['currentGrowthStageId'],
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        if (open && seasonId != null)
                          TextButton.icon(
                            icon: const Icon(
                              Icons.calendar_month_outlined,
                              size: 16,
                            ),
                            label: const Text('Lịch tưới theo ngày'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SeasonIrrigationCalendarScreen(
                                  zone: zone,
                                  seasonId: seasonId,
                                ),
                              ),
                            ),
                          ),
                        if (canRecordYield && canYield && seasonId != null)
                          TextButton.icon(
                            icon: const Icon(Icons.scale_outlined, size: 16),
                            label: Text(
                              yieldKg == null
                                  ? 'Ghi sản lượng'
                                  : 'Sửa sản lượng',
                            ),
                            onPressed: () async {
                              final ok = await showHarvestYieldDialog(
                                context,
                                zoneId: zone.zoneId,
                                zoneName: zone.name,
                                areaM2: zone.areaM2,
                                cropLabel: seasonCropLabel(s, zone.currentCrop),
                                season: s,
                              );
                              if (ok == true && context.mounted) {
                                // Cập nhật dữ liệu Zone (trạng thái vụ/giai đoạn) rồi danh sách vụ.
                                await context
                                    .read<FarmProvider>()
                                    .fetchFromApi();
                                await reload();
                              }
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
