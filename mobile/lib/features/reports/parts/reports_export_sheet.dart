import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/export_utils.dart';
import '../../../core/utils/user_error.dart';

/// Modal BottomSheet cho phép Chủ trang trại chọn xuất các mẫu báo cáo Excel chuyên biệt.
Future<void> showReportExportSheet(
  BuildContext context, {
  required String farmId,
  required String farmName,
  DateTime? from,
  DateTime? to,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ReportExportSheet(
      farmId: farmId,
      farmName: farmName,
      from: from,
      to: to,
    ),
  );
}

class _ReportExportSheet extends StatefulWidget {
  final String farmId;
  final String farmName;
  final DateTime? from;
  final DateTime? to;

  const _ReportExportSheet({
    required this.farmId,
    required this.farmName,
    this.from,
    this.to,
  });

  @override
  State<_ReportExportSheet> createState() => _ReportExportSheetState();
}

class _ReportExportSheetState extends State<_ReportExportSheet> {
  String? _exportingKind; // 'all', 'overview', 'water-usage', etc.

  Future<void> _doExport(String? kind, String title, String fileSuffix) async {
    if (_exportingKind != null) return;
    setState(() => _exportingKind = kind ?? 'all');
    try {
      final bytes = await ReportApi.downloadFarmReportExcel(
        widget.farmId,
        kind: kind,
        from: widget.from,
        to: widget.to,
      );
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      final fileName =
          'bao-cao-$fileSuffix-${widget.farmName}-$dateStr.xlsx'
              .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

      if (mounted) Navigator.pop(context);

      await saveAndShareFile(
        fileName,
        bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xuất $title thất bại: ${userFacingError(e)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingKind = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF047857).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.table_chart_rounded,
                    color: Color(0xFF047857),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Xuất Báo Cáo Excel (.xlsx)',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Trang trại: ${widget.farmName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Chọn loại báo cáo bạn muốn tải về máy. File Excel được tạo chuẩn từ máy chủ backend:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 14),

            // Options
            _tile(
              kindKey: 'all',
              kindParam: null,
              title: 'Báo Cáo Tài Nguyên Toàn Diện (6 Sheets)',
              subtitle: 'Gồm Tổng quan, Nước tưới, Điện năng, Zone và Chi tiết đo',
              icon: Icons.layers_rounded,
              color: const Color(0xFF047857),
              fileSuffix: 'tai-nguyen-toan-dien',
              badge: 'Khuyên Dùng',
            ),
            _tile(
              kindKey: 'overview',
              kindParam: 'overview',
              title: 'Báo Cáo Tổng Quan Trang Trại',
              subtitle: 'Số liệu vận hành, phân khu, thiết bị, tài chính tháng',
              icon: Icons.insights_rounded,
              color: const Color(0xFF0284C7),
              fileSuffix: 'tong-quan-trang-trai',
            ),
            _tile(
              kindKey: 'water-usage',
              kindParam: 'water-usage',
              title: 'Báo Cáo Tiêu Thụ Nước Tưới',
              subtitle: 'Lượng nước theo từng phân khu và chu kỳ bơm',
              icon: Icons.water_drop_rounded,
              color: const Color(0xFF0284C7),
              fileSuffix: 'nuoc-tuoi',
            ),
            _tile(
              kindKey: 'electricity',
              kindParam: 'electricity',
              title: 'Báo Cáo Tiêu Thụ Điện Năng',
              subtitle: 'Số kWh tiêu thụ của hệ thống máy bơm, van điện',
              icon: Icons.bolt_rounded,
              color: const Color(0xFFD97706),
              fileSuffix: 'dien-nang',
            ),
            _tile(
              kindKey: 'tasks',
              kindParam: 'tasks',
              title: 'Báo Cáo Công Việc & Nhân Công',
              subtitle: 'Tiến độ hoàn thành công việc theo từng nông dân',
              icon: Icons.assignment_turned_in_rounded,
              color: const Color(0xFF2563EB),
              fileSuffix: 'cong-viec-nhan-cong',
            ),
            _tile(
              kindKey: 'inventory',
              kindParam: 'inventory',
              title: 'Báo Cáo Kho Vật Tư & Phân Bón',
              subtitle: 'Tồn kho, nhập xuất và các mặt hàng dưới ngưỡng an toàn',
              icon: Icons.inventory_2_rounded,
              color: const Color(0xFF0F766E),
              fileSuffix: 'kho-vat-tu',
            ),
            _tile(
              kindKey: 'maintenance',
              kindParam: 'maintenance',
              title: 'Báo Cáo Bảo Trì & Thiết Bị IoT',
              subtitle: 'Yêu cầu hỗ trợ, sửa chữa, thay thế Gateway/Node',
              icon: Icons.build_rounded,
              color: const Color(0xFF7C3AED),
              fileSuffix: 'bao-tri-thiet-bi',
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required String kindKey,
    required String? kindParam,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String fileSuffix,
    String? badge,
  }) {
    final isThisExporting = _exportingKind == kindKey;
    final isBusy = _exportingKind != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: isBusy
              ? null
              : () => _doExport(kindParam, title, fileSuffix),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isThisExporting
                    ? color
                    : const Color(0xFFE2E8F0),
                width: isThisExporting ? 1.5 : 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x03000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isThisExporting)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF047857),
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
