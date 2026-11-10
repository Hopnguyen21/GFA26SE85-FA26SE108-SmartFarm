/// Vai trò mà ứng dụng mobile hỗ trợ. Vai trò khác (vd. PlatformAdmin) bị chặn đăng nhập.
enum AppRole { farmOwner, farmer, platformTechnician }

class RoleParseResult {
  final AppRole? role;
  final String message;
  const RoleParseResult(this.role, this.message);
}

/// Chuẩn hoá chuỗi role từ API (FarmOwner / FARM_OWNER / farm-owner ...) và đối chiếu CHÍNH XÁC.
/// Không dùng contains(): ADMIN không bao giờ thành OWNER, role lạ không tự thành FARMER.
AppRole? parseAppRole(String? raw) {
  if (raw == null) return null;
  final n = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
  switch (n) {
    case 'farmowner':
      return AppRole.farmOwner;
    case 'farmer':
      return AppRole.farmer;
    case 'platformtechnician':
      return AppRole.platformTechnician;
    default:
      return null;
  }
}

/// Thông báo lỗi tiếng Việt cho role không được hỗ trợ trên mobile.
String unsupportedRoleMessage(String? raw) {
  final n = (raw ?? '').trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
  if (n == 'platformadmin') {
    return 'Tài khoản Quản trị nền tảng (Platform Admin) không được hỗ trợ trên ứng dụng di động. Vui lòng dùng bản web.';
  }
  return 'Vai trò tài khoản không được hỗ trợ trên ứng dụng di động.';
}

/// Tên role dùng cho FarmProvider.switchRole.
String providerRoleName(AppRole r) {
  switch (r) {
    case AppRole.farmOwner:
      return 'OWNER';
    case AppRole.platformTechnician:
      return 'TECHNICIAN';
    case AppRole.farmer:
      return 'FARMER';
  }
}
