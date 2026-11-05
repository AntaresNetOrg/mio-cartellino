import 'package:flutter/material.dart';

import '../services.dart';
import 'dashboard_screen.dart';
import 'exit_time_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.services});

  final AppServices services;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _settingsTab = 2;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // First run: open Impostazioni (onboarding: year + min date for riposi).
    widget.services.settings.isFirstRun().then((first) {
      if (first && mounted) setState(() => _index = _settingsTab);
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(services: services),
          ExitTimeScreen(services: services),
          SettingsScreen(services: services),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Riepilogo',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: 'Uscita',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Impostazioni',
          ),
        ],
      ),
    );
  }
}
