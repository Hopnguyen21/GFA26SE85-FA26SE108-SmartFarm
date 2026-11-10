import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/farm_provider.dart';
import 'services/api_service.dart';
import 'services/app_role.dart';
import 'screens/home_screen.dart';
import 'screens/ai_screen.dart';
import 'screens/crop_profiles_screen.dart';
import 'screens/device_health_screen.dart';
import 'screens/gis_map_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/farmer_dashboard_screen.dart';
import 'screens/alerts_tasks_screen.dart';
import 'screens/login_screen.dart';

/// Chỉ dùng cho môi trường Debug/Phát triển nội bộ khi làm việc với chứng chỉ tự ký cục bộ.
/// Tuyệt đối KHÔNG bỏ qua xác minh chứng chỉ trong bản Release hoặc cho các host ngoài danh sách cục bộ.
class DebugLocalHttpOverrides extends HttpOverrides {
  static const Set<String> localDevHosts = {
    'localhost',
    '127.0.0.1',
    '10.0.2.2',
  };

  /// Kiểm tra host có được phép dùng chứng chỉ tự ký hay không.
  /// Tuyệt đối từ chối nếu không phải chế độ debug hoặc không phải host nội bộ.
  static bool isHostPermittedForSelfSigned(String host, {bool isDebug = kDebugMode}) {
    if (!isDebug) return false;
    return localDevHosts.contains(host.toLowerCase());
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    if (!kDebugMode) {
      return client;
    }
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      // Chỉ cho phép chứng chỉ tự ký cục bộ trong chế độ debug cho host phát triển nội bộ
      return isHostPermittedForSelfSigned(host, isDebug: true);
    };
    return client;
  }
}

void main() {
  // Bản release TUYỆT ĐỐI không dùng HttpOverrides, tuân thủ xác minh TLS chuẩn của hệ điều hành
  if (kDebugMode) {
    HttpOverrides.global = DebugLocalHttpOverrides();
  } else {
    HttpOverrides.global = null;
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FarmProvider()),
      ],
      child: const SmartFarmApp(),
    ),
  );
}

class SmartFarmApp extends StatelessWidget {
  const SmartFarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartFarm Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981),
          primary: const Color(0xFF062326),
          secondary: const Color(0xFF10B981),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF062326),
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white),
          actionsIconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            const ExtendSelectionByCharacterIntent(
                forward: false, collapseSelection: true),
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            const ExtendSelectionByCharacterIntent(
                forward: true, collapseSelection: true),
        const SingleActivator(LogicalKeyboardKey.arrowUp):
            const ExtendSelectionVerticallyToAdjacentLineIntent(
                forward: false, collapseSelection: true),
        const SingleActivator(LogicalKeyboardKey.arrowDown):
            const ExtendSelectionVerticallyToAdjacentLineIntent(
                forward: true, collapseSelection: true),
      },
      home: const AppEntryPoint(),
    );
  }
}

/// Entry point: Show LoginScreen nếu chưa đăng nhập, MainNavigationShell nếu đã đăng nhập
class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  bool _isCheckingAuth = true;

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    ApiService.sessionVersion.addListener(_onSessionChanged);
    _checkSavedAuth();
  }

  @override
  void dispose() {
    ApiService.sessionVersion.removeListener(_onSessionChanged);
    super.dispose();
  }

  Future<void> _checkSavedAuth() async {
    final hasTokens = await ApiService.loadSavedTokens();
    if (mounted) {
      if (hasTokens && ApiService.isAuthenticated) {
        final provider = Provider.of<FarmProvider>(context, listen: false);
        final role = parseAppRole(ApiService.userRole);
        if (role == null) {
          await ApiService.clearTokens();
        } else {
          provider.switchRole(providerRoleName(role));
          provider.fetchFromApi();
        }
      }
      setState(() => _isCheckingAuth = false);
    }
  }

  void _onLoginSuccess() {
    setState(() {});
    final provider = Provider.of<FarmProvider>(context, listen: false);
    final role = parseAppRole(ApiService.userRole);
    if (role == null) {
      ApiService.clearTokens();
      return;
    }
    provider.switchRole(providerRoleName(role));
    provider.fetchFromApi();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return const Scaffold(
        backgroundColor: Color(0xFF062326),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
      );
    }
    if (!ApiService.isAuthenticated) {
      return LoginScreen(onLoginSuccess: _onLoginSuccess);
    }
    return const MainNavigationShell();
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  // Owner screens (includes AI)
  static const List<Widget> _ownerScreens = [
    HomeScreen(),
    CropProfilesScreen(),
    GISMapScreen(),
    AiAssistantScreen(),
    ProfileScreen(),
  ];

  // Technician screens (No AI -> Alerts/Tasks)
  static const List<Widget> _technicianScreens = [
    HomeScreen(),
    DeviceHealthScreen(),
    GISMapScreen(),
    AlertsTasksScreen(),
    ProfileScreen(),
  ];

  // Farmer screens (No AI -> Tasks & Alerts)
  static const List<Widget> _farmerScreens = [
    FarmerDashboardScreen(),
    CropProfilesScreen(),
    GISMapScreen(),
    AlertsTasksScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final farmProvider = Provider.of<FarmProvider>(context);
    final role = farmProvider.currentRole;
    final isFarmer = role == 'FARMER';
    final isTech = role == 'TECHNICIAN';
    final isOwner = !isFarmer && !isTech;
    final screens = isFarmer
        ? _farmerScreens
        : (isTech ? _technicianScreens : _ownerScreens);

    return Scaffold(
      body: Column(
        children: [
          if (farmProvider.syncError != null)
            Material(
              color: const Color(0xFFFEF3C7),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, size: 16, color: Color(0xFF92400E)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Không đồng bộ được: ${farmProvider.syncError}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                        ),
                      ),
                      TextButton(
                        onPressed: farmProvider.isLoadingApi ? null : farmProvider.fetchFromApi,
                        child: const Text('Thử lại', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        backgroundColor: Colors.white,
        elevation: 8,
        indicatorColor: const Color(0xFF10B981).withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Icon(
                isFarmer ? Icons.grass_outlined : (isTech ? Icons.precision_manufacturing_outlined : Icons.dashboard_outlined)),
            selectedIcon: Icon(
              isFarmer ? Icons.grass : (isTech ? Icons.precision_manufacturing : Icons.dashboard),
              color: const Color(0xFF062326),
            ),
            label: isFarmer ? 'Khu Vực' : (isTech ? 'Khảo Sát' : 'Trang Trại'),
          ),
          NavigationDestination(
            icon: Icon(isTech ? Icons.monitor_heart_outlined : Icons.eco_outlined),
            selectedIcon: Icon(isTech ? Icons.monitor_heart : Icons.eco, color: const Color(0xFF062326)),
            label: isTech ? 'Thiết Bị' : 'Cây Trồng',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map, color: Color(0xFF062326)),
            label: 'Bản Đồ',
          ),
          NavigationDestination(
            icon: Icon(isOwner ? Icons.psychology_outlined : Icons.assignment_outlined),
            selectedIcon: Icon(isOwner ? Icons.psychology : Icons.assignment, color: const Color(0xFF062326)),
            label: isOwner ? 'Trợ Lý AI' : 'Tác Vụ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Color(0xFF062326)),
            label: 'Hồ Sơ',
          ),
        ],
      ),
      // FAB for Device Health – chỉ hiện cho TECHNICIAN
      floatingActionButton: (_currentIndex == 0 && role == 'TECHNICIAN')
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const DeviceHealthScreen()),
              ),
              backgroundColor: const Color(0xFF062326),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.monitor_heart_outlined, size: 20),
              label: const Text('Device Health',
                  style:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              elevation: 4,
            )
          : null,
    );
  }
}
