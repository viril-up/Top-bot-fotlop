import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/data/viril_repository.dart';
import 'core/state/viril_controller.dart';
import 'core/theme/viril_theme.dart';
import 'features/shell/viril_shell.dart';

class VirilApp extends StatefulWidget {
  const VirilApp({super.key});

  @override
  State<VirilApp> createState() => _VirilAppState();
}

class _VirilAppState extends State<VirilApp> {
  late final VirilController controller;
  late final Future<void> initialization;

  @override
  void initState() {
    super.initState();
    controller = VirilController(
      VirilRepository(Supabase.instance.client),
    );
    initialization = controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Viril',
      debugShowCheckedModeBanner: false,
      theme: VirilTheme.dark,
      home: FutureBuilder<void>(
        future: initialization,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _VirilSplash();
          }
          return VirilShell(controller: controller);
        },
      ),
    );
  }
}

class _VirilSplash extends StatelessWidget {
  const _VirilSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-.7, -.8),
            radius: 1.5,
            colors: [Color(0xFF1C2D4A), VirilTheme.background],
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('VIRIL', style: TextStyle(
              fontSize: 32, letterSpacing: 8, fontWeight: FontWeight.w900,
            )),
            SizedBox(height: 22),
            SizedBox(
              width: 130,
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Color(0xFF26334A),
                color: VirilTheme.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
