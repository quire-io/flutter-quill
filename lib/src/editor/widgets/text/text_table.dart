import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../controller/quill_controller.dart';
import '../../../document/attribute.dart';
import '../../../document/nodes/block.dart';
import '../../editor.dart';
import '../box.dart';
import '../default_styles.dart';
import 'text_line.dart';
import 'text_selection.dart';

/// A specialized widget for rendering table blocks where each cell contains
/// an [EditableTextLine] that can be edited independently.
class EditableTextTable extends MultiChildRenderObjectWidget {
  const EditableTextTable({
    required this.block,
    required this.controller,
    required this.textDirection,
    required this.tableStyle,
    super.key,
    super.children,
  });

  final Block block;
  final QuillController controller;
  final TextDirection textDirection;
  final DefaultTableStyle tableStyle;

  @override
  MultiChildRenderObjectElement createElement() => _TextTableElement(this);

  @override
  RenderEditableTextTable createRenderObject(BuildContext context) {
    return RenderEditableTextTable(
      block: block,
      textDirection: textDirection,
      tableStyle: tableStyle,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderEditableTextTable renderObject) {
    renderObject
      ..setContainer(block)
      ..textDirection = textDirection
      ..tableStyle = tableStyle;
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
    DefaultTableStyle? tableStyle,
    super.children,
  })  : _configuration = ImageConfiguration(textDirection: textDirection),
        _tableStyle = tableStyle ?? const DefaultTableStyle(),
        super(
          container: block,
          scrollBottomInset: 0,
          padding: EdgeInsets.zero,
        );

  BoxPainter? _painter;

  DefaultTableStyle _tableStyle;
  DefaultTableStyle get tableStyle => _tableStyle;

  set tableStyle(DefaultTableStyle value) {
    if (value == _tableStyle) return;
    _tableStyle = value;
    markNeedsPaint();
  }

  ImageConfiguration get configuration => _configuration;
  ImageConfiguration _configuration;

  set configuration(ImageConfiguration value) {
    if (value == _configuration) return;
    _configuration = value;
    markNeedsPaint();
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
    _painter?.dispose();
    _painter = null;
    super.detach();
    markNeedsPaint();
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
      totalWidth += child.getMinIntrinsicWidth(height) + paddingWidth;
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
      totalWidth += child.getMaxIntrinsicWidth(height) + paddingWidth;
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

    final cellWidth = (width / childCount) - paddingWidth;
    var maxHeight = 0.0;
    var child = firstChild;
    while (child != null) {
      maxHeight = math.max(maxHeight, child.getMinIntrinsicHeight(cellWidth) + paddingHeight);
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

    final cellWidth = (width / childCount) - paddingWidth;
    var maxHeight = 0.0;
    var child = firstChild;
    while (child != null) {
      maxHeight = math.max(maxHeight, child.getMaxIntrinsicHeight(cellWidth) + paddingHeight);
      child = childAfter(child);
    }
    return maxHeight;
  }

  @override
  void performLayout() {
    assert(constraints.hasBoundedWidth);

    if (childCount == 0) {
      size = constraints.constrain(Size.zero);
      return;
    }

    // Get cell padding from table style
    final cellPadding = tableStyle.cellPadding;
    final paddingWidth = cellPadding.horizontal;
    final paddingHeight = cellPadding.vertical;

    // Calculate cell width by evenly dividing available width
    final cellWidth = constraints.maxWidth / childCount;

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

    // Layout each child and position them horizontally with padding
    while (child != null) {
      child.layout(cellConstraints, parentUsesSize: true);
      // Apply left and top padding to the child position
      (child.parentData as EditableContainerParentData).offset = Offset(
        currentX + cellPadding.left,
        cellPadding.top,
      );

      // Include padding in height calculation
      maxHeight = math.max(maxHeight, child.size.height + paddingHeight);
      currentX += cellWidth;

      child = childAfter(child);
    }

    // Set the table size
    size = constraints.constrain(Size(constraints.maxWidth, maxHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Paint striped background first (if applicable)
    _paintStripedBackground(context, offset);

    // Paint children next
    defaultPaint(context, offset);

    // Paint borders last
    _paintBorders(context, offset);
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

  /// Determines if this table row is the first table row (header row).
  bool get isFirstTableRow {
    var prevBlock = container.previous;

    // Check if there are any previous table blocks
    while (prevBlock != null) {
      if (prevBlock is Block &&
          prevBlock.style.attributes.containsKey(Attribute.table.key)) {
        return false; // Found a previous table block, so this is not the first
      }
      prevBlock = prevBlock.previous;
    }

    return true; // No previous table blocks found, this is the first
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

    // Check if the next block is also a table to avoid overlapping borders
    final nextBlock = container.next;
    final shouldDrawBottomBorder = border.bottom.width > 0 &&
        !(nextBlock is Block && nextBlock.style.attributes.containsKey(Attribute.table.key));

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

    // Draw vertical separators between cells using verticalInside border
    if (border.verticalInside.width > 0) {
      final paint = Paint()
        ..color = border.verticalInside.color
        ..strokeWidth = border.verticalInside.width
        ..style = PaintingStyle.stroke;

      final cellWidth = size.width / childCount;
      for (var i = 1; i < childCount; i++) {
        final x = offset.dx + (i * cellWidth);
        canvas.drawLine(
          Offset(x, offset.dy),
          Offset(x, offset.dy + size.height),
          paint,
        );
      }
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
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