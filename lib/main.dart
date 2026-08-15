import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;

import 'services/raw_decoder.dart';
import 'services/photo_processor.dart';
import 'widgets/before_after.dart';

void main() => runApp(const RawEditorApp());

class RawEditorApp extends StatelessWidget {
  const RawEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI RAW Editor',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: const EditorPage(),
    );
  }
}

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  Uint8List? _original;
  Uint8List? _edited;
  String? _filename;
  bool _loading = false;
  double _exposure = 0;
  double _contrast = 0;
  double _highlights = 0;
  double _shadows = 0;
  double _temperature = 0;

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'dng', 'cr2', 'cr3', 'nef', 'arw', 'raf', 'rw2', 'orf', 'pef',
        'srw', 'raw', 'jpg', 'jpeg', 'png', 'webp'
      ],
      withData: false,
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _loading = true);
    try {
      final path = result.files.single.path!;
      final bytes = await RawDecoder.decodeToPreview(path);
      setState(() {
        _original = bytes;
        _edited = bytes;
        _filename = result.files.single.name;
        _resetAdjustments();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de décoder le fichier : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetAdjustments() {
    _exposure = 0;
    _contrast = 0;
    _highlights = 0;
    _shadows = 0;
    _temperature = 0;
  }

  Future<void> _render() async {
    if (_original == null) return;
    final source = img.decodeImage(_original!);
    if (source == null) return;

    final out = PhotoProcessor.process(
      source,
      exposure: _exposure,
      contrast: _contrast,
      highlights: _highlights,
      shadows: _shadows,
      temperature: _temperature,
    );
    setState(() => _edited = Uint8List.fromList(img.encodeJpg(out, quality: 96)));
  }

  Future<void> _autoAI() async {
    if (_original == null) return;
    setState(() => _loading = true);
    try {
      final source = img.decodeImage(_original!);
      if (source == null) throw Exception('Image invalide');

      final settings = PhotoProcessor.autoSettings(source);
      _exposure = settings.exposure;
      _contrast = settings.contrast;
      _highlights = settings.highlights;
      _shadows = settings.shadows;
      _temperature = settings.temperature;
      await _render();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export() async {
    if (_edited == null) return;
    try {
      final ok = await Gal.requestAccess();
      if (!ok) throw Exception('Accès à la galerie refusé');
      await Gal.putImageBytes(
        _edited!,
        name: 'AI_RAW_${DateTime.now().millisecondsSinceEpoch}',
        album: 'AI RAW Editor',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo exportée dans la galerie')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export impossible : $e')),
        );
      }
    }
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 92, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) * 10).round(),
            label: value.toStringAsFixed(1),
            onChanged: (v) {
              setState(() => onChanged(v));
              _render();
            },
          ),
        ),
        SizedBox(width: 42, child: Text(value.toStringAsFixed(1))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_filename ?? 'AI RAW Editor'),
        actions: [
          IconButton(
            tooltip: 'Importer',
            onPressed: _loading ? null : _import,
            icon: const Icon(Icons.folder_open),
          ),
          IconButton(
            tooltip: 'Exporter',
            onPressed: _edited == null ? null : _export,
            icon: const Icon(Icons.download),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _original == null
                ? _emptyState()
                : Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: BeforeAfterSlider(
                            before: _original!,
                            after: _edited ?? _original!,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(22),
                          ),
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _autoAI,
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text('Auto-Edit AI'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _slider('Exposition', _exposure, -3, 3,
                                (v) => _exposure = v),
                            _slider('Contraste', _contrast, -100, 100,
                                (v) => _contrast = v),
                            _slider('Hautes lumières', _highlights, -100, 100,
                                (v) => _highlights = v),
                            _slider('Ombres', _shadows, -100, 100,
                                (v) => _shadows = v),
                            _slider('Température', _temperature, -100, 100,
                                (v) => _temperature = v),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
      floatingActionButton: _original == null
          ? FloatingActionButton.extended(
              onPressed: _import,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Importer RAW'),
            )
          : null,
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_camera_outlined,
                size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20),
            const Text(
              'Éditeur RAW + amélioration automatique',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'DNG, CR2/CR3, NEF, ARW, RAF, RW2, ORF, PEF, SRW et images classiques.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _import,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choisir une photo'),
            ),
          ],
        ),
      ),
    );
  }
}
