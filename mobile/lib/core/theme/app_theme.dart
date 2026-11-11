import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Bảng màu dùng chung. Giá trị khớp với màu đang dùng khắp app để chuyển dần sang token mà không đổi diện mạo.
abstract final class AppColors {
  // Thương hiệu
  static const Color ink = Color(0xFF062326); // nền AppBar, nút chính
  static const Color primary = Color(0xFF10B981); // xanh nhấn (emerald)
  static const Color primaryDark = Color(0xFF059669);
  static const Color primarySoft = Color(0xFFECFDF5);

  // Chữ & viền (slate)
  static const Color text = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textFaint = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);
  static const Color surfaceMuted = Color(0xFFF8FAFC);

  // Trạng thái
  static const Color info = Color(0xFF0284C7);
  static const Color infoSoft = Color(0xFFF0F9FF);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFEF2F2);
}

/// Khoảng cách và bo góc thống nhất.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double radius = 12;
  static const double radiusLg = 16;
}

/// Theme toàn app: mọi nút, ô nhập, thẻ, hộp thoại, snackbar... dùng chung một kiểu nên các màn hình
/// nhất quán mà không cần tự tô từng chỗ. Vùng chạm tối thiểu 48dp cho nút bấm.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.ink,
    secondary: AppColors.primary,
    surface: Colors.white,
    error: AppColors.danger,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radius));
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppSpacing.radius),
    borderSide: const BorderSide(color: AppColors.borderStrong),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.surfaceMuted,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ink,
      foregroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
      centerTitle: false,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.8)),
      errorBorder: inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.danger)),
      focusedErrorBorder: inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.danger, width: 1.8)),
      labelStyle: const TextStyle(color: AppColors.textMuted),
      hintStyle: const TextStyle(color: AppColors.textFaint),
      helperMaxLines: 3,
      errorMaxLines: 3,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.borderStrong),
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 44), shape: shape),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(44, 44))),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.ink,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: const BorderSide(color: AppColors.border),
      labelStyle: const TextStyle(fontSize: 12),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.text),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      insetPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      contentTextStyle: const TextStyle(fontSize: 13, height: 1.35),
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: AppColors.primary,
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textFaint,
      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      unselectedLabelStyle: TextStyle(fontSize: 12),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primary.withValues(alpha: 0.15),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? AppColors.ink : AppColors.textMuted,
        ),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
    listTileTheme: const ListTileThemeData(minVerticalPadding: 8),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
  );
}
