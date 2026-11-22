import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

import '../receipt/bill_scanner.dart';
import '../receipt/ocr_types.dart';
import 'warranty_parser.dart';

/// Photos of a bill or warranty card, read on the phone.
class WarrantyScan {
  const WarrantyScan(this.guess, this.photos);
  final WarrantyGuess guess;

  /// Compressed JPEGs, ready to store and sync.
  final List<Uint8List> photos;
}

/// Reads warranty paperwork with ML Kit (offline) and shrinks the photos so
/// they sync quickly: longest side 1600 px, JPEG, about 200–400 KB.
class WarrantyScanner {
  WarrantyScanner({required this.bills, WarrantyParser? parser}) : parser = parser ?? WarrantyParser();

  /// Camera and gallery capture are shared with bill scanning.
  final BillScanner bills;
  final WarrantyParser parser;

  static const maxSide = 1600;
  static const targetBytes = 400 * 1024;

  Future<WarrantyScan> read(List<String> paths) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final pages = <OcrPage>[];
      for (final path in paths) {
        try {
          final text = await recognizer.processImage(InputImage.fromFilePath(path));
          pages.add(BillScanner.toPage(text));
        } catch (e) {
          debugPrint('OCR failed for $path: $e');
        }
      }
      final photos = <Uint8List>[];
      for (final path in paths) {
        final small = await compressFile(path);
        if (small != null) photos.add(small);
      }
      return WarrantyScan(parser.parse(pages), photos);
    } finally {
      await recognizer.close();
    }
  }

  /// Shrinks a photo on a background isolate. Null if it can't be decoded.
  static Future<Uint8List?> compressFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return compute(compressBytes, bytes);
  }

  /// Decodes, turns upright, scales down and re-encodes until the photo is
  /// under [targetBytes] (or as small as sensible).
  static Uint8List? compressBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    var image = img.bakeOrientation(decoded);
    var side = maxSide;
    var quality = 75;
    Uint8List out;
    while (true) {
      final longest = image.width > image.height ? image.width : image.height;
      final scaled = longest > side
          ? (image.width >= image.height
              ? img.copyResize(image, width: side, interpolation: img.Interpolation.average)
              : img.copyResize(image, height: side, interpolation: img.Interpolation.average))
          : image;
      out = img.encodeJpg(scaled, quality: quality);
      if (out.length <= targetBytes || side <= 900) break;
      if (quality > 60) {
        quality -= 10;
      } else {
        side = (side * 0.8).round();
        image = scaled;
      }
    }
    return out;
  }
}
