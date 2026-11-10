import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/farm_provider.dart';
import 'services/api_service.dart';
import 'screens/home_screen.dart';
import 'screens/ai_screen.dart';
import 'screens/crop_profiles_screen.dart';
import 'screens/device_health_screen.dart';
import 'screens/gis_map_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/farmer_dashboard_screen.dart';
import 'screens/alerts_tasks_screen.dart';
import 'screens/landing_screen.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  HttpOverrides.global = MyHttpOverrides();
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

  @override
  void initState() {
    super.initState();
    _checkSavedAuth();
  }

  Future<void> _checkSavedAuth() async {
    final hasToken = await ApiService.loadSavedTokens();
    if (mounted) {
      setState(() => _isCheckingAuth = false);
      if (hasToken) {
        final provider = Provider.of<FarmProvider>(context, listen: false);
        if (ApiService.userRole != null) {
          final r = ApiService.userRole!.toUpperCase();
          if (r.contains('OWNER') || r.contains('ADMIN')) {
            provider.switchRole('OWNER');
          } else if (r.contains('TECH')) {
            provider.switchRole('TECHNICIAN');
          } else {
            provider.switchRole('FARMER');
          }
        }
        provider.fetchFromApi();
      }
    }
  }

  void _onLoginSuccess() {
    setState(() {});
    final provider = Provider.of<FarmProvider>(context, listen: false);
    if (ApiService.userRole != null) {
      final r = ApiService.userRole!.toUpperCase();
      if (r.contains('OWNER') || r.contains('ADMIN')) {
        provider.switchRole('OWNER');
      } else if (r.contains('TECH')) {
        provider.switchRole('TECHNICIAN');
      } else {
        provider.switchRole('FARMER');
      }
    }
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
      return LandingScreen(onLoginSuccess: _onLoginSuccess);
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
    final role = Provider.of<FarmProvider>(context).currentRole;
    final isFarmer = role == 'FARMER';
    final isTech = role == 'TECHNICIAN';
    final isOwner = !isFarmer && !isTech;
    final screens = isFarmer
        ? _farmerScreens
        : (isTech ? _technicianScreens : _ownerScreens);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
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
