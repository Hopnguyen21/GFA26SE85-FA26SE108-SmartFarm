import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Dịch vụ lưu đệm ranh giới GIS và toạ độ node ngoại tuyến (Offline GIS Cache).
/// Khi người dùng ở vùng nông thôn sóng 4G chập chờn hoặc không có mạng,
/// bản đồ vẫn hiển thị được các polygon thửa đất/Zone và vị trí các trạm cảm biến đã tải trước đó.
class OfflineGisCacheService {
  OfflineGisCacheService._();

  static const _boundaryPrefix = 'smartfarm_gis_boundary_';
  static const _nodesPrefix = 'smartfarm_gis_nodes_';

  /// Lưu đệm ranh giới Zone của trang trại
  static Future<void> cacheFarmZoneBoundaries(
    String farmId,
    List<Map<String, dynamic>> zoneBoundaries,
  ) async {
    if (farmId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_boundaryPrefix$farmId',
        jsonEncode({
          'farmId': farmId,
          'cachedAt': DateTime.now().toUtc().toIso8601String(),
          'zones': zoneBoundaries,
        }),
      );
    } catch (_) {}
  }

  /// Nạp ranh giới Zone đã lưu đệm của trang trại khi mất mạng
  static Future<List<Map<String, dynamic>>?> getCachedFarmZoneBoundaries(
    String farmId,
  ) async {
    if (farmId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_boundaryPrefix$farmId');
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final list = map['zones'] as List<dynamic>?;
      if (list == null) return null;
      return list.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return null;
    }
  }

  /// Lưu đệm danh sách Node đã chấm toạ độ
  static Future<void> cacheZoneNodes(
    String zoneId,
    List<Map<String, dynamic>> nodes,
  ) async {
    if (zoneId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_nodesPrefix$zoneId',
        jsonEncode({
          'zoneId': zoneId,
          'cachedAt': DateTime.now().toUtc().toIso8601String(),
          'nodes': nodes,
        }),
      );
    } catch (_) {}
  }

  /// Nạp danh sách Node đã lưu đệm khi mất mạng
  static Future<List<Map<String, dynamic>>?> getCachedZoneNodes(
    String zoneId,
  ) async {
    if (zoneId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_nodesPrefix$zoneId');
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final list = map['nodes'] as List<dynamic>?;
      if (list == null) return null;
      return list.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return null;
    }
  }
}
