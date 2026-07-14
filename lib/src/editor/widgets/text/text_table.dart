import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../document/attribute.dart';
import '../../../document/nodes/block.dart';
import '../../editor.dart';
import '../box.dart';
import '../default_styles.dart';
import 'table_horizontal_scroll.dart';
import 'text_line.dart';
import 'text_selection.dart';

/// Tolerance below which a table's content is treated as fitting its
/// viewport exactly, to avoid spurious clipping/scrolling from floating
/// point rounding.
const double _kTableOverflowEpsilon = 0.01;

/// A specialized widget for rendering table blocks where each cell contains
/// an [EditableTextLine] that can be edited independently.
class EditableTextTable extends MultiChildRenderObjectWidget {
  const EditableTextTable({
    required this.block,
    required this.textDirection,
    required this.tableStyle,
    required this.tableKey,
    this.scrollRegistry,
    super.key,
    super.children,
  });

  final Block block;
  final TextDirection textDirection;
  final DefaultTableStyle tableStyle;

  /// Identifies which table (a run of consecutive table-row blocks) this
  /// row belongs to, so all of its rows share one horizontal scroll state.
  final String tableKey;

  /// Registry of shared horizontal scroll state, keyed by [tableKey]. Null
  /// disables horizontal scrolling: columns are still floored at
  /// [DefaultTableStyle.minCellWidth], but any overflow is simply clipped.
  final TableScrollRegistry? scrollRegistry;

  @override
  MultiChildRenderObjectElement createElement() => _TextTableElement(this);

  @override
  RenderEditableTextTable createRenderObject(BuildContext context) {
    return RenderEditableTextTable(
      block: block,
      textDirection: textDirection,
      tableStyle: tableStyle,
      scrollRegistry: scrollRegistry,
      tableKey: tableKey,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderEditableTextTable renderObject) {
    renderObject
      ..setContainer(block)
      ..textDirection = textDirection
      ..tableStyle = tableStyle
      ..setScrollContext(scrollRegistry, tableKey);
  }
}

class _TextTableElement extends MultiChildRenderObjectElement {
  _TextTableElement(EditableTextTable super.widget);

  @override
  RenderEditableTextTable get renderObject
  => super.renderObject as RenderEditableTextTable;
}

/// Render object for the table widget
class RenderEditableTextTable extends RenderEditableContainerBox
    implements RenderEditableBox {
  RenderEditableTextTable({
    required Block block,
    required super.textDirection,
    required String tableKey,
    DefaultTableStyle? tableStyle,
    TableScrollRegistry? scrollRegistry,
    super.children,
  })  : _tableStyle = tableStyle ?? const DefaultTableStyle(),
        // ignore: prefer_initializing_formals
        _tableKey = tableKey,
        // ignore: prefer_initializing_formals
        _scrollRegistry = scrollRegistry,
        super(
          container: block,
          scrollBottomInset: 0,
          padding: EdgeInsets.zero,
        );

  DefaultTableStyle _tableStyle;
  DefaultTableStyle get tableStyle => _tableStyle;

  set tableStyle(DefaultTableStyle value) {
    if (value == _tableStyle) return;
    final layoutChanged = value.cellPadding != _tableStyle.cellPadding ||
        value.minCellWidth != _tableStyle.minCellWidth;
    _tableStyle = value;
    if (layoutChanged) {
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
  }

  // --- Horizontal scroll (shared across every row of the same table) ---

  TableScrollRegistry? _scrollRegistry;
  String _tableKey;
  TableHorizontalScrollState? _scrollState;

  /// Cached results from the last [performLayout], reused by painting,
  /// hit-testing, and border drawing so they stay consistent with layout.
  double _cellWidth = 0;
  double _contentWidth = 0;
  double _rowShift = 0;

  /// This row's current per-column width, floored at
  /// [DefaultTableStyle.minCellWidth]. Exposed for widget tests only.
  @visibleForTesting
  double get cellWidthForTest => _cellWidth;

  /// This row's total content width (`cellWidth * columnCount`). Exposed for
  /// widget tests only.
  @visibleForTesting
  double get contentWidthForTest => _contentWidth;

  /// The horizontal shift currently applied to this row's cells to reflect
  /// the shared scroll offset. Exposed for widget tests only.
  @visibleForTesting
  double get rowShiftForTest => _rowShift;

  /// The current opacity (0-1) of the tap-to-reveal scroll indicator, or 0
  /// if there's no shared scroll state. Exposed for widget tests only.
  @visibleForTesting
  double get indicatorOpacityForTest => _scrollState?.indicatorOpacity ?? 0;

  /// The scroll indicator's thumb rect in this row's local coordinates, or
  /// `null` when nothing should be painted right now. Exposed for widget
  /// tests only.
  @visibleForTesting
  Rect? get scrollbarThumbRectForTest => _computeScrollbarGeometry();

  /// Updates which shared scroll state this row participates in. Called by
  /// [EditableTextTable.updateRenderObject] on every rebuild; a no-op when
  /// neither the registry nor the table key actually changed.
  void setScrollContext(TableScrollRegistry? registry, String tableKey) {
    if (identical(registry, _scrollRegistry) && tableKey == _tableKey) return;
    if (attached) _unsubscribeScroll();
    _scrollRegistry = registry;
    _tableKey = tableKey;
    if (attached) _subscribeScroll();
    markNeedsLayout();
  }

  void _subscribeScroll() {
    final state = _scrollRegistry?.acquire(_tableKey);
    _scrollState = state;
    state?.addListener(_onScrollChanged);
    state?.indicatorListenable.addListener(_onIndicatorChanged);
  }

  void _unsubscribeScroll() {
    final state = _scrollState;
    if (state == null) return;
    state
      ..removeListener(_onScrollChanged)
      ..indicatorListenable.removeListener(_onIndicatorChanged)
      ..removeRow(this);
    _scrollRegistry?.release(_tableKey);
    _scrollState = null;
  }

  void _onScrollChanged() => markNeedsLayout();

  void _onIndicatorChanged() => markNeedsPaint();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _subscribeScroll();
  }

  @override
  TextRange getLineBoundary(TextPosition position) {
    final child = childAtPosition(position);
    final rangeInChild = child.getLineBoundary(TextPosition(
      offset: position.offset - child.container.offset,
      affinity: position.affinity,
    ));
    return TextRange(
      start: rangeInChild.start + child.container.offset,
      end: rangeInChild.end + child.container.offset,
    );
  }

  @override
  Offset getOffsetForCaret(TextPosition position) {
    final child = childAtPosition(position);
    return child.getOffsetForCaret(TextPosition(
          offset: position.offset - child.container.offset,
          affinity: position.affinity,
        )) +
        (child.parentData as EditableContainerParentData).offset;
  }

  @override
  TextPosition getPositionForOffset(Offset offset) {
    final child = childAtOffset(offset);
    final parentData = child.parentData as EditableContainerParentData;
    final localPosition =
        child.getPositionForOffset(offset - parentData.offset);
    return TextPosition(
      offset: localPosition.offset + child.container.offset,
      affinity: localPosition.affinity,
    );
  }

  @override
  TextRange getWordBoundary(TextPosition position) {
    final child = childAtPosition(position);
    final nodeOffset = child.container.offset;
    final childWord = child
        .getWordBoundary(TextPosition(offset: position.offset - nodeOffset));
    return TextRange(
      start: childWord.start + nodeOffset,
      end: childWord.end + nodeOffset,
    );
  }

  @override
  TextPosition? getPositionAbove(TextPosition position) {
    assert(position.offset < container.length);

    final child = childAtPosition(position);
    final childLocalPosition =
        TextPosition(offset: position.offset - child.container.offset);
    final result = child.getPositionAbove(childLocalPosition);
    if (result != null) {
      return TextPosition(offset: result.offset + child.container.offset);
    }

    final sibling = childBefore(child);
    if (sibling == null) {
      return null;
    }

    final caretOffset = child.getOffsetForCaret(childLocalPosition);
    final testPosition = TextPosition(offset: sibling.container.length - 1);
    final testOffset = sibling.getOffsetForCaret(testPosition);
    final finalOffset = Offset(caretOffset.dx, testOffset.dy);
    return TextPosition(
        offset: sibling.container.offset +
            sibling.getPositionForOffset(finalOffset).offset);
  }

  @override
  TextPosition? getPositionBelow(TextPosition position) {
    assert(position.offset < container.length);

    final child = childAtPosition(position);
    final childLocalPosition =
        TextPosition(offset: position.offset - child.container.offset);
    final result = child.getPositionBelow(childLocalPosition);
    if (result != null) {
      return TextPosition(offset: result.offset + child.container.offset);
    }

    final sibling = childAfter(child);
    if (sibling == null) {
      return null;
    }

    final caretOffset = child.getOffsetForCaret(childLocalPosition);
    final testOffset = sibling.getOffsetForCaret(const TextPosition(offset: 0));
    final finalOffset = Offset(caretOffset.dx, testOffset.dy);
    return TextPosition(
        offset: sibling.container.offset +
            sibling.getPositionForOffset(finalOffset).offset);
  }

  @override
  double preferredLineHeight(TextPosition position) {
    final child = childAtPosition(position);
    return child.preferredLineHeight(
        TextPosition(offset: position.offset - child.container.offset));
  }

  @override
  TextSelectionPoint getBaseEndpointForSelection(TextSelection selection) {
    if (selection.isCollapsed) {
      return TextSelectionPoint(
        Offset(0, preferredLineHeight(selection.extent)) +
            getOffsetForCaret(selection.extent),
        null,
      );
    }

    final baseNode = container
        .queryChild(
          selection.start,
          false,
        )
        .node;
    var baseChild = firstChild;
    while (baseChild != null) {
      if (baseChild.container == baseNode) {
        break;
      }
      baseChild = childAfter(baseChild);
    }
    assert(baseChild != null);

    final basePoint = baseChild!.getBaseEndpointForSelection(
      localSelection(
        baseChild.container,
        selection,
        true,
      ),
    );
    return TextSelectionPoint(
      basePoint.point + (baseChild.parentData as EditableContainerParentData).offset,
      basePoint.direction,
    );
  }

  @override
  TextSelectionPoint getExtentEndpointForSelection(TextSelection selection) {
    if (selection.isCollapsed) {
      return TextSelectionPoint(
        Offset(0, preferredLineHeight(selection.extent)) +
            getOffsetForCaret(selection.extent),
        null,
      );
    }

    final extentNode = container.queryChild(selection.end, false).node;

    var extentChild = firstChild;
    while (extentChild != null) {
      if (extentChild.container == extentNode) {
        break;
      }
      extentChild = childAfter(extentChild);
    }
    assert(extentChild != null);

    final extentPoint = extentChild!.getExtentEndpointForSelection(
      localSelection(
        extentChild.container,
        selection,
        true,
      ),
    );
    return TextSelectionPoint(
      extentPoint.point + (extentChild.parentData as EditableContainerParentData).offset,
      extentPoint.direction,
    );
  }

  @override
  void detach() {
    _unsubscribeScroll();
    _dragRecognizer?.dispose();
    _dragRecognizer = null;
    super.detach();
    markNeedsPaint();
  }

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    super.dispose();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! EditableContainerParentData) {
      child.parentData = EditableContainerParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final cellPadding = tableStyle.cellPadding;
    final paddingWidth = cellPadding.horizontal;

    var totalWidth = 0.0;
    var child = firstChild;
    while (child != null) {
      totalWidth += math.max(
        child.getMinIntrinsicWidth(height) + paddingWidth,
        tableStyle.minCellWidth,
      );
      child = childAfter(child);
    }
    return totalWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final cellPadding = tableStyle.cellPadding;
    final paddingWidth = cellPadding.horizontal;

    var totalWidth = 0.0;
    var child = firstChild;
    while (child != null) {
      totalWidth += math.max(
        child.getMaxIntrinsicWidth(height) + paddingWidth,
        tableStyle.minCellWidth,
      );
      child = childAfter(child);
    }
    return totalWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (childCount == 0) return 0;

    final cellPadding = tableStyle.cellPadding;
    final paddingWidth = cellPadding.horizontal;
    final paddingHeight = cellPadding.vertical;

    final cellWidth = math.max<double>(
        0, math.max(width / childCount, tableStyle.minCellWidth) - paddingWidth);
    var maxHeight = 0.0;
    var child = firstChild;
    while (child != null) {
      maxHeight = math.max(
          maxHeight, child.getMinIntrinsicHeight(cellWidth) + paddingHeight);
      child = childAfter(child);
    }
    return maxHeight;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (childCount == 0) return 0;

    final cellPadding = tableStyle.cellPadding;
    final paddingWidth = cellPadding.horizontal;
    final paddingHeight = cellPadding.vertical;

    final cellWidth = math.max<double>(
        0, math.max(width / childCount, tableStyle.minCellWidth) - paddingWidth);
    var maxHeight = 0.0;
    var child = firstChild;
    while (child != null) {
      maxHeight = math.max(
          maxHeight, child.getMaxIntrinsicHeight(cellWidth) + paddingHeight);
      child = childAfter(child);
    }
    return maxHeight;
  }

  @override
  void performLayout() {
    assert(constraints.hasBoundedWidth);

    if (childCount == 0) {
      _cellWidth = 0;
      _contentWidth = 0;
      _rowShift = 0;
      size = constraints.constrain(Size.zero);
      return;
    }

    // Get cell padding from table style
    final cellPadding = tableStyle.cellPadding;
    final paddingWidth = cellPadding.horizontal;
    final paddingHeight = cellPadding.vertical;

    // Calculate cell width by evenly dividing the available width, floored
    // at the configured minimum so columns don't squeeze to unreadable
    // widths on narrow screens; the table scrolls horizontally instead.
    final cellWidth =
        math.max(constraints.maxWidth / childCount, tableStyle.minCellWidth);
    final contentWidth = cellWidth * childCount;

    // Report this row's geometry to the shared scroll state (if any), so
    // sibling rows of the same table know how far the table can scroll.
    // This must stay side-effect free w.r.t. the render tree: it never
    // notifies listeners, since a sibling row may still be mid-layout.
    _scrollState?.reportRowGeometry(this, contentWidth, constraints.maxWidth);
    final rowShift = math.min<double>(
      _scrollState?.offset ?? 0,
      math.max(0, contentWidth - constraints.maxWidth),
    );

    _cellWidth = cellWidth;
    _contentWidth = contentWidth;
    _rowShift = rowShift;

    // Create constraints for each cell, accounting for padding
    final cellConstraints = BoxConstraints(
      minWidth: math.max(0, cellWidth - paddingWidth),
      maxWidth: math.max(0, cellWidth - paddingWidth),
      minHeight: 0,
      maxHeight: math.max(0, constraints.maxHeight - paddingHeight),
    );

    var child = firstChild;
    var currentX = 0.0;
    var maxHeight = 0.0;

    // Layout each child and position them horizontally with padding, then
    // shift everything left by the shared horizontal scroll offset.
    while (child != null) {
      child.layout(cellConstraints, parentUsesSize: true);
      (child.parentData as EditableContainerParentData).offset = Offset(
        currentX + cellPadding.left - rowShift,
        cellPadding.top,
      );

      // Include padding in height calculation
      maxHeight = math.max(maxHeight, child.size.height + paddingHeight);
      currentX += cellWidth;

      child = childAfter(child);
    }

    // The table's own size always matches the viewport; overflowing content
    // scrolls beneath it (see paint()).
    size = constraints.constrain(Size(constraints.maxWidth, maxHeight));
  }

  final LayerHandle<ClipRectLayer> _clipRectLayer =
      LayerHandle<ClipRectLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    // Paint striped background first (if applicable)
    _paintStripedBackground(context, offset);

    // Paint children next, clipping to the row's own bounds whenever the
    // scrolled content is wider than the viewport.
    if (_contentWidth > size.width + _kTableOverflowEpsilon) {
      _clipRectLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        defaultPaint,
        oldLayer: _clipRectLayer.layer,
      );
    } else {
      _clipRectLayer.layer = null;
      defaultPaint(context, offset);
    }

    // Paint borders last
    _paintBorders(context, offset);

    // Paint the tap-to-reveal scroll indicator on top (last row only).
    _paintScrollbar(context, offset);
  }

  void _paintStripedBackground(PaintingContext context, Offset offset) {
    if (childCount == 0) return;

    // Calculate row index by counting previous table blocks
    var rowIndex = 0;
    var prevBlock = container.previous;

    // Count previous table rows
    while (prevBlock != null &&
           prevBlock is Block &&
           prevBlock.style.attributes.containsKey(Attribute.table.key)) {
      rowIndex++;
      prevBlock = prevBlock.previous;
    }

    // Apply striped background to even rows (excluding row 0 which is header)
    // Row index 2, 4, 6... will get the stripe (visually rows 3, 5, 7...)
    final stripeColor = tableStyle.stripeColor;
    final shouldApplyStripe = rowIndex > 1 && rowIndex % 2 == 0;
    if (shouldApplyStripe && stripeColor != null) {
      final canvas = context.canvas;
      final tableRect = offset & size;

      // Use the stripe color from table style
      final stripePaint = Paint()
        ..color = stripeColor
        ..style = PaintingStyle.fill;

      canvas.drawRect(tableRect, stripePaint);
    }
  }

  /// Whether this row is the last row of its table, i.e. the immediately
  /// following block is not also a table row. A table is a run of
  /// consecutive table blocks (matches [_paintStripedBackground] and the
  /// tableKey derivation in text_block.dart).
  bool get isLastTableRow {
    final nextBlock = container.next;
    return !(nextBlock is Block &&
        nextBlock.style.attributes.containsKey(Attribute.table.key));
  }

  void _paintBorders(PaintingContext context, Offset offset) {
    if (childCount == 0) return;

    final canvas = context.canvas;
    final tableRect = offset & size;

    // Use the tableStyle for painting
    final border = tableStyle.border;

    // Draw outer border
    if (border.top.width > 0) {
      final paint = Paint()
        ..color = border.top.color
        ..strokeWidth = border.top.width
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(tableRect.left, tableRect.top),
        Offset(tableRect.right, tableRect.top),
        paint,
      );
    }

    // Only the last row draws a bottom border, to avoid doubling it up
    // against the next row's top border.
    final shouldDrawBottomBorder = border.bottom.width > 0 && isLastTableRow;

    if (shouldDrawBottomBorder) {
      final paint = Paint()
        ..color = border.bottom.color
        ..strokeWidth = border.bottom.width
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(tableRect.left, tableRect.bottom),
        Offset(tableRect.right, tableRect.bottom),
        paint,
      );
    }

    if (border.left.width > 0) {
      final paint = Paint()
        ..color = border.left.color
        ..strokeWidth = border.left.width
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(tableRect.left, tableRect.top),
        Offset(tableRect.left, tableRect.bottom),
        paint,
      );
    }

    if (border.right.width > 0) {
      final paint = Paint()
        ..color = border.right.color
        ..strokeWidth = border.right.width
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(tableRect.right, tableRect.top),
        Offset(tableRect.right, tableRect.bottom),
        paint,
      );
    }

    // Draw vertical separators between cells using verticalInside border,
    // accounting for the current horizontal scroll offset. Separators that
    // land outside the row's own bounds (scrolled past either edge) are
    // skipped since the clip in paint() would hide them anyway.
    if (border.verticalInside.width > 0 && _cellWidth > 0) {
      final paint = Paint()
        ..color = border.verticalInside.color
        ..strokeWidth = border.verticalInside.width
        ..style = PaintingStyle.stroke;

      for (var i = 1; i < childCount; i++) {
        final x = offset.dx + i * _cellWidth - _rowShift;
        if (x <= tableRect.left || x >= tableRect.right) continue;
        canvas.drawLine(
          Offset(x, offset.dy),
          Offset(x, offset.dy + size.height),
          paint,
        );
      }
    }
  }

  /// Computes the tap-to-reveal scroll indicator's thumb rect in this row's
  /// local coordinates, or `null` when nothing should be painted (not the
  /// last row, the table fits, the indicator is disabled, or it's not
  /// currently visible).
  ///
  /// Geometry is derived from the shared [_scrollState] (table-wide extent
  /// and offset) rather than this row's own `_contentWidth`/`_rowShift`,
  /// since a ragged table's last row may overflow less than its siblings —
  /// or not at all — while the table as a whole still scrolls.
  Rect? _computeScrollbarGeometry() {
    if (!tableStyle.scrollbarEnabled) return null;
    final scrollState = _scrollState;
    if (scrollState == null || !scrollState.canScroll) return null;
    if (!isLastTableRow) return null;
    if (scrollState.indicatorOpacity <= 0) return null;

    final thickness = tableStyle.scrollbarThickness;
    if (thickness <= 0) return null;
    if (size.isEmpty) return null;

    const horizontalInset = 2.0;
    const trackLeft = horizontalInset;
    final trackRight = size.width - horizontalInset;
    final trackWidth = trackRight - trackLeft;
    if (trackWidth <= 0) return null;

    final maxScrollExtent = scrollState.maxScrollExtent;
    final visibleFraction = size.width / (size.width + maxScrollExtent);
    final thumbWidth = math.min(
      trackWidth,
      math.max(
          trackWidth * visibleFraction, tableStyle.scrollbarMinThumbWidth),
    );
    final scrollFraction =
        (scrollState.offset / maxScrollExtent).clamp(0.0, 1.0);
    final thumbLeft = trackLeft + (trackWidth - thumbWidth) * scrollFraction;
    final thumbTop = size.height - tableStyle.scrollbarBottomPadding - thickness;

    return Rect.fromLTWH(thumbLeft, thumbTop, thumbWidth, thickness);
  }

  void _paintScrollbar(PaintingContext context, Offset offset) {
    final thumb = _computeScrollbarGeometry();
    if (thumb == null) return;

    final opacity = _scrollState!.indicatorOpacity;
    // Normally already resolved to a concrete color by text_block.dart (the
    // sole place with a BuildContext to resolve "auto"); this fallback only
    // matters for a DefaultTableStyle constructed and painted directly,
    // bypassing that resolution.
    final color =
        tableStyle.scrollbarColor ?? DefaultTableStyle.defaultLightScrollbarColor;
    final radius = Radius.circular(tableStyle.scrollbarThickness / 2);
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(thumb.shift(offset), radius),
      Paint()..color = color.withValues(alpha: color.a * opacity),
    );
  }

  @override
  bool hitTestSelf(Offset position) => _scrollState?.canScroll ?? false;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  /// Override childAtOffset to handle horizontal table layout instead of vertical.
  ///
  /// The base class [RenderEditableContainerBox.childAtOffset] assumes children
  /// are laid out vertically, but table cells are laid out horizontally.
  @override
  RenderEditableBox childAtOffset(Offset offset) {
    assert(firstChild != null);

    if (childCount == 0 || _cellWidth <= 0) {
      return firstChild!;
    }

    // For horizontal layout, we need to check the x-coordinate, accounting
    // for the current horizontal scroll offset.
    final cellIndex = ((offset.dx + _rowShift) / _cellWidth)
        .floor()
        .clamp(0, childCount - 1);

    // Find the child at the calculated index
    var child = firstChild;
    for (var i = 0; i < cellIndex && child != null; i++) {
      child = childAfter(child);
    }

    return child ?? lastChild!;
  }

  // --- Horizontal drag-to-scroll / wheel-to-scroll gestures ---
  //
  // Gestures are only claimed while the table actually overflows its
  // viewport ([TableHorizontalScrollState.canScroll]); a table that fits
  // never intercepts pointer events. The drag recognizer only accepts
  // touch/stylus/trackpad devices — mouse drags are left to the editor's
  // own (mouse-only) selection drag recognizer, so desktop text selection
  // is unaffected.
  HorizontalDragGestureRecognizer? _dragRecognizer;

  HorizontalDragGestureRecognizer _ensureDragRecognizer() {
    final existing = _dragRecognizer;
    if (existing != null) return existing;

    final recognizer = HorizontalDragGestureRecognizer(
      debugOwner: this,
      supportedDevices: const {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
      },
    )
      ..dragStartBehavior = DragStartBehavior.down
      ..onStart = (_) {
        _scrollState?.showIndicator();
      }
      ..onUpdate = (details) {
        final state = _scrollState;
        state?.scrollBy(-details.delta.dx);
        state?.showIndicator();
      }
      ..onEnd = (_) {
        _scrollState?.scheduleIndicatorFadeOut();
      }
      ..onCancel = () {
        _scrollState?.scheduleIndicatorFadeOut();
      };
    _dragRecognizer = recognizer;
    return recognizer;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    assert(debugHandleEvent(event, entry));
    final scrollState = _scrollState;
    if (scrollState == null || !scrollState.canScroll) return;

    if (event is PointerDownEvent) {
      _ensureDragRecognizer().addPointer(event);
    } else if (event is PointerPanZoomStartEvent) {
      _ensureDragRecognizer().addPointerPanZoom(event);
    } else if (event is PointerScrollEvent &&
        event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()) {
      GestureBinding.instance.pointerSignalResolver
          .register(event, _handlePointerScroll);
    }
  }

  void _handlePointerScroll(PointerEvent event) {
    if (event is PointerScrollEvent) {
      // Each wheel/trackpad tick is discrete (no clean start/end pairing
      // like a drag has), so re-arm the fade-out linger on every tick;
      // once ticks stop arriving, the last-scheduled timer fires and fades
      // the indicator out.
      _scrollState
        ?..scrollBy(event.scrollDelta.dx)
        ..showIndicator()
        ..scheduleIndicatorFadeOut();
    }
  }

  @override
  Rect getLocalRectForCaret(TextPosition position) {
    final child = childAtPosition(position);
    final localPosition = TextPosition(
      offset: position.offset - child.container.offset,
      affinity: position.affinity,
    );
    final parentData = child.parentData as EditableContainerParentData;
    return child.getLocalRectForCaret(localPosition).shift(parentData.offset);
  }

  @override
  TextPosition globalToLocalPosition(TextPosition position) {
    assert(container.containsOffset(position.offset) || container.length == 0,
        'The provided text position is not in the current node');
    return TextPosition(
      offset: position.offset - container.documentOffset,
      affinity: position.affinity,
    );
  }

  @override
  Rect getCaretPrototype(TextPosition position) {
    final child = childAtPosition(position);
    final localPosition = TextPosition(
      offset: position.offset - child.container.offset,
      affinity: position.affinity,
    );
    return child.getCaretPrototype(localPosition);
  }
}
