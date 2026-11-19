import 'package:flutter/material.dart';
import '../../core/models/field_survey_report.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/user_error.dart';
import 'field_survey_logic.dart';

/// Báo cáo khảo sát thực địa như `FieldSurveyReportModal` trên web: Mục 1 (thông tin buổi khảo sát) và 9 mục nội dung văn bản tự do,
/// trạng thái Bản nháp / Đã nộp / Đã duyệt. KTV lập và sửa phiếu của mình; Owner/Farmer chỉ xem ([readOnly]).
/// Trong luồng lắp đặt ([requireFeasibility]) KTV phải chọn kết luận "Khả thi / Không khả thi" khi nộp: app không tự suy ra kết luận.
/// Trả [FieldSurveyOutcome] khi nộp xong; "Lưu bản nháp" ở lại màn hình.
class FieldSurveyReportScreen extends StatefulWidget {
  final String? reportId;
  final FieldSurveyTarget? target;
  final bool readOnly;
  final bool requireFeasibility;

  /// Họ tên người đăng nhập: điền sẵn "Người khảo sát" cho báo cáo mới.
  final String? currentUserName;
  const FieldSurveyReportScreen({
    super.key,
    this.reportId,
    this.target,
    this.readOnly = false,
    this.requireFeasibility = false,
    this.currentUserName,
  });

  @override
  State<FieldSurveyReportScreen> createState() =>
      _FieldSurveyReportScreenState();
}

class _FieldSurveyReportScreenState extends State<FieldSurveyReportScreen> {
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _surveyor = TextEditingController();
  final _representative = TextEditingController();
  final Map<String, TextEditingController> _sections = {
    for (final s in fieldSurveySections) s.key: TextEditingController(),
  };
  DateTime _date = DateTime.now();
  FieldSurveyReport? _existing;
  String _status = 'Submitted';
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String?
  _notice; // thông báo thành công hiện ngay trên form (SnackBar sẽ che nút Lưu/Nộp ở chân trang)
  bool? _feasible;

  bool get _editable => !widget.readOnly && _status != 'Approved';
  String get _farmId => _existing?.farmId ?? widget.target?.farmId ?? '';
  String get _farmName => _existing?.farmName.isNotEmpty == true
      ? _existing!.farmName
      : (widget.target?.farmName ?? '');
  String get _zoneName => _existing?.zoneName?.isNotEmpty == true
      ? _existing!.zoneName!
      : (widget.target?.zoneName ?? '');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _surveyor.dispose();
    _representative.dispose();
    for (final c in _sections.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(FieldSurveyReport r) {
    _existing = r;
    _title.text = r.title;
    _location.text = r.location;
    _surveyor.text = r.surveyorName;
    _representative.text = r.representativeName;
    for (final s in fieldSurveySections) {
      _sections[s.key]!.text = r.sections[s.key] ?? '';
    }
    _date = r.surveyDate?.toLocal() ?? DateTime.now();
    _status = r.status;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      FieldSurveyReport? found;
      if (widget.reportId != null) {
        found = await FieldSurveyApi.getById(widget.reportId!);
      } else if (widget.target?.serviceRequestId != null) {
        found = await FieldSurveyApi.getByServiceRequest(
          widget.target!.serviceRequestId!,
        );
      }
      if (found != null) {
        _fill(found);
      } else {
        _title.text = defaultFieldSurveyTitle(widget.target);
        final who = (widget.currentUserName ?? '').trim();
        _surveyor.text = who.isEmpty ? 'Kỹ thuật viên SmartFarm' : who;
        _status = 'Draft';
      }
    } catch (e) {
      _error = 'Không tải được báo cáo khảo sát: ${userFacingError(e)}';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null && mounted) setState(() => _date = d);
  }

  Future<void> _save({required bool submit}) async {
    if (_saving) return;
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập tiêu đề báo cáo khảo sát.');
      return;
    }
    if (_farmId.isEmpty) {
      setState(() => _error = 'Chưa xác định trang trại được khảo sát.');
      return;
    }
    if (submit && widget.requireFeasibility && _feasible == null) {
      setState(
        () => _error =
            'Chọn kết luận khảo sát: Khả thi hoặc Không khả thi trước khi nộp.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      final status = submit ? 'Submitted' : 'Draft';
      final payload = fieldSurveyPayload(
        farmId: _existing == null ? _farmId : null,
        serviceRequestId: _existing == null
            ? widget.target?.serviceRequestId
            : null,
        zoneId: _existing == null ? widget.target?.zoneId : null,
        title: _title.text,
        surveyDate: _date,
        location: _location.text,
        surveyorName: _surveyor.text,
        representativeName: _representative.text,
        sections: {for (final e in _sections.entries) e.key: e.value.text},
        status: status,
      );
      final saved = _existing == null
          ? await FieldSurveyApi.create(payload)
          : await FieldSurveyApi.update(_existing!.id, payload);
      if (!mounted) return;
      setState(() {
        _existing = saved;
        _status = saved.status;
      });
      if (submit) {
        Navigator.pop(
          context,
          FieldSurveyOutcome(
            saved,
            widget.requireFeasibility ? _feasible : null,
          ),
        );
      } else {
        setState(() => _notice = 'Đã lưu bản nháp.');
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'Không lưu được báo cáo: ${userFacingError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _statusChip() {
    final (bg, fg) = switch (_status) {
      'Approved' => (const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
      'Submitted' => (const Color(0xFFD1FAE5), const Color(0xFF065F46)),
      _ => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
    };
    return Container(
      key: const ValueKey('fs-status'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        fieldSurveyStatusLabels[_status] ?? _status,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }

  Widget _field(
    String key,
    TextEditingController c,
    String label, {
    String? hint,
    int maxLines = 1,
  }) {
    if (!_editable) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
              ),
            ),
            SelectableText(
              c.text.trim().isEmpty ? '—' : c.text.trim(),
              key: ValueKey(key),
              style: const TextStyle(fontSize: 13.5, height: 1.35),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        key: ValueKey(key),
        controller: c,
        minLines: maxLines == 1 ? 1 : 3,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintMaxLines: 3,
          alignLabelWithHint: maxLines > 1,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _infoCard() => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mục 1: Thông tin buổi khảo sát thực tế',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _pill(
                Icons.agriculture_outlined,
                'Trang trại: ${_farmName.isEmpty ? '—' : _farmName}',
              ),
              if (_zoneName.isNotEmpty)
                _pill(Icons.grid_view_rounded, 'Phân khu: $_zoneName'),
              if (widget.target?.requestCode != null)
                _pill(Icons.tag, 'Phiếu #${widget.target!.requestCode}'),
            ],
          ),
          const SizedBox(height: 12),
          _field(
            'fs-title',
            _title,
            'Tiêu đề báo cáo *',
            hint:
                'Ví dụ: Báo cáo khảo sát thực địa Nhà màng Z01 - Cà chua Beef…',
          ),
          InkWell(
            key: const ValueKey('fs-date'),
            onTap: _editable ? _pickDate : null,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Ngày khảo sát',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_month),
              ),
              child: Text(fieldSurveyDate(_date)),
            ),
          ),
          const SizedBox(height: 10),
          _field(
            'fs-location',
            _location,
            'Địa điểm khảo sát',
            hint: 'Ví dụ: Thôn 3, Xã Đạ Sar, Huyện Lạc Dương, Lâm Đồng',
          ),
          _field('fs-surveyor', _surveyor, 'Người khảo sát (kỹ thuật viên)'),
          _field(
            'fs-representative',
            _representative,
            'Đại diện trang trại',
            hint: 'Họ tên chủ trại / quản lý trang trại',
          ),
        ],
      ),
    ),
  );

  Widget _pill(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFFF0FDF4),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFBBF7D0)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF047857)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF065F46)),
          ),
        ),
      ],
    ),
  );

  Widget _sectionTile(FieldSurveySection s, int index) {
    final filled = _sections[s.key]!.text.trim().isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        key: PageStorageKey('fs-tile-${s.key}'),
        maintainState: true,
        initiallyExpanded: !_editable || index == 0,
        title: Text(
          s.title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        subtitle: Text(
          filled ? 'Đã nhập' : 'Chưa nhập',
          style: TextStyle(
            fontSize: 11.5,
            color: filled ? const Color(0xFF047857) : AppColors.textMuted,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        children: [
          _field(
            'fs-section-${s.key}',
            _sections[s.key]!,
            'Nội dung',
            hint: s.hint,
            maxLines: 8,
          ),
        ],
      ),
    );
  }

  Widget _feasibilityCard() => Card(
    color: const Color(0xFFFFFBEB),
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kết luận khảo sát (bắt buộc để tiếp tục luồng lắp đặt)',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
          ),
          const SizedBox(height: 4),
          const Text(
            'Theo kết quả khảo sát, địa điểm này có lắp đặt được hệ thống IoT không?',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  key: const ValueKey('fs-feasible'),
                  label: const Text('Khả thi'),
                  selected: _feasible == true,
                  onSelected: (_) => setState(() => _feasible = true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  key: const ValueKey('fs-infeasible'),
                  label: const Text('Không khả thi'),
                  selected: _feasible == false,
                  onSelected: (_) => setState(() => _feasible = false),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        title: Text(
          _existing == null && _editable
              ? 'Lập báo cáo khảo sát thực địa'
              : 'Báo cáo khảo sát thực địa',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: _statusChip()),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      if (_error != null)
                        Container(
                          key: const ValueKey('fs-error'),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE4E6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 18,
                                color: AppColors.danger,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF881337),
                                  ),
                                ),
                              ),
                              if (_existing == null && _loadFailed)
                                TextButton(
                                  onPressed: _load,
                                  child: const Text('Thử lại'),
                                ),
                            ],
                          ),
                        ),
                      if (_notice != null)
                        Container(
                          key: const ValueKey('fs-notice'),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: Color(0xFF065F46),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _notice!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF065F46),
                                ),
                              ),
                            ],
                          ),
                        ),
                      _infoCard(),
                      for (var i = 0; i < fieldSurveySections.length; i++)
                        _sectionTile(fieldSurveySections[i], i),
                      if (_editable && widget.requireFeasibility)
                        _feasibilityCard(),
                      if (_existing != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          child: Text(
                            'Người tạo: ${_existing!.createdByUserName.isEmpty ? '—' : _existing!.createdByUserName}'
                            ' · Cập nhật: ${fieldSurveyDate(_existing!.updatedAtUtc ?? _existing!.createdAtUtc)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_editable)
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              key: const ValueKey('fs-save-draft'),
                              onPressed: _saving
                                  ? null
                                  : () => _save(submit: false),
                              child: const Text('Lưu bản nháp'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              key: const ValueKey('fs-submit'),
                              onPressed: _saving
                                  ? null
                                  : () => _save(submit: true),
                              child: Text(
                                _saving
                                    ? 'Đang lưu…'
                                    : (_existing == null
                                          ? 'Nộp báo cáo'
                                          : 'Cập nhật & nộp'),
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

  bool get _loadFailed =>
      _error != null && _error!.startsWith('Không tải được');
}
