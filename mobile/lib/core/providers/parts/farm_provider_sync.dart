part of '../farm_provider.dart';

extension FarmProviderSync on FarmProvider {
  /// Dữ liệu mẫu không bao giờ được hiển thị như dữ liệu thật của trang trại.
  void _clearSeedData() {
    _farmWeather = null;
    _tenant = null;
    _farms.clear();
    _fields.clear();
    _zones.clear();
    _farmers.clear();
    _actuators.clear();
    _alerts.clear();
    _notifications.clear();
    _tasks.clear();
    _automationRules.clear();
    _inventoryItems.clear();
  }

  Future<void> _loadInventory() async {
    try {
      final items = await TaskApi.getInventory(_selectedFarmId);
      _inventoryItems
        ..clear()
        ..addAll(items);
    } catch (_) {
      _inventoryItems.clear();
    }
  }

  /// Luật tự động hoá THÔ của mọi Zone (tải song song); lỗi từng Zone thì coi như Zone đó chưa có luật.
  Future<List<List<Map<String, dynamic>>>> _fetchRulesRaw() => Future.wait(
    _zones.map(
      (z) => AutomationApi.getAutoRules(
        z.zoneId,
      ).catchError((_) => <Map<String, dynamic>>[]),
    ),
  );

  /// Dựng luật từ dữ liệu thô; cần danh sách actuator đã có để gắn tên thiết bị.
  void _applyRules(List<List<Map<String, dynamic>>> zoneRulesList) {
    final rules = <AutomationRuleModel>[];
    for (int i = 0; i < _zones.length && i < zoneRulesList.length; i++) {
      final z = _zones[i];
      for (final r in zoneRulesList[i]) {
        final actuator = _actuators
            .where((a) => a.actuatorId == r['actuatorId']?.toString())
            .firstOrNull;
        rules.add(
          AutomationRuleModel.fromJson(
            r,
            actuatorName: actuator?.name,
            defaultZoneName: z.name,
          ),
        );
      }
    }
    _automationRules
      ..clear()
      ..addAll(rules);
  }

  /// Kéo-để-làm-mới ở màn Lịch & Luật: tải lại lịch tưới và luật tự động của mọi Zone song song.
  /// Lỗi mạng giữ nguyên danh sách đang có (không xoá dữ liệu cũ).
  Future<void> refreshSchedulesAndRules() async {
    await Future.wait([
      fetchSchedules(),
      () async {
        if (_zones.isEmpty) return;
        try {
          _applyRules(await _fetchRulesRaw());
          _notify();
        } catch (_) {}
      }(),
    ]);
  }

  Future<void> _loadInventoryAndRules() async {
    await _loadInventory();
    if (_zones.isEmpty) {
      _automationRules.clear();
      return;
    }
    _applyRules(await _fetchRulesRaw());
  }

  /// Gộp các lần gọi chồng nhau: lúc khởi động provider tự đồng bộ, màn hình đầu tiên lại gọi thêm một lần nữa,
  /// khiến toàn bộ ~60 lời gọi API chạy hai lần. Lần gọi đến khi lượt trước mới bắt đầu (< 2 giây) dùng chung kết quả.
  /// Lần gọi muộn hơn (sau khi người dùng vừa sửa dữ liệu) vẫn chạy lượt mới để không đọc dữ liệu cũ.
  Future<void> fetchFromApi() {
    final running = _fetchInFlight;
    final started = _fetchStartedAt;
    if (running != null &&
        started != null &&
        DateTime.now().difference(started) < const Duration(seconds: 2)) {
      return running;
    }
    _fetchStartedAt = DateTime.now();
    final f = _fetchFromApiImpl();
    _fetchInFlight = f;
    return f.whenComplete(() {
      if (identical(_fetchInFlight, f)) _fetchInFlight = null;
    });
  }

  Future<void> _fetchFromApiImpl() async {
    _isLoadingApi = true;
    _syncError = null;
    _structureError = null;
    _notify();
    try {
      // 1. Tải song song danh tính người dùng và danh sách nông trại
      final initResults = await Future.wait([
        AccountApi.getMe(),
        FarmApi.getFarms(),
        AccountApi.getMyTenant(),
      ]);
      _me = initResults[0] as Map<String, dynamic>?;
      _tenant = initResults[2] as Map<String, dynamic>?;
      unawaited(loadCropProfiles());
      var apiFarms = initResults[1] as List<FarmModel>;
      // Nông dân chỉ làm việc trong trang trại được giao (`me.farmId`); backend vẫn trả mọi trang trại của tổ chức.
      if (parseAppRole(ApiService.userRole) == AppRole.farmer) {
        final own = _me?['farmId']?.toString().toLowerCase();
        if (own != null && own.isNotEmpty) {
          final mine = apiFarms
              .where((f) => f.farmId.toLowerCase() == own)
              .toList();
          if (mine.isNotEmpty) apiFarms = mine;
        }
      }

      if (apiFarms.isEmpty) {
        _clearSeedData();
      } else {
        _isApiConnected = true;
        _farms
          ..clear()
          ..addAll(apiFarms);
        if (!_farms.any((f) => f.farmId == _selectedFarmId)) {
          _selectedFarmId = _farms.first.farmId;
        }

        // KTV chỉ làm việc qua API triển khai/kho; dữ liệu vận hành của farm (thời tiết, cảnh báo, actuator, telemetry, luật)
        // thuộc Owner/Farmer nên gọi sẽ nhận 403 hàng loạt.
        final isTech =
            parseAppRole(ApiService.userRole) == AppRole.platformTechnician;

        // 2. Chỉ Thửa đất (để tải Zone) và nhân sự (để gắn người phụ trách vào Zone) chặn việc hiện Zone. Thời tiết (API ngoài,
        // thường chậm nhất), cảnh báo, tác vụ, thông báo chạy song song và được áp sau, không làm trễ Zone.
        final fieldsFuture = FarmApi.getFields(_selectedFarmId)
            .then<List<FieldModel>?>((v) => v)
            .catchError((Object e) {
              _structureError =
                  'Không tải được Thửa đất: ${userFacingError(e)}';
              return null;
            });
        final farmersFuture = _currentRole == 'OWNER'
            ? FarmApi.getFarmers().catchError((_) => <FarmerModel>[])
            : Future.value(<FarmerModel>[]);
        final extrasFuture = Future.wait([
          isTech
              ? Future<Map<String, dynamic>?>.value(null)
              : FarmApi.getFarmWeather(_selectedFarmId).catchError((_) => null),
          // Lỗi tải → null: GIỮ danh sách đang có và báo lỗi, không biến thành "không có cảnh báo".
          isTech
              ? Future.value(<AlertModel>[])
              : TaskApi.getAlerts(
                  _selectedFarmId,
                ).then<List<AlertModel>?>((v) => v).catchError((Object e) {
                  _syncError ??=
                      'Không tải được cảnh báo: ${userFacingError(e)}';
                  return null;
                }),
          if (parseAppRole(ApiService.userRole) == AppRole.farmOwner ||
              parseAppRole(ApiService.userRole) == AppRole.farmer)
            TaskApi.getTasks(
              _selectedFarmId,
            ).then<List<TaskModel>?>((v) => v).catchError((Object e) {
              _syncError ??= 'Không tải được công việc: ${userFacingError(e)}';
              return null;
            })
          else
            Future.value(<TaskModel>[]),
          fetchNotifications().catchError((_) {}),
        ]);

        // Tải lỗi → GIỮ danh sách đang có (không biến thành rỗng) và báo lỗi qua structureError.
        final apiFields = (await fieldsFuture) ?? _fields.toList();
        final apiFarmers = await farmersFuture;
        _fields
          ..clear()
          ..addAll(apiFields);
        _farmers
          ..clear()
          ..addAll(apiFarmers);

        // 3. Tải song song các Zones của toàn bộ Fields
        final zonesPerField = await Future.wait(
          apiFields.map(
            (field) =>
                FarmApi.getZones(
                  field.fieldId,
                  farmId: _selectedFarmId,
                  farmName: currentFarm.name,
                  fieldName: field.name,
                ).catchError((Object e) {
                  _structureError ??=
                      'Không tải được Zone của lô "${field.name}": ${userFacingError(e)}';
                  // Giữ Zone đã có của lô này thay vì xoá.
                  return _zones
                      .where((z) => z.fieldId == field.fieldId)
                      .toList();
                }),
          ),
        );

        _zones
          ..clear()
          ..addAll(zonesPerField.expand((list) => list));

        _syncZoneWorkers();

        // Báo cập nhật UI ngay lập tức để người dùng thấy farm, fields, zones mà không cần đợi tải sâu
        _isLoadingApi = false;
        _notify();

        // 4-5. Cảnh báo/tác vụ/thời tiết (đã tải song song từ trên) và dữ liệu vận hành sâu của Zone (thiết bị chấp hành, ngữ cảnh AI,
        // số đo, kho, luật) chạy ĐỒNG THỜI thay vì nối đuôi nhau.
        Future<void> applyFarmExtras() async {
          final r = await extrasFuture;
          _farmWeather = r[0] as Map<String, dynamic>?;
          final alerts = r[1] as List<AlertModel>?;
          if (alerts != null) {
            _alerts
              ..clear()
              ..addAll(alerts);
          }
          final tasks = r[2] as List<TaskModel>?;
          if (tasks != null) {
            _tasks
              ..clear()
              ..addAll(tasks.map(_withZoneName));
          }
          _notify();
        }

        await Future.wait([
          applyFarmExtras(),
          if (!isTech) _syncOperationalData(),
        ]);
      }
    } catch (e) {
      // Lỗi mạng/máy chủ: GIỮ dữ liệu đang có, báo lỗi thay vì xoá như thể tài khoản trống.
      _syncError = userFacingError(e);
    } finally {
      _isLoadingApi = false;
      _notify();
    }
  }

  /// Dữ liệu vận hành của Zone (không dành cho KTV). Kho, số đo và luật thô chỉ cần danh sách Zone nên tải CÙNG LÚC với thiết bị
  /// chấp hành/ngữ cảnh AI; luật chỉ được dựng sau khi có actuator (để gắn tên thiết bị).
  Future<void> _syncOperationalData() async {
    final inventoryFuture = _loadInventory();
    final rulesFuture = _fetchRulesRaw();
    final telemetryFuture = refreshAllZonesTelemetry();
    final schedulesFuture = fetchSchedules(
      farmId: _selectedFarmId,
    ).catchError((_) {});
    await _syncZoneActuatorsAndContext();
    await Future.wait([inventoryFuture, telemetryFuture, schedulesFuture]);
    final rules = await rulesFuture;
    if (_zones.isEmpty) {
      _automationRules.clear();
    } else {
      _applyRules(rules);
    }
  }

  /// Thiết bị chấp hành và cây trồng/ngữ cảnh AI của từng Zone (tải song song).
  Future<void> _syncZoneActuatorsAndContext() async {
    if (_zones.isNotEmpty) {
      final zoneDetails = await Future.wait(
        _zones.map((z) async {
          // Lỗi tải thiết bị KHÔNG được coi là "Zone không có thiết bị": trả null để giữ danh sách cũ và ghi nhận lỗi.
          final actsFuture = FarmApi.fetchZoneActuators(z.zoneId)
              .then<List<ActuatorModel>?>((v) => v)
              .catchError((Object e) {
                _actuatorErrors[z.zoneId.toLowerCase()] = e
                    .toString()
                    .replaceFirst('Exception: ', '');
                return null;
              });
          final ctxFuture = AiApi.getAiContext(
            z.zoneId,
          ).catchError((_) => null);
          final res = await Future.wait([actsFuture, ctxFuture]);
          return (
            zoneId: z.zoneId,
            acts: res[0] as List<ActuatorModel>?,
            ctx: res[1] as Map<String, dynamic>?,
          );
        }),
      );

      for (final d in zoneDetails) {
        final acts = d.acts;
        if (acts != null) {
          final idLower = d.zoneId.toLowerCase();
          _actuators.removeWhere((a) => a.zoneId.toLowerCase() == idLower);
          _actuators.addAll(acts);
          _actuatorErrors.remove(idLower);
        }
        final ctx = d.ctx;
        if (ctx != null && ctx['cropName'] != null) {
          final idx = _zones.indexWhere((z) => z.zoneId == d.zoneId);
          if (idx != -1) {
            final z = _zones[idx];
            // Zone API là nguồn chính của cây/giai đoạn (cây kèm giống, vd "Cà Chua (Beef F1)"); ngữ cảnh AI chỉ bù khi Zone API không có.
            final hasCrop = !z.currentCrop.startsWith('Chưa gán cây');
            final hasStage =
                z.seasonStatus == 'InProgress' &&
                !z.currentStage.startsWith('Chưa có vụ');
            final reqs = ctx['requirements'];
            _zones[idx] = z.copyWith(
              currentCrop: hasCrop ? null : ctx['cropName'].toString(),
              currentStage: hasStage
                  ? null
                  : (ctx['growthStageName']?.toString() ?? z.currentStage),
              cropContextIsDbBacked: true,
              appliedRequirements: reqs is List
                  ? [
                      for (final r in reqs)
                        if (r is Map) Map<String, dynamic>.from(r),
                    ]
                  : const [],
            );
          }
        }
      }
    }
  }

  /// Áp số đo mới nhất (từ FarmApi.getLatestTelemetry) lên một Zone; null khi không có gì thay đổi.
  ZoneModel? _zoneWithTelemetry(ZoneModel z, Map<String, double> t) {
    final hasFresh =
        t['__hasFreshTelemetry'] == 1.0 &&
        t.containsKey('TEMPERATURE') &&
        t.containsKey('SOILMOISTURE') &&
        t.containsKey('AIRHUMIDITY') &&
        (t.containsKey('LIGHTINTENSITY') || t.containsKey('LIGHT'));
    final temp = t['TEMPERATURE'] ?? z.currentTemp;
    final moist = t['SOILMOISTURE'] ?? z.currentSoilMoisture;
    final humid = t['AIRHUMIDITY'] ?? z.currentHumidity;
    final lux = t['LIGHTINTENSITY'] ?? t['LIGHT'] ?? z.currentLux;
    final changed =
        temp != z.currentTemp ||
        moist != z.currentSoilMoisture ||
        humid != z.currentHumidity ||
        lux != z.currentLux ||
        hasFresh != z.telemetryIsFresh;
    if (!changed) return null;
    return z.copyWith(
      currentTemp: temp,
      currentSoilMoisture: moist,
      currentHumidity: humid,
      currentLux: lux,
      telemetryIsFresh: hasFresh,
    );
  }

  /// Tải số đo mới nhất cho các Zone (trừ [exceptZoneId], thường là Zone đang chọn đã có vòng cập nhật 5 giây riêng).
  Future<void> refreshAllZonesTelemetry({String? exceptZoneId}) async {
    _lastAllZonesTelemetryAt = DateTime.now();
    final ids = [
      for (final z in _zones)
        if (z.zoneId != exceptZoneId) z.zoneId,
    ];
    if (ids.isEmpty) return;
    final results = await Future.wait(
      ids.map((id) => FarmApi.getLatestTelemetry(id).catchError((_) => null)),
    );
    var any = false;
    for (var i = 0; i < ids.length; i++) {
      final t = results[i];
      if (t == null) continue;
      final idx = _zones.indexWhere((z) => z.zoneId == ids[i]);
      if (idx == -1) continue;
      final updated = _zoneWithTelemetry(_zones[idx], t);
      if (updated != null) {
        _zones[idx] = updated;
        any = true;
      }
    }
    if (any) _notify();
  }

  void _startRealtimeSensorTimer() {
    _realtimeTimer?.cancel();
    if (!_lifecycleObserverAdded) {
      WidgetsBinding.instance.addObserver(this);
      _lifecycleObserverAdded = true;
    }
    // Cập nhật vi khí hậu thực tế từ trạm cảm biến LoRa mỗi 5 giây
    _realtimeTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      // KTV không có quyền đọc telemetry của farm (403): không hỏi.
      if (parseAppRole(ApiService.userRole) == AppRole.platformTechnician) {
        // Chỉ làm mới THÔNG BÁO (mỗi ~30 giây) để KTV thấy việc mới được giao/cọc/nghiệm thu mà không cần mở lại app.
        _techNotifTick++;
        if (_techNotifTick % 6 == 0 && ApiService.isAuthenticated) {
          unawaited(fetchNotifications());
        }
        return;
      }
      // Lần hỏi trước chưa xong (mạng chậm) thì bỏ lượt này, tránh dồn nhiều yêu cầu chồng nhau.
      if (_pollInFlight) return;
      final lastAll = _lastAllZonesTelemetryAt;
      if (_isApiConnected &&
          _zones.length > 1 &&
          (lastAll == null ||
              DateTime.now().difference(lastAll) >
                  const Duration(seconds: 30))) {
        unawaited(refreshAllZonesTelemetry(exceptZoneId: currentZone.zoneId));
      }
      // Nếu đang kết nối API, thử lấy số liệu đo từ API cho Zone hiện tại
      if (_isApiConnected && _zones.isNotEmpty) {
        _pollInFlight = true;
        try {
          final curZ = currentZone;
          final telemetry = await FarmApi.getLatestTelemetry(curZ.zoneId);
          if (telemetry != null) {
            final idx = _zones.indexWhere((z) => z.zoneId == curZ.zoneId);
            if (idx != -1) {
              final hasFresh =
                  telemetry['__hasFreshTelemetry'] == 1.0 &&
                  telemetry.containsKey('TEMPERATURE') &&
                  telemetry.containsKey('SOILMOISTURE') &&
                  telemetry.containsKey('AIRHUMIDITY') &&
                  (telemetry.containsKey('LIGHTINTENSITY') ||
                      telemetry.containsKey('LIGHT'));
              final newTemp = telemetry['TEMPERATURE'] ?? curZ.currentTemp;
              final newMoist =
                  telemetry['SOILMOISTURE'] ?? curZ.currentSoilMoisture;
              final newHumid = telemetry['AIRHUMIDITY'] ?? curZ.currentHumidity;
              final newLux =
                  telemetry['LIGHTINTENSITY'] ??
                  telemetry['LIGHT'] ??
                  curZ.currentLux;

              final changed =
                  newTemp != curZ.currentTemp ||
                  newMoist != curZ.currentSoilMoisture ||
                  newHumid != curZ.currentHumidity ||
                  newLux != curZ.currentLux ||
                  hasFresh != curZ.telemetryIsFresh;
              _lastTelemetryReceivedAt = DateTime.now();
              // Số đo không đổi thì không dựng lại giao diện.
              if (changed) {
                _zones[idx] = curZ.copyWith(
                  currentTemp: newTemp,
                  currentSoilMoisture: newMoist,
                  currentHumidity: newHumid,
                  currentLux: newLux,
                  telemetryIsFresh: hasFresh,
                );
                _notify();
              }

              // Đồng bộ trạng thái rơ-le chấp hành của zone hiện tại: 15 giây/lần (số đo vẫn 5 giây/lần);
              // lệnh điều khiển của người dùng có luồng làm mới riêng nên không phụ thuộc nhịp này.
              if (_actuatorPollTick++ % 3 != 0) return;
              try {
                final freshActs = await FarmApi.getZoneActuators(curZ.zoneId);
                final zIdLower = curZ.zoneId.toLowerCase();
                final oldActs = _actuators
                    .where((a) => a.zoneId.toLowerCase() == zIdLower)
                    .toList();
                bool actsChanged = oldActs.length != freshActs.length;
                if (!actsChanged) {
                  for (int j = 0; j < oldActs.length; j++) {
                    if (oldActs[j].actuatorId != freshActs[j].actuatorId ||
                        oldActs[j].isRunning != freshActs[j].isRunning ||
                        oldActs[j].awaitingAck != freshActs[j].awaitingAck ||
                        oldActs[j].remainingMinutes !=
                            freshActs[j].remainingMinutes ||
                        oldActs[j].name != freshActs[j].name) {
                      actsChanged = true;
                      break;
                    }
                  }
                }
                if (actsChanged) {
                  _actuators.removeWhere(
                    (a) => a.zoneId.toLowerCase() == zIdLower,
                  );
                  _actuators.addAll(freshActs);
                  _notify();
                }
              } catch (_) {}

              return;
            }
          }
        } catch (_) {
        } finally {
          _pollInFlight = false;
        }
        // API connected: stale or missing readings must not be replaced by generated values.
        return;
      }
    });
  }

  /// Khớp danh sách nhân công với từng Zone dựa trên quyền Zone (UserZoneAccess).
  void _syncZoneWorkers() {
    for (int i = 0; i < _zones.length; i++) {
      final z = _zones[i];
      final workers = getWorkersForZone(z.zoneId);
      if (workers.isNotEmpty) {
        final names = workers.map((w) => w.name).join(', ');
        final role = workers.length == 1
            ? (workers.first.role.isNotEmpty ? workers.first.role : 'Nông dân')
            : '${workers.length} nhân công phụ trách';
        _zones[i] = z.copyWith(assignedWorkerName: names, workerRole: role);
      } else {
        _zones[i] = z.copyWith(clearAssignedWorker: true);
      }
    }
  }
}
