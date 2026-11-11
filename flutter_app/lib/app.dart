import 'package:flutter/material.dart';
import 'core/theme/viril_theme.dart';
import 'features/shell/viril_shell.dart';

class VirilApp extends StatelessWidget {
  const VirilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Viril',
      debugShowCheckedModeBanner: false,
      theme: VirilTheme.dark,
      home: const VirilShell(),
    );
  }
}
