import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/models/iot_deployment.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/mini_gis_map_picker.dart';
import '../../core/widgets/state_views.dart';
import '../crops/widgets/create_season_sheet.dart';
import '../devices/deployment_request_send_screen.dart';
import '../devices/deployment_screens.dart';
import '../zones/honeycomb_estimate.dart';
import '../zones/widgets/zone_honeycomb_estimate_card.dart';
import 'farm_setup_logic.dart';

/// Wizard thiết lập trang trại (khớp CreateFarmWizard trên Web, chỉ FarmOwner):
/// 5 bước: Trang trại → Lô đất → Zone → Cây trồng & Vụ mùa (kèm yêu cầu IoT) → Xem lại & gửi.
/// Gửi một request POST /farms/wizard-setup. Backend tạo Farm → Field → Zone → Vụ trồng → Yêu cầu IoT trong một
/// giao dịch nhưng im lặng bỏ qua vụ trồng/yêu cầu IoT nếu hồ sơ sinh trưởng không có giai đoạn, nên app
/// kiểm tra điều kiện trước khi gửi và đối chiếu ID trả về sau khi gửi.
class FarmSetupWizardScreen extends StatefulWidget {
  const FarmSetupWizardScreen({super.key});

  @override
  State<FarmSetupWizardScreen> createState() => _FarmSetupWizardScreenState();
}

class _FarmSetupWizardScreenState extends State<FarmSetupWizardScreen> {
  static const _lastStep = 4;
  static const _stepTitles = [
    'Trang trại',
    'Lô đất',
    'Zone',
    'Cây trồng & Vụ mùa',
    'Xem lại & gửi',
  ];
  static const _vietnamCenter = LatLng(
    14.0583,
    108.2772,
  ); // chỉ để mở bản đồ toàn quốc, không phải vị trí trang trại

  int _step = 0;
  bool _busy = false;
  String? _submitError;
  WizardOutcome? _outcome;

  // Trang trại
  final _farmName = TextEditingController();
  final _address = TextEditingController();
  final _farmArea = TextEditingController();
  LatLng? _farmCenter; // null cho tới khi người dùng đặt ghim
  final _farmCenterLabel = ValueNotifier<String>('Chưa đặt ghim');

  // Lô đất
  final _fieldName = TextEditingController();
  final _fieldArea = TextEditingController();
  String _soil = 'Loam';
  bool _drawField = true;
  List<LatLng>? _fieldBoundary;

  // Zone
  final _zoneName = TextEditingController();
  final _zoneArea = TextEditingController();
  String _zoneType = 'Greenhouse';
  bool _drawZone = true;
  List<LatLng>? _zoneBoundary;

  // Vụ trồng
  bool _withSeason = true;
  bool _nameEdited = false;
  bool _endEdited = false;
  final _seasonName = TextEditingController();
  List<Map<String, dynamic>> _crops = [];
  List<Map<String, dynamic>> _varieties = [];
  List<Map<String, dynamic>> _profiles = [];
  String? _cropId, _varietyId, _profileId;
  bool _loadingProfiles = false;
  String? _cropsError;
  DateTime _start = DateTime.now();
  DateTime? _end;

  // IoT
  bool _withIot = true;
  // Thông số cần đo lấy từ hồ sơ sinh trưởng đã chọn (không hard-code); người dùng có thể chỉnh.
  final Set<String> _params = {};
  HoneycombEstimate? _estimate;

  // Chống tạo trùng: đã gửi thành công hoặc nhiều khả năng đã tạo xong (mất phản hồi) thì không cho gửi lại.
  bool _submitted = false;
  String? _possiblyCreatedFarmId;
  Future<Map<String, String?>>? _statusFuture;
  final _iotNotes = TextEditingController();

  static const _soils = {
    'Loam': 'Đất thịt',
    'Clay': 'Đất sét',
    'Sandy': 'Đất cát',
    'Silt': 'Đất phù sa',
  };
  static const _zoneTypes = {
    'Greenhouse': 'Nhà màng',
    'OpenField': 'Ngoài trời',
    'NetHouse': 'Nhà lưới',
  };
  static const _paramLabels = {
    'SoilMoisture': 'Độ ẩm đất',
    'Temperature': 'Nhiệt độ',
    'AirHumidity': 'Độ ẩm không khí',
    'LightIntensity': 'Ánh sáng',
    'Ph': 'pH',
    'Ec': 'EC',
  };

  @override
  void initState() {
    super.initState();
    _loadCrops();
  }

  @override
  void dispose() {
    for (final c in [
      _farmName,
      _address,
      _farmArea,
      _fieldName,
      _fieldArea,
      _zoneName,
      _zoneArea,
      _seasonName,
      _iotNotes,
    ]) {
      c.dispose();
    }
    _farmCenterLabel.dispose();
    super.dispose();
  }

  bool _loadingCrops = true;

  Future<void> _loadCrops() async {
    setState(() {
      _loadingCrops = true;
      _cropsError = null;
    });
    try {
      final c = await CropApi.getCropsForProfiles();
      if (mounted) setState(() => _crops = c);
    } catch (e) {
      if (mounted) setState(() => _cropsError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loadingCrops = false);
    }
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  int? get _selectedProfileStages {
    final p = _profiles
        .where((p) => '${p['profileId']}' == _profileId)
        .firstOrNull;
    if (p == null) return null;
    final st = p['stages'];
    return st is List ? st.length : 0;
  }

  /// Hồ sơ dùng được: có giai đoạn và khớp ĐÚNG giống đã chọn (hồ sơ chung chỉ khi không chọn giống).
  List<Map<String, dynamic>> get _usableProfiles => [
    for (final p in _profiles)
      if ((p['stages'] is List) &&
          (p['stages'] as List).isNotEmpty &&
          p['varietyId']?.toString() == _varietyId)
        p,
  ];

  void _pickDefaultProfile() {
    final usable = _usableProfiles;
    final def =
        usable.where((p) => p['isDefault'] == true).firstOrNull ??
        usable.firstOrNull;
    _profileId = def == null ? null : '${def['profileId']}';
  }

  Map<String, dynamic>? get _selectedProfile =>
      _profiles.where((p) => '${p['profileId']}' == _profileId).firstOrNull;

  String get _cropName =>
      _crops
          .where((c) => '${c['cropId'] ?? c['id']}' == _cropId)
          .map((c) => '${c['name']}')
          .firstOrNull ??
      '';

  String get _varietyName =>
      _varieties
          .where((v) => '${v['varietyId']}' == _varietyId)
          .map((v) => '${v['name']}')
          .firstOrNull ??
      '';

  /// Đồng bộ ngày thu hoạch, thông số cần đo và tên vụ theo hồ sơ/cây/ngày bắt đầu hiện tại.
  void _onSeasonInputsChanged() {
    final p = _selectedProfile;
    final days = profileTotalDays(p);
    if (!_endEdited)
      _end = days == null ? null : expectedEndFromProfile(_start, days);
    _params
      ..clear()
      ..addAll(profileRequiredParameters(p));
    if (!_nameEdited && _cropId != null)
      _seasonName.text = suggestedSeasonName(_cropName, _start);
  }

  Future<void> _selectCrop(String? id) async {
    setState(() {
      _cropId = id;
      _varietyId = null;
      _profileId = null;
      _varieties = [];
      _profiles = [];
      _endEdited = false;
      _end = null;
      _params.clear();
      _loadingProfiles = id != null;
    });
    if (id == null) return;
    try {
      final r = await Future.wait([
        CropApi.getVarieties(cropId: id),
        CropApi.getCropGrowthProfiles(id),
      ]);
      if (!mounted || _cropId != id) return;
      setState(() {
        _varieties = r[0];
        _profiles = r[1];
        _pickDefaultProfile();
        _onSeasonInputsChanged();
        _loadingProfiles = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingProfiles = false);
        showAppSnack(context, friendlyError(e), error: true);
      }
    }
  }

  /// Kiểm tra bước [step]; trả về thông báo lỗi hoặc null.
  String? _validate(int step) {
    switch (step) {
      case 0:
        return validateFarmStep(
          name: _farmName.text,
          lat: _farmCenter?.latitude,
          lng: _farmCenter?.longitude,
          totalAreaM2: _num(_farmArea),
        );
      case 1:
        return validateFieldStep(
          name: _fieldName.text,
          areaM2: _num(_fieldArea),
          farmAreaM2: _num(_farmArea),
          boundary: _drawField ? _fieldBoundary : null,
        );
      case 2:
        return validateZoneStep(
          name: _zoneName.text,
          areaM2: _num(_zoneArea),
          fieldAreaM2: _num(_fieldArea),
          boundary: _drawZone ? _zoneBoundary : null,
          fieldBoundary: _drawField ? _fieldBoundary : null,
        );
      case 3:
        return validateSeasonStep(
              enabled: _withSeason,
              name: _seasonName.text,
              cropId: _cropId,
              profileId: _profileId,
              profileStageCount: _selectedProfileStages,
              start: _start,
              expectedEnd: _end,
            ) ??
            validateIotStep(
              seasonEnabled: _withSeason,
              iotEnabled: _withIot,
              parameters: _params,
            );
    }
    return null;
  }

  Future<void> _submit() async {
    if (_busy || _submitted)
      return; // chống bấm nhiều lần / gửi lại sau khi đã tạo
    final provider = context.read<FarmProvider>();
    if (!provider.canManageFarmStructure) {
      showAppSnack(
        context,
        'Chỉ chủ trang trại mới được tạo trang trại.',
        error: true,
      );
      return;
    }
    for (var s = 0; s <= 3; s++) {
      final err = _validate(s);
      if (err != null) {
        setState(() {
          _step = s;
          _submitError = null;
        });
        showAppSnack(context, err, error: true);
        return;
      }
    }
    setState(() {
      _busy = true;
      _submitError = null;
    });
    final farmIdsBefore = {for (final f in provider.farms) f.farmId};
    final est = _estimate;
    final estimateDraft = _withIot
        ? buildWizardEstimateItems(est)
        : const WizardEstimateDraft([], null);
    final payload = {
      'farm': {
        'name': _farmName.text.trim(),
        'locationText': _address.text.trim().isEmpty
            ? null
            : _address.text.trim(),
        'latitude': _farmCenter!.latitude,
        'longitude': _farmCenter!.longitude,
        'totalAreaM2': _num(_farmArea),
        'timeZone': 'Asia/Ho_Chi_Minh',
      },
      'field': {
        'name': _fieldName.text.trim(),
        'areaM2': _num(_fieldArea),
        'soilType': _soil,
        'boundaryGeoJson': _drawField
            ? boundaryGeoJsonString(_fieldBoundary)
            : null,
      },
      'zone': {
        'name': _zoneName.text.trim(),
        'areaM2': _num(_zoneArea),
        'zoneType': _zoneType,
        'boundaryGeoJson': _drawZone
            ? boundaryGeoJsonString(_zoneBoundary)
            : null,
      },
      'season': _withSeason
          ? {
              'name': _seasonName.text.trim(),
              'cropId': _cropId,
              'varietyId': _varietyId,
              'growthProfileId': _profileId,
              'startDate': DateTime.utc(
                _start.year,
                _start.month,
                _start.day,
              ).toIso8601String(),
              // Luôn gửi ngày tính từ hồ sơ/người dùng chỉnh: nếu bỏ trống, backend tự cộng 90 ngày.
              'expectedEndDate': DateTime.utc(
                _end!.year,
                _end!.month,
                _end!.day,
              ).toIso8601String(),
            }
          : null,
      'initialDeploymentRequest': _withSeason && _withIot
          ? {
              'requiredParameters': _params.toList(),
              if (estimateDraft.hasItems) 'estimateItems': estimateDraft.items,
              'ownerNotes': () {
                final n = buildWizardIotNotes(
                  userNotes: _iotNotes.text,
                  gateways: est?.gateways,
                  sensors: est?.sensors,
                  actuators: est?.actuators,
                  totalVnd: est?.total,
                );
                return n.isEmpty ? null : n;
              }(),
            }
          : null,
    };
    try {
      final res = await FarmApi.farmWizardSetup(payload);
      final outcome = analyzeWizardResult(
        result: res,
        requestedField: true,
        requestedZone: true,
        requestedSeason: _withSeason,
        requestedIot: _withSeason && _withIot,
      );
      // Tải lại từ máy chủ rồi chuyển sang trang trại vừa tạo.
      await provider.fetchFromApi();
      final newFarmId = outcome.idOf('farmId');
      if (newFarmId != null && provider.farms.any((f) => f.farmId == newFarmId))
        provider.selectFarm(newFarmId);
      if (mounted) {
        setState(() {
          _submitted = true;
          _outcome = outcome;
          _statusFuture = _loadCreatedStatuses(outcome);
        });
      }
    } catch (e) {
      // Nội dung người dùng đã nhập được giữ nguyên (không reset form).
      final kind = classifyWizardFailure(e);
      if (kind == WizardFailureKind.ambiguousNetwork) {
        // Có thể máy chủ đã tạo xong nhưng phản hồi bị mất: tải lại rồi so với danh sách trước khi gửi.
        try {
          await provider.fetchFromApi();
        } catch (_) {}
        final name = _farmName.text.trim().toLowerCase();
        final created = provider.farms
            .where(
              (f) =>
                  !farmIdsBefore.contains(f.farmId) &&
                  f.name.trim().toLowerCase() == name,
            )
            .firstOrNull;
        if (mounted) {
          setState(() {
            if (created != null) {
              _submitted = true; // không cho gửi lại để tránh tạo trùng
              _possiblyCreatedFarmId = created.farmId;
              _submitError =
                  'Mất kết nối khi nhận phản hồi, nhưng trang trại "${created.name}" ĐÃ có trong danh sách của bạn. '
                  'Không gửi lại để tránh tạo trùng — hãy mở trang trại để kiểm tra các mục bên trong.';
            } else {
              _submitError =
                  'Mất kết nối hoặc quá thời gian chờ nên chưa rõ máy chủ đã xử lý chưa. Chưa thấy trang trại mới trong danh sách; '
                  'dữ liệu bạn nhập vẫn được giữ, hãy kiểm tra mạng rồi bấm gửi lại.';
            }
          });
          showAppSnack(
            context,
            'Mất kết nối khi gửi. Xem hướng dẫn ở bước cuối.',
            error: true,
          );
        }
      } else if (mounted) {
        // Máy chủ đã phản hồi từ chối (dữ liệu sai, không có quyền, xung đột...) nên CHƯA tạo gì: sửa rồi gửi lại được.
        setState(() => _submitError = friendlyError(e));
        showAppSnack(context, friendlyError(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ───────────────────────── UI helpers ─────────────────────────
  Widget _field(
    TextEditingController c,
    String label, {
    bool number = false,
    int? maxLength,
    bool readOnly = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
      maxLength: maxLength,
      readOnly: readOnly,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Widget _dropdown(
    String label,
    String? value,
    Map<String, String> items,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final e in items.entries)
        DropdownMenuItem(value: e.key, child: Text(e.value)),
    ],
    onChanged: onChanged,
  );

  String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<DateTime?> _pick(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );

  Widget _hint(String text, {Color color = AppColors.textMuted}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, color: color, height: 1.4),
    ),
  );

  Widget _boundaryState(List<LatLng>? pts) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      pts == null || pts.length < 3
          ? 'Chưa có ranh giới GIS — đối tượng sẽ được tạo mà không có ranh giới.'
          : 'Ranh giới GIS: ${pts.length} đỉnh. Kéo các đỉnh trên bản đồ để chỉnh.',
      style: TextStyle(
        fontSize: 12,
        color: pts == null || pts.length < 3
            ? AppColors.warning
            : AppColors.primaryDark,
      ),
    ),
  );

  // ───────────────────────── Các bước ─────────────────────────
  Step _farmStep() => Step(
    title: const Text('Trang trại'),
    isActive: _step >= 0,
    state: _step > 0 ? StepState.complete : StepState.indexed,
    content: _step != 0
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(_farmName, 'Tên trang trại', maxLength: 200),
              _hint(
                'Di chuyển bản đồ để đặt ghim tại vị trí trang trại (hoặc bấm 🔍 để tìm địa chỉ).',
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MiniGISMapPicker(
                  initialCenter: _farmCenter ?? _vietnamCenter,
                  initialZoom: _farmCenter == null ? 6 : 16.5,
                  level: 'FARM',
                  height: 260,
                  onCenterChanged: (c) {
                    _farmCenter = c;
                    _farmCenterLabel.value =
                        '${c.latitude.toStringAsFixed(6)}, ${c.longitude.toStringAsFixed(6)}';
                  },
                  onAddressResolved: (a) {
                    if (_address.text.trim().isEmpty && !a.startsWith('Đang'))
                      _address.text = a;
                  },
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<String>(
                valueListenable: _farmCenterLabel,
                builder: (_, v, _) => Text(
                  'Toạ độ: $v',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _field(_address, 'Địa chỉ (không bắt buộc)'),
            ],
          ),
  );

  Step _fieldStep() => Step(
    title: const Text('Lô đất'),
    isActive: _step >= 1,
    state: _step > 1 ? StepState.complete : StepState.indexed,
    content: _step != 1 || _farmCenter == null
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(_fieldName, 'Tên lô đất'),
              _dropdown(
                'Loại đất',
                _soil,
                _soils,
                (v) => setState(() => _soil = v ?? _soil),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Vẽ ranh giới lô đất trên bản đồ',
                  style: TextStyle(fontSize: 13),
                ),
                value: _drawField,
                onChanged: (v) => setState(() {
                  _drawField = v;
                  if (!v) _drawZone = false;
                }),
              ),
              if (_drawField)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MiniGISMapPicker(
                    key: const ValueKey('wizard-field-map'),
                    initialCenter: _farmCenter!,
                    initialPolygon: _fieldBoundary,
                    level: 'FIELD',
                    height: 280,
                    emitInitialPolygon: true,
                    onPolygonChanged: (pts) =>
                        setState(() => _fieldBoundary = pts),
                    onAreaCalculated: (a) {
                      if (a > 0 && _fieldArea.text != a.toStringAsFixed(0))
                        _fieldArea.text = a.toStringAsFixed(0);
                    },
                  ),
                ),
              _boundaryState(_drawField ? _fieldBoundary : null),
              const SizedBox(height: 10),
              _field(_fieldArea, 'Diện tích lô đất (m²)', number: true),
            ],
          ),
  );

  Step _zoneStep() => Step(
    title: const Text('Zone canh tác'),
    isActive: _step >= 2,
    state: _step > 2 ? StepState.complete : StepState.indexed,
    content: _step != 2 || _farmCenter == null
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(_zoneName, 'Tên Zone'),
              _dropdown(
                'Loại Zone',
                _zoneType,
                _zoneTypes,
                (v) => setState(() => _zoneType = v ?? _zoneType),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Vẽ ranh giới Zone trên bản đồ',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: !_drawField
                    ? const Text(
                        'Cần vẽ ranh giới lô đất trước.',
                        style: TextStyle(fontSize: 11),
                      )
                    : null,
                value: _drawZone && _drawField,
                onChanged: _drawField
                    ? (v) => setState(() => _drawZone = v)
                    : null,
              ),
              if (_drawZone && _drawField)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MiniGISMapPicker(
                    key: const ValueKey('wizard-zone-map'),
                    initialCenter: _farmCenter!,
                    initialPolygon: _zoneBoundary,
                    parentPolygon: _fieldBoundary,
                    level: 'ZONE',
                    height: 280,
                    emitInitialPolygon: true,
                    onPolygonChanged: (pts) =>
                        setState(() => _zoneBoundary = pts),
                    onAreaCalculated: (a) {
                      if (a > 0 && _zoneArea.text != a.toStringAsFixed(0))
                        _zoneArea.text = a.toStringAsFixed(0);
                    },
                  ),
                ),
              _boundaryState(_drawZone && _drawField ? _zoneBoundary : null),
              const SizedBox(height: 10),
              _field(_zoneArea, 'Diện tích Zone (m²)', number: true),
            ],
          ),
  );

  // ───────────────────────── Bước 4: Cây trồng & Vụ mùa (kèm yêu cầu IoT) ─────────────────────────
  Widget _infoCard(String title, List<Widget> rows) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        ...rows,
      ],
    ),
  );

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            k,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 8),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryDark,
      ),
    ),
  );

  Widget _profileCard() {
    final p = _selectedProfile;
    if (p == null) return const SizedBox.shrink();
    final stages = profileStages(p);
    final days = profileTotalDays(p);
    final params = profileRequiredParameters(p);
    return _infoCard('HỒ SƠ SINH TRƯỞNG (dữ liệu từ máy chủ)', [
      _kv('Hồ sơ', '${p['name']}'),
      _kv(
        'Nguồn',
        p['isSystemDefined'] == true ? 'Hồ sơ hệ thống' : 'Của trang trại',
      ),
      _kv(
        'Tổng thời gian',
        days == null
            ? 'Hồ sơ không khai báo số ngày'
            : '$days ngày · ${stages.length} giai đoạn',
      ),
      _kv(
        'Thông số cần đo',
        params.isEmpty
            ? 'Hồ sơ không khai báo'
            : params.map((e) => _paramLabels[e] ?? e).join(', '),
      ),
      const SizedBox(height: 6),
      for (var i = 0; i < stages.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            '${i + 1}. ${stages[i]['name']} · ${stages[i]['durationDays'] ?? '?'} ngày',
            style: const TextStyle(fontSize: 12),
          ),
        ),
    ]);
  }

  Step _seasonStep() {
    final usableProfiles = _usableProfiles;
    final zoneArea = _num(_zoneArea);
    return Step(
      title: const Text('Cây trồng & Vụ mùa'),
      isActive: _step >= 3,
      state: _step > 3 ? StepState.complete : StepState.indexed,
      content: _step != 3
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoCard('ĐỐI TƯỢNG SẼ ĐƯỢC TẠO', [
                  _kv('Trang trại', _farmName.text.trim()),
                  _kv(
                    'Lô đất',
                    '${_fieldName.text.trim()} · ${_fieldArea.text} m²',
                  ),
                  _kv(
                    'Zone',
                    '${_zoneName.text.trim()} · ${_zoneArea.text} m² · ${_zoneTypes[_zoneType] ?? _zoneType}',
                  ),
                ]),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Tạo vụ trồng đầu tiên cho Zone',
                    style: TextStyle(fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Vụ được tạo ở trạng thái Kế hoạch (Planned) cho đúng Zone này.',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: _withSeason,
                  onChanged: (v) => setState(() {
                    _withSeason = v;
                    if (!v) _withIot = false;
                  }),
                ),
                if (_withSeason) ...[
                  _sectionTitle('Cây trồng & hồ sơ'),
                  if (_loadingCrops)
                    const LinearProgressIndicator(minHeight: 2),
                  if (_cropsError != null)
                    Row(
                      children: [
                        Expanded(
                          child: _hint(
                            'Không tải được danh sách cây: $_cropsError',
                            color: AppColors.danger,
                          ),
                        ),
                        TextButton(
                          onPressed: _loadCrops,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    )
                  else if (!_loadingCrops && _crops.isEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: _hint(
                            'Hệ thống chưa có cây trồng nào trong danh mục nên chưa thể tạo vụ. '
                            'Hãy tắt phần vụ trồng và tạo sau, hoặc liên hệ quản trị.',
                            color: AppColors.warning,
                          ),
                        ),
                        TextButton(
                          onPressed: _loadCrops,
                          child: const Text('Tải lại'),
                        ),
                      ],
                    ),
                  DropdownButtonFormField<String>(
                    initialValue: _cropId,
                    isExpanded: true,
                    hint: const Text('Chọn cây trồng'),
                    decoration: const InputDecoration(labelText: 'Cây trồng *'),
                    items: [
                      for (final c in _crops)
                        DropdownMenuItem(
                          value: '${c['cropId'] ?? c['id']}',
                          child: Text(
                            '${c['name']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _crops.isEmpty ? null : _selectCrop,
                  ),
                  const SizedBox(height: 10),
                  if (_loadingProfiles)
                    const LinearProgressIndicator(minHeight: 2),
                  if (_cropId != null &&
                      !_loadingProfiles &&
                      _varieties.isEmpty)
                    _hint(
                      'Cây này chưa có giống trong danh mục: tiếp tục không chọn giống.',
                    ),
                  DropdownButtonFormField<String?>(
                    key: ValueKey('v-$_cropId-${_varieties.length}'),
                    initialValue: _varietyId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Giống (thuộc cây đã chọn)',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('— Không chọn giống —'),
                      ),
                      for (final v in _varieties)
                        DropdownMenuItem<String?>(
                          value: '${v['varietyId']}',
                          child: Text(
                            '${v['name']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _cropId == null
                        ? null
                        : (v) => setState(() {
                            _varietyId = v;
                            _endEdited = false;
                            _pickDefaultProfile(); // hồ sơ cũ có thể không còn khớp giống mới
                            _onSeasonInputsChanged();
                          }),
                  ),
                  const SizedBox(height: 10),
                  if (_cropId != null &&
                      !_loadingProfiles &&
                      usableProfiles.isEmpty)
                    _hint(
                      _varietyId == null
                          ? 'Cây này chưa có hồ sơ sinh trưởng chung nào có giai đoạn. Hãy chọn một giống có hồ sơ, '
                                'chọn cây khác, hoặc tắt phần vụ trồng và tạo vụ sau.'
                          : 'Giống đã chọn chưa có hồ sơ sinh trưởng nào có giai đoạn. Hãy chọn giống khác hoặc bỏ chọn giống.',
                      color: AppColors.danger,
                    ),
                  DropdownButtonFormField<String?>(
                    key: ValueKey(
                      'p-$_cropId-$_varietyId-${usableProfiles.length}',
                    ),
                    initialValue: _profileId,
                    isExpanded: true,
                    hint: const Text('Chưa có hồ sơ phù hợp'),
                    decoration: const InputDecoration(
                      labelText: 'Hồ sơ sinh trưởng *',
                    ),
                    items: [
                      for (final p in usableProfiles)
                        DropdownMenuItem<String?>(
                          value: '${p['profileId']}',
                          child: Text(
                            '${p['name']} · ${(p['stages'] as List).length} giai đoạn',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: usableProfiles.isEmpty
                        ? null
                        : (v) => setState(() {
                            _profileId = v;
                            _endEdited = false;
                            _onSeasonInputsChanged();
                          }),
                  ),
                  const SizedBox(height: 12),
                  _profileCard(),
                  _sectionTitle('Vụ mùa'),
                  TextField(
                    controller: _seasonName,
                    maxLength: 200,
                    onChanged: (_) => _nameEdited = true,
                    decoration: const InputDecoration(
                      labelText: 'Tên vụ mùa *',
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event, size: 18),
                      onPressed: () async {
                        final d = await _pick(_start);
                        if (d != null) {
                          setState(() {
                            _start = d;
                            _onSeasonInputsChanged();
                          });
                        }
                      },
                      label: Text('Ngày bắt đầu xuống giống: ${_d(_start)}'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_available, size: 18),
                      onPressed: () async {
                        final d = await _pick(
                          _end ?? _start.add(const Duration(days: 90)),
                        );
                        if (d != null) {
                          setState(() {
                            _end = d;
                            _endEdited = true;
                          });
                        }
                      },
                      label: Text(
                        _end == null
                            ? 'Chọn ngày thu hoạch dự kiến'
                            : 'Dự kiến thu hoạch: ${_d(_end!)}',
                      ),
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final days = profileTotalDays(_selectedProfile);
                      if (days == null) {
                        return _hint(
                          'Hồ sơ không khai báo số ngày các giai đoạn nên không tự tính được ngày thu hoạch: hãy chọn thủ công.',
                        );
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: _hint(
                              _endEdited
                                  ? 'Bạn đã chỉnh ngày thu hoạch (hồ sơ gợi ý $days ngày kể từ ngày bắt đầu).'
                                  : 'Tự tính: ngày bắt đầu + $days ngày (tổng các giai đoạn của hồ sơ).',
                            ),
                          ),
                          if (_endEdited)
                            TextButton(
                              onPressed: () => setState(() {
                                _endEdited = false;
                                _onSeasonInputsChanged();
                              }),
                              child: const Text('Tính lại'),
                            ),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 24),
                  _sectionTitle('Yêu cầu lắp đặt thiết bị IoT'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Gửi yêu cầu khảo sát & lắp đặt cho kỹ thuật viên',
                      style: TextStyle(fontSize: 13),
                    ),
                    value: _withIot,
                    onChanged: (v) => setState(() => _withIot = v),
                  ),
                  if (_withIot) ...[
                    const Text(
                      'Thông số cần đo (theo hồ sơ đã chọn)',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    if (_params.isEmpty && _selectedProfile != null)
                      _hint(
                        'Hồ sơ không khai báo thông số môi trường. Hãy chọn thủ công những thông số cần đo.',
                        color: AppColors.warning,
                      ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final e in _paramLabels.entries)
                          FilterChip(
                            label: Text(
                              e.value,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: _params.contains(e.key),
                            onSelected: (v) => setState(
                              () => v
                                  ? _params.add(e.key)
                                  : _params.remove(e.key),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _field(
                      _iotNotes,
                      'Ghi chú cho kỹ thuật viên',
                      maxLength: 800,
                    ),
                    const SizedBox(height: 4),
                    if (zoneArea != null && zoneArea > 0 && _cropId != null)
                      ZoneHoneycombEstimateCard(
                        measurementParameters: _params.toList(),
                        measurementSource:
                            'Theo profile đã chọn và nhu cầu sẽ gửi kỹ thuật viên',
                        areaM2: zoneArea,
                        cropName: _cropName,
                        // Chu vi thật của ranh giới Zone vừa vẽ (nếu có) để tính số node chính xác hơn.
                        perimeterM: _drawZone && _zoneBoundary != null
                            ? convexHullPerimeterM([
                                for (final p in _zoneBoundary!)
                                  (lat: p.latitude, lng: p.longitude),
                              ])
                            : null,
                        onEstimate: (e) {
                          if (mounted) setState(() => _estimate = e);
                        },
                      )
                    else
                      _hint(
                        'Chọn cây trồng và nhập diện tích Zone để xem danh sách thiết bị dự kiến và dự toán.',
                      ),
                    _hint(
                      'Danh sách thiết bị và dự toán ở trên sẽ được LƯU kèm yêu cầu (mã, tên, số lượng, đơn giá tại thời '
                      'điểm gửi). Đây chưa phải báo giá hay hợp đồng: kỹ thuật viên khảo sát, chỉnh sửa danh sách rồi lập '
                      'báo giá/hợp đồng để bạn xem và xác nhận.',
                      color: AppColors.textMuted,
                    ),
                  ],
                ],
              ],
            ),
    );
  }

  Step _reviewStep() {
    Widget line(IconData icon, String text, {Color? color}) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color ?? AppColors.primaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
          ),
        ],
      ),
    );
    final fieldPts = _drawField ? _fieldBoundary : null;
    final zonePts = _drawZone && _drawField ? _zoneBoundary : null;
    final profile = _selectedProfile;
    final days = profileTotalDays(profile);
    final est = _estimate;
    return Step(
      title: const Text('Xem lại & gửi'),
      isActive: _step >= 4,
      content: _step != 4
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                line(
                  Icons.agriculture,
                  'Trang trại "${_farmName.text.trim()}"\n'
                  '${_address.text.trim().isEmpty ? 'Chưa nhập địa chỉ' : _address.text.trim()}'
                  '${_num(_farmArea) == null ? '' : ' · ${_farmArea.text.trim()} m²'}'
                  '${_farmCenter == null ? '' : '\nToạ độ: ${_farmCenter!.latitude.toStringAsFixed(5)}, ${_farmCenter!.longitude.toStringAsFixed(5)}'}',
                ),
                line(
                  Icons.layers_outlined,
                  'Lô đất "${_fieldName.text.trim()}" · ${_soils[_soil] ?? _soil} · ${_fieldArea.text} m² · '
                  '${fieldPts != null && fieldPts.length >= 3 ? 'có ranh giới GIS' : 'chưa có ranh giới GIS'}',
                  color: fieldPts != null && fieldPts.length >= 3
                      ? null
                      : AppColors.warning,
                ),
                line(
                  Icons.home_work_outlined,
                  'Zone "${_zoneName.text.trim()}" · ${_zoneTypes[_zoneType] ?? _zoneType} · ${_zoneArea.text} m² · '
                  '${zonePts != null && zonePts.length >= 3 ? 'có ranh giới GIS' : 'chưa có ranh giới GIS'}\n'
                  'Thuộc lô đất "${_fieldName.text.trim()}" của trang trại "${_farmName.text.trim()}"',
                  color: zonePts != null && zonePts.length >= 3
                      ? null
                      : AppColors.warning,
                ),
                if (_withSeason) ...[
                  line(
                    Icons.eco_outlined,
                    'Vụ mùa "${_seasonName.text.trim()}" (trạng thái Kế hoạch)\n'
                    'Cây: $_cropName${_varietyId == null ? '' : ' · Giống: $_varietyName'}\n'
                    'Hồ sơ: ${profile?['name'] ?? '—'}${days == null ? '' : ' ($days ngày)'}\n'
                    '${_d(_start)} → ${_end == null ? '—' : _d(_end!)}',
                  ),
                ] else
                  line(
                    Icons.eco_outlined,
                    'Không tạo vụ trồng (có thể tạo sau)',
                    color: AppColors.textMuted,
                  ),
                if (_withSeason && _withIot) ...[
                  line(
                    Icons.settings_input_antenna,
                    'Yêu cầu IoT gửi kỹ thuật viên · đo: ${_params.map((p) => _paramLabels[p] ?? p).join(', ')}',
                  ),
                  if (est != null)
                    line(
                      Icons.calculate_outlined,
                      buildWizardEstimateItems(est).hasItems
                          ? 'Dự toán sẽ được lưu kèm yêu cầu: ${buildWizardEstimateItems(est).items.length} hạng mục'
                                '${est.total == null ? '' : ' · ~${formatVnd(est.total!)}'}'
                          : 'Dự toán KHÔNG được lưu: ${buildWizardEstimateItems(est).skippedReason ?? 'Zone không cần bổ sung thiết bị.'}',
                      color: buildWizardEstimateItems(est).hasItems
                          ? null
                          : AppColors.warning,
                    )
                  else
                    line(
                      Icons.calculate_outlined,
                      'Chưa có dự toán (không tải được đơn giá thiết bị hoặc chưa đủ dữ liệu).',
                      color: AppColors.textMuted,
                    ),
                ] else
                  line(
                    Icons.settings_input_antenna,
                    'Không gửi yêu cầu IoT (có thể gửi sau)',
                    color: AppColors.textMuted,
                  ),
                if (_submitError != null)
                  _hint(_submitError!, color: AppColors.danger),
              ],
            ),
    );
  }

  // ───────────────────────── Build ─────────────────────────
  Widget _progress() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i <= _lastStep; i++)
              Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i == _lastStep ? 0 : 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: i <= _step
                        ? AppColors.primaryDark
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Bước ${_step + 1} / ${_lastStep + 1} · ${_stepTitles[_step]}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FarmProvider>();
    if (!provider.canManageFarmStructure) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Thiết lập trang trại',
            style: TextStyle(fontSize: 15),
          ),
        ),
        body: const AppEmptyState(
          icon: Icons.lock_outline,
          message:
              'Chỉ chủ trang trại (FarmOwner) mới được tạo trang trại, lô đất và Zone.',
        ),
      );
    }
    if (_outcome != null) return _resultView(provider);

    final steps = [
      _farmStep(),
      _fieldStep(),
      _zoneStep(),
      _seasonStep(),
      _reviewStep(),
    ];
    final isLast = _step == _lastStep;
    void next() {
      final err = _validate(_step);
      if (err != null) {
        showAppSnack(context, err, error: true);
        return;
      }
      if (_step < _lastStep) {
        setState(() {
          _step++;
          _submitError = null;
        });
      } else {
        _submit();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thiết lập trang trại',
          style: TextStyle(fontSize: 15),
        ),
      ),
      body: Column(
        children: [
          _progress(),
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey('wizard-step-$_step'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: steps[_step].content,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              if (_step > 0) ...[
                OutlinedButton(
                  onPressed: _busy ? null : () => setState(() => _step--),
                  child: const Text('Quay lại'),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: _busy || (isLast && _submitted)
                      ? null
                      : (isLast && _possiblyCreatedFarmId != null
                            ? null
                            : next),
                  child: _busy && isLast
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isLast ? 'Gửi yêu cầu cấu hình' : 'Tiếp tục'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Kết quả ─────────────────────────
  /// Đọc lại trạng thái THẬT của vụ mùa và yêu cầu triển khai vừa tạo (không suy đoán).
  Future<Map<String, String?>> _loadCreatedStatuses(WizardOutcome o) async {
    String? season, request;
    final seasonId = o.idOf('seasonId');
    final zoneId = o.idOf('zoneId');
    final reqId = o.idOf('deploymentRequestId');
    if (seasonId != null && zoneId != null) {
      try {
        final list = await CropApi.getPlantingSeasons(zoneId: zoneId);
        season = list
            .where((x) => '${x['seasonId']}' == seasonId)
            .firstOrNull?['status']
            ?.toString();
      } catch (_) {}
    }
    if (reqId != null) {
      try {
        request = (await DeploymentApi.getDeploymentRequest(
          reqId,
          technician: false,
        )).status;
      } catch (_) {}
    }
    return {'season': season, 'request': request};
  }

  static const _seasonStatusLabels = {
    'Planned': 'Kế hoạch (Planned)',
    'InProgress': 'Đang canh tác',
    'Completed': 'Đã kết thúc',
    'Cancelled': 'Đã hủy',
  };

  Widget _resultView(FarmProvider provider) {
    final outcome = _outcome!;
    final zoneId = outcome.idOf('zoneId');
    final missing = outcome.missing;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          outcome.isComplete ? 'Hoàn tất thiết lập' : 'Đã tạo một phần',
          style: const TextStyle(fontSize: 15),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Icon(
            outcome.isComplete
                ? Icons.check_circle
                : Icons.warning_amber_rounded,
            size: 56,
            color: outcome.isComplete
                ? AppColors.primaryDark
                : AppColors.warning,
          ),
          const SizedBox(height: 8),
          Text(
            outcome.isComplete
                ? 'Đã tạo "${_farmName.text.trim()}" theo đúng những gì bạn yêu cầu.'
                : 'Một số mục bạn yêu cầu CHƯA được tạo. Các mục khác đã lưu trên máy chủ.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          for (final item in outcome.items)
            ListTile(
              dense: true,
              isThreeLine: item.id != null,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                switch (item.state) {
                  WizardItemState.created => Icons.check_circle,
                  WizardItemState.notRequested => Icons.remove_circle_outline,
                  WizardItemState.notCreated => Icons.error_outline,
                },
                color: switch (item.state) {
                  WizardItemState.created => AppColors.primaryDark,
                  WizardItemState.notRequested => AppColors.textFaint,
                  WizardItemState.notCreated => AppColors.danger,
                },
              ),
              title: Text(item.label),
              subtitle: item.state == WizardItemState.created
                  ? FutureBuilder<Map<String, String?>>(
                      future: _statusFuture,
                      builder: (context, snap) {
                        final st = snap.data;
                        String? status;
                        if (item.key == 'seasonId') {
                          final raw = st?['season'];
                          status = raw == null
                              ? null
                              : (_seasonStatusLabels[raw] ?? raw);
                        } else if (item.key == 'deploymentRequestId') {
                          final raw = st?['request'];
                          status = raw == null
                              ? null
                              : (deploymentStatusLabels[raw] ?? raw);
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              status == null
                                  ? 'Đã tạo'
                                  : 'Đã tạo · Trạng thái: $status',
                            ),
                            SelectableText(
                              'ID: ${item.id}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  : Text(switch (item.state) {
                      WizardItemState.notRequested => 'Không yêu cầu',
                      _ => item.problem ?? 'Chưa tạo được',
                    }),
            ),
          const SizedBox(height: 12),
          if (zoneId != null && missing.any((m) => m.key == 'seasonId'))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton.icon(
                icon: const Icon(Icons.eco_outlined),
                label: const Text('Tạo vụ trồng cho Zone'),
                onPressed: () async {
                  final zone = provider.allZones
                      .where((z) => z.zoneId == zoneId)
                      .firstOrNull;
                  if (zone == null) {
                    showAppSnack(
                      context,
                      'Không tìm thấy Zone vừa tạo. Hãy kéo để làm mới danh sách rồi thử lại.',
                      error: true,
                    );
                    return;
                  }
                  await showCreateSeasonSheet(context, zone);
                },
              ),
            ),
          if (zoneId != null &&
              missing.any(
                (m) => m.key == 'deploymentRequestId' || m.key == 'seasonId',
              ))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.settings_input_antenna),
                label: const Text('Gửi yêu cầu triển khai IoT'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeploymentRequestSendScreen(zoneId: zoneId),
                  ),
                ),
              ),
            ),
          if (outcome.idOf('deploymentRequestId') != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton.icon(
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Mở yêu cầu kỹ thuật vừa tạo'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeploymentRequestDetailScreen(
                      requestId: outcome.idOf('deploymentRequestId')!,
                      technician: false,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.list_alt),
              label: const Text('Danh sách yêu cầu kỹ thuật'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OwnerDeploymentRequestsScreen(),
                ),
              ),
            ),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xong'),
          ),
        ],
      ),
    );
  }
}
