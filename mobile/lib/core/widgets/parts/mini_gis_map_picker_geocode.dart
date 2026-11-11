part of '../mini_gis_map_picker.dart';

extension _MiniGISMapPickerStateGeocode on _MiniGISMapPickerState {
  /// Mở hộp thoại tìm địa điểm (backend proxy) và dời ghim tới kết quả được chọn.
  Future<void> _openLocationSearch() async {
    final picked = await showDialog<LatLng>(context: context, builder: (_) => const _LocationSearchDialog());
    if (picked != null && mounted) _moveTo(picked, zoom: 16);
  }

  // ── Lấy địa chỉ thực tế qua Backend Proxy (chặn rò rỉ vị trí trực tiếp tới dịch vụ bên thứ ba) ───────────
  Future<void> _resolveAddress(LatLng point) async {
    if (!mounted) return;
    final int myId = ++_requestId;
    _addressPending = true;
    widget.onAddressLoading?.call();

    bool stale() => !mounted || myId != _requestId;

    // Chỉ gọi qua backend proxy, tuyệt đối không gọi trực tiếp bên thứ ba từ thiết bị client
    final result = await FarmApi.reverseGeocodeDetailed(point.latitude, point.longitude);
    // Response của toạ độ cũ (đã có request mới hơn) bị bỏ, không ghi đè địa chỉ của vị trí mới.
    if (stale()) return;

    _addressPending = false;
    final levelTag = widget.level == 'ZONE'
        ? 'Nhà màng (Zone)'
        : widget.level == 'FIELD'
        ? 'Thửa đất (Field)'
        : 'Trang trại (Farm)';

    if (result.ok) {
      final resolvedAddress = result.displayName!;
      debugPrint('[MiniGISMapPicker][$levelTag] Địa chỉ: $resolvedAddress | Vùng: ${result.region}');
      _rebuild(() {
        _displayPlaceName = resolvedAddress;
      });
      // Đồng bộ tên địa điểm thực tế về form; chỉ truyền tên thật.
      widget.onAddressResolved?.call(resolvedAddress);
      if (result.region.isNotEmpty) {
        widget.onRegionNameResolved?.call(result.region);
      }
    } else {
      debugPrint(
        '[MiniGISMapPicker][$levelTag] Không lấy được tên địa danh: ${result.failure?.name} (HTTP ${result.statusCode ?? '-'})',
      );
      // Nhãn bản đồ vẫn hiện toạ độ; ô địa chỉ của form KHÔNG bị ghi toạ độ.
      _rebuild(() {
        _displayPlaceName = _coordFallback(point);
      });
      widget.onAddressFailed?.call(result.message);
    }
  }
}

/// Tìm địa điểm qua backend (POST /gis/search-location) và trả về toạ độ được chọn.
class _LocationSearchDialog extends StatefulWidget {
  const _LocationSearchDialog();

  @override
  State<_LocationSearchDialog> createState() => _LocationSearchDialogState();
}

class _LocationSearchDialogState extends State<_LocationSearchDialog> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.length < 3) {
      setState(() => _message = 'Nhập ít nhất 3 ký tự.');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final r = await FarmApi.searchLocation(q);
      if (!mounted) return;
      setState(() {
        _results = r;
        _message = r.isEmpty ? 'Không tìm thấy địa điểm phù hợp.' : null;
      });
    } catch (e) {
      if (mounted) setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tìm địa điểm', style: TextStyle(fontSize: 15)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Địa chỉ, xã/phường, quận/huyện…',
                suffixIcon: IconButton(
                  tooltip: 'Tìm kiếm',
                  icon: const Icon(Icons.search),
                  onPressed: _loading ? null : _search,
                ),
              ),
            ),
            if (_loading)
              const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator(minHeight: 2)),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_message!, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final r in _results)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined, size: 18),
                      title: Text('${r['displayName'] ?? ''}', style: const TextStyle(fontSize: 12)),
                      onTap: () {
                        final lat = (r['latitude'] as num?)?.toDouble();
                        final lng = (r['longitude'] as num?)?.toDouble();
                        if (lat != null && lng != null) Navigator.pop(context, LatLng(lat, lng));
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))],
    );
  }
}
