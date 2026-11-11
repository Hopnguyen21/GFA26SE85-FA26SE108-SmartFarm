import 'dart:math' as math;

/// Dự toán lắp đặt IoT (thuật toán Tổ ong) – chỉ để Owner THAM KHẢO, không phải báo giá/hợp đồng.
///
/// Nguồn đơn giá DUY NHẤT: danh mục phần cứng của backend (GET /platform/hardware-items). Không có giá dự phòng,
/// không đoán theo tên. Mỗi hạng mục được xác định bằng cấu hình rõ ràng `estimateRole` do quản trị khai báo trên
/// bản ghi phần cứng (Gateway | SensorNode | ActuatorNode | InstallKit). Chỉ riêng Gateway có đường lui theo
/// `category == Gateway` khi bản ghi chưa gán vai trò, vì Gateway luôn là một thiết bị hoàn chỉnh.
/// Đầu dò rời, Arduino, nguồn điện… không bao giờ được dùng làm giá của một bộ node hoàn chỉnh.

enum EstimateRole { gateway, sensorNode, actuatorNode, installKit }

extension EstimateRoleX on EstimateRole {
  /// Giá trị gửi/nhận với backend.
  String get wire => switch (this) {
    EstimateRole.gateway => 'Gateway',
    EstimateRole.sensorNode => 'SensorNode',
    EstimateRole.actuatorNode => 'ActuatorNode',
    EstimateRole.installKit => 'InstallKit',
  };

  String get label => switch (this) {
    EstimateRole.gateway => 'Gateway LoRa',
    EstimateRole.sensorNode => 'Node cảm biến',
    EstimateRole.actuatorNode => 'Node điều khiển van/bơm',
    EstimateRole.installKit => 'Vật tư phụ kiện',
  };
}

EstimateRole? parseEstimateRole(Object? raw) {
  final s = '${raw ?? ''}'.trim().toLowerCase();
  for (final r in EstimateRole.values) {
    if (r.wire.toLowerCase() == s) return r;
  }
  return null;
}

/// Một bản ghi của danh mục phần cứng, đã chuẩn hoá từ JSON (chịu được camelCase/PascalCase, giá số/chuỗi/null).
class HardwareCatalogItem {
  final String id;
  final String code;
  final String name;
  final String? model;
  final String category;
  final String status;
  final int quantityInStock;
  final double? unitPrice; // null = giá thiếu/không hợp lệ
  final String? assignedTechnicianId;
  final EstimateRole? role;
  final int estimateUnits;
  final List<String>? measuredParameters; // null = chưa khai báo

  const HardwareCatalogItem({
    required this.id,
    required this.code,
    required this.name,
    this.model,
    required this.category,
    required this.status,
    required this.quantityInStock,
    required this.unitPrice,
    this.assignedTechnicianId,
    this.role,
    this.estimateUnits = 1,
    this.measuredParameters,
  });

  factory HardwareCatalogItem.fromJson(Map<String, dynamic> m) {
    Object? g(String k) => m[k] ?? m['${k[0].toUpperCase()}${k.substring(1)}'];
    final rawPrice = g('unitPrice');
    final price = rawPrice == null
        ? null
        : (rawPrice is num ? rawPrice.toDouble() : double.tryParse('$rawPrice'.trim().replaceAll(',', '.')));
    final measured = g('measuredParameters');
    final units = int.tryParse('${g('estimateUnits') ?? 1}') ?? 1;
    return HardwareCatalogItem(
      id: '${g('id') ?? ''}',
      code: '${g('code') ?? ''}'.trim(),
      name: '${g('name') ?? ''}'.trim(),
      model: g('model')?.toString().trim().isEmpty ?? true ? null : g('model').toString().trim(),
      category: '${g('category') ?? ''}'.trim(),
      status: '${g('status') ?? ''}'.trim(),
      quantityInStock: int.tryParse('${g('quantityInStock') ?? 0}') ?? 0,
      unitPrice: price != null && price.isFinite ? price : null,
      assignedTechnicianId: g('assignedTechnicianId')?.toString(),
      role: parseEstimateRole(g('estimateRole')),
      estimateUnits: units < 1 ? 1 : units,
      measuredParameters: measured is List ? [for (final e in measured) '$e'] : null,
    );
  }

  bool get hasValidPrice => unitPrice != null && unitPrice! > 0;

  /// Bản ghi đã ngừng dùng thì không đưa vào dự toán. Hết hàng KHÔNG bị coi là không có giá.
  bool get isRetired {
    final s = status.toLowerCase();
    return s.contains('retire') || s.contains('discontinu') || s.contains('ngừng');
  }

  /// Gateway luôn là thiết bị hoàn chỉnh nên được nhận theo category khi chưa gán vai trò.
  bool get isGatewayByCategory => role == null && category.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '') == 'gateway';
}

enum ResolutionIssue { none, notConfigured, noPrice, ambiguous, priceConflict, retiredOnly }

/// Thiết bị được chọn cho một hạng mục.
class HoneycombItem {
  final String code;
  final String name;
  final String? model;
  final double unitPrice;
  final int unitsPerItem;
  final List<String>? measuredParameters;
  final bool fromCategoryFallback;
  const HoneycombItem({
    required this.code,
    required this.name,
    this.model,
    required this.unitPrice,
    this.unitsPerItem = 1,
    this.measuredParameters,
    this.fromCategoryFallback = false,
  });

  String get title => model == null || model!.isEmpty ? name : '$name ($model)';
}

/// Kết quả xác định thiết bị cho một vai trò. Tính theo TỪNG THIẾT BỊ: Sensor/Actuator/InstallKit có thể gồm nhiều
/// loại thiết bị (vd. node không khí + node đất), mỗi loại có số lượng riêng; Gateway chỉ được đúng một loại.
class ItemResolution {
  final EstimateRole role;
  final List<HoneycombItem> items;
  final ResolutionIssue issue;
  final String detail;
  const ItemResolution(this.role, this.items, this.issue, this.detail);
  HoneycombItem? get item => items.isEmpty ? null : items.first;
  bool get ok => items.isNotEmpty;
}

/// Một dòng của bảng chẩn đoán: bản ghi nào được chọn/bỏ qua và vì sao (dùng cho test, log debug).
class CatalogDiagnosticRow {
  final String code;
  final String category;
  final double? price;
  final String status;
  final EstimateRole? usedFor;
  final bool selected;
  final String reason;
  const CatalogDiagnosticRow(
    this.code,
    this.category,
    this.price,
    this.status,
    this.usedFor,
    this.selected,
    this.reason,
  );
  @override
  String toString() =>
      '$code | $category | ${price ?? 'null'} | $status | ${usedFor?.wire ?? '-'} | ${selected ? 'CHỌN' : 'BỎ QUA'} | $reason';
}

/// Danh mục + kết quả xác định thiết bị cho từng hạng mục.
class HoneycombCatalog {
  final List<HardwareCatalogItem> items;
  final Map<EstimateRole, ItemResolution> resolutions;
  const HoneycombCatalog._(this.items, this.resolutions);

  ItemResolution of(EstimateRole r) => resolutions[r]!;
  HoneycombItem? get gateway => resolutions[EstimateRole.gateway]!.item;
  HoneycombItem? get sensor => resolutions[EstimateRole.sensorNode]!.item;
  HoneycombItem? get actuator => resolutions[EstimateRole.actuatorNode]!.item;
  HoneycombItem? get accessories => resolutions[EstimateRole.installKit]!.item;

  factory HoneycombCatalog.fromHardwareItems(List<Map<String, dynamic>> raw) =>
      HoneycombCatalog.fromItems([for (final m in raw) HardwareCatalogItem.fromJson(m)]);

  factory HoneycombCatalog.fromItems(List<HardwareCatalogItem> items) =>
      HoneycombCatalog._(items, {for (final r in EstimateRole.values) r: _resolve(r, items)});

  static ItemResolution _resolve(EstimateRole role, List<HardwareCatalogItem> all) {
    final candidates = [
      for (final i in all)
        if (i.role == role || (role == EstimateRole.gateway && i.isGatewayByCategory)) i,
    ];
    if (candidates.isEmpty) {
      return ItemResolution(
        role,
        const [],
        ResolutionIssue.notConfigured,
        role == EstimateRole.gateway
            ? 'Danh mục chưa có Gateway.'
            : 'Danh mục chưa có thiết bị hoàn chỉnh được cấu hình cho hạng mục này.',
      );
    }
    final active = candidates.where((c) => !c.isRetired).toList();
    if (active.isEmpty) {
      return ItemResolution(
        role,
        const [],
        ResolutionIssue.retiredOnly,
        'Các thiết bị của hạng mục này đã ngừng sử dụng.',
      );
    }
    // Gộp theo mã: bản sao cấp cho kỹ thuật viên cùng mã là CÙNG một sản phẩm.
    final byCode = <String, List<HardwareCatalogItem>>{};
    for (final c in active) {
      byCode.putIfAbsent(c.code.isEmpty ? c.id : c.code.toUpperCase(), () => []).add(c);
    }
    final priced = <HardwareCatalogItem>[];
    final unusable = <String>[];
    var conflict = false;
    for (final group in byCode.values) {
      final prices = {
        for (final g in group)
          if (g.hasValidPrice) g.unitPrice!,
      };
      if (prices.isEmpty) {
        unusable.add(group.first.code);
        continue;
      }
      if (prices.length > 1) {
        conflict = true;
        unusable.add(group.first.code);
        continue;
      }
      priced.add(
        group.firstWhere(
          (g) => g.assignedTechnicianId == null && g.hasValidPrice,
          orElse: () => group.firstWhere((g) => g.hasValidPrice),
        ),
      );
    }
    // Gateway: một vùng chỉ dùng một loại gateway nên nhiều loại là mơ hồ.
    if (role != EstimateRole.sensorNode && role != EstimateRole.installKit && priced.length > 1) {
      return ItemResolution(
        role,
        const [],
        ResolutionIssue.ambiguous,
        'Có ${priced.length} thiết bị ${role.label} (${priced.map((p) => p.code).join(', ')}); quản trị cần để một loại.',
      );
    }
    // Không được bỏ lặng lẽ một thiết bị chưa có giá trong khi vẫn tính tổng các thiết bị còn lại.
    if (priced.isEmpty || unusable.isNotEmpty) {
      return ItemResolution(
        role,
        const [],
        conflict ? ResolutionIssue.priceConflict : ResolutionIssue.noPrice,
        'Thiết bị ${unusable.join(', ')} chưa có đơn giá hợp lệ (trống/0) hoặc đơn giá không nhất quán giữa các bản ghi.',
      );
    }
    priced.sort((a, b) => a.code.compareTo(b.code));
    return ItemResolution(
      role,
      [
        for (final p in priced)
          HoneycombItem(
            code: p.code,
            name: p.name,
            model: p.model,
            unitPrice: p.unitPrice!,
            unitsPerItem: p.role == null ? 1 : p.estimateUnits,
            measuredParameters: p.measuredParameters,
            fromCategoryFallback: p.role == null,
          ),
      ],
      ResolutionIssue.none,
      '',
    );
  }

  /// Bảng chẩn đoán: mọi bản ghi của danh mục, được chọn hay bỏ qua, lý do.
  List<CatalogDiagnosticRow> diagnose() {
    final chosen = {
      for (final e in resolutions.entries)
        for (final it in e.value.items) it.code.toUpperCase(): e.key,
    };
    return [
      for (final i in items)
        () {
          final role = i.role ?? (i.isGatewayByCategory ? EstimateRole.gateway : null);
          final used = chosen[i.code.toUpperCase()];
          if (used != null && used == role) {
            return CatalogDiagnosticRow(
              i.code,
              i.category,
              i.unitPrice,
              i.status,
              role,
              true,
              'Được chọn cho ${role!.label}',
            );
          }
          final reason = role == null
              ? 'Chưa gán vai trò dự toán (có thể là linh kiện rời) nên không dùng làm giá bộ hoàn chỉnh'
              : i.isRetired
              ? 'Đã ngừng sử dụng'
              : !i.hasValidPrice
              ? 'Đơn giá null/0'
              : resolutions[role]!.detail;
          return CatalogDiagnosticRow(i.code, i.category, i.unitPrice, i.status, role, false, reason);
        }(),
    ];
  }
}

/// Cách đọc nhu cầu đo: so khớp không phân biệt hoa thường.
String _norm(String s) => s.trim().toLowerCase();

/// Kiểm tra năng lực đo của node cảm biến so với nhu cầu đo của Zone/hồ sơ.
class CapabilityCheck {
  final bool declared; // thiết bị đã khai báo thông số đo
  final List<String> missing; // nhu cầu mà thiết bị đã khai báo nhưng KHÔNG đo được
  const CapabilityCheck(this.declared, this.missing);
  bool get hasGap => declared && missing.isNotEmpty;
}

/// Thiết bị ĐÃ GẮN vào Zone (lấy từ GET /zones/{id}/devices): dự toán chỉ tính phần cần BỔ SUNG.
/// Thiết bị đã gắn không liên kết với mã trong kho nên chỉ so được theo loại thiết bị và theo thông số cảm biến đo được.
class ZoneInstalledDevices {
  final int sensorNodes;
  final int actuatorNodes;
  final int gateways; // số gateway khác nhau mà các thiết bị của Zone đang dùng
  final Set<String> measured; // thông số (đã chuẩn hóa chữ thường) mà cảm biến đã gắn đo được
  const ZoneInstalledDevices({
    this.sensorNodes = 0,
    this.actuatorNodes = 0,
    this.gateways = 0,
    this.measured = const {},
  });

  static const none = ZoneInstalledDevices();

  bool get isEmpty => sensorNodes == 0 && actuatorNodes == 0 && gateways == 0;

  factory ZoneInstalledDevices.fromJson(List<Map<String, dynamic>> devices) {
    var sensors = 0, actuators = 0;
    final gw = <String>{};
    final measured = <String>{};
    for (final d in devices) {
      if ('${d['status']}'.toLowerCase().contains('decommission')) continue; // đã ngừng thì không tính
      final type = '${d['deviceType']}'.toLowerCase();
      if (type == 'sensornode') sensors++;
      if (type == 'actuatornode') actuators++;
      final g = '${d['gatewayId'] ?? ''}';
      if (g.isNotEmpty && g != 'null' && g != '00000000-0000-0000-0000-000000000000') gw.add(g);
      final ss = d['sensors'];
      if (ss is List) {
        for (final x in ss) {
          measured.add(_norm('$x'));
        }
      }
    }
    return ZoneInstalledDevices(
      sensorNodes: sensors,
      actuatorNodes: actuators,
      gateways: gw.length,
      measured: measured,
    );
  }
}

/// Kiểm tra năng lực đo: thông số đo được = thiết bị ĐÃ GẮN + node cảm biến sẽ bổ sung, so với nhu cầu của Zone/hồ sơ.
CapabilityCheck checkCapability(
  List<HoneycombItem> addedSensors,
  List<String> required, {
  Set<String> installedMeasured = const {},
}) {
  if (required.isEmpty) return const CapabilityCheck(true, []);
  // Chỉ kết luận thiếu hụt khi MỌI node sẽ bổ sung đã khai báo thông số; thiếu khai báo thì không khẳng định gì.
  if (addedSensors.any((s) => s.measuredParameters == null || s.measuredParameters!.isEmpty)) {
    return const CapabilityCheck(false, []);
  }
  final have = {...installedMeasured, for (final s in addedSensors) ...s.measuredParameters!.map(_norm)};
  return CapabilityCheck(true, [
    for (final r in {...required})
      if (!have.contains(_norm(r))) r,
  ]);
}

class EstimateLine {
  final EstimateRole role;
  final int requiredUnits; // số đơn vị CẦN BỔ SUNG (đã trừ thiết bị đã gắn)
  final int quantity; // số thiết bị phải mua = ceil(requiredUnits / unitsPerItem của thiết bị này)
  final ItemResolution resolution;
  final HoneycombItem? item; // null = hạng mục chưa có thiết bị/đơn giá (hoặc đã đủ, xem covered)
  final int neededTotal; // tổng nhu cầu theo thuật toán
  final int installed; // đã gắn trong Zone
  final bool covered; // không cần bổ sung hạng mục này
  final String? note;
  const EstimateLine(
    this.role,
    this.requiredUnits,
    this.quantity,
    this.resolution,
    this.item, {
    this.neededTotal = 0,
    this.installed = 0,
    this.covered = false,
    this.note,
  });

  double? get unitPrice => item?.unitPrice;
  double? get lineTotal => covered ? 0 : (item == null ? null : quantity * item!.unitPrice);
}

class HoneycombEstimate {
  final double areaM2;
  final double radiusM;
  final double cellAreaM2;
  final double interNodeDistanceM;
  final int gateways; // nhu cầu theo thuật toán (tổng)
  final int sensors;
  final int actuators;
  final int accessoryPoints; // số vị trí cần phụ kiện (chỉ phần bổ sung)
  final List<EstimateLine> lines;
  final double installationCost;
  final CapabilityCheck capability;
  final ZoneInstalledDevices installed;

  const HoneycombEstimate({
    required this.areaM2,
    required this.radiusM,
    required this.cellAreaM2,
    required this.interNodeDistanceM,
    required this.gateways,
    required this.sensors,
    required this.actuators,
    required this.accessoryPoints,
    required this.lines,
    required this.installationCost,
    required this.capability,
    this.installed = ZoneInstalledDevices.none,
  });

  EstimateLine line(EstimateRole r) => lines.firstWhere((l) => l.role == r);
  List<EstimateLine> linesOf(EstimateRole r) => [
    for (final l in lines)
      if (l.role == r) l,
  ];

  /// Tổng chi phí các thiết bị của một vai trò; null nếu vai trò đó thiếu thiết bị/đơn giá.
  double? costOf(EstimateRole r) {
    final ls = linesOf(r);
    if (ls.any((l) => l.lineTotal == null)) return null;
    return ls.fold<double>(0, (a, l) => a + l.lineTotal!);
  }

  double? get gatewayCost => costOf(EstimateRole.gateway);
  double? get sensorCost => costOf(EstimateRole.sensorNode);

  double? get actuatorCost => costOf(EstimateRole.actuatorNode);

  double? get accessoriesCost => costOf(EstimateRole.installKit);

  bool get hasFullPricing => lines.every((l) => l.lineTotal != null);

  /// Zone không cần bổ sung thiết bị nào (đủ số lượng và đủ thông số).
  bool get nothingToAdd => lines.every((l) => l.covered) && !capability.hasGap;

  /// Lý do không có tổng (null khi có tổng).
  String? get totalBlockedReason {
    final missing = lines.where((l) => l.lineTotal == null).map((l) => l.role.label).toSet().toList();
    if (missing.isNotEmpty) return 'Thiếu dữ liệu thiết bị/đơn giá: ${missing.join(', ')}.';
    if (capability.hasGap) {
      return 'Chưa có thiết bị nào (đã gắn hoặc trong danh mục) đo được: ${capability.missing.join(', ')}.';
    }
    return null;
  }

  /// Tổng = đúng tổng các dòng + phí thi công; thiếu một hạng mục hoặc có thiếu hụt năng lực đo thì không có tổng.
  double? get total =>
      totalBlockedReason != null ? null : lines.fold<double>(0, (a, l) => a + l.lineTotal!) + installationCost;

  /// Tạm tính khi MỌI hạng mục đã có thiết bị và đơn giá nhưng thiết bị chưa đáp ứng hết nhu cầu đo (capability.hasGap).
  /// Không phải tổng đầy đủ: phải hiển thị kèm cảnh báo thông số còn thiếu. Null khi còn thiếu hạng mục/đơn giá.
  double? get partialTotal =>
      total == null && hasFullPricing ? lines.fold<double>(0, (a, l) => a + l.lineTotal!) + installationCost : null;
  double? get minTotal => total == null || total == 0 ? null : (total! * 0.88).roundToDouble();
  double? get maxTotal => total == null || total == 0 ? null : (total! * 1.18).roundToDouble();
}

/// Phí khảo sát, định vị GPS & cấu hình mạng mesh: tham số cố định của thuật toán (khớp web), KHÔNG lấy từ danh mục.
const double honeycombInstallationFlatVnd = 500000;

/// Bán kính ô dự toán cố định theo cấu hình hiện tại (m).
const double honeycombFixedRadiusM = 25;

/// Hệ số bù biên cho hình học thực tế không vuông vức (khớp web).
const double honeycombBoundaryFactor = 1.12;

/// Mỗi Gateway LoRa phủ tối đa ~15.000 m² nhà màng (khớp web).
const double honeycombGatewayCoverM2 = 15000;

/// Tỉ lệ van/bơm trên mỗi node cảm biến theo cây trồng (khớp web); cây khác dùng mặc định như cà chua.
double honeycombActuatorRatio(String cropName) {
  final c = cropName.toLowerCase();
  if (c.contains('ớt')) return 0.5;
  if (c.contains('dưa leo') || c.contains('dưa chuột')) return 0.7;
  if (c.contains('xà lách')) return 0.8;
  if (c.contains('dâu')) return 0.75;
  return 0.6;
}

int _ceilDiv(int a, int b) => b <= 1 ? a : (a + b - 1) ~/ b;

/// Một loại bộ node cảm biến được chọn kèm số bộ.
class SensorKitPick {
  final HoneycombItem item;
  final int qty;
  const SensorKitPick(this.item, this.qty);
}

/// Các bộ node cảm biến trong kho là PHƯƠNG ÁN THAY THẾ nhau (mỗi bộ gồm vi điều khiển + nhiều cảm biến; biến thể đo
/// ánh sáng, biến thể đo pH...). Mỗi điểm đo dùng MỘT bộ. Chọn ít loại bộ nhất để phủ đủ thông số cần đo:
/// - bộ chính (phủ nhiều thông số cần nhất, ngang nhau thì rẻ hơn) dùng cho các điểm còn lại;
/// - mỗi thông số mà bộ chính chưa đo được thì thêm 1 bộ biến thể phủ nó, thay cho 1 bộ chính (tổng số điểm không đổi).
/// Không có căn cứ chọn theo thông số (chưa khai báo/không có nhu cầu): dùng bộ rẻ nhất cho mọi điểm, không khẳng định gì.
List<SensorKitPick> planSensorKits(List<HoneycombItem> kits, List<String> target, int nodes) {
  if (kits.isEmpty || nodes <= 0) return const [];
  final want = {for (final t in target) _norm(t)};
  Set<String> paramsOf(HoneycombItem k) => {for (final p in k.measuredParameters ?? const <String>[]) _norm(p)};
  int byPrice(HoneycombItem a, HoneycombItem b) {
    final c = a.unitPrice.compareTo(b.unitPrice);
    return c != 0 ? c : a.code.compareTo(b.code);
  }

  final cheapest = ([...kits]..sort(byPrice)).first;
  final declared = kits.where((k) => paramsOf(k).isNotEmpty).toList();
  if (want.isEmpty || declared.isEmpty) return [SensorKitPick(cheapest, nodes)];

  HoneycombItem? best(Set<String> remaining) {
    HoneycombItem? bestKit;
    var bestHit = 0;
    for (final k in declared) {
      final hit = paramsOf(k).where(remaining.contains).length;
      if (hit == 0) continue;
      if (hit > bestHit || (hit == bestHit && byPrice(k, bestKit!) < 0)) {
        bestKit = k;
        bestHit = hit;
      }
    }
    return bestKit;
  }

  final primary = best(want);
  if (primary == null)
    return [SensorKitPick(cheapest, nodes)]; // không bộ nào đo được: vẫn tính điểm đo, thiếu hụt báo riêng
  final remaining = {...want}..removeAll(paramsOf(primary));
  final extras = <HoneycombItem>[];
  while (remaining.isNotEmpty) {
    final k = best(remaining);
    if (k == null) break;
    extras.add(k);
    remaining.removeAll(paramsOf(k));
  }
  final total = math.max(nodes, extras.length + 1);
  return [SensorKitPick(primary, total - extras.length), for (final k in extras) SensorKitPick(k, 1)];
}

/// Thuật toán mạng Tổ ong (ô lục giác bán kính R): S = 3√3/2·R², khoảng cách node D = √3·R.
/// Có [installed]: chỉ tính phần BỔ SUNG = nhu cầu − thiết bị đã gắn (theo loại), cộng thêm node cảm biến đo được
/// các thông số mà thiết bị đã gắn chưa đo.
HoneycombEstimate computeHoneycombEstimate({
  required double areaM2,
  required double radiusM,
  required double actuatorRatio,
  required HoneycombCatalog catalog,
  List<String> requiredParameters = const [],
  ZoneInstalledDevices installed = ZoneInstalledDevices.none,
}) {
  final area = math.max(50.0, areaM2);
  final r = radiusM.clamp(6.0, 30.0).toDouble();
  final cell = 3 * math.sqrt(3) / 2 * r * r;
  final sensors = math.max(2, (area / cell * honeycombBoundaryFactor).ceil());
  final actuators = math.max(1, (sensors * actuatorRatio).ceil());
  final gateways = math.max(1, (area / honeycombGatewayCoverM2).ceil());

  final gwAdd = math.max(0, gateways - installed.gateways);
  final sensorsAdd = math.max(0, sensors - installed.sensorNodes);
  final actuatorsAdd = math.max(0, actuators - installed.actuatorNodes);
  final missing = [
    for (final p in {...requiredParameters})
      if (!installed.measured.contains(_norm(p))) p,
  ];
  final sensorRes = catalog.of(EstimateRole.sensorNode);
  final topUp = sensorsAdd == 0 && missing.isNotEmpty;
  final missingNorm = missing.map(_norm).toSet();
  // Đủ số node nhưng thiếu thông số: chỉ bổ sung khi kho có bộ đo được thông số còn thiếu (không thêm node vô ích).
  final canTopUp = sensorRes.items.any(
    (k) => (k.measuredParameters ?? const <String>[]).map(_norm).any(missingNorm.contains),
  );
  final sensorToAdd = sensorsAdd > 0 ? sensorsAdd : (topUp && canTopUp ? 1 : 0);
  // Thông số cần phủ bằng bộ mới: những thông số thiết bị đã gắn chưa đo; Zone chưa gắn gì thì toàn bộ nhu cầu.
  final plan = sensorToAdd > 0
      ? planSensorKits(sensorRes.items, missing.isNotEmpty ? missing : [...requiredParameters], sensorToAdd)
      : const <SensorKitPick>[];

  List<EstimateLine> mk(EstimateRole role, int toAdd, int needed, int have, {String? gapNote}) {
    final res = catalog.of(role);
    EstimateLine covered(String? note) =>
        EstimateLine(role, 0, 0, res, null, neededTotal: needed, installed: have, covered: true, note: note);
    if (toAdd <= 0) return [covered(gapNote)];
    if (res.items.isEmpty) {
      return [EstimateLine(role, toAdd, toAdd, res, null, neededTotal: needed, installed: have)];
    }
    return [
      for (final it in res.items)
        EstimateLine(role, toAdd, _ceilDiv(toAdd, it.unitsPerItem), res, it, neededTotal: needed, installed: have),
    ];
  }

  final List<EstimateLine> sensorLines;
  if (sensorToAdd <= 0) {
    sensorLines = mk(
      EstimateRole.sensorNode,
      0,
      sensors,
      installed.sensorNodes,
      gapNote: topUp ? 'Danh mục chưa có bộ node đo được: ${missing.join(', ')}' : null,
    );
  } else if (plan.isEmpty) {
    sensorLines = mk(EstimateRole.sensorNode, sensorToAdd, sensors, installed.sensorNodes);
  } else {
    sensorLines = [
      for (final p in plan)
        EstimateLine(
          EstimateRole.sensorNode,
          p.qty,
          _ceilDiv(p.qty, p.item.unitsPerItem),
          sensorRes,
          p.item,
          neededTotal: sensors,
          installed: installed.sensorNodes,
        ),
    ];
  }
  final addedSensorItems = [for (final p in plan) p.item];
  final sensorPoints = plan.fold<int>(0, (a, p) => a + p.qty);
  final points = sensorPoints + actuatorsAdd;
  final hasWork = gwAdd > 0 || sensorToAdd > 0 || actuatorsAdd > 0;

  return HoneycombEstimate(
    areaM2: area,
    radiusM: r,
    cellAreaM2: cell,
    interNodeDistanceM: math.sqrt(3) * r,
    gateways: gateways,
    sensors: sensors,
    actuators: actuators,
    accessoryPoints: points,
    lines: [
      ...mk(EstimateRole.gateway, gwAdd, gateways, installed.gateways),
      ...sensorLines,
      ...mk(EstimateRole.actuatorNode, actuatorsAdd, actuators, installed.actuatorNodes),
      ...mk(EstimateRole.installKit, points, sensors + actuators, 0),
    ],
    installationCost: hasWork ? honeycombInstallationFlatVnd : 0,
    capability: checkCapability(addedSensorItems, requiredParameters, installedMeasured: installed.measured),
    installed: installed,
  );
}

String formatVnd(double v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '$b đ';
}
