import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

class ArtArchiveImporter {
  static Future<int> importBytes(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final directory = await getApplicationDocumentsDirectory();
    final artDirectory = Directory('${directory.path}/viril_art');
    if (!await artDirectory.exists()) {
      await artDirectory.create(recursive: true);
    }

    var imported = 0;
    for (final entry in archive.files) {
      final normalized = entry.name.replaceAll('\\', '/');
      final parts = normalized.split('/');
      final artIndex = parts.lastIndexOf('art');
      if (!entry.isFile ||
          !normalized.endsWith('.txt') ||
          artIndex < 0 ||
          artIndex != parts.length - 2 ||
          parts.any((part) => part == '..' || part == '.' || part.isEmpty)) {
        continue;
      }
      // Supports "art/<slug>.txt", "assets/art/<slug>.txt", and
      // "viril_training_module/art/<slug>.txt" archive layouts.
      final name = parts.last;
      if (name.length <= 4 || name.contains('/')) continue;
      final output = File('${artDirectory.path}/$name');
      final content = entry.content;
      if (content is List<int>) {
        await output.writeAsBytes(content, flush: false);
        imported++;
      }
    }
    return imported;
  }
}

class ArtAnimationWidget extends StatefulWidget {
  const ArtAnimationWidget({
    super.key,
    required this.slug,
    this.size = 112,
  });

  final String slug;
  final double size;

  @override
  State<ArtAnimationWidget> createState() => _ArtAnimationWidgetState();
}

class _ArtAnimationWidgetState extends State<ArtAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  late Future<List<Path>> _frames;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1560),
    )..repeat();
    _frames = _loadFrames();
  }

  @override
  void didUpdateWidget(covariant ArtAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug) _frames = _loadFrames();
  }

  Future<List<Path>> _loadFrames() async {
    if (widget.slug.isEmpty || widget.slug.contains('/') || widget.slug.contains('..')) {
      return [];
    }
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/viril_art/${widget.slug}.txt');
    if (!await file.exists()) return [];
    final lines = await file.readAsLines();
    final paths = <Path>[];
    for (final line in lines) {
      final data = line.trim();
      if (data.isEmpty) continue;
      try {
        paths.add(parseSvgPathData(data));
      } catch (_) {
        // Skip malformed frames but keep the remaining valid vector frames.
      }
    }
    return paths;
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Path>>(
      future: _frames,
      builder: (context, snapshot) {
        final paths = snapshot.data ?? const <Path>[];
        if (paths.isEmpty) {
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: const Center(
              child: Icon(Icons.fitness_center_rounded, color: Color(0xFF8BBBD8)),
            ),
          );
        }
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) => CustomPaint(
              painter: _ExerciseArtPainter(paths, _animation.value),
            ),
          ),
        );
      },
    );
  }
}

class _ExerciseArtPainter extends CustomPainter {
  _ExerciseArtPainter(this.frames, this.progress) {
    Rect? found;
    for (final path in frames) {
      final rect = path.getBounds();
      if (rect.isEmpty) continue;
      found = found == null ? rect : found.expandToInclude(rect);
    }
    final bounds = found ?? const Rect.fromLTWH(0, 0, 432, 432);
    final pad = (max(bounds.width, bounds.height) * .07).toDouble();
    _viewBox = bounds.inflate(pad);
  }

  final List<Path> frames;
  final double progress;
  late final Rect _viewBox;

  @override
  void paint(Canvas canvas, Size size) {
    if (frames.isEmpty || size.isEmpty) return;
    final scale = min(size.width / _viewBox.width, size.height / _viewBox.height).toDouble();
    final dx = (size.width - _viewBox.width * scale) / 2 - _viewBox.left * scale;
    final dy = (size.height - _viewBox.height * scale) / 2 - _viewBox.top * scale;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    if (frames.length == 1) {
      canvas.drawPath(frames.first, Paint()..color = const Color(0xFF8BBBD8));
    } else {
      final steps = (frames.length - 1) * 2;
      final position = progress * steps;
      final step = position.floor() % steps;
      final fraction = position - position.floor();
      final ascending = step < frames.length - 1;
      final from = ascending ? step : steps - step;
      final to = ascending ? from + 1 : from - 1;
      final raw = fraction < .72 ? 0.0 : (fraction - .72) / .28;
      final blend = raw * raw * (3 - 2 * raw);
      const color = Color(0xFF8BBBD8);

      canvas.drawPath(
        frames[from],
        Paint()..color = color.withValues(alpha: 1 - blend),
      );
      canvas.drawPath(
        frames[to],
        Paint()..color = color.withValues(alpha: blend),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ExerciseArtPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.frames != frames;
}
