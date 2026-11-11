import 'package:flutter/material.dart';

import '../../core/state/viril_controller.dart';
import '../home/home_screen.dart';
import '../growth/growth_screen.dart';
import '../placeholders/section_screen.dart';

class VirilShell extends StatefulWidget {
  const VirilShell({super.key, required this.controller});
  final VirilController controller;

  @override
  State<VirilShell> createState() => _VirilShellState();
}

class _VirilShellState extends State<VirilShell> {
  int index = 0;

  static const destinations = <({String label, IconData icon})>[
    (label: 'Главная', icon: Icons.home_rounded),
    (label: 'Ресурсы', icon: Icons.auto_stories_rounded),
    (label: 'Развитие', icon: Icons.rocket_launch_rounded),
    (label: 'Прогресс', icon: Icons.insights_rounded),
    (label: 'Лига', icon: Icons.emoji_events_rounded),
    (label: 'Профиль', icon: Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(controller: widget.controller, onNavigate: (value) => setState(() => index = value)),
      const SectionScreen(title: 'Ресурсы', subtitle: 'Книги и материалы из Supabase Storage'),
      GrowthScreen(controller: widget.controller),
      const SectionScreen(title: 'Прогресс', subtitle: 'История, аналитика и достижения'),
      const SectionScreen(title: 'Глобальная лига', subtitle: 'Мировой рейтинг и сезонные рекорды'),
      const SectionScreen(title: 'Профиль', subtitle: 'Аккаунт, аватар, настройки и синхронизация'),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: [
          for (final item in destinations)
            NavigationDestination(icon: Icon(item.icon), label: item.label),
        ],
      ),
    );
  }
}
