import 'package:flutter/material.dart';
import '../../core/models/iot_deployment.dart';
import '../../core/services/api_service.dart';
import 'install_voucher_logic.dart';

String _err(Object e) => e.toString().replaceFirst('Exception: ', '');

/// Đọc phiếu xuất kho của hợp đồng (null = chưa có phiếu). Lỗi mạng/quyền thì ném ra: người gọi phải khoá, không coi là "chưa có".
Future<InstallVoucher?> loadInstallVoucher({
  required String farmId,
  required String zoneId,
  required String quotationId,
  String? serviceRequestId,
}) async {
  final all = await StockOutApi.getFarmStockOuts(farmId);
  return pickInstallVoucher(
    all,
    installContractNumber(quotationId),
    zoneId: zoneId,
    serviceRequestId: serviceRequestId,
  );
}

/// Kết quả tạo phiếu: phiếu mới, các dòng hợp đồng không có trong kho (không đưa vào phiếu).
typedef VoucherCreation = ({InstallVoucher voucher, List<String> unmatched});

/// Tạo phiếu xuất kho từ các dòng hợp đồng (khớp theo mã thiết bị trong kho) rồi gửi Admin duyệt (Pending).
/// Tạo xong mà gửi lỗi thì phiếu vẫn là bản nháp (người dùng gửi lại được); lỗi được ném ra.
Future<VoucherCreation> createAndSendVoucher({
  required String farmId,
  required String? zoneId,
  required Quotation quotation,
  String? serviceRequestId,
  List<Map<String, dynamic>>? hardwareItems,
}) async {
  final hardware = hardwareItems ?? await DeploymentApi.getHardwareItems();
  final built = buildVoucherDetails([
    for (final i in quotation.items)
      (code: i.code, name: i.name, quantity: i.quantity),
  ], hardware);
  if (built.details.isEmpty) {
    throw Exception(
      'Hợp đồng chưa có thiết bị nào khớp mã trong kho nên không lập được phiếu xuất kho.',
    );
  }
  final contract = installContractNumber(quotation.id);
  final created = await StockOutApi.create(
    farmId,
    zoneId: (zoneId == null || zoneId.isEmpty) ? null : zoneId,
    notes: installVoucherNotes(contract),
    details: built.details,
    serviceRequestId: serviceRequestId,
  );
  final sent = await StockOutApi.setStatus(
    farmId,
    '${created['id']}',
    'Pending',
  );
  return (voucher: InstallVoucher.fromJson(sent), unmatched: built.unmatched);
}

/// Khung "Phiếu xuất kho thiết bị" của hợp đồng lắp đặt: tạo + gửi Admin duyệt; Admin duyệt xong mới gắn được Node.
class InstallVoucherCard extends StatefulWidget {
  /// Yêu cầu dịch vụ (luồng lắp đặt) mà phiếu thuộc về: phiếu mới tạo được gắn đúng yêu cầu này.
  final String serviceRequestId;
  final String farmId;
  final String zoneId;
  final Quotation? quotation;

  /// null khi chưa đọc được (đang tải hoặc lỗi).
  final InstallVoucher? voucher;
  final bool loaded;
  final String? loadError;

  /// Gọi sau khi tạo/gửi phiếu để màn cha tải lại và mở khoá cổng Gắn Node nếu đủ điều kiện.
  final Future<void> Function() onChanged;
  const InstallVoucherCard({
    super.key,
    required this.serviceRequestId,
    required this.farmId,
    required this.zoneId,
    required this.quotation,
    required this.voucher,
    required this.loaded,
    required this.onChanged,
    this.loadError,
  });

  @override
  State<InstallVoucherCard> createState() => _InstallVoucherCardState();
}

class _InstallVoucherCardState extends State<InstallVoucherCard> {
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  Future<void> _create() async {
    final q = widget.quotation;
    if (q == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final hardware = await DeploymentApi.getHardwareItems();
      final preview = buildVoucherDetails([
        for (final i in q.items)
          (code: i.code, name: i.name, quantity: i.quantity),
      ], hardware);
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(
            'Tạo phiếu xuất kho?',
            style: TextStyle(fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Text(
              preview.details.isEmpty
                  ? 'Không có thiết bị nào trong hợp đồng khớp mã trong kho, nên chưa lập được phiếu.'
                  : 'Phiếu gồm ${preview.details.length} loại thiết bị theo hợp đồng và được gửi Admin duyệt. '
                        'Chỉ khi Admin duyệt mới gắn được Node.'
                        '${preview.unmatched.isEmpty ? '' : '\n\nKhông có trong kho, KHÔNG đưa vào phiếu:\n• ${preview.unmatched.join('\n• ')}'}',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            if (preview.details.isNotEmpty)
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Tạo & gửi duyệt'),
              ),
          ],
        ),
      );
      if (go != true) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      await createAndSendVoucher(
        farmId: widget.farmId,
        zoneId: widget.zoneId,
        quotation: q,
        serviceRequestId: widget.serviceRequestId,
        hardwareItems: hardware,
      );
      if (mounted) {
        setState(() {
          _message = 'Đã tạo phiếu xuất kho và gửi Admin duyệt.';
          _messageIsError = false;
        });
      }
      await widget.onChanged();
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = _err(e);
          _messageIsError = true;
        });
      }
      // Có thể đã tạo được bản nháp nhưng gửi lỗi: tải lại để hiện đúng trạng thái.
      await widget.onChanged();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send(InstallVoucher v) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await StockOutApi.setStatus(widget.farmId, v.id, 'Pending');
      if (mounted) {
        setState(() {
          _message = 'Đã gửi phiếu ${v.code} cho Admin duyệt.';
          _messageIsError = false;
        });
      }
      await widget.onChanged();
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = _err(e);
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.voucher;
    final phase = !widget.loaded ? null : (v?.phase ?? VoucherPhase.none);
    final (title, color) = switch (phase) {
      null => ('Chưa đọc được phiếu xuất kho', const Color(0xFF64748B)),
      VoucherPhase.none => ('Chưa có phiếu xuất kho', const Color(0xFFB45309)),
      VoucherPhase.draft => (
        'Phiếu nháp — chưa gửi duyệt',
        const Color(0xFFB45309),
      ),
      VoucherPhase.pending => ('Chờ Admin duyệt', const Color(0xFF0369A1)),
      VoucherPhase.approved => ('Admin đã duyệt', const Color(0xFF047857)),
      VoucherPhase.cancelled => ('Phiếu đã bị hủy', const Color(0xFFDC2626)),
    };
    final canCreate =
        widget.quotation != null &&
        (phase == VoucherPhase.none || phase == VoucherPhase.cancelled);
    return Container(
      key: const Key('install_voucher_card'),
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: color, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Phiếu xuất kho thiết bị theo hợp đồng',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              title,
              if (v != null && v.code.isNotEmpty) '· ${v.code}',
            ].join(' '),
            key: const Key('voucher_status'),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          if (v != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                // Phiếu thuộc luồng nào: yêu cầu dịch vụ + hợp đồng (liên kết lưu ở backend).
                'Thuộc yêu cầu #${widget.serviceRequestId.length >= 8 ? widget.serviceRequestId.substring(0, 8).toUpperCase() : widget.serviceRequestId}'
                ' · hợp đồng ${installContractNumber(widget.quotation?.id ?? '')}'
                '${v.serviceRequestId == null ? ' (phiếu cũ, nhận theo mã hợp đồng)' : ''}',
                key: const Key('voucher_link'),
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ),
          if (v != null && v.itemLines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                v.itemLines.map((l) => '• $l').join('\n'),
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            switch (phase) {
              VoucherPhase.approved =>
                'Đã được phép gắn/chấm Node cho hợp đồng này.',
              VoucherPhase.pending =>
                'Chỉ Admin được duyệt phiếu. Kỹ thuật viên chưa gắn Node được cho tới khi phiếu được duyệt.',
              _ =>
                'Cần có phiếu xuất kho các thiết bị trong hợp đồng và được Admin duyệt thì mới gắn/chấm Node được.',
            },
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          if (widget.loadError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Không tải được phiếu: ${widget.loadError}',
                style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
              ),
            ),
          if (canCreate || phase == VoucherPhase.draft || phase == null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                children: [
                  if (canCreate)
                    FilledButton.icon(
                      key: const Key('voucher_create'),
                      onPressed: _busy ? null : _create,
                      icon: const Icon(Icons.send, size: 16),
                      label: Text(
                        phase == VoucherPhase.cancelled
                            ? 'Tạo phiếu mới & gửi duyệt'
                            : 'Tạo phiếu & gửi Admin duyệt',
                      ),
                    ),
                  if (phase == VoucherPhase.draft && v != null)
                    FilledButton.icon(
                      key: const Key('voucher_send'),
                      onPressed: _busy ? null : () => _send(v),
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text('Gửi Admin duyệt'),
                    ),
                  if (phase == null)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : widget.onChanged,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Tải lại'),
                    ),
                ],
              ),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _message!,
                key: const Key('voucher_message'),
                style: TextStyle(
                  fontSize: 12,
                  color: _messageIsError
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF047857),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Giai đoạn phiếu xuất kho của hợp đồng gắn với một yêu cầu triển khai (dùng ở màn chi tiết triển khai của kỹ thuật viên,
/// nơi chỉ biết mã triển khai): tìm phiếu dịch vụ có `deploymentRequestId` này → báo giá → phiếu xuất kho.
/// Không có phiếu dịch vụ/báo giá thì [VoucherPhase.none]. Lỗi mạng/quyền được ném ra (người gọi khoá, không đoán).
Future<({VoucherPhase phase, String? code})> loadVoucherPhaseForDeployment({
  required String deploymentRequestId,
  required String farmId,
}) async {
  final requests = await SupportApi.getServiceRequests();
  final sr = requests
      .where(
        (r) =>
            '${r['deploymentRequestId'] ?? ''}'.toLowerCase() ==
            deploymentRequestId.toLowerCase(),
      )
      .firstOrNull;
  if (sr == null) return (phase: VoucherPhase.none, code: null);
  final q = await SupportApi.getQuotation('${sr['id']}');
  if (q == null) return (phase: VoucherPhase.none, code: null);
  final v = await loadInstallVoucher(
    farmId: farmId,
    zoneId: '${sr['zoneId'] ?? ''}',
    quotationId: q.id,
    serviceRequestId: '${sr['id']}',
  );
  return (phase: v?.phase ?? VoucherPhase.none, code: v?.code);
}
