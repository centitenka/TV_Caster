import 'package:flutter/material.dart';
import 'video_list_screen.dart';
import 'dlna_devices_screen.dart';
import 'rules_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const VideoListScreen(),
    const DLNADevicesScreen(),
    const RulesScreen(),
    const SettingsScreen(),
  ];

  final List<String> _titles = [
    '视频',
    '设备',
    '规则',
    '设置',
  ];

  final List<IconData> _icons = [
    Icons.video_library,
    Icons.cast_connected,
    Icons.rule_folder,
    Icons.settings,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: List.generate(
          _titles.length,
          (index) => NavigationDestination(
            icon: Icon(_icons[index]),
            label: _titles[index],
            selectedIcon: Icon(
              _icons[index],
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
