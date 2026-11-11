import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/data/legacy_storage_probe.dart';
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
  final Completer<Map<String, String>> _legacyStorage = Completer();
  late final Future<void> initialization;

  @override
  void initState() {
    super.initState();
    controller = VirilController(
      VirilRepository(Supabase.instance.client),
    );
    initialization = _bootstrap();
  }

  Future<void> _bootstrap() async {
    Map<String, String> legacy = const {};
    try {
      legacy = await _legacyStorage.future.timeout(const Duration(seconds: 4));
    } catch (_) {
      // A fresh install or unsupported WebView simply starts without import.
    }
    await Future.wait([
      controller.initialize(legacyStorage: legacy),
      Future<void>.delayed(const Duration(seconds: 1)),
    ]);
  }

  void _onLegacyStorage(Map<String, String> values) {
    if (!_legacyStorage.isCompleted) _legacyStorage.complete(values);
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
      home: Stack(
        children: [
          Positioned.fill(
            child: FutureBuilder<void>(
              future: initialization,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _VirilSplash();
                }
                return VirilShell(controller: controller);
              },
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.01,
                child: SizedBox(
                  width: 1,
                  height: 1,
                  child: LegacyStorageProbe(onLoaded: _onLegacyStorage),
                ),
              ),
            ),
          ),
        ],
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
            Image.asset('assets/app_splash.png', width: 190, height: 100, fit: BoxFit.contain),
            SizedBox(height: 22),
            SizedBox(
              width: 130,
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Color(0xFF26334A),
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
