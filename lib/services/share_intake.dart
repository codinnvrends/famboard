import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Text shared into FamBoard from other apps, e.g. a bill SMS (spec FR-43).
/// Android only; on iOS users paste the text instead.
class ShareIntake {
  final _texts = StreamController<String>.broadcast();
  StreamSubscription<List<SharedMediaFile>>? _sub;
  String? _initial;

  Stream<String> get texts => _texts.stream;

  /// Text the app was launched with, if any (consumed once).
  String? takeInitial() {
    final t = _initial;
    _initial = null;
    return t;
  }

  Future<void> init() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      _initial = _firstText(initial);
      await ReceiveSharingIntent.instance.reset();
      _sub = ReceiveSharingIntent.instance.getMediaStream().listen((files) {
        final text = _firstText(files);
        if (text != null) _texts.add(text);
      });
    } catch (e) {
      debugPrint('Share intake unavailable: $e');
    }
  }

  static String? _firstText(List<SharedMediaFile> files) {
    for (final f in files) {
      if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) {
        final t = f.path.trim();
        if (t.isNotEmpty) return t;
      }
    }
    return null;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _texts.close();
  }
}
