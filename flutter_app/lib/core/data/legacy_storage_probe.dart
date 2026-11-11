import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Reads only the three known Capacitor-origin storage keys needed to migrate
/// the existing Viril installation. It does not inspect unrelated website data.
class LegacyStorageProbe extends StatefulWidget {
  const LegacyStorageProbe({super.key, required this.onLoaded});
  final ValueChanged<Map<String, String>> onLoaded;

  @override
  State<LegacyStorageProbe> createState() => _LegacyStorageProbeState();
}

class _LegacyStorageProbeState extends State<LegacyStorageProbe> {
  late final WebViewController _webView;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _webView = WebViewController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _configure());
  }

  Future<void> _configure() async {
    try {
      await _webView.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _webView.addJavaScriptChannel(
        'VirilMigration',
        onMessageReceived: (message) {
          if (_sent) return;
          _sent = true;
          try {
            final decoded = jsonDecode(message.message);
            final values = <String, String>{};
            if (decoded is Map) {
              decoded.forEach((key, value) {
                if (value is String) values[key.toString()] = value;
              });
            }
            widget.onLoaded(values);
          } catch (_) {
            widget.onLoaded(const {});
          }
        },
      );
      await _webView.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _readKnownKeys(),
          onWebResourceError: (_) {
            if (!_sent) {
              _sent = true;
              widget.onLoaded(const {});
            }
          },
        ),
      );

      // Capacitor's default Android origin is https://localhost. Using that
      // exact origin lets WebView read the previous app's own localStorage.
      await _webView.loadHtmlString(
        '<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body></body></html>',
        baseUrl: 'https://localhost',
      );
    } catch (_) {
      if (!_sent) {
        _sent = true;
        widget.onLoaded(const {});
      }
    }
  }

  Future<void> _readKnownKeys() async {
    if (_sent) return;
    const script = r'''
      (() => {
        const keys = [
          'viril_self_development_v1',
          'viril_training_v1',
          'sb-pjewrbblgnchzlznlpld-auth-token'
        ];
        const result = {};
        for (const key of keys) {
          const value = window.localStorage.getItem(key);
          if (value !== null) result[key] = value;
        }
        window.VirilMigration.postMessage(JSON.stringify(result));
      })();
    ''';
    try {
      await _webView.runJavaScript(script);
    } catch (_) {
      if (!_sent) {
        _sent = true;
        widget.onLoaded(const {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      height: 1,
      child: WebViewWidget(controller: _webView),
    );
  }
}
