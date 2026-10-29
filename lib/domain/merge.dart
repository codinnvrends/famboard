import 'dart:convert';

import 'change.dart';

/// Per-field merge rules (spec section 5).
///
/// Every rule picks a winner by a total order over (value, clock), so the
/// result doesn't depend on the order changes arrive in. That is what lets two
/// phones that synced through different peers end up identical.
class MergeRules {
  const MergeRules();

  /// Applies [change] to [current] (or a new record). Returns true when the
  /// record changed.
  bool apply(RecordState state, Change change) {
    final field = change.field;
    final incomingClock = change.hlc.toString();
    final currentClock = state.clocks[field];

    if (currentClock == null) {
      state.fields[field] = change.value;
      state.clocks[field] = incomingClock;
      return true;
    }
    if (currentClock == incomingClock) {
      // Can't happen between honest devices (one clock per write), but keep
      // the result order-independent anyway by comparing the values.
      final a = jsonEncode(state.fields[field]);
      final b = change.valueJson;
      if (b.compareTo(a) <= 0) return false;
      state.fields[field] = change.value;
      return true;
    }

    final incomingWins = switch ((state.entity, field)) {
      ('entry', 'status') => _statusWins(
          state.fields[field],
          currentClock,
          change.value,
          incomingClock,
        ),
      _ => incomingClock.compareTo(currentClock) > 0,
    };
    if (!incomingWins) return false;
    state.fields[field] = change.value;
    state.clocks[field] = incomingClock;
    return true;
  }

  /// Status values are stored as `{"s": status, "e": epoch}`.
  ///
  /// Order: higher epoch wins (an explicit "reopen" bumps the epoch); within
  /// an epoch, done/cancelled beats open/in-progress/proposed, so a finished
  /// item never reopens by accident; otherwise the later clock wins.
  bool _statusWins(
    Object? current,
    String currentClock,
    Object? incoming,
    String incomingClock,
  ) {
    final a = StatusValue.fromJson(current);
    final b = StatusValue.fromJson(incoming);
    if (b.epoch != a.epoch) return b.epoch > a.epoch;
    final ta = a.isTerminal ? 1 : 0;
    final tb = b.isTerminal ? 1 : 0;
    if (tb != ta) return tb > ta;
    return incomingClock.compareTo(currentClock) > 0;
  }
}

/// Entry status as stored and synced.
class StatusValue {
  const StatusValue(this.status, this.epoch);

  final String status;
  final int epoch;

  static const terminal = {'done', 'cancelled'};

  bool get isTerminal => terminal.contains(status);

  factory StatusValue.fromJson(Object? json) {
    if (json is Map) {
      return StatusValue(
        json['s'] as String? ?? 'open',
        (json['e'] as num?)?.toInt() ?? 0,
      );
    }
    if (json is String) return StatusValue(json, 0);
    return const StatusValue('open', 0);
  }

  Map<String, Object?> toJson() => {'s': status, 'e': epoch};
}
