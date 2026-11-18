import 'package:flutter/material.dart';
import '../../core/models/iot_deployment.dart';
import '../../core/models/models.dart' show BusinessParameters;
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_views.dart';

/// Kết quả soạn báo giá. [notes] và [terms] cùng là nội dung ô "Ghi chú điều khoản & phạm vi lắp đặt".
class QuotationDraft {
  final List<Map<String, dynamic>> items;
  final String notes;
  final String terms;
  const QuotationDraft(this.items, this.notes, this.terms);
}

/// 12500000 → "12.500.000 đ" (làm tròn đồng).
String formatMoney(double v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$b đ';
}

String formatContractDate(DateTime value) {
  final date = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
}

/// Bảng dự toán thiết bị & hợp đồng lắp đặt, theo bảng trên web: khung đầu hợp đồng, ô điều khoản bắt buộc, bảng dòng
/// (chọn, mã, tên và mô tả, ĐVT, đơn giá, VAT, số lượng, thành tiền), thêm từ kho / chọn tất cả,
/// tổng và hai đợt thanh toán (cọc 30%, nghiệm thu 70%).
/// [readOnly]: hợp đồng đã ký hoặc đã cọc, chỉ xem, không sửa.
class QuotationEditor extends StatefulWidget {
  final Quotation? initial;

  /// Dòng dựng sẵn từ "Thiết bị đề xuất & dự toán" Owner đã lưu (chỉ dùng khi chưa có báo giá). Kỹ thuật viên chỉnh theo khảo sát.
  final List<QuotationItem>? estimateItems;

  /// Tiêu đề hợp đồng (ví dụ "Hợp đồng lắp đặt IoT #339E17EB-…"), trang trại và phân khu, hiện ở khung đầu bảng.
  final String? contractTitle;
  final String? farmName;
  final String? zoneName;
  final bool readOnly;

  /// Lời giải thích nguồn dữ liệu khi dòng dựng sẵn là ước tính theo diện tích Zone (Owner chưa lưu dự toán); thay cho câu mặc định.
  final String? proposalNote;
  const QuotationEditor({
    super.key,
    this.initial,
    this.estimateItems,
    this.contractTitle,
    this.farmName,
    this.zoneName,
    this.readOnly = false,
    this.proposalNote,
  });

  @override
  State<QuotationEditor> createState() => _QuotationEditorState();
}

class _Line {
  final notes = TextEditingController();
  final code = TextEditingController();
  final name = TextEditingController();
  final unit = TextEditingController(text: 'Cái');
  final quantity = TextEditingController(text: '1');
  final price = TextEditingController();
  final vat = TextEditingController(text: '8');
  String category = 'HARDWARE';
  bool selected = true; // dòng không chọn không đưa vào hợp đồng

  /// Dòng dựng từ dự toán chỉ có LOẠI + số lượng: chưa chọn thiết bị cụ thể từ kho (gửi hợp đồng phải chọn xong).
  bool pendingDevice = false;

  _Line([QuotationItem? item]) {
    if (item == null) return;
    code.text = item.code;
    notes.text = item.notes ?? '';
    name.text = item.name;
    unit.text = item.unit;
    quantity.text = '${item.quantity}';
    price.text = _num(item.unitPrice);
    vat.text = _num(item.vatPercent);
    category = item.category;
  }

  double get _qty => (int.tryParse(quantity.text.trim()) ?? 0).toDouble();
  double get _price => double.tryParse(price.text.trim()) ?? 0;
  double get _vatPct => double.tryParse(vat.text.trim()) ?? 0;

  /// Tiền hàng chưa thuế, thuế VAT và thành tiền của dòng.
  double get net => _qty * _price;
  double get vatAmount => net * _vatPct / 100;
  double get total => net + vatAmount;

  bool get isBlank =>
      code.text.trim().isEmpty &&
      name.text.trim().isEmpty &&
      price.text.trim().isEmpty;

  Map<String, dynamic> toJson() => {
    'notes': notes.text.trim(),
    'code': code.text.trim(),
    'name': name.text.trim(),
    'category': category,
    'unit': unit.text.trim(),
    'quantity': int.parse(quantity.text.trim()),
    'unitPrice': double.parse(price.text.trim()),
    'vatPercent': double.parse(vat.text.trim()),
  };

  void dispose() {
    for (final c in [code, name, unit, quantity, price, vat, notes]) {
      c.dispose();
    }
  }
}

/// Thử nghiệm (ui-ux-pro-max): xanh #15803D (5.0:1 trên nền trắng) chỉ cho màn này.
const _brandGreen = Color(0xFF15803D);

/// Tên LOẠI của dòng thiết bị dựng từ dự toán: bảng báo giá chỉ giữ loại + số lượng đề xuất, thiết bị cụ thể chọn từ kho.
const _deviceRoleLabels = <String, String>{
  'GATEWAY': 'Gateway LoRa',
  'SENSOR_NODE': 'Node cảm biến',
  'ACTUATOR_NODE': 'Node điều khiển van/bơm',
  'ACCESSORY': 'Vật tư phụ kiện',
};

/// Dòng dựng từ dự toán (Owner đã lưu hoặc tính trên máy): thiết bị dự toán chỉ là gợi ý nên bỏ mã/tên cụ thể, giữ loại,
/// số lượng và đơn giá tham khảo; kỹ thuật viên chọn thiết bị thật từ kho bằng dropdown (đổi giá theo thiết bị đã chọn).
_Line _lineFromEstimate(QuotationItem i) {
  final line = _Line(i);
  final label = _deviceRoleLabels[i.category];
  if (label != null) {
    line.code.clear();
    line.name.text = label;
    line.pendingDevice = true;
  }
  return line;
}

/// Loại dòng báo giá của GÓI DỊCH VỤ (tích chọn ở mục "Gói dịch vụ"); không phải thiết bị nên không tạo chỗ chấm Node.
const kPackageCategory = 'SERVICE_PACKAGE';

/// Mã dòng của một gói: PKG- + toàn bộ mã gói (để nhận lại đúng gói đã tích khi mở hợp đồng đã lưu; không cắt ngắn vì
/// các gói thường có tiền tố mã giống nhau).
String packageLineCode(Object? packageId) =>
    'PKG-${'${packageId ?? ''}'.replaceAll('-', '').toUpperCase()}';

class _QuotationEditorState extends State<QuotationEditor> {
  final _form = GlobalKey<FormState>();
  late final List<_Line> _lines;
  final _removed = <_Line>[];
  late final TextEditingController _terms;
  bool _loadingStock = false;
  List<Map<String, dynamic>> _stock = const [];
  List<Map<String, dynamic>> _packages = const [];
  bool _loadingPackages = false;
  String? _packagesError;

  bool get _ro => widget.readOnly;

  @override
  void initState() {
    super.initState();
    _lines =
        widget.initial?.items.map((i) => _Line(i)).toList() ??
        [
          for (final i in widget.estimateItems ?? const <QuotationItem>[])
            _lineFromEstimate(i),
        ];
    if (!_ro) {
      _loadPackages();
      _loadStockSilently();
    }
    final saved = widget.initial?.contractTerms?.trim() ?? '';
    _terms = TextEditingController(
      text: saved.isNotEmpty ? saved : widget.initial?.notes,
    );
  }

  @override
  void dispose() {
    for (final line in [..._lines, ..._removed]) {
      line.dispose();
    }
    _terms.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Vui lòng nhập thông tin' : null;

  String? _number(String? v, {bool quantity = false, bool vat = false}) {
    final n = double.tryParse(v?.trim() ?? '');
    if (n == null ||
        !n.isFinite ||
        n < 0 ||
        (!vat && n == 0) ||
        (vat && n > 100) ||
        (quantity && int.tryParse(v!.trim()) == null)) {
      return quantity
          ? 'Nhập số nguyên dương'
          : vat
          ? 'Nhập VAT từ 0 đến 100'
          : 'Nhập đơn giá lớn hơn 0';
    }
    return null;
  }

  Iterable<_Line> get _chosen => _lines.where((l) => l.selected);

  /// Các dòng GÓI đang được chọn (đã nằm trong tiền hàng và VAT của hợp đồng).
  Iterable<_Line> get _chosenPackages =>
      _chosen.where((l) => l.category == kPackageCategory);

  Future<void> _loadPackages() async {
    setState(() {
      _loadingPackages = true;
      _packagesError = null;
    });
    try {
      final list = await SupportApi.getContractPackages();
      if (mounted) setState(() => _packages = list);
    } catch (e) {
      if (mounted) setState(() => _packagesError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loadingPackages = false);
    }
  }

  _Line? _packageLine(Map<String, dynamic> p) => _lines
      .where(
        (l) =>
            l.category == kPackageCategory &&
            l.code.text.trim().toUpperCase() == packageLineCode(p['id']),
      )
      .firstOrNull;

  /// Tích gói: thêm một dòng "Gói" (SL 1, đơn giá của gói, cùng VAT với các dòng khác) vào hợp đồng; bỏ tích thì bỏ chọn dòng đó.
  void _togglePackage(Map<String, dynamic> p, bool on) {
    setState(() {
      final existing = _packageLine(p);
      if (existing != null) {
        existing.selected = on;
        return;
      }
      if (!on) return;
      final months = (p['durationMonths'] as num?)?.toInt() ?? 0;
      final zones = (p['maxZones'] as num?)?.toInt() ?? 0;
      final desc = '${p['description'] ?? ''}'.trim();
      final vatText = _lines
          .where((l) => l.category != kPackageCategory && !l.isBlank)
          .map((l) => l.vat.text.trim())
          .firstOrNull;
      final line = _Line()
        ..code.text = packageLineCode(p['id'])
        ..name.text = '${p['packageName'] ?? 'Gói dịch vụ'}'
        ..category = kPackageCategory
        ..unit.text = 'Gói'
        ..price.text = _num((p['price'] as num?) ?? 0)
        ..vat.text = (vatText == null || vatText.isEmpty) ? '8' : vatText
        ..notes.text = [
          if (months > 0) '$months tháng',
          if (zones > 0) 'tối đa $zones Zone',
          if (desc.isNotEmpty) desc,
        ].join(' · ');
      if (_lines.length == 1 && _lines.first.isBlank) {
        _removed.add(_lines.removeAt(0));
      }
      _lines.add(line);
    });
  }

  Widget _packagesCard() {
    final active = [
      for (final p in _packages)
        if ('${p['status'] ?? 'Active'}'.toLowerCase() == 'active') p,
    ];
    final picked = _chosenPackages.length;
    String info(Map<String, dynamic> p) => [
      if (((p['durationMonths'] as num?) ?? 0) > 0)
        '${(p['durationMonths'] as num).toInt()} tháng',
      if (((p['maxZones'] as num?) ?? 0) > 0)
        'tối đa ${(p['maxZones'] as num).toInt()} Zone',
    ].join(' · ');
    // Card (là Material) để ExpansionTile/ListTile vẽ được hiệu ứng chạm.
    return Card(
      margin: const EdgeInsets.only(top: 12),
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('packages-card'),
          initiallyExpanded: picked > 0,
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(4, 0, 12, 8),
          dense: true,
          title: const Text(
            'Gói dịch vụ đi kèm',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
          ),
          subtitle: Text(
            picked > 0
                ? 'Đã chọn $picked gói'
                : 'Tích để thêm gói vào hợp đồng',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loadingPackages)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              )
            else if (_packagesError != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Không tải được danh sách gói: $_packagesError',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadPackages,
                    child: const Text('Thử lại'),
                  ),
                ],
              )
            else if (active.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 8),
                child: Text(
                  'Chưa có gói dịch vụ nào đang bán.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              )
            else
              for (final p in active)
                // ListTile cần Material tổ tiên để vẽ nền/hiệu ứng chạm.
                Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    key: ValueKey('pkg-${p['id']}'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    value: _packageLine(p)?.selected ?? false,
                    onChanged: (v) => _togglePackage(p, v ?? false),
                    title: Text(
                      '${p['packageName']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: info(p).isEmpty
                        ? null
                        : Text(info(p), style: const TextStyle(fontSize: 12)),
                    secondary: Text(
                      formatMoney(((p['price'] as num?) ?? 0).toDouble()),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: _brandGreen,
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  double get _net => _ro && widget.initial != null
      ? widget.initial!.subtotal
      : _chosen.fold(0, (s, l) => s + l.net);
  double get _vat => _ro && widget.initial != null
      ? widget.initial!.vatAmount
      : _chosen.fold(0, (s, l) => s + l.vatAmount);
  double get _total =>
      _ro && widget.initial != null ? widget.initial!.totalAmount : _net + _vat;

  /// Ô nhập của một dòng; dòng không được chọn không bị kiểm tra bắt buộc, chế độ chỉ đọc khóa ô.
  Widget _field(
    _Line line,
    TextEditingController c,
    String label, {
    String? Function(String?)? validator,
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: TextFormField(
      controller: c,
      enabled: !_ro,
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      ),
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      // Dòng dựng theo loại chưa có mã: không báo lỗi ô ẩn, mà chặn bằng thông báo "Chọn thiết bị từ kho" khi gửi.
      validator: (v) => line.selected && !(line.pendingDevice && c == line.code)
          ? (validator ?? _required)(v)
          : null,
      onChanged: (_) => setState(() {}),
    ),
  );

  /// Bộ chỉnh số lượng gọn: [−] số [+]; chế độ chỉ đọc hiện chữ "SL".
  Widget _quantityField(_Line line) {
    if (_ro) return Text('SL ${line.quantity.text}');
    void step(int d) {
      final n = (int.tryParse(line.quantity.text.trim()) ?? 0) + d;
      if (n < 1) return;
      setState(() => line.quantity.text = '$n');
    }

    Widget btn(String tip, IconData icon, int d) => IconButton(
      tooltip: tip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 40),
      icon: Icon(icon, size: 22),
      onPressed: () => step(d),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn('Giảm số lượng', Icons.remove_circle_outline, -1),
        SizedBox(
          width: 42,
          child: _field(
            line,
            line.quantity,
            'SL',
            number: true,
            validator: (v) => _number(v, quantity: true),
          ),
        ),
        btn('Tăng số lượng', Icons.add_circle_outline, 1),
      ],
    );
  }

  /// Chọn thiết bị từ kho (hộp chọn có tìm kiếm, lọc chủng loại, tồn kho; chọn lại món đã có thì tăng số lượng).
  /// Tải kho CHÍNH cho hộp chọn; null khi lỗi (đã báo bằng SnackBar).
  Future<List<Map<String, dynamic>>?> _loadMainStock() async {
    setState(() => _loadingStock = true);
    try {
      // Danh mục báo giá lấy từ kho CHÍNH: bỏ các dòng đang ở kho KTV (cùng mã với dòng kho chính sau khi chuyển kho) để không bị trùng món.
      final list = _mainOnly(await DeploymentApi.getHardwareItems());
      if (mounted) _stock = list;
      return list;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
      return null;
    } finally {
      if (mounted) setState(() => _loadingStock = false);
    }
  }

  /// Kho CHÍNH (bỏ dòng ở kho kỹ thuật viên, mỗi mã một dòng) từ danh sách thô của API.
  List<Map<String, dynamic>> _mainOnly(List<Map<String, dynamic>> raw) {
    final seen = <String>{};
    return [
      for (final h in raw)
        if ('${h['status'] ?? ''}'.toLowerCase() != 'intechnicianstock' &&
            seen.add('${h['code'] ?? h['id']}'.toLowerCase()))
          h,
    ];
  }

  /// Tải kho để dropdown "Thiết bị từ kho" có dữ liệu; lỗi thì bỏ qua (dropdown báo chưa có kho, vẫn thêm tay được).
  Future<void> _loadStockSilently() async {
    try {
      final list = _mainOnly(await DeploymentApi.getHardwareItems());
      if (mounted) setState(() => _stock = list);
    } catch (_) {}
  }

  static const _deviceCategories = {
    'GATEWAY',
    'SENSOR_NODE',
    'ACTUATOR_NODE',
    'ACCESSORY',
  };

  /// Thiết bị trong kho phù hợp với loại của dòng (gateway / node cảm biến / node van-bơm / vật tư).
  List<Map<String, dynamic>> _candidatesFor(_Line line) => [
    for (final s in _stock)
      if (_stockMatches(line.category, s)) s,
  ];

  bool _stockMatches(String category, Map<String, dynamic> s) {
    final c = '${s['category'] ?? ''}'.toUpperCase();
    final r = '${s['estimateRole'] ?? ''}'.toLowerCase();
    return switch (category) {
      'GATEWAY' => r == 'gateway' || c.contains('GATEWAY'),
      'SENSOR_NODE' => r == 'sensornode' || c.contains('SENSOR'),
      'ACTUATOR_NODE' =>
        r == 'actuatornode' ||
            c.contains('VALVE') ||
            c.contains('PUMP') ||
            c.contains('ACTUATOR'),
      'ACCESSORY' =>
        r == 'installkit' ||
            [
              'ACCESSORY',
              'KIT',
              'CABLE',
              'PERIPHERAL',
              'SPARE',
            ].any(c.contains),
      _ => true,
    };
  }

  /// Chọn thiết bị từ kho cho dòng: thay mã/tên/đơn giá/ĐVT bằng của thiết bị, GIỮ số lượng; thành tiền tự tính lại.
  void _applyDevice(_Line line, Map<String, dynamic> item) {
    final price = (item['unitPrice'] as num?)?.toDouble() ?? 0;
    final model = '${item['model'] ?? ''}'.trim();
    final maker = '${item['manufacturer'] ?? ''}'.trim();
    final old = line.notes.text.trim();
    setState(() {
      line.code.text = '${item['code'] ?? ''}'.trim();
      line.name.text = '${item['name'] ?? ''}';
      // Thiết bị chưa có giá thì để trống để kỹ thuật viên nhập, không giữ giá của thiết bị khác.
      line.price.text = price > 0 ? _num(price) : '';
      line.unit.text = switch (line.category) {
        'GATEWAY' => 'Trạm',
        'SENSOR_NODE' || 'ACTUATOR_NODE' => 'Node',
        _ => 'Bộ',
      };
      line.notes.text = [
        if (model.isNotEmpty)
          'Model: $model${maker.isEmpty ? '' : ' ($maker)'}',
        if (old.startsWith('Cần ')) old,
      ].join(' · ');
      line.pendingDevice = false;
    });
  }

  /// Dropdown chọn thiết bị từ kho cho dòng thiết bị/vật tư: chọn xong tính lại đơn giá và thành tiền.
  Widget _deviceDropdown(_Line line) {
    final cands = _candidatesFor(line);
    final cur = line.code.text.trim().toLowerCase();
    final match = cands
        .where((s) => '${s['code'] ?? ''}'.toLowerCase() == cur)
        .firstOrNull;
    final value = match == null ? null : '${match['code']}';
    String money(Map<String, dynamic> s) {
      final p = (s['unitPrice'] as num?)?.toDouble() ?? 0;
      return p > 0 ? formatMoney(p) : 'chưa có giá';
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 12, bottom: 6),
      child: DropdownButtonFormField<String>(
        key: ValueKey('dev-${identityHashCode(line)}-$value-${cands.length}'),
        initialValue: value,
        isExpanded: true,
        itemHeight: null,
        decoration: const InputDecoration(
          labelText: 'Thiết bị từ kho',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        ),
        hint: Text(
          cands.isEmpty
              ? 'Kho chưa có thiết bị phù hợp'
              : (cur.isEmpty
                    ? 'Chọn thiết bị từ kho'
                    : '${line.code.text.trim()} (không có trong kho)'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        items: [
          for (final s in cands)
            DropdownMenuItem(
              value: '${s['code']}',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${s['name'] ?? s['code']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      '${s['code']} · ${money(s)}'
                      '${s['quantityInStock'] == null ? '' : ' · Tồn: ${s['quantityInStock']}'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        selectedItemBuilder: (_) => [
          for (final s in cands)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${s['code']} · ${s['name'] ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
        ],
        onChanged: cands.isEmpty
            ? null
            : (code) {
                final s = cands
                    .where((e) => '${e['code']}' == code)
                    .firstOrNull;
                if (s != null) _applyDevice(line, s);
              },
        validator: (v) => line.selected && line.pendingDevice && v == null
            ? 'Cần chọn thiết bị từ kho cho dòng này'
            : null,
      ),
    );
  }

  Future<void> _addFromStock() async {
    if (_loadingStock || _ro) return;
    final stock = await _loadMainStock();
    if (stock == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: _StockPicker(
          stock: stock,
          codesInTable: () => [
            for (final l in _lines) l.code.text.trim().toLowerCase(),
          ],
          tableCount: () => _lines.where((l) => !l.isBlank).length,
          onAdd: _addStockItem,
        ),
      ),
    );
  }

  /// Thêm một món từ kho: đã có cùng mã thì +1 số lượng và chọn lại; chưa có thì thêm dòng mới (đơn giá lấy từ kho,
  /// không có giá thì để trống để kỹ thuật viên nhập, không điền giá giả).
  void _addStockItem(Map<String, dynamic> item) {
    final code = '${item['code'] ?? ''}'.trim();
    setState(() {
      final existing = _lines
          .where(
            (l) =>
                code.isNotEmpty &&
                l.code.text.trim().toLowerCase() == code.toLowerCase(),
          )
          .firstOrNull;
      if (existing != null) {
        existing.quantity.text =
            '${(int.tryParse(existing.quantity.text.trim()) ?? 0) + 1}';
        existing.selected = true;
        return;
      }
      final category = '${item['category'] ?? ''}'.toUpperCase();
      final price = (item['unitPrice'] as num?)?.toDouble() ?? 0;
      final model = '${item['model'] ?? ''}'.trim();
      final maker = '${item['manufacturer'] ?? ''}'.trim();
      final line = _Line()
        ..code.text = code
        ..name.text = '${item['name'] ?? ''}'
        ..category = _categoryOf(category)
        ..unit.text = category.contains('GATEWAY')
            ? 'Trạm'
            : (category.contains('SENSOR') || category.contains('NODE'))
            ? 'Node'
            : 'Bộ'
        ..price.text = price > 0 ? _num(price) : ''
        ..notes.text = model.isEmpty
            ? 'Lấy từ kho vật tư nền tảng'
            : 'Model: $model${maker.isEmpty ? '' : ' ($maker)'}';
      if (_lines.length == 1 && _lines.first.isBlank) {
        _removed.add(_lines.removeAt(0));
      }
      _lines.add(line);
    });
  }

  /// Loại dòng báo giá theo danh mục của kho: gateway, node, vật tư; còn lại để Thiết bị.
  String _categoryOf(String stockCategory) {
    final c = stockCategory.toUpperCase();
    if (const {'GATEWAY', 'SENSOR_NODE', 'ACTUATOR_NODE'}.contains(c)) return c;
    if (c.contains('ACCESSORY') || c.contains('KIT') || c.contains('CABLE')) {
      return 'ACCESSORY';
    }
    return 'HARDWARE';
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    if (_chosen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chọn ít nhất một hạng mục đưa vào hợp đồng.'),
        ),
      );
      return;
    }
    // Chỉ dòng THIẾT BỊ lấy giá từ kho mới bắt buộc có đơn giá (gói dịch vụ giá 0 hoặc dòng dịch vụ không bị chặn).
    final noPrice = _chosen
        .where((l) => _deviceCategories.contains(l.category) && l._price <= 0)
        .toList();
    if (noPrice.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chưa có đơn giá trong kho cho: ${noPrice.map((l) => l.name.text.trim()).join(', ')}. Chọn thiết bị khác hoặc báo Admin cập nhật giá.',
          ),
        ),
      );
      return;
    }
    final pending = _chosen.where((l) => l.pendingDevice).toList();
    if (pending.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chọn thiết bị cụ thể từ kho cho: ${pending.map((l) => l.name.text.trim()).join(', ')}.',
          ),
        ),
      );
      return;
    }
    final text = _terms.text.trim();
    Navigator.pop(
      context,
      QuotationDraft(_chosen.map((l) => l.toJson()).toList(), text, text),
    );
  }

  /// Một dòng của bảng báo giá, gọn như bảng bên web: mã · tên và THÀNH TIỀN ở đầu hàng, rồi (chế độ sửa) dropdown thiết bị từ
  /// kho + Đơn giá · VAT · SL trên một hàng; chế độ chỉ đọc là một dòng "SL ĐVT × đơn giá · VAT". ĐVT/mã/tên/loại/ghi chú
  /// nằm trong "Sửa chi tiết". Các hàng nằm chung một khung, ngăn bằng đường kẻ mảnh.
  Widget _lineCard(_Line line) {
    final index = _lines.indexOf(line) + 1;
    final name = line.name.text.trim();
    final desc = line.notes.text.trim();
    final code = line.code.text.trim();
    final total = line.total.isFinite ? formatMoney(line.total) : '—';
    final pending = line.pendingDevice && line.selected;
    Widget chip(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
    // Material (không phải Container có màu) để "Sửa chi tiết" (ListTile) vẽ hiệu ứng chạm được.
    return Material(
      key: ObjectKey(line),
      color: pending
          ? const Color(0xFFFFFBEB)
          : (line.selected ? Colors.white : AppColors.surfaceMuted),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 6, 6),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  visualDensity: VisualDensity.compact,
                  value: line.selected,
                  onChanged: _ro
                      ? null
                      : (v) => setState(() => line.selected = v ?? true),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.pendingDevice
                              ? 'Chưa chọn thiết bị'
                              : (code.isEmpty ? 'Hạng mục $index' : code),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: line.pendingDevice
                                ? AppColors.warning
                                : AppColors.textMuted,
                          ),
                        ),
                        Text(
                          name.isEmpty ? 'Chưa nhập tên hạng mục' : name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            height: 1.25,
                          ),
                        ),
                        if (desc.isNotEmpty)
                          Text(
                            desc,
                            maxLines: _ro ? 3 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.3,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 104),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        total,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: _brandGreen,
                        ),
                      ),
                    ),
                  ),
                ),
                if (!_ro)
                  IconButton(
                    tooltip: 'Xóa hạng mục',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    icon: const Icon(
                      Icons.close,
                      size: 19,
                      color: AppColors.danger,
                    ),
                    onPressed: () => setState(() {
                      _lines.remove(line);
                      _removed.add(line);
                    }),
                  ),
              ],
            ),
            if (_ro)
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 2, 0, 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${line.quantity.text.trim()} ${line.unit.text.trim()} × ${formatMoney(line._price)}',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      chip('VAT ${line.vat.text.trim()}%'),
                    ],
                  ),
                ),
              )
            else ...[
              if (_deviceCategories.contains(line.category))
                _deviceDropdown(line),
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        line._price > 0
                            ? 'Đơn giá ${formatMoney(line._price)} · VAT ${line.vat.text.trim()}%'
                            : 'Chưa có đơn giá trong kho',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: line._price > 0
                              ? AppColors.textMuted
                              : AppColors.danger,
                        ),
                      ),
                    ),
                    _quantityField(line),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _moneyRow(String label, double value, {bool strong = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: strong ? FontWeight.w800 : FontWeight.normal,
                  fontSize: strong ? 15 : 13,
                ),
              ),
            ),
            Text(
              formatMoney(value),
              style: TextStyle(
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                fontSize: strong ? 15 : 13,
              ),
            ),
          ],
        ),
      );

  Widget _payBox(String label, double value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(height: 4),
          Text(
            formatMoney(value),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ],
      ),
    ),
  );

  Widget _banner() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _brandGreen,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_ro)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.lock, color: Colors.amber, size: 16),
              ),
            Expanded(
              child: Text(
                widget.contractTitle ?? 'Hợp đồng lắp đặt IoT',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 2,
          children: [
            if (widget.farmName != null)
              Text(
                'Trang trại: ${widget.farmName}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            if (widget.zoneName != null)
              Text(
                'Phân khu: ${widget.zoneName}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Khách hàng: Chủ trang trại',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final chosen = _chosen.length;
    final allSelected = chosen == _lines.length;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        title: Text(
          _ro
              ? 'Hợp đồng triển khai IoT (đã khóa)'
              : 'Bảng dự toán thiết bị & hợp đồng lắp đặt',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _banner(),
            if (widget.initial case final q?) ...[
              if (q.createdAtUtc != null)
                Text('Ngày lập: ${formatContractDate(q.createdAtUtc!)}'),
              if (_ro &&
                  q.notes?.trim().isNotEmpty == true &&
                  q.notes?.trim() != q.contractTerms?.trim())
                Text('Ghi chú bổ sung: ${q.notes}'),
            ],
            if (_ro) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning),
                ),
                child: const Text(
                  'Hợp đồng đã được chủ trang trại ký và thanh toán cọc. Kỹ thuật viên không được sửa danh mục thiết bị, số lượng, đơn giá và điều khoản; đang ở chế độ chỉ xem.',
                  style: TextStyle(fontSize: 13.5, height: 1.4),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                widget.proposalNote != null
                    ? widget.proposalNote!
                    : widget.initial == null &&
                          (widget.estimateItems?.isNotEmpty ?? false)
                    ? 'Đã dựng sẵn ${widget.estimateItems!.length} hạng mục từ phần "Thiết bị đề xuất & dự toán" mà Owner đã gửi cùng yêu cầu. '
                          'Chỉnh số lượng, đơn giá theo khảo sát thực địa; Owner sẽ xem và ký xác nhận báo giá này.'
                    : 'Điều chỉnh hạng mục theo khảo sát và trao đổi với Owner. '
                          'Owner sẽ xem và ký xác nhận báo giá này.',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextFormField(
              controller: _terms,
              enabled: !_ro,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Ghi chú điều khoản & phạm vi lắp đặt *',
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            const SizedBox(height: 16),
            Text(
              'BẢNG BÁO GIÁ THIẾT BỊ & VẬT TƯ IOT ($chosen/${_lines.length})',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            if (!_ro) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilledButton.icon(
                    onPressed: _loadingStock ? null : _addFromStock,
                    icon: const Icon(Icons.warehouse_outlined, size: 18),
                    label: const Text('Thêm thiết bị từ kho'),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      for (final l in _lines) {
                        l.selected = !allSelected;
                      }
                    }),
                    child: Text(allSelected ? 'Bỏ chọn tất cả' : 'Chọn tất cả'),
                  ),
                ],
              ),
            ],
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  if (_lines.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Chưa có hạng mục nào. Bấm "Thêm thiết bị từ kho" để thêm.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  for (var k = 0; k < _lines.length; k++) ...[
                    if (k > 0)
                      const Divider(height: 1, color: AppColors.border),
                    _lineCard(_lines[k]),
                  ],
                ],
              ),
            ),
            if (!_ro) _packagesCard(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _moneyRow('Tiền hàng chưa thuế', _net),
                  if (_chosenPackages.isNotEmpty)
                    _moneyRow(
                      '  trong đó gói dịch vụ (${_chosenPackages.length} gói)',
                      _chosenPackages.fold<double>(0, (s, l) => s + l.net),
                    ),
                  _moneyRow('Thuế VAT', _vat),
                  const Divider(),
                  _moneyRow('TỔNG GIÁ TRỊ HỢP ĐỒNG', _total, strong: true),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _payBox(
                        'TẠM ỨNG ${(_ro && widget.initial != null ? widget.initial!.depositLabel : BusinessParameters.active.depositLabel)} KHI KÝ HĐ (OWNER CỌC)',
                        _ro && widget.initial != null
                            ? widget.initial!.deposit30
                            : _total *
                                  BusinessParameters.active.depositPercent /
                                  100,
                        AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      _payBox(
                        'THANH TOÁN ${(_ro && widget.initial != null ? widget.initial!.remainingLabel : BusinessParameters.active.remainingLabel)} KHI NGHIỆM THU',
                        _ro && widget.initial != null
                            ? widget.initial!.remaining70
                            : _total *
                                  BusinessParameters.active.remainingPercent /
                                  100,
                        AppColors.info,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _ro
                  ? 'Hợp đồng đã có giá trị và đã nhận thanh toán cọc.'
                  : 'Sau khi gửi, Owner sẽ nhận được hợp đồng để ký và đặt cọc ${BusinessParameters.active.depositLabel}.',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_ro ? 'Đóng' : 'Hủy bỏ'),
                ),
                if (!_ro) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      child: const Text('Xác nhận & gửi hợp đồng cho khách'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Hộp chọn thiết bị từ kho: tìm theo mã/tên/model/loại, lọc chủng loại, hiện tồn kho và đơn giá.
/// Giữ mở để chọn nhiều món; món đã có trong bảng hiện "Thêm (+1)".
class _StockPicker extends StatefulWidget {
  final List<Map<String, dynamic>> stock;
  final List<String> Function() codesInTable;
  final int Function() tableCount;
  final void Function(Map<String, dynamic>) onAdd;
  const _StockPicker({
    required this.stock,
    required this.codesInTable,
    required this.tableCount,
    required this.onAdd,
  });

  @override
  State<_StockPicker> createState() => _StockPickerState();
}

class _StockPickerState extends State<_StockPicker> {
  static const _filters = <(String, String)>[
    ('ALL', 'Tất cả chủng loại'),
    ('GATEWAY', 'Gateway'),
    ('SENSOR', 'Cảm biến'),
    ('VALVE', 'Van'),
    ('PUMP', 'Bơm'),
  ];
  final _search = TextEditingController();
  String _filter = 'ALL';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visible {
    final q = _search.text.toLowerCase().trim();
    return [
      for (final s in widget.stock)
        if ((_filter == 'ALL' ||
                '${s['category'] ?? ''}'.toUpperCase().contains(_filter)) &&
            (q.isEmpty ||
                [
                  s['code'],
                  s['name'],
                  s['model'],
                  s['category'],
                ].any((v) => '${v ?? ''}'.toLowerCase().contains(q))))
          s,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    final inTable = widget.codesInTable();
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Chọn thiết bị & vật tư từ kho nền tảng',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Tìm theo mã hàng, tên thiết bị, model...',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final (code, label) in _filters)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: _filter == code,
                    onSelected: (_) => setState(() => _filter = code),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text('Không tìm thấy thiết bị nào phù hợp trong kho.'),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = items[i];
                    final code = '${s['code'] ?? ''}';
                    final already = inTable.contains(code.toLowerCase());
                    final stock = s['quantityInStock'] as num?;
                    final price = (s['unitPrice'] as num?)?.toDouble() ?? 0;
                    final model = '${s['model'] ?? ''}'.trim();
                    return ListTile(
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              code,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${s['category'] ?? 'THIẾT BỊ'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          if (stock != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              'Tồn kho: $stock',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: stock > 0
                                    ? _brandGreen
                                    : AppColors.danger,
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        '${s['name'] ?? ''}'
                        '${model.isEmpty ? '' : '\nModel: $model'}'
                        '\nĐơn giá: ${price > 0 ? formatMoney(price) : 'chưa có giá'}',
                        style: const TextStyle(fontSize: 13, height: 1.35),
                      ),
                      isThreeLine: true,
                      trailing: FilledButton(
                        onPressed: () {
                          widget.onAdd(s);
                          setState(() {});
                        },
                        child: Text(already ? 'Thêm (+1)' : 'Chọn'),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Đã có ${widget.tableCount()} thiết bị trong bảng báo giá',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hoàn tất chọn'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Số không có phần thập phân thừa: 2150000.0 → 2150000, 8.5 giữ nguyên.
String _num(num v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toString();
