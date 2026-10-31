import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'bill_merger.dart';
import 'ocr_types.dart';
import 'receipt_parser.dart';

/// Photographs bills and reads them, all on the phone (no internet).
///
/// Camera capture uses ML Kit's document scanner (edge detection, crop,
/// several pages for a long bill). Text is read by ML Kit text recognition,
/// then [ReceiptParser] rebuilds rows and [BillMerger] joins pages.
class BillScanner {
  BillScanner({ReceiptParser? parser}) : parser = parser ?? ReceiptParser();

  final ReceiptParser parser;

  bool get canUseCameraScanner => Platform.isAndroid;

  /// Returns image paths, or an empty list if the person backed out.
  /// Throws [ScannerUnavailable] when Google Play services can't open the
  /// scanner (it downloads its module once, which needs internet).
  Future<List<String>> scanWithCamera() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(pageLimit: 10, mode: ScannerMode.full, isGalleryImport: true),
    );
    try {
      final result = await scanner.scanDocument();
      return result.images ?? const [];
    } on PlatformException catch (e) {
      if (e.code.toLowerCase().contains('cancel') || '${e.message}'.toLowerCase().contains('cancel')) return const [];
      throw ScannerUnavailable();
    } finally {
      await scanner.close();
    }
  }

  Future<List<String>> pickPhotos() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    return [
      for (final f in files)
        if (f.path != null) f.path!,
    ];
  }

  /// Reads each photo in order; overlapping photos of one long bill merge.
  /// [hindi] uses the Devanagari model, which also reads English.
  Future<ParsedBill> read(List<String> paths, {bool hindi = false}) async {
    final recognizer = TextRecognizer(script: hindi ? TextRecognitionScript.devanagiri : TextRecognitionScript.latin);
    try {
      final pages = <ParsedBill>[];
      for (final path in paths) {
        final text = await recognizer.processImage(InputImage.fromFilePath(path));
        pages.add(parser.parse(toPage(text)));
      }
      return const BillMerger().merge(pages);
    } finally {
      await recognizer.close();
    }
  }

  /// One fragment per recognised line, in image coordinates.
  static OcrPage toPage(RecognizedText text) {
    final frags = <OcrFragment>[];
    var w = 0.0, h = 0.0;
    for (final block in text.blocks) {
      for (final line in block.lines) {
        final r = line.boundingBox;
        frags.add(OcrFragment(line.text, r.left, r.top, r.right, r.bottom));
        if (r.right > w) w = r.right;
        if (r.bottom > h) h = r.bottom;
      }
    }
    return OcrPage(frags, width: w, height: h);
  }
}

class ScannerUnavailable implements Exception {}
