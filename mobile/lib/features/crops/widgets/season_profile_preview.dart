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
    appBar: AppBar(title: const Text('Xem hồ sơ & lịch tưới')),
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
            const Text(
              'Khi tạo vụ, hệ thống sao chép hồ sơ và lịch tưới để tùy chỉnh riêng cho Zone.',
            ),
            for (final json in stages) ...[
              const SizedBox(height: 12),
              Text(
                '${json['name']} · ${json['durationDays']} ngày',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final requirement in StageDraft.fromJson(json).requirements)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(describeRequirementDraft(requirement)),
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
