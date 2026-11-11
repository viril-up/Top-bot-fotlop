import 'package:flutter/material.dart';
import '../../core/theme/viril_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('VIRIL', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Chip(
                  avatar: const Icon(Icons.local_fire_department, color: Color(0xFFFFC875), size: 18),
                  label: const Text('0 дней'),
                  side: BorderSide(color: Colors.white.withValues(alpha: .1)),
                  backgroundColor: VirilTheme.panel,
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            sliver: SliverList.list(children: [
              const _WelcomeHeader(),
              const SizedBox(height: 18),
              const _LevelCard(),
              const SizedBox(height: 24),
              const Text('ТВОЙ ДЕНЬ', style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _FeatureCard(icon: Icons.check_circle_outline, title: 'Планы на сегодня', subtitle: 'Твои цели и ежедневные задачи', color: VirilTheme.blue, onTap: () {}),
              const SizedBox(height: 10),
              const Text('ИНСТРУМЕНТЫ', style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.55,
                children: const [
                  _MiniFeature(icon: Icons.menu_book_rounded, title: 'Дневник мыслей', caption: 'Записывай идеи'),
                  _MiniFeature(icon: Icons.timer_outlined, title: 'Фокус', caption: 'Работа и отдых'),
                  _MiniFeature(icon: Icons.bar_chart_rounded, title: 'Аналитика', caption: 'Изучай прогресс'),
                  _MiniFeature(icon: Icons.fitness_center_rounded, title: 'Тренировки', caption: 'Развивай силу'),
                ],
              ),
              const SizedBox(height: 18),
              const Text('Это первый Flutter-экран Viril 2.0. Данные и существующие функции будут подключаться поэтапно, без удаления старой версии.', style: TextStyle(color: Colors.white54, height: 1.5)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Твой следующий уровень начинается сегодня', style: TextStyle(fontSize: 25, height: 1.15, fontWeight: FontWeight.w800)),
      SizedBox(height: 7),
      Text('Маленькие действия. Большие изменения.', style: TextStyle(color: Colors.white60)),
    ],
  );
}

class _LevelCard extends StatelessWidget {
  const _LevelCard();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('ТВОЙ УРОВЕНЬ', style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1.3)),
          Icon(Icons.auto_awesome, color: VirilTheme.blue),
        ]),
        const SizedBox(height: 10),
        const Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('1', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900)),
          SizedBox(width: 9),
          Padding(padding: EdgeInsets.only(bottom: 7), child: Text('Новичок', style: TextStyle(color: VirilTheme.blue))),
          Spacer(),
          Padding(padding: EdgeInsets.only(bottom: 7), child: Text('0 / 100 XP', style: TextStyle(color: Colors.white60, fontSize: 12))),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: const LinearProgressIndicator(value: 0, minHeight: 7, backgroundColor: Color(0xFF30364B), color: VirilTheme.blue),
        ),
        const SizedBox(height: 8),
        const Text('100 XP до следующего уровня', style: TextStyle(color: Colors.white54, fontSize: 11)),
      ]),
    ),
  );
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(backgroundColor: color.withValues(alpha: .12), child: Icon(icon, color: color)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
    ),
  );
}

class _MiniFeature extends StatelessWidget {
  const _MiniFeature({required this.icon, required this.title, required this.caption});
  final IconData icon;
  final String title;
  final String caption;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: VirilTheme.violet, size: 22),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 3),
        Text(caption, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ]),
    ),
  );
}
