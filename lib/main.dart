import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/home_shell.dart';
import 'reservations/ui/smartspace_style.dart';

void main() {
  // sqflite fonctionne nativement sur Android/iOS. Sur PC (Windows/Linux),
  // on passe par sqflite_common_ffi pour pouvoir tester l'appli sans téléphone.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const SmartSpaceApp());
}

class SmartSpaceApp extends StatelessWidget {
  const SmartSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartSpace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: SsColors.primaire),
        scaffoldBackgroundColor: SsColors.fond,
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}
