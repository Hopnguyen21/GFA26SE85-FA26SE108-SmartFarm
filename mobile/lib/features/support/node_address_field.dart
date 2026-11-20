import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/gps_service.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/address_autofill.dart';
import 'node_placement_logic.dart';

/// Ô "Địa chỉ nơi lắp đặt" của Node (tuỳ chọn) kèm nút lấy địa chỉ từ GPS của điện thoại.
/// GPS → toạ độ → reverse-geocode qua backend; thất bại (GPS tắt/từ chối quyền/không có mạng/không tìm thấy) thì GIỮ nội dung ô,
/// hiện lý do và KTV nhập tay. Không bao giờ điền toạ độ thay cho địa chỉ.
class NodeAddressField extends StatefulWidget {
  final TextEditingController controller;
  final GpsProvider gps;

  /// Tra địa chỉ từ toạ độ; mặc định gọi backend (`FarmApi.reverseGeocodeDetailed`). Cho phép thay để kiểm thử.
  final Future<GeocodeResult> Function(double lat, double lng)? lookup;
  final bool enabled;
  const NodeAddressField({
    super.key,
    required this.controller,
    this.gps = const GeolocatorGpsProvider(),
    this.lookup,
    this.enabled = true,
  });

  @override
  State<NodeAddressField> createState() => _NodeAddressFieldState();
}

class _NodeAddressFieldState extends State<NodeAddressField> {
  late final AddressAutofill _auto = AddressAutofill(widget.controller);
  bool _gpsBusy = false;

  @override
  void dispose() {
    _auto.dispose();
    super.dispose();
  }

  Future<void> _fromGps() async {
    if (_gpsBusy) return;
    setState(() => _gpsBusy = true);
    try {
      final fix = await widget.gps.current();
      await _auto.retry(fix.latitude, fix.longitude, lookup: widget.lookup);
    } on GpsException catch (e) {
      _auto.onFailed(e.message);
    } catch (e) {
      _auto.onFailed('Không lấy được địa chỉ: ${userFacingError(e)}');
    } finally {
      if (mounted) setState(() => _gpsBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('node-install-address'),
          controller: widget.controller,
          enabled: widget.enabled,
          minLines: 1,
          maxLines: 3,
          maxLength: nodeAddressMaxLength,
          onChanged: _auto.onUserChanged,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Địa chỉ nơi lắp đặt (tuỳ chọn)',
            hintText: 'Vd: Nhà màng 02, luống 3, Đà Lạt',
          ),
        ),
        _auto.statusLine(),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          key: const ValueKey('node-address-gps'),
          onPressed: (_gpsBusy || !widget.enabled) ? null : _fromGps,
          icon: _gpsBusy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location, size: 18),
          label: Text(_gpsBusy ? 'Đang lấy địa chỉ…' : 'Lấy địa chỉ từ GPS'),
        ),
      ],
    );
  }
}
