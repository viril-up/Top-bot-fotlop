import 'package:flutter/material.dart';
import '../../core/theme/viril_theme.dart';
import '../home/home_screen.dart';
import '../placeholders/section_screen.dart';

class VirilShell extends StatefulWidget {
  const VirilShell({super.key});

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
      const HomeScreen(),
      const SectionScreen(title: 'Ресурсы', subtitle: 'Библиотека, книги и материалы'),
      const SectionScreen(title: 'Развитие', subtitle: 'Тренировки, привычки и инструменты'),
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
        backgroundColor: VirilTheme.panel,
        indicatorColor: VirilTheme.blue.withValues(alpha: .15),
        destinations: [
          for (final item in destinations)
            NavigationDestination(icon: Icon(item.icon), label: item.label),
        ],
      ),
    );
  }
}
