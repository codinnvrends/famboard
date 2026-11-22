import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/warranty.dart';
import '../../ui/l10n_ext.dart';

/// A photo on the warranty page: either already stored (an id) or just
/// taken and not saved yet (bytes).
class PhotoRef {
  const PhotoRef.stored(String this.id, {this.kind = PhotoKind.other}) : bytes = null;
  const PhotoRef.fresh(Uint8List this.bytes, {this.kind = PhotoKind.other}) : id = null;
  const PhotoRef._(this.id, this.bytes, this.kind);

  final String? id;
  final Uint8List? bytes;

  /// Bill, warranty card or other.
  final PhotoKind kind;

  PhotoRef withKind(PhotoKind k) => PhotoRef._(id, bytes, k);
}

/// [short] fits a small thumbnail ("Card" instead of "Warranty card").
String photoKindLabel(BuildContext context, PhotoKind k, {bool short = false}) => switch (k) {
      PhotoKind.bill => context.l10n.photoKindBill,
      PhotoKind.card => short ? context.l10n.photoKindCardShort : context.l10n.photoKindCard,
      PhotoKind.other => context.l10n.photoKindOther,
    };

/// Loads a stored photo; shows a "syncing" placeholder until it arrives
/// from another phone, then swaps it in.
class StoredPhoto extends ConsumerStatefulWidget {
  const StoredPhoto({super.key, required this.id, this.fit = BoxFit.cover});

  final String id;
  final BoxFit fit;

  @override
  ConsumerState<StoredPhoto> createState() => _StoredPhotoState();
}

class _StoredPhotoState extends ConsumerState<StoredPhoto> {
  Uint8List? _bytes;
  bool _loading = true;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = ref.read(servicesProvider).blobs.added.listen((id) {
      if (id == widget.id && _bytes == null) _load();
    });
  }

  @override
  void didUpdateWidget(StoredPhoto old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    final bytes = await ref.read(servicesProvider).blobs.blob(session.familyId, widget.id);
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: widget.fit, gaplessPlayback: true);
    }
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: _loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_sync_outlined, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.photoNotSyncedYet,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

Widget photoWidget(PhotoRef p, {BoxFit fit = BoxFit.cover}) => p.id != null
    ? StoredPhoto(id: p.id!, fit: fit)
    : Image.memory(p.bytes!, fit: fit, gaplessPlayback: true);

/// A row of thumbnails. Tapping one opens the full-screen viewer.
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({
    super.key,
    required this.photos,
    this.onRemove,
    this.onKind,
    this.trailing,
    this.height = 96,
  });

  final List<PhotoRef> photos;

  /// Shows a remove button on each thumbnail (forms only).
  final void Function(int index)? onRemove;

  /// Lets the label be changed (forms only).
  final void Function(int index, PhotoKind kind)? onKind;

  /// Extra tile after the photos, e.g. "Add photo".
  final Widget? trailing;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final (i, p) in photos.indexed)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: height * 0.78,
                      height: height,
                      child: Material(
                        child: InkWell(
                          onTap: () => openPhotoViewer(context, photos, i),
                          child: photoWidget(p),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: _KindBadge(
                      kind: p.kind,
                      short: height < 120,
                      onChanged: onKind == null ? null : (k) => onKind!(i, k),
                    ),
                  ),
                  if (onRemove != null)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => onRemove!(i),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.close, size: 16, semanticLabel: context.l10n.removePhoto, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ?trailing,
        ],
      ),
    );
  }
}

/// The label on a thumbnail; a menu to change it when [onChanged] is set.
class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind, this.onChanged, this.short = false});

  final PhotoKind kind;
  final bool short;
  final ValueChanged<PhotoKind>? onChanged;

  @override
  Widget build(BuildContext context) {
    final label = photoKindLabel(context, kind, short: short);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          if (onChanged != null) const Icon(Icons.arrow_drop_down, size: 14, color: Colors.white),
        ],
      ),
    );
    if (onChanged == null) return chip;
    return PopupMenuButton<PhotoKind>(
      tooltip: context.l10n.photoKindChange,
      initialValue: kind,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final k in PhotoKind.values)
          PopupMenuItem(value: k, child: Text(photoKindLabel(context, k))),
      ],
      child: chip,
    );
  }
}

Future<void> openPhotoViewer(BuildContext context, List<PhotoRef> photos, int start) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _PhotoViewer(photos: photos, start: start),
      ),
    );

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.photos, required this.start});

  final List<PhotoRef> photos;
  final int start;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final _controller = PageController(initialPage: widget.start);
  late int _page = widget.start;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${photoKindLabel(context, widget.photos[_page].kind)} · ${_page + 1} / ${widget.photos.length}'),
      ),
      body: PageView(
        controller: _controller,
        onPageChanged: (p) => setState(() => _page = p),
        children: [
          for (final p in widget.photos)
            InteractiveViewer(
              maxScale: 6,
              child: Center(child: photoWidget(p, fit: BoxFit.contain)),
            ),
        ],
      ),
    );
  }
}
