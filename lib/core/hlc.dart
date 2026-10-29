/// Hybrid logical clock (HLC).
///
/// Every change FamBoard writes carries an HLC timestamp. HLCs order events
/// across devices even when phone clocks disagree, and their string form sorts
/// lexicographically in the same order as the clock itself, so SQLite can
/// compare them with plain `>`.
///
/// String form: `<millis, 15 digits>:<counter, 4 hex>:<node id>`.
class Hlc implements Comparable<Hlc> {
  const Hlc(this.millis, this.counter, this.node)
      : assert(counter >= 0 && counter <= 0xffff);

  /// Wall-clock milliseconds since epoch.
  final int millis;

  /// Logical counter for events within the same millisecond.
  final int counter;

  /// Identifier of the device that produced this timestamp.
  final String node;

  static const int maxCounter = 0xffff;

  /// Largest drift we accept from a remote clock before refusing it (1 day).
  static const int maxDriftMillis = 24 * 60 * 60 * 1000;

  factory Hlc.zero(String node) => Hlc(0, 0, node);

  factory Hlc.parse(String value) {
    final parts = value.split(':');
    if (parts.length < 3) {
      throw FormatException('Invalid HLC: $value');
    }
    return Hlc(
      int.parse(parts[0]),
      int.parse(parts[1], radix: 16),
      parts.sublist(2).join(':'),
    );
  }

  @override
  String toString() =>
      '${millis.toString().padLeft(15, '0')}:'
      '${counter.toRadixString(16).padLeft(4, '0')}:$node';

  @override
  int compareTo(Hlc other) {
    if (millis != other.millis) return millis.compareTo(other.millis);
    if (counter != other.counter) return counter.compareTo(other.counter);
    return node.compareTo(other.node);
  }

  bool operator >(Hlc other) => compareTo(other) > 0;
  bool operator <(Hlc other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      other is Hlc &&
      other.millis == millis &&
      other.counter == counter &&
      other.node == node;

  @override
  int get hashCode => Object.hash(millis, counter, node);
}

/// A device's running hybrid logical clock.
class HlcClock {
  HlcClock(this.node, {int Function()? now, Hlc? last})
      : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
        _last = last ?? Hlc.zero(node);

  final String node;
  final int Function() _now;
  Hlc _last;

  Hlc get last => _last;

  /// Timestamp for a new local event.
  Hlc tick() {
    final wall = _now();
    if (wall > _last.millis) {
      _last = Hlc(wall, 0, node);
    } else {
      _last = Hlc(_last.millis, _nextCounter(_last.counter), node);
    }
    return _last;
  }

  /// Merges a timestamp received from another device so local events that
  /// follow it are ordered after it.
  void receive(Hlc remote) {
    final wall = _now();
    if (remote.millis - wall > Hlc.maxDriftMillis) {
      // A clock this far ahead is wrong; don't let it drag ours forward.
      return;
    }
    final maxMillis = [wall, _last.millis, remote.millis].reduce(
      (a, b) => a > b ? a : b,
    );
    int counter;
    if (maxMillis == _last.millis && maxMillis == remote.millis) {
      counter = _nextCounter(
        _last.counter > remote.counter ? _last.counter : remote.counter,
      );
    } else if (maxMillis == _last.millis) {
      counter = _nextCounter(_last.counter);
    } else if (maxMillis == remote.millis) {
      counter = _nextCounter(remote.counter);
    } else {
      counter = 0;
    }
    _last = Hlc(maxMillis, counter, node);
  }

  int _nextCounter(int counter) {
    if (counter >= Hlc.maxCounter) {
      throw StateError('HLC counter overflow');
    }
    return counter + 1;
  }
}
