import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';

import '../data/presenze_portal.dart';
import '../data/stores.dart';
import '../domain/cartellino.dart';
import '../services.dart';

enum _Phase { login, loadingCartellino, extracting, saving, error }

/// Downloads the cartellino: the user logs in (SPID or CIE level 2) inside
/// the WebView, then the page is scraped by `assets/js/extract_cartellino.js`.
/// Pops `true` when a new cartellino has been saved.
///
/// Verified on iPhone with SPID; CIE is still to be checked (CLAUDE.md
/// § "Spike checklist").
class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key, required this.services, required this.year});

  final AppServices services;
  final int year;

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  late final WebViewController _controller;
  _Phase _phase = _Phase.login;
  String _status = 'Accedi con SPID o CIE';
  final _rows = <CartellinoRow>[];

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(PresenzePortal.jsChannel, onMessageReceived: _onMessage)
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: _onPageFinished))
      ..loadRequest(PresenzePortal.home);
  }

  Future<void> _onPageFinished(String url) async {
    switch (_phase) {
      case _Phase.login when PresenzePortal.isLoggedInUrl(url):
        setState(() {
          _phase = _Phase.loadingCartellino;
          _status = 'Accesso eseguito, apro il cartellino ${widget.year}…';
        });
        await _controller.setUserAgent(PresenzePortal.desktopUserAgent);
        await _controller.loadRequest(PresenzePortal.cartellinoUrl(widget.year));
      case _Phase.loadingCartellino when url.contains('page=cartellino'):
        setState(() {
          _phase = _Phase.extracting;
          _status = 'Lettura del cartellino…';
        });
        final script = await rootBundle.loadString('assets/js/extract_cartellino.js');
        await _controller.runJavaScript(script);
        await _controller.runJavaScript('window.__cartellino.run();');
      default:
        break;
    }
  }

  void _onMessage(JavaScriptMessage message) {
    final msg = jsonDecode(message.message) as Map<String, dynamic>;
    switch (msg['type']) {
      case 'page':
        try {
          _rows.addAll(_parsePage(msg));
          setState(() => _status = 'Letti ${_rows.length} giorni…');
        } on FormatException catch (e) {
          _fail(e.message);
        }
      case 'done':
        _save();
      case 'error':
        _fail(msg['message'] as String? ?? 'Errore sconosciuto');
    }
  }

  /// Maps the portal columns ("Stato", "Data", "Voci Base") to [CartellinoRow].
  List<CartellinoRow> _parsePage(Map<String, dynamic> msg) {
    final headers = (msg['headers'] as List<dynamic>).cast<String>();
    for (final required in const ['Stato', 'Data', 'Voci Base']) {
      if (!headers.contains(required)) {
        throw FormatException('Colonna "$required" assente. Colonne trovate: ${headers.join(', ')}');
      }
    }
    List<String> cell(Map<String, dynamic> row, String name) =>
        (row[name] as List<dynamic>? ?? const []).cast<String>();
    return [
      for (final r in (msg['rows'] as List<dynamic>).cast<Map<String, dynamic>>())
        CartellinoRow(
          stato: cell(r, 'Stato').join(' '),
          data: cell(r, 'Data').join(' '),
          vociBase: cell(r, 'Voci Base'),
        ),
    ];
  }

  Future<void> _save() async {
    if (_phase == _Phase.error) return;
    setState(() {
      _phase = _Phase.saving;
      _status = 'Salvataggio…';
    });
    try {
      // Validate before overwriting the cache: every date must parse.
      explodeRows(_rows, widget.year);
      await widget.services.cartellino.save(
        StoredCartellino(year: widget.year, fetchedAt: DateTime.now(), rows: List.of(_rows)),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _fail('Dati non validi: $e');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.error;
      _status = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final busy = _phase == _Phase.loadingCartellino ||
        _phase == _Phase.extracting ||
        _phase == _Phase.saving;
    return Scaffold(
      appBar: AppBar(title: Text('Aggiorna cartellino ${widget.year}')),
      body: Column(
        children: [
          Material(
            color: _phase == _Phase.error
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ListTile(
              leading: busy
                  ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator())
                  : Icon(_phase == _Phase.error ? Icons.error_outline : Icons.login),
              title: Text(_status),
            ),
          ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
