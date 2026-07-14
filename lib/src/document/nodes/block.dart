import '../../../../quill_delta.dart';
import '../attribute.dart';
import 'container.dart';
import 'line.dart';
import 'node.dart';

/// Represents a group of adjacent [Line]s with the same block style.
///
/// Block elements are:
/// - Blockquote
/// - Header
/// - Indent
/// - List
/// - Text Alignment
/// - Text Direction
/// - Code Block
/// - Table
base class Block extends QuillContainer<Line?> {
  /// Creates new unmounted [Block].
  @override
  Node newInstance() => Block();

  @override
  Line get defaultChild => Line();

  @override
  Delta toDelta() {
    // Line nodes take care of incorporating block style into their delta.
    return children
        .map((child) => child.toDelta())
        .fold(Delta(), (a, b) => a.concat(b));
  }

  @override
  void adjust() {
    if (isEmpty) {
      final sibling = previous;
      unlink();
      if (sibling != null) {
        sibling.adjust();
      }
      return;
    }

    var block = this;
    final prev = block.previous;
    // merging it with previous block if style is the same
    // or if both blocks have table attributes with the same value
    if (!block.isFirst &&
        block.previous is Block &&
        (prev!.style == block.style ||
         (block.style.attributes.containsKey(Attribute.table.key) &&
          prev.style.attributes.containsKey(Attribute.table.key) &&
          block.style.attributes[Attribute.table.key]?.value ==
          prev.style.attributes[Attribute.table.key]?.value))) {
      block
        ..moveChildToNewParent(prev as QuillContainer<Node?>?)
        ..unlink();
      block = prev as Block;
    }
    final next = block.next;
    // merging it with next block if style is the same
    // or if both blocks have table attributes with the same value
    if (!block.isLast &&
        block.next is Block &&
        (next!.style == block.style ||
         (block.style.attributes.containsKey(Attribute.table.key) &&
          next.style.attributes.containsKey(Attribute.table.key) &&
          block.style.attributes[Attribute.table.key]?.value ==
          next.style.attributes[Attribute.table.key]?.value))) {
      (next as Block).moveChildToNewParent(block);
      next.unlink();
    }
  }

  /// Whether this block is one row of a table, i.e. it carries the table
  /// attribute. A "table" is a maximal run of adjacent table-row blocks (see
  /// [adjust], which merges adjacent table blocks that share a table value,
  /// so within a table each row-block has a distinct value).
  bool get isTableRow => style.attributes.containsKey(Attribute.table.key);

  /// The first row-block of the table run this block belongs to. Returns
  /// `this` when the block is the run's first row (or not a table row).
  Block get tableRunFirstRow {
    var first = this;
    var prev = first.previous;
    while (prev is Block && prev.isTableRow) {
      first = prev;
      prev = prev.previous;
    }
    return first;
  }

  /// This row-block's zero-based index within its table run (0 for the header
  /// row). Only meaningful for [isTableRow] blocks.
  int get tableRowIndex {
    var index = 0;
    var prev = previous;
    while (prev is Block && prev.isTableRow) {
      index++;
      prev = prev.previous;
    }
    return index;
  }

  /// A stable key identifying the table run this row belongs to, so every row
  /// of the same table shares one horizontal scroll state. Derived from the
  /// run's first row (see [tableRunFirstRow]); reading it on the first row
  /// itself is O(1), so callers iterating in document order can compute it
  /// once per run instead of walking back from every row.
  String get tableRunKey {
    final first = tableRunFirstRow;
    return first.style.attributes[Attribute.table.key]?.value?.toString() ??
        'table-${identityHashCode(first)}';
  }

  @override
  String toString() {
    final block = style.attributes.toString();
    final buffer = StringBuffer('§ {$block}\n');
    for (final child in children) {
      final tree = child.isLast ? '└' : '├';
      buffer.write('  $tree $child');
      if (!child.isLast) buffer.writeln();
    }
    return buffer.toString();
  }
}
