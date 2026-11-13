import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Something another app handed to FamBoard.
sealed class Shared {
  Shared() : id = _next++;
  static int _next = 0;
  final int id;
}

/// Text, e.g. a bill SMS shared from Messages (spec FR-43).
class SharedText extends Shared {
  SharedText(this.text);
  final String text;
}

/// A file, e.g. a backup opened from WhatsApp or a file manager.
class SharedFile extends Shared {
  SharedFile(this.path);
  final String path;
  Future<List<int>> read() => File(path).readAsBytes();
}

/// Receives shares and "Open with FamBoard" on Android. Each item is
/// handled once, by whichever screen claims it first.
class ShareIntake {
  final _items = StreamController<Shared>.broadcast();
  StreamSubscription<List<SharedMediaFile>>? _sub;
  Shared? _initial;
  final Set<int> _claimed = {};

  Stream<Shared> get items => _items.stream;

  /// What the app was launched with, if not yet handled.
  Shared? get pending => _initial != null && !_claimed.contains(_initial!.id) ? _initial : null;

  /// Returns true the first time [item] is claimed.
  bool claim(Shared item) => _claimed.add(item.id);

  Future<void> init() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      _initial = _first(await ReceiveSharingIntent.instance.getInitialMedia());
      await ReceiveSharingIntent.instance.reset();
      _sub = ReceiveSharingIntent.instance.getMediaStream().listen((files) {
        final item = _first(files);
        if (item != null) _items.add(item);
      });
    } catch (e) {
      debugPrint('Share intake unavailable: $e');
    }
  }

  static Shared? _first(List<SharedMediaFile> files) {
    for (final f in files) {
      final value = f.path.trim();
      if (value.isEmpty) continue;
      if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) {
        // A "url" from a file manager can be a file path.
        if (f.type == SharedMediaType.url && File(value).existsSync()) return SharedFile(value);
        return SharedText(value);
      }
      if (f.type == SharedMediaType.file) return SharedFile(value);
    }
    return null;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _items.close();
  }
}
