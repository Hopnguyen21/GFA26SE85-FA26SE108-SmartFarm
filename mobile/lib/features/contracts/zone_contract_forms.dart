import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_views.dart';
import '../../core/services/api_service.dart';
import 'zone_contract_logic.dart';
part 'parts/zone_contract_forms_create.dart';
part 'parts/zone_contract_forms_renew.dart';
part 'parts/zone_contract_forms_depreciation.dart';
part 'parts/zone_contract_forms_detail.dart';

/// Form hợp đồng thuê Zone & khấu hao thiết bị, khớp với backend ZoneContractService:
/// - Tổng giá trị: KHÔNG tự đặt; backend tính = giá thuê × số tháng (theo ngày bắt đầu/kết thúc).
/// - Chiết khấu: để trống thì backend tự áp ưu đãi (15% nếu ký lần 2 trong 60 ngày, 10% nếu tái ký từ HĐ cũ).
/// - Tiền cọc: để trống thì backend lấy 30% tổng sau chiết khấu.
/// App chỉ hiển thị ước tính; số chính thức là số backend trả về.

final _vnd = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
final _ymd = DateFormat('yyyy-MM-dd');
final _dmy = DateFormat('dd/MM/yyyy');

String _err(Object e) => e.toString().replaceFirst('Exception: ', '');

void _snack(BuildContext context, String m, {bool error = false}) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(m), backgroundColor: error ? const Color(0xFFDC2626) : const Color(0xFF059669)));

double? _money(TextEditingController c) {
  final t = c.text.trim().replaceAll(RegExp(r'[.,\s₫]'), '');
  return t.isEmpty ? null : double.tryParse(t);
}

/// Số tháng giống backend: chênh lệch năm*12 + tháng, tối thiểu 1.
int contractMonths(DateTime start, DateTime end) =>
    ((end.year - start.year) * 12 + end.month - start.month).clamp(1, 1200);

DateTime _addMonths(DateTime d, int m) {
  final y = d.year + ((d.month - 1 + m) ~/ 12);
  final mo = (d.month - 1 + m) % 12 + 1;
  final lastDay = DateTime(y, mo + 1, 0).day;
  return DateTime(y, mo, d.day > lastDay ? lastDay : d.day);
}

InputDecoration _dec(String label, {String? hint, String? helper}) => InputDecoration(
  labelText: label,
  hintText: hint,
  helperText: helper,
  helperMaxLines: 2,
  border: const OutlineInputBorder(),
  isDense: true,
);
