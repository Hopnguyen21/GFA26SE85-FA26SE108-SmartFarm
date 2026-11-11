import 'package:flutter/material.dart';
import 'widgets/zone_crop_plan_edit_panel.dart';
import '../crops/widgets/create_season_sheet.dart';
import '../irrigation/season_irrigation_calendar_screen.dart';
import 'widgets/stage_draft_tile.dart' show describeRequirementDraft, thresholdNotice;
import 'zone_crop_plan_logic.dart' show StageDraft;
import 'widgets/zone_irrigation_panel.dart';
import '../../core/widgets/state_views.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/export_utils.dart';
part 'parts/zone_operations_screens_actuator_history.dart';
part 'parts/zone_operations_screens_nodes.dart';
part 'parts/zone_operations_screens_planting_seasons.dart';
part 'parts/zone_operations_screens_growth_stages.dart';
part 'parts/zone_operations_screens_zone_edit.dart';
part 'parts/zone_operations_screens_cultivation_live.dart';

/// Các luồng cấp Zone trước đây chỉ có trên Web: lịch sử điều khiển, số đo theo node + vị trí GIS,
/// vụ trồng (sản lượng, giai đoạn, xuất Excel), sửa/lưu trữ Zone và đồng bộ lịch tưới từ cây trồng.

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _green = Color(0xFF059669);
const _red = Color(0xFFDC2626);

String _err(Object e) => e.toString().replaceFirst('Exception: ', '');

void _toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? _red : _green));
}

String _fmtTime(dynamic raw) {
  final d = DateTime.tryParse('${raw ?? ''}')?.toLocal();
  if (d == null) return '—';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
}

/// Khung chung: tải dữ liệu, hiện lỗi + nút thử lại, kéo để làm mới.
class _AsyncList<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  const _AsyncList({super.key, required this.load, required this.builder});
  @override
  State<_AsyncList<T>> createState() => _AsyncListState<T>();
}

class _AsyncListState<T> extends State<_AsyncList<T>> {
  late Future<T> _future = widget.load();
  Future<void> _reload() async {
    final f = widget.load();
    setState(() => _future = f);
    await f.catchError((_) => null as T);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) return const AppLoading();
      if (snap.hasError) return AppErrorState(message: friendlyError(snap.error!), onRetry: _reload);
      return RefreshIndicator(onRefresh: _reload, child: widget.builder(context, snap.data as T, _reload));
    },
  );
}

/// Trạng thái rỗng nằm trong ListView để vẫn kéo xuống làm mới được.
Widget _empty(String text, IconData icon) => ListView(
  physics: const AlwaysScrollableScrollPhysics(),
  children: [
    SizedBox(
      height: 360,
      child: AppEmptyState(message: text, icon: icon),
    ),
  ],
);
