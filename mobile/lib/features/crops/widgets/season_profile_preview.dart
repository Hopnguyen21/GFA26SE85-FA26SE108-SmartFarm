import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../zones/profile_irrigation_logic.dart';
import '../../zones/zone_crop_plan_logic.dart';
import '../../zones/widgets/profile_irrigation_view.dart';
import '../../zones/widgets/stage_draft_tile.dart'
    show describeRequirementDraft;

class SeasonProfilePreview extends StatefulWidget {
  final String profileId;
  const SeasonProfilePreview({super.key, required this.profileId});
  @override
  State<SeasonProfilePreview> createState() => _SeasonProfilePreviewState();
}

class _SeasonProfilePreviewState extends State<SeasonProfilePreview> {
  late Future<List<Object>> _data = _load();
  Future<List<Object>> _load() => Future.wait<Object>([
    CropApi.getGrowthStages(widget.profileId),
    CropApi.getProfileIrrigation(widget.profileId),
  ]);
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    appBar: AppBar(
      backgroundColor: const Color(0xFF062326),
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Xem hồ sơ & lịch tưới',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ),
    body: FutureBuilder<List<Object>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Không tải được hồ sơ: ${snapshot.error}'),
                TextButton(
                  onPressed: () => setState(() => _data = _load()),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final stages = snapshot.data![0] as List<Map<String, dynamic>>;
        final schedule = ProfileSchedule.fromJson(
          snapshot.data![1] as Map<String, dynamic>,
        );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Color(0xFF047857)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Khi tạo vụ, hệ thống sao chép hồ sơ và lịch tưới để tùy chỉnh riêng cho Zone.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF065F46)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final json in stages) ...[
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
                          child: const Center(
                            child: Icon(
                              Icons.eco_rounded,
                              size: 14,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${json['name']} · ${json['durationDays']} ngày',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final requirement in StageDraft.fromJson(
                      json,
                    ).requirements)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          describeRequirementDraft(requirement),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const Divider(height: 32),
            ProfileIrrigationView(schedule: schedule),
          ],
        );
      },
    ),
  );
}
