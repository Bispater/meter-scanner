import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/services/auth_service.dart';
import 'presentation/providers/app_providers.dart';
import 'presentation/screens/home_screen.dart';
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

  final auth = AuthService();
  await auth.loadPersistedSession();

  runApp(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWith((ref) => auth),
      ],
      child: const MetscanApp(),
    ),
  );
}

class MetscanApp extends ConsumerWidget {
  const MetscanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    return MaterialApp(
      title: 'Metscan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: auth.isAuthenticated ? const HomeScreen() : const LoginScreen(),
    );
  }
}
