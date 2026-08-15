import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_libraw/flutter_libraw.dart';
import 'package:image/image.dart' as img;

class RawDecoder {
  static const _rawExtensions = {
    'dng', 'cr2', 'cr3', 'nef', 'arw', 'raf', 'rw2',
    'orf', 'pef', 'srw', 'raw'
  };

  static Future<Uint8List> decodeToPreview(String path) async {
    final ext = path.split('.').last.toLowerCase();

    if (!_rawExtensions.contains(ext)) {
      final bytes = await File(path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('Format image non supporté');
      return Uint8List.fromList(img.encodeJpg(decoded, quality: 96));
    }

    if (!Platform.isAndroid) {
      throw UnsupportedError('Le décodage RAW de cette version cible Android.');
    }

    // LibRaw is compiled by GitHub Actions and packaged as
    // android/app/src/main/jniLibs/arm64-v8a/libraw.so.
    final dylib = DynamicLibrary.open('libraw.so');
    final bindings = FlutterLibRawBindings(dylib);
    final rawFile = File(path);
    final ptr = bindings.libraw_init(0);
    if (ptr.address == 0) throw Exception('libraw_init a échoué');

    try {
      final result = bindings.libraw_open_file(
        ptr,
        rawFile.absolute.path.toNativeUtf8().cast(),
      );
      if (result != 0) {
        throw Exception('LibRaw ne peut pas ouvrir ce fichier RAW ($result)');
      }

      final thumbResult = bindings.libraw_unpack_thumb(ptr);
      if (thumbResult != 0) {
        throw Exception('Aucun aperçu JPEG/thumbnail disponible dans ce RAW');
      }

      final bytes = pointerToUint8List(
        ptr.ref.thumbnail.thumb,
        ptr.ref.thumbnail.tlength,
      );
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('Thumbnail RAW invalide');

      return Uint8List.fromList(img.encodeJpg(decoded, quality: 96));
    } finally {
      bindings.libraw_close(ptr);
    }
  }
}
