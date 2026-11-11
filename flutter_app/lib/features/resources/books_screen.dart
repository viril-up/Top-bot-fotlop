import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/state/viril_controller.dart';
import '../../core/theme/viril_theme.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key, required this.controller});
  final VirilController controller;

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  List<_BookItem> _books = [];
  bool _loading = true;
  String? _error;
  String? _opening;
  String _query = '';

  String get _bucket => 'books';

  Future<Directory> _offlineDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(root.path + '/viril_books');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final storage = widget.controller.repository.client.storage.from(_bucket);
      final files = await storage.list();
      final visible = files.where((file) {
        final name = file.name;
        return name.isNotEmpty && !name.startsWith('.') &&
            (name.toLowerCase().endsWith('.pdf') || name.toLowerCase().endsWith('.epub'));
      }).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      Map<String, dynamic> catalog = {};
      try {
        final catalogFile = files.where((f) => f.name.toLowerCase() == 'catalog.json');
        if (catalogFile.isNotEmpty) {
          final bytes = await storage.download(catalogFile.first.name);
          final decoded = jsonDecode(utf8.decode(bytes));
          if (decoded is Map) {
            final data = decoded['books'] is Map ? decoded['books'] : decoded;
            catalog = Map<String, dynamic>.from(data as Map);
          }
        }
      } catch (_) {}

      final directory = await _offlineDirectory();
      final books = <_BookItem>[];
      for (final file in visible) {
        final name = file.name;
        final base = name.replaceFirst(RegExp(r'\.(pdf|epub)$', caseSensitive: false), '');
        final rawMeta = catalog[name] ?? catalog[base] ?? const {};
        final meta = rawMeta is Map ? Map<String, dynamic>.from(rawMeta) : <String, dynamic>{};
        final coverName = (meta['cover'] ?? '').toString();
        final coverFile = files.where((f) => f.name == coverName);
        String? coverUrl;
        if (coverName.isNotEmpty && coverFile.isNotEmpty) {
          coverUrl = storage.getPublicUrl(coverName);
        } else {
          final matchingCover = files.where((f) {
            final lower = f.name.toLowerCase();
            final stem = lower.replaceFirst(RegExp(r'\.(png|jpe?g|webp)$'), '');
            return stem == base.toLowerCase() &&
                (lower.endsWith('.png') || lower.endsWith('.jpg') ||
                 lower.endsWith('.jpeg') || lower.endsWith('.webp'));
          });
          if (matchingCover.isNotEmpty) coverUrl = storage.getPublicUrl(matchingCover.first.name);
        }
        final local = File(directory.path + '/' + name);
        books.add(_BookItem(
          name: name,
          title: (meta['title'] ?? _titleFromName(name)).toString(),
          author: (meta['author'] ?? '').toString(),
          description: (meta['description'] ?? meta['desc'] ?? '').toString(),
          coverUrl: coverUrl,
          localPath: await local.exists() ? local.path : null,
        ));
      }
      if (!mounted) return;
      setState(() { _books = books; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _error = error.toString(); _loading = false; });
    }
  }

  String _titleFromName(String name) => name
      .replaceFirst(RegExp(r'\.(pdf|epub)$', caseSensitive: false), '')
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .trim();

  Future<String> _download(_BookItem book, {required bool keepOffline}) async {
    final directory = keepOffline
        ? await _offlineDirectory()
        : await getTemporaryDirectory();
    final target = File(directory.path + '/' + book.name);
    if (await target.exists()) return target.path;
    final bytes = await widget.controller.repository.client.storage
        .from(_bucket).download(book.name);
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  Future<void> _saveOffline(_BookItem book) async {
    try {
      setState(() => _opening = book.name);
      final path = await _download(book, keepOffline: true);
      if (!mounted) return;
      setState(() {
        _books = _books.map((item) => item.name == book.name
          ? item.copyWith(localPath: path) : item).toList();
        _opening = null;
      });
      _message('Книга сохранена для офлайн-чтения');
    } catch (error) {
      if (!mounted) return;
      setState(() => _opening = null);
      _message('Не удалось сохранить книгу: ' + error.toString());
    }
  }

  Future<void> _open(_BookItem book) async {
    try {
      setState(() => _opening = book.name);
      final path = book.localPath ?? await _download(book, keepOffline: false);
      if (!mounted) return;
      setState(() => _opening = null);
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BookReaderScreen(
          title: book.title,
          path: path,
          isEpub: book.name.toLowerCase().endsWith('.epub'),
          isOffline: book.localPath != null,
        ),
      ));
    } catch (error) {
      if (!mounted) return;
      setState(() => _opening = null);
      _message('Не удалось открыть книгу: ' + error.toString());
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _books.where((book) {
      final q = _query.trim().toLowerCase();
      return q.isEmpty || book.title.toLowerCase().contains(q) ||
          book.author.toLowerCase().contains(q);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Книги'),
        actions: [
          IconButton(onPressed: _loading ? null : _load,
            tooltip: 'Обновить библиотеку', icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? _errorView()
          : _books.isEmpty
            ? _emptyView()
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Поиск по названию или автору',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Открывай книги из облака или сохраняй их на устройство для чтения без интернета.',
                      style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
                    ),
                  ),
                ),
                Expanded(child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final book = visible[index];
                    final busy = _opening == book.name;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 78, height: 108,
                              child: book.coverUrl == null
                                ? Container(
                                    color: VirilTheme.background,
                                    child: const Icon(Icons.menu_book_rounded,
                                      size: 34, color: VirilTheme.blue),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: book.coverUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: VirilTheme.background,
                                      child: const Icon(Icons.menu_book_rounded),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: VirilTheme.background,
                                      child: const Icon(Icons.menu_book_rounded),
                                    ),
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(book.title,
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                              if (book.author.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(book.author,
                                  style: const TextStyle(color: VirilTheme.blue, fontSize: 10)),
                              ],
                              if (book.description.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(book.description, maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white60, fontSize: 10, height: 1.35)),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                book.name.toLowerCase().endsWith('.pdf') ? 'PDF' : 'EPUB',
                                style: const TextStyle(color: Colors.white38, fontSize: 9),
                              ),
                              const SizedBox(height: 7),
                              Wrap(spacing: 7, runSpacing: 6, children: [
                                FilledButton(
                                  onPressed: busy ? null : () => _open(book),
                                  child: Text(busy ? 'Загрузка…' : 'Читать'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: busy || book.localPath != null
                                    ? null : () => _saveOffline(book),
                                  icon: Icon(book.localPath != null
                                    ? Icons.check_circle : Icons.download_rounded, size: 16),
                                  label: Text(book.localPath != null ? 'Офлайн' : 'Скачать'),
                                ),
                              ]),
                            ],
                          )),
                        ]),
                      ),
                    );
                  },
                )),
              ]),
    );
  }

  Widget _errorView() => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.cloud_off_rounded, size: 42, color: Colors.white54),
      const SizedBox(height: 12),
      const Text('Не удалось загрузить библиотеку',
        style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 7),
      Text(_error!, textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white54, fontSize: 11)),
      const SizedBox(height: 14),
      FilledButton(onPressed: _load, child: const Text('Повторить')),
    ]),
  ));

  Widget _emptyView() => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.auto_stories_rounded, size: 44, color: VirilTheme.blue),
      const SizedBox(height: 12),
      const Text('Пока нет книг', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 7),
      const Text('Добавь PDF или EPUB в корень bucket «books» в Supabase Storage.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.5)),
      const SizedBox(height: 14),
      FilledButton(onPressed: _load, child: const Text('Обновить')),
    ]),
  ));
}

class _BookItem {
  const _BookItem({
    required this.name,
    required this.title,
    required this.author,
    required this.description,
    required this.coverUrl,
    required this.localPath,
  });

  final String name;
  final String title;
  final String author;
  final String description;
  final String? coverUrl;
  final String? localPath;

  _BookItem copyWith({String? localPath}) => _BookItem(
    name: name, title: title, author: author, description: description,
    coverUrl: coverUrl, localPath: localPath ?? this.localPath,
  );
}

class BookReaderScreen extends StatefulWidget {
  const BookReaderScreen({
    super.key,
    required this.title,
    required this.path,
    required this.isEpub,
    required this.isOffline,
  });

  final String title;
  final String path;
  final bool isEpub;
  final bool isOffline;

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  PdfControllerPinch? _pdfController;
  EpubController? _epubController;
  String? _readerError;

  @override
  void initState() {
    super.initState();
    if (widget.isEpub) {
      _epubController = EpubController(
        document: EpubDocument.openFile(widget.path),
      );
    } else {
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(widget.path),
      );
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    _epubController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        if (widget.isOffline)
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.offline_pin_rounded, color: VirilTheme.green),
          ),
      ],
    ),
    drawer: widget.isEpub && _epubController != null
      ? Drawer(child: SafeArea(
          child: EpubViewTableOfContents(controller: _epubController!),
        ))
      : null,
    body: _readerError != null
      ? Center(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(_readerError!, textAlign: TextAlign.center),
        ))
      : widget.isEpub
        ? EpubView(
            controller: _epubController!,
            onDocumentError: (error) {
              if (mounted) setState(() => _readerError = error.toString());
            },
          )
        : PdfViewPinch(
            controller: _pdfController!,
            builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
              options: const DefaultBuilderOptions(),
              documentLoaderBuilder: (_) => const Center(
                child: CircularProgressIndicator(),
              ),
              pageLoaderBuilder: (_) => const Center(
                child: CircularProgressIndicator(),
              ),
              errorBuilder: (_, error) => Center(
                child: Text('Не удалось открыть PDF: ' + error.toString()),
              ),
            ),
          ),
  );
}
