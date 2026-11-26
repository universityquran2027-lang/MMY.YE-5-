import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/db/app_database.dart';
import 'core/theme.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/biometric_service.dart';
import 'features/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = await AppDatabase.open();
  final auth = AuthService(app);
  await auth.ensureDefaultAdmin(); // يعمل مرة واحدة فقط عند قاعدة جديدة
  runApp(MmyApp(app: app, auth: auth, bio: BiometricService()));
}

class MmyApp extends StatelessWidget {
  const MmyApp({super.key, required this.app, required this.auth, required this.bio});
  final AppDatabase app;
  final AuthService auth;
  final BiometricService bio;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الإعلام الحربي اليمني',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: LoginScreen(app: app, auth: auth, bio: bio),
    );
  }
}
