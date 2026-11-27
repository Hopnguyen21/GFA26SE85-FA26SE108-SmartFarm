import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Dịch vụ lưu trữ và khôi phục bản nháp báo cáo công việc khi mất mạng (Offline Task Drafts).
/// Giúp nông dân không bị mất nội dung đã nhập hoặc ảnh đã chọn khi đang tác nghiệp ở vùng mất sóng.
class OfflineTaskDraftService {
  OfflineTaskDraftService._();

  static const _prefix = 'smartfarm_task_draft_';

  static Future<void> saveDraft({
    required String taskId,
    required String result,
    required List<String> imageUrls,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'taskId': taskId,
      'result': result,
      'imageUrls': imageUrls,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await prefs.setString('$_prefix$taskId', jsonEncode(data));
  }

  static Future<({String result, List<String> imageUrls, DateTime savedAt})?> getDraft(
    String taskId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$taskId');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final result = map['result'] as String? ?? '';
      final images = (map['imageUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
      final savedAt = DateTime.tryParse(map['savedAt'] as String? ?? '') ??
          DateTime.now();
      return (result: result, imageUrls: images, savedAt: savedAt);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearDraft(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$taskId');
  }

  static Future<bool> hasDraft(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_prefix$taskId');
  }
}
