part of '../farm_provider.dart';

extension FarmProviderInventoryProfile on FarmProvider {
  Future<String?> _inventoryCall(Future<void> Function() call) async {
    try {
      await call();
      await _loadInventoryAndRules();
      _notify();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> addInventoryItem({
    required String materialName,
    required String category,
    required double quantity,
    required String unit,
    required double minimumStock,
  }) => _inventoryCall(
    () => TaskApi.createInventoryItem(_selectedFarmId, {
      'name': materialName,
      'materialType': switch (category) {
        'SEED' => 'Seed',
        'FERTILIZER' => 'Fertilizer',
        'PESTICIDE' => 'Pesticide',
        _ => 'Tool',
      },
      'unit': unit,
      'lowStockThreshold': minimumStock,
      'initialQuantity': quantity,
    }),
  );

  Future<String?> receiveStock(String itemId, double quantity) =>
      _inventoryCall(
        () => TaskApi.receiveInventory(_selectedFarmId, itemId, quantity),
      );

  Future<String?> issueStock(String itemId, double quantity, String zoneId) =>
      _inventoryCall(
        () => TaskApi.issueInventory(_selectedFarmId, itemId, quantity, zoneId),
      );

  /// Xóa toàn bộ dữ liệu phiên khi đăng xuất (Clean state on logout)
  void resetState() {
    _isApiConnected = false;
    _chatMessages.clear();
    _schedules.clear();
    _alerts.clear();
    _tasks.clear();
    _notifications.clear();
    _clearSeedData();
    _selectedFarmId = '';
    _syncError = null;
    _selectedFieldId = null;
    _selectedZoneIndex = 0;
    _notify();
  }

  Future<bool> updateProfile({required String fullName, String? phone}) async {
    final updated = await AccountApi.updateProfile(fullName, phone);
    if (updated != null) {
      _me = updated;
      _notify();
      return true;
    }
    return false;
  }
}
