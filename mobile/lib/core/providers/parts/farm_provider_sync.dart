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

  Future<void> _loadInventoryAndRules() async {
    try {
      final items = await TaskApi.getInventory(_selectedFarmId);
      _inventoryItems
        ..clear()
        ..addAll(items);
    } catch (_) {
      _inventoryItems.clear();
    }
    if (_zones.isEmpty) {
      _automationRules.clear();
      return;
    }
    // Tải song song toàn bộ luật tự động hoá của các Zone
    final zoneRulesList = await Future.wait(
      _zones.map(
        (z) => AutomationApi.getAutoRules(
          z.zoneId,
        ).catchError((_) => <Map<String, dynamic>>[]),
      ),
    );
    final rules = <AutomationRuleModel>[];
    for (int i = 0; i < _zones.length; i++) {
      final z = _zones[i];
      final zoneRules = zoneRulesList[i];
      for (final r in zoneRules) {
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

  Future<void> fetchFromApi() async {
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
      final apiFarms = initResults[1] as List<FarmModel>;

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

        // 2. Tải song song dữ liệu cấp Farm: Thời tiết, Thửa đất, Nhân sự (nếu Owner), Cảnh báo, Tác vụ, Thông báo
        final farmLevelResults = await Future.wait([
          FarmApi.getFarmWeather(_selectedFarmId).catchError((_) => null),
          FarmApi.getFields(
            _selectedFarmId,
          ).then<List<FieldModel>?>((v) => v).catchError((Object e) {
            _structureError =
                'Không tải được Thửa đất: ${e.toString().replaceFirst('Exception: ', '')}';
            return null;
          }),
          if (_currentRole == 'OWNER')
            FarmApi.getFarmers().catchError((_) => <FarmerModel>[])
          else
            Future.value(<FarmerModel>[]),
          TaskApi.getAlerts(_selectedFarmId).catchError((_) => <AlertModel>[]),
          if (parseAppRole(ApiService.userRole) == AppRole.farmOwner ||
              parseAppRole(ApiService.userRole) == AppRole.farmer)
            TaskApi.getTasks(_selectedFarmId).catchError((_) => <TaskModel>[])
          else
            Future.value(<TaskModel>[]),
          fetchNotifications().catchError((_) {}),
        ]);

        _farmWeather = farmLevelResults[0] as Map<String, dynamic>?;
        // Tải lỗi → GIỮ danh sách đang có (không biến thành rỗng) và báo lỗi qua structureError.
        final apiFields =
            (farmLevelResults[1] as List<FieldModel>?) ?? _fields.toList();
        final apiFarmers = farmLevelResults[2] as List<FarmerModel>;
        final apiAlerts = farmLevelResults[3] as List<AlertModel>;
        final apiTasks = farmLevelResults[4] as List<TaskModel>;

        _fields
          ..clear()
          ..addAll(apiFields);
        _farmers
          ..clear()
          ..addAll(apiFarmers);
        _alerts
          ..clear()
          ..addAll(apiAlerts);
        _tasks
          ..clear()
          ..addAll(apiTasks.map(_withZoneName));

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
                      'Không tải được Zone của lô "${field.name}": ${e.toString().replaceFirst('Exception: ', '')}';
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

        // 4. Đồng bộ song song Thiết bị chấp hành và Cây trồng từ DB cho từng Zone
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
                final crop = ctx['cropName'].toString();
                final stage =
                    ctx['growthStageName']?.toString() ??
                    _zones[idx].currentStage;
                _zones[idx] = _zones[idx].copyWith(
                  currentCrop: crop,
                  currentStage: stage,
                  cropContextIsDbBacked: true,
                );
              }
            }
          }
        }

        // 5. Tải song song kho vật tư và luật tự động hoá
        await _loadInventoryAndRules();
      }
    } catch (e) {
      // Lỗi mạng/máy chủ: GIỮ dữ liệu đang có, báo lỗi thay vì xoá như thể tài khoản trống.
      _syncError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoadingApi = false;
      _notify();
    }
  }

  void _startRealtimeSensorTimer() {
    _realtimeTimer?.cancel();
    if (!_lifecycleObserverAdded) {
      WidgetsBinding.instance.addObserver(this);
      _lifecycleObserverAdded = true;
    }
    // Cập nhật vi khí hậu thực tế từ trạm cảm biến LoRa mỗi 5 giây
    _realtimeTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      // Lần hỏi trước chưa xong (mạng chậm) thì bỏ lượt này, tránh dồn nhiều yêu cầu chồng nhau.
      if (_pollInFlight) return;
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

              // Đồng bộ trạng thái rơ-le chấp hành của zone hiện tại
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
