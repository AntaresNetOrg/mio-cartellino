import 'package:flutter/material.dart';

import 'services.dart';
import 'theme/unisa_theme.dart';
import 'ui/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.create();
  runApp(CartellinoApp(services: services));
}

class CartellinoApp extends StatelessWidget {
  const CartellinoApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mio Cartellino',
      theme: buildUnisaTheme(Brightness.light),
      darkTheme: buildUnisaTheme(Brightness.dark),
      home: HomeShell(services: services),
    );
  }
}
