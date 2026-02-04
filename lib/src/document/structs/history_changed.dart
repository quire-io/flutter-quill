import 'package:flutter/foundation.dart' show immutable;

@immutable
class HistoryChanged {
  const HistoryChanged(
    this.changed,
    this.len,
    {this.isIndentChange = false}
  );

  final bool changed;
  final int len;

  // Potix #23917(8): Wether the change is related to indent attribute.
  // Should retain the cursor position for undo/redo indent changes.
  final bool isIndentChange;
}
