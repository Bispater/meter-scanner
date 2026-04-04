import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/providers/app_providers.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  final container = ProviderContainer();

  // Initialize connectivity monitoring
  final connectivity = container.read(connectivityServiceProvider);
  await connectivity.init();

  // Initialize sync service (auto-syncs when online)
  final syncService = container.read(syncServiceProvider);
  await syncService.init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const HydroScanApp(),
    ),
  );
}

class HydroScanApp extends StatelessWidget {
  const HydroScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HydroScan Cam',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const LoginScreen(),
    );
  }
}
