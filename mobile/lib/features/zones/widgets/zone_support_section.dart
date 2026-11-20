import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../support/support_requests_screen.dart' show OwnerRequestCard;
import '../../../core/utils/user_error.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

const zoneSupportFailureCodes = <String, String>{
  'SENSOR_OFFLINE': 'Cảm biến mất kết nối',
  'SENSOR_INACCURATE': 'Cảm biến đo sai',
  'ACTUATOR_FAULT': 'Thiết bị chấp hành lỗi',
  'GATEWAY_OFFLINE': 'Gateway mất kết nối',
  'OTHER': 'Sự cố khác',
};

/// Yêu cầu hỗ trợ/bảo trì kỹ thuật CỦA ZONE đang mở (POST /farms/{farmId}/service-requests với `zoneId`), tách biệt với yêu cầu
/// TRIỂN KHAI/lắp đặt IoT (deployment request, tab "Triển khai IoT"). Chỉ Owner gửi được (backend chỉ cho FarmOwner);
/// Technician chỉ xem; Farmer không có quyền nên không hiển thị phần này.
class ZoneSupportSection extends StatefulWidget {
  final ZoneModel zone;
  final bool canCreate;
  const ZoneSupportSection({
    super.key,
    required this.zone,
    required this.canCreate,
  });

  @override
  State<ZoneSupportSection> createState() => _ZoneSupportSectionState();
}

class _ZoneSupportSectionState extends State<ZoneSupportSection> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = [];
  int _gen = 0; // đổi sau mỗi lần tải để thẻ đọc lại hợp đồng/trạng thái

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ZoneSupportSection old) {
    super.didUpdateWidget(old);
    if (old.zone.zoneId != widget.zone.zoneId) _load();
  }

  Future<void> _load() async {
    final zoneId = widget.zone.zoneId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await SupportApi.getServiceRequests();
      if (!mounted || widget.zone.zoneId != zoneId) return;
      setState(() {
        // API trả yêu cầu của cả tenant: chỉ giữ yêu cầu của Zone này.
        _requests = [
          for (final r in all)
            if ('${r['zoneId']}'.toLowerCase() == zoneId.toLowerCase()) r,
        ];
        _loading = false;
        _gen++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingError(e);
        _loading = false;
      });
    }
  }

  Future<void> _openForm() async {
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SupportRequestDialog(zone: widget.zone),
    );
    if (created == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã gửi yêu cầu hỗ trợ kỹ thuật'
          ' · trạng thái: ${created['status'] ?? '—'}',
        ),
        backgroundColor: const Color(0xFF047857),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.support_agent,
                size: 16,
                color: Color(0xFF0284C7),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'HỖ TRỢ KỸ THUẬT CỦA ZONE NÀY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0284C7),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Tải lại',
                visualDensity: VisualDensity.compact,
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          const Text(
            'Dành cho sự cố/bảo trì thiết bị đã lắp. Việc lắp đặt thiết bị mới là "Yêu cầu triển khai" ở tab Triển khai IoT.',
            style: TextStyle(fontSize: 11, color: _muted, height: 1.35),
          ),
          if (widget.canCreate)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _openForm,
                  icon: const Icon(Icons.build_circle_outlined, size: 18),
                  label: const Text('Gửi yêu cầu hỗ trợ kỹ thuật'),
                ),
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (_error != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Không tải được yêu cầu: $_error',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                ),
                TextButton(onPressed: _load, child: const Text('Thử lại')),
              ],
            )
          else if (_requests.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Zone chưa có yêu cầu hỗ trợ nào.',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
            )
          else
            for (final r in _requests)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OwnerRequestCard(
                  key: ValueKey('${r['id']}-$_gen'),
                  request: r,
                  zoneName: '${widget.zone.name} · ${widget.zone.farmName}',
                  zone: widget.zone,
                  onChanged: _load,
                ),
              ),
        ],
      ),
    );
  }
}

/// Form gửi yêu cầu hỗ trợ: Farm và Zone cố định theo Zone đang xem; thiết bị chọn trong các thiết bị CỦA Zone này.
class _SupportRequestDialog extends StatefulWidget {
  final ZoneModel zone;
  const _SupportRequestDialog({required this.zone});

  @override
  State<_SupportRequestDialog> createState() => _SupportRequestDialogState();
}

class _SupportRequestDialogState extends State<_SupportRequestDialog> {
  final _description = TextEditingController();
  String _code = zoneSupportFailureCodes.keys.first;
  String? _deviceId;
  List<Map<String, dynamic>> _devices = [];
  bool _loadingDevices = true;
  String? _devicesError;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loadingDevices = true;
      _devicesError = null;
    });
    try {
      final list = await SupportApi.listZoneDevices(widget.zone.zoneId);
      if (!mounted) return;
      setState(() {
        // Chỉ thiết bị thuộc đúng Zone này.
        _devices = [
          for (final d in list)
            if ('${d['zoneId'] ?? widget.zone.zoneId}'.toLowerCase() ==
                widget.zone.zoneId.toLowerCase())
              d,
        ];
        _loadingDevices = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _devicesError = userFacingError(e);
        _loadingDevices = false;
      });
    }
  }

  Future<void> _submit() async {
    final text = _description.text.trim();
    if (text.length < 5) {
      setState(() => _error = 'Hãy mô tả sự cố (ít nhất 5 ký tự).');
      return;
    }
    if (_deviceId != null &&
        !_devices.any((d) => '${d['deviceId']}' == _deviceId)) {
      setState(() => _error = 'Thiết bị đã chọn không thuộc Zone này.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await SupportApi.createServiceRequest(
        farmId: widget.zone.farmId,
        zoneId: widget.zone.zoneId,
        failureCode: _code,
        description: text,
        deviceId: _deviceId,
      );
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      // Giữ nguyên nội dung form để người dùng sửa/gửi lại.
      if (mounted) {
        setState(() {
          _busy = false;
          _error = userFacingError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Gửi yêu cầu hỗ trợ kỹ thuật',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: _muted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${widget.zone.farmName} › ${widget.zone.name}',
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
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _code,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Loại sự cố *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: [
                for (final e in zoneSupportFailureCodes.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _code = v ?? _code),
            ),
            const SizedBox(height: 12),
            if (_loadingDevices)
              const LinearProgressIndicator(minHeight: 2)
            else if (_devicesError != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Không tải được thiết bị: $_devicesError',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadDevices,
                    child: const Text('Thử lại'),
                  ),
                ],
              )
            else
              DropdownButtonFormField<String?>(
                initialValue: _deviceId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Thiết bị liên quan (không bắt buộc)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Không chọn thiết bị cụ thể'),
                  ),
                  for (final d in _devices)
                    DropdownMenuItem<String?>(
                      value: '${d['deviceId']}',
                      child: Text(
                        '${d['hardwareAddress'] ?? d['deviceId']} · ${d['deviceType'] ?? ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy ? null : (v) => setState(() => _deviceId = v),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              enabled: !_busy,
              maxLines: 4,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: 'Mô tả sự cố *',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF047857),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Gửi'),
        ),
      ],
    );
  }
}
