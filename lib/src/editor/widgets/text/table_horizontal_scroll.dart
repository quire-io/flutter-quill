import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// Tolerance below which a table's content is treated as fitting its viewport
/// exactly, to avoid spurious clipping/scrolling from floating-point rounding.
/// Shared by the layout/paint clip and the scroll/gesture gate so they agree.
const double kTableOverflowEpsilon = 0.01;

/// How long the tap-to-reveal scroll indicator stays fully visible after the
/// user stops interacting, before it starts fading out.
const Duration _kIndicatorLingerDuration = Duration(milliseconds: 600);

/// How long the fade-out itself takes.
const Duration _kIndicatorFadeDuration = Duration(milliseconds: 300);

/// Shared horizontal scroll state for one table (a run of consecutive
/// table-row blocks). Every row of the same table registers its content
/// width here so all rows scroll in sync behind a single clamped offset.
///
/// Also owns the visibility of the tap-to-reveal scroll indicator: hidden by
/// default, shown the instant the user starts interacting with an
/// overflowing table, and faded out automatically once they stop.
///
/// Rows report their geometry during layout via [reportRowGeometry], which
/// must never call [notifyListeners] — doing so could trigger a relayout of
/// sibling rows while this table is still mid-layout.
class TableHorizontalScrollState extends ChangeNotifier {
  TableHorizontalScrollState({required TickerProvider vsync})
      : _fadeController = AnimationController(
          vsync: vsync,
          duration: _kIndicatorFadeDuration,
          value: 0,
        );

  double _offset = 0;
  final Map<RenderBox, double> _rowContentWidths = <RenderBox, double>{};
  final Map<RenderBox, double> _rowViewportWidths = <RenderBox, double>{};

  final AnimationController _fadeController;
  Timer? _fadeOutTimer;

  /// The current shared horizontal scroll offset. Always >= 0.
  double get offset => _offset;

  /// The maximum distance the table can be scrolled, based on whichever
  /// registered row currently overflows the most. Zero when every row fits.
  double get maxScrollExtent {
    var extent = 0.0;
    for (final entry in _rowContentWidths.entries) {
      final viewportWidth = _rowViewportWidths[entry.key] ?? 0;
      extent = math.max(extent, entry.value - viewportWidth);
    }
    // Treat sub-epsilon overflow (floating-point rounding on an exactly-fitting
    // table) as no overflow, so canScroll/hit-testing don't claim gestures for
    // a table that visually fits. Keeps this gate consistent with the paint
    // clip, which uses the same tolerance.
    return extent > kTableOverflowEpsilon ? extent : 0.0;
  }

  /// Whether any registered row currently overflows its viewport.
  bool get canScroll => maxScrollExtent > 0;

  /// Whether the offset can still move by [delta] in its direction, i.e. it is
  /// not already clamped at the corresponding extent. Used to decide whether a
  /// wheel/trackpad scroll should be claimed or left to a scrollable ancestor.
  bool canScrollBy(double delta) {
    if (delta > 0) return _offset < maxScrollExtent;
    if (delta < 0) return _offset > 0;
    return false;
  }

  /// Current opacity (0-1) of the tap-to-reveal scroll indicator.
  double get indicatorOpacity => _fadeController.value;

  /// Notifies listeners whenever [indicatorOpacity] changes.
  Listenable get indicatorListenable => _fadeController;

  /// Reveals the scroll indicator immediately and cancels any pending
  /// fade-out. Call when the user starts/continues interacting with an
  /// overflowing table.
  void showIndicator() {
    _fadeOutTimer?.cancel();
    _fadeOutTimer = null;
    _fadeController.value = 1;
  }

  /// After a short linger, fades the scroll indicator back out. Call once
  /// the user stops interacting (e.g. a drag ends, or a burst of wheel
  /// scrolling settles).
  void scheduleIndicatorFadeOut() {
    _fadeOutTimer?.cancel();
    _fadeOutTimer = Timer(_kIndicatorLingerDuration, () {
      _fadeOutTimer = null;
      _fadeController.reverse();
    });
  }

  /// Records [row]'s content width (`columnCount * cellWidth`) and available
  /// viewport width. Called from [RenderBox.performLayout] — must stay
  /// side-effect free with respect to the render tree: it never notifies
  /// listeners.
  void reportRowGeometry(
      RenderBox row, double contentWidth, double viewportWidth) {
    _rowContentWidths[row] = contentWidth;
    _rowViewportWidths[row] = viewportWidth;
  }

  /// Stops tracking [row], e.g. when it detaches from the render tree.
  void removeRow(RenderBox row) {
    _rowContentWidths.remove(row);
    _rowViewportWidths.remove(row);
  }

  /// Scrolls by [delta] logical pixels (positive moves content left),
  /// clamped to the valid scroll range.
  void scrollBy(double delta) => scrollTo(_offset + delta);

  /// Scrolls to an absolute [target] offset, clamped to the valid range.
  void scrollTo(double target) {
    final clamped = target.clamp(0.0, maxScrollExtent);
    if (clamped == _offset) return;
    _offset = clamped;
    notifyListeners();
  }

  @override
  void dispose() {
    _fadeOutTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }
}

/// Owns one [TableHorizontalScrollState] per table, keyed by a stable table
/// id, and reference-counts access so each state is disposed once every row
/// of that table has released it.
class TableScrollRegistry {
  TableScrollRegistry({required this.vsync});

  /// Drives the fade animation of every table's scroll indicator.
  final TickerProvider vsync;

  final Map<String, TableHorizontalScrollState> _states = {};
  final Map<String, int> _refCounts = {};

  /// Returns the shared scroll state for [tableKey], creating it on first
  /// use, and increments its reference count. Every call must be paired
  /// with a matching [release].
  TableHorizontalScrollState acquire(String tableKey) {
    final state = _states.putIfAbsent(
        tableKey, () => TableHorizontalScrollState(vsync: vsync));
    _refCounts[tableKey] = (_refCounts[tableKey] ?? 0) + 1;
    return state;
  }

  /// Decrements the reference count for [tableKey], disposing and removing
  /// its scroll state once no row references it anymore.
  void release(String tableKey) {
    final refCount = (_refCounts[tableKey] ?? 0) - 1;
    if (refCount <= 0) {
      _refCounts.remove(tableKey);
      _states.remove(tableKey)?.dispose();
    } else {
      _refCounts[tableKey] = refCount;
    }
  }

  /// Disposes every tracked scroll state, e.g. when the editor is disposed.
  void dispose() {
    for (final state in _states.values) {
      state.dispose();
    }
    _states.clear();
    _refCounts.clear();
  }
}
