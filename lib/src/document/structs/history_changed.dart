import 'package:flutter/foundation.dart' show immutable;

@immutable
class HistoryChanged {
  const HistoryChanged(
    this.changed,
    this.diff,
    this.retains,
  );

  final bool changed;
  final int diff;
  final int retains;
}
