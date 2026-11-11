import 'package:flutter/material.dart';

class SectionScreen extends StatelessWidget {
  const SectionScreen({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.construction_rounded, size: 42, color: Colors.white54),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 12),
          const Text('Раздел подготовлен в архитектуре Flutter. Перенос исходной функциональности — следующий этап.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, height: 1.5)),
        ]),
      ),
    ),
  );
}
