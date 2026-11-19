import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/field_survey_report.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/paging.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/paged_list.dart';
import '../../core/widgets/state_views.dart';
import 'field_survey_logic.dart';
import 'field_survey_report_screen.dart';

/// Danh sách báo cáo khảo sát thực địa (như trang `/technician/field-surveys` và `/owner/field-surveys` trên web).
/// Backend tự giới hạn phạm vi theo vai trò (Owner/Farmer: cùng tenant). KTV mở để xem/sửa và xoá báo cáo của mình;
/// Owner/Farmer chỉ xem. Lập báo cáo mới từ phiếu lắp đặt (bước khảo sát) của KTV.
class FieldSurveyReportsScreen extends StatefulWidget {
  const FieldSurveyReportsScreen({super.key});

  @override
  State<FieldSurveyReportsScreen> createState() =>
      _FieldSurveyReportsScreenState();
}

class _FieldSurveyReportsScreenState extends State<FieldSurveyReportsScreen> {
  List<FieldSurveyReport> _all = const [];
  bool _loading = true;
  String? _error;
  String _status = 'ALL';
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _isTechnician =>
      context.read<FarmProvider>().currentRole == 'TECHNICIAN';

  Future<void> _load() async {
    setState(() {
      _loading = _all.isEmpty;
      _error = null;
    });
    try {
      final r = await FieldSurveyApi.list();
      if (mounted) setState(() => _all = r);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'Không tải được danh sách: ${userFacingError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<FieldSurveyReport> get _shown {
    final q = _query.trim().toLowerCase();
    return sortNewestFirst(
      _all.where((r) {
        if (_status != 'ALL' && r.status != _status) return false;
        if (q.isEmpty) return true;
        return '${r.title} ${r.farmName} ${r.zoneName ?? ''} ${r.location} ${r.surveyorName}'
            .toLowerCase()
            .contains(q);
      }),
      (r) => r.surveyDate ?? r.createdAtUtc,
    );
  }

  Future<void> _open(FieldSurveyReport r) async {
    final p = context.read<FarmProvider>();
    final mine =
        p.me?['userId']?.toString().toLowerCase() ==
        r.createdByUserId.toLowerCase();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FieldSurveyReportScreen(
          reportId: r.id,
          // Chỉ KTV tạo ra báo cáo mới sửa được (backend cũng kiểm tra); Owner/Farmer và KTV khác chỉ xem.
          readOnly: !(_isTechnician && mine),
          currentUserName: p.me?['fullName']?.toString(),
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _delete(FieldSurveyReport r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá báo cáo khảo sát?'),
        content: Text('"${r.title}" sẽ bị xoá và không khôi phục được.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            key: const ValueKey('fs-confirm-delete'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await FieldSurveyApi.delete(r.id);
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không xoá được: ${userFacingError(e)}')),
        );
      }
    }
  }

  Widget _chip(String value, String label) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: ChoiceChip(
      key: ValueKey('fs-filter-$value'),
      label: Text(label),
      selected: _status == value,
      onSelected: (_) => setState(() => _status = value),
    ),
  );

  Widget _card(FieldSurveyReport r) {
    final p = context.read<FarmProvider>();
    final mine =
        p.me?['userId']?.toString().toLowerCase() ==
        r.createdByUserId.toLowerCase();
    final (bg, fg) = switch (r.status) {
      'Approved' => (const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
      'Submitted' => (const Color(0xFFD1FAE5), const Color(0xFF065F46)),
      _ => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
    };
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        key: ValueKey('fs-card-${r.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(r),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      r.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (r.farmName.isNotEmpty) r.farmName,
                  if ((r.zoneName ?? '').isNotEmpty) r.zoneName!,
                ].join(' · '),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                'Ngày khảo sát ${fieldSurveyDate(r.surveyDate)}'
                '${r.surveyorName.isEmpty ? '' : ' · ${r.surveyorName}'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              if (_isTechnician && mine)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: ValueKey('fs-delete-${r.id}'),
                    onPressed: () => _delete(r),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Xoá'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        title: const Text(
          'Báo cáo khảo sát thực địa',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _all.isEmpty
          ? AppErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: PagedList<FieldSurveyReport>(
                items: shown,
                itemGap: 8,
                header: [
                  TextField(
                    key: const ValueKey('fs-search'),
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Tìm theo tiêu đề, trang trại, địa điểm…',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('ALL', 'Tất cả'),
                        _chip('Draft', 'Bản nháp'),
                        _chip('Submitted', 'Đã nộp'),
                        _chip('Approved', 'Đã duyệt'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  if (shown.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Chưa có báo cáo khảo sát thực địa nào.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    ),
                ],
                itemBuilder: (_, r) => _card(r),
              ),
            ),
    );
  }
}
