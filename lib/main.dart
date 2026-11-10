import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'modules/evenements/entities/utilisateur_courant.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // sqflite fonctionne nativement sur Android/iOS. Sur PC (Windows/Linux),
  // on passe par sqflite_common_ffi pour pouvoir tester l'appli sans téléphone.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  // Module Événements : charge le dernier employé choisi (sera
  // synchronisé avec la vraie connexion dans AuthProvider).
  await UtilisateurCourant.charger();
  runApp(const SmartSpaceApp());
}

class SmartSpaceApp extends StatelessWidget {
  const SmartSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    // AuthProvider : état de session du module Utilisateurs, partagé
    // avec toute l'application (Session + HomeShell).
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'SmartSpace',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SplashScreen(),
      ),
