import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:xml/xml.dart' as xml;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:epub_view/epub_view.dart' hide DefaultBuilderOptions;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdfx/pdfx.dart';

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

  static const List<_BookItem> _bundledBooks = [
    _BookItem(
      name: '118-dumay-medlenno-reshay-byistro.fb2',
      title: 'Думай медленно… решай быстро',
      author: 'Даниэль Канеман',
      description: 'Книга о мышлении, решениях и когнитивных ошибках.',
      coverUrl: null, localPath: null, isAsset: true,
      assetPath: 'assets/books/118-dumay-medlenno-reshay-byistro.fb2',
    ),
    _BookItem(
      name: '148322-samyiy-bogatyiy-chelovek-v-vavilone.fb2',
      title: 'Самый богатый человек в Вавилоне',
      author: 'Джордж Клейсон',
      description: 'Притчи о финансовой грамотности и привычках.',
      coverUrl: null, localPath: null, isAsset: true,
      assetPath: 'assets/books/148322-samyiy-bogatyiy-chelovek-v-vavilone.fb2',
    ),
    _BookItem(
      name: '30393-hitryiy-kak-lis-lovkiy-kak-tigr-36-kitayskih-stratagem-kotoryie-naucha.fb2',
      title: '36 китайских стратагем',
      author: 'Китайская классическая традиция',
      description: 'Исторический сборник о стратегиях и дипломатии.',
      coverUrl: null, localPath: null, isAsset: true,
      assetPath: 'assets/books/30393-hitryiy-kak-lis-lovkiy-kak-tigr-36-kitayskih-stratagem-kotoryie-naucha.fb2',
    ),
    _BookItem(
      name: '810-chernyiy-lebed-pod-znakom-nepredskazuemosti-sbornik.fb2',
      title: 'Чёрный лебедь',
      author: 'Нассим Николас Талеб',
      description: 'О редких событиях и неопределённости.',
      coverUrl: null, localPath: null, isAsset: true,
      assetPath: 'assets/books/810-chernyiy-lebed-pod-znakom-nepredskazuemosti-sbornik.fb2',
    ),
    _BookItem(
      name: '8365-stoitsizm-na-kazhdyiy-den-366-razmyishleniy-o-mudrosti-vole-i-iskusst.fb2',
      title: 'Стоицизм на каждый день',
      author: 'Райан Холидей и Стивен Хансельман',
      description: '366 размышлений о мудрости и самообладании.',
      coverUrl: null, localPath: null, isAsset: true,
      assetPath: 'assets/books/8365-stoitsizm-na-kazhdyiy-den-366-razmyishleniy-o-mudrosti-vole-i-iskusst.fb2',
    ),
  ];

  Future<Directory> _offlineDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(root.path + '/viril_books');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final books = List<_BookItem>.from(_bundledBooks);
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
      List<_BookItem> cached = [];
      try {
        cached = await _cachedBooks();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _books = [..._bundledBooks, ...cached];
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<List<_BookItem>> _cachedBooks() async {
    final directory = await _offlineDirectory();
    final entries = await directory.list().where((entry) => entry is File).toList();
    final result = <_BookItem>[];
    for (final entry in entries.whereType<File>()) {
      final name = entry.uri.pathSegments.isEmpty ? '' : entry.uri.pathSegments.last;
      final lower = name.toLowerCase();
      if (!lower.endsWith('.pdf') && !lower.endsWith('.epub')) continue;
      result.add(_BookItem(
        name: name,
        title: _titleFromName(name),
        author: '',
        description: 'Сохранено на устройстве · доступно офлайн',
        coverUrl: null,
        localPath: entry.path,
      ));
    }
    return result;
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
    if (book.isAsset) return;
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
      if (book.isAsset) {
        if (!mounted) return;
        setState(() => _opening = null);
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Fb2ReaderScreen(title: book.title, assetPath: book.assetPath!),
        ));
        return;
      }
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
        : _error != null && _books.isEmpty
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
                if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('Облачная библиотека сейчас недоступна. Встроенные книги остаются доступны офлайн.',
                    style: const TextStyle(color: Colors.white54, fontSize: 10)),
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
                                book.isAsset ? 'FB2 · ВСТРОЕНА' : (book.name.toLowerCase().endsWith('.pdf') ? 'PDF' : 'EPUB'),
                                style: const TextStyle(color: Colors.white38, fontSize: 9),
                              ),
                              const SizedBox(height: 7),
                              Wrap(spacing: 7, runSpacing: 6, children: [
                                FilledButton(
                                  onPressed: busy ? null : () => _open(book),
                                  child: Text(busy ? 'Загрузка…' : 'Читать'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: busy || book.isAsset || book.localPath != null
                                    ? null : () => _saveOffline(book),
                                  icon: Icon(book.localPath != null
                                    ? Icons.check_circle : Icons.download_rounded, size: 16),
                                  label: Text(book.isAsset ? 'В памяти' : (book.localPath != null ? 'Офлайн' : 'Скачать')),
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
    this.isAsset = false,
    this.assetPath,
  });

  final String name;
  final String title;
  final String author;
  final String description;
  final String? coverUrl;
  final String? localPath;
  final bool isAsset;
  final String? assetPath;

  _BookItem copyWith({String? localPath}) => _BookItem(
    name: name, title: title, author: author, description: description,
    coverUrl: coverUrl, localPath: localPath ?? this.localPath,
    isAsset: isAsset, assetPath: assetPath,
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
        document: EpubDocument.openFile(File(widget.path)),
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


class Fb2ReaderScreen extends StatefulWidget {
  const Fb2ReaderScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  @override
  State<Fb2ReaderScreen> createState() => _Fb2ReaderScreenState();
}

class _Fb2ReaderScreenState extends State<Fb2ReaderScreen> {
  late Future<List<_Fb2Block>> _content;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  double _fontSize = 17;
  double _lineHeight = 1.65;
  String _theme = 'dark';

  @override
  void initState() {
    super.initState();
    _content = _loadContent();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fontSize = prefs.getDouble('viril_reader_font_size') ?? 17;
      _lineHeight = prefs.getDouble('viril_reader_line_height') ?? 1.65;
      _theme = prefs.getString('viril_reader_theme') ?? 'dark';
    });
  }

  Future<List<_Fb2Block>> _loadContent() async {
    final source = await rootBundle.loadString(widget.assetPath);
    final document = xml.XmlDocument.parse(source);
    final bodies = document.findAllElements('body').toList();
    final body = bodies.isEmpty ? document.rootElement : bodies.first;
    final blocks = <_Fb2Block>[];

    void collect(xml.XmlNode node) {
      if (node is xml.XmlElement) {
        final tag = node.name.local.toLowerCase();
        if (tag == 'title') {
          final value = node.innerText.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (value.isNotEmpty) blocks.add(_Fb2Block(value, true));
          return;
        }
        if (tag == 'p') {
          final value = node.innerText.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (value.isNotEmpty) blocks.add(_Fb2Block(value, false));
          return;
        }
      }
      for (final child in node.children) {
        collect(child);
      }
    }

    collect(body);
    return blocks;
  }

  Color get _background => _theme == 'light'
      ? const Color(0xFFF4F1E8)
      : _theme == 'sepia'
          ? const Color(0xFFF0E1C5)
          : VirilTheme.background;

  Color get _foreground => _theme == 'dark'
      ? const Color(0xFFE9ECF5)
      : const Color(0xFF30291F);

  Future<void> _showSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: VirilTheme.panel,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Настройки чтения',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Row(children: [
                const Text('Размер текста'),
                const Spacer(),
                IconButton(onPressed: () => setSheetState(() =>
                  _fontSize = (_fontSize - 1).clamp(13, 28).toDouble()),
                  icon: const Icon(Icons.remove)),
                Text(_fontSize.toInt().toString()),
                IconButton(onPressed: () => setSheetState(() =>
                  _fontSize = (_fontSize + 1).clamp(13, 28).toDouble()),
                  icon: const Icon(Icons.add)),
              ]),
              Row(children: [
                const Text('Интервал строк'),
                const Spacer(),
                DropdownButton<double>(
                  value: _lineHeight,
                  items: const [
                    DropdownMenuItem(value: 1.4, child: Text('Компактный')),
                    DropdownMenuItem(value: 1.65, child: Text('Обычный')),
                    DropdownMenuItem(value: 1.9, child: Text('Свободный')),
                  ],
                  onChanged: (value) {
                    if (value != null) setSheetState(() => _lineHeight = value);
                  },
                ),
              ]),
              Row(children: [
                const Text('Оформление'),
                const Spacer(),
                DropdownButton<String>(
                  value: _theme,
                  items: const [
                    DropdownMenuItem(value: 'dark', child: Text('Тёмное')),
                    DropdownMenuItem(value: 'light', child: Text('Светлое')),
                    DropdownMenuItem(value: 'sepia', child: Text('Сепия')),
                  ],
                  onChanged: (value) {
                    if (value != null) setSheetState(() => _theme = value);
                  },
                ),
              ]),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Готово'),
              )),
            ]),
          ),
        ),
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('viril_reader_font_size', _fontSize);
    await prefs.setDouble('viril_reader_line_height', _lineHeight);
    await prefs.setString('viril_reader_theme', _theme);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: _background,
      foregroundColor: _foreground,
      title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(onPressed: _showSettings,
          tooltip: 'Настройки чтения', icon: const Icon(Icons.text_fields)),
      ],
    ),
    body: FutureBuilder<List<_Fb2Block>>(
      future: _content,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Не удалось прочитать FB2: ' + snapshot.error.toString()));
        }
        final all = snapshot.data ?? const <_Fb2Block>[];
        final query = _search.text.trim().toLowerCase();
        final blocks = query.isEmpty ? all : all.where((block) =>
          block.text.toLowerCase().contains(query)).toList();
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: _foreground, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Поиск по книге',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty ? null : IconButton(
                  onPressed: () { _search.clear(); setState(() {}); },
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ),
          Expanded(child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 36),
            itemCount: blocks.length,
            itemBuilder: (context, index) {
              final block = blocks[index];
              return Padding(
                padding: EdgeInsets.only(bottom: block.heading ? 14 : 11, top: block.heading ? 12 : 0),
                child: Text(
                  block.text,
                  textAlign: TextAlign.justify,
                  style: TextStyle(
                    color: _foreground,
                    fontSize: block.heading ? _fontSize + 2 : _fontSize,
                    fontWeight: block.heading ? FontWeight.w800 : FontWeight.w400,
                    height: _lineHeight,
                  ),
                ),
              );
            },
          )),
        ]);
      },
    ),
  );
}

class _Fb2Block {
  const _Fb2Block(this.text, this.heading);
  final String text;
  final bool heading;
}
