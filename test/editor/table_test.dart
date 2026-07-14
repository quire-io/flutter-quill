import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/src/editor/widgets/text/table_horizontal_scroll.dart';
import 'package:flutter_quill/src/editor/widgets/text/text_table.dart';
import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> tableRow(List<String> cells, String rowId) {
  final ops = <Map<String, dynamic>>[];
  for (final cell in cells) {
    ops
      ..add({'insert': cell})
      ..add({
        'insert': '\n',
        'attributes': {'table': rowId},
      });
  }
  return ops;
}

void main() {
  group('Table Test', () {
    testWidgets('Verify cells are positioned in the same row', (tester) async {
      await tester.pumpWidget(const TableTestApp(
        initialDelta: [
          {'insert': 'Cell A'},
          {'insert': '\n', 'attributes': {'table': 'row-1'}},
          {'insert': 'Cell B'},
          {'insert': '\n', 'attributes': {'table': 'row-1'}},
          {'insert': '\n'},
        ],
      ));

      // Find the text widgets for both cells
      final cellAFinder = find.text('Cell A', findRichText: true);
      final cellBFinder = find.text('Cell B', findRichText: true);

      expect(cellAFinder, findsOneWidget);
      expect(cellBFinder, findsOneWidget);

      // Get the positions of both cells
      final cellARect = tester.getRect(cellAFinder);
      final cellBRect = tester.getRect(cellBFinder);

      // Verify they are on the same row (same Y position with some tolerance)
      expect(cellARect.top, equals(cellBRect.top),
        reason: 'Cell A and Cell B should be at the same vertical position (same row)');

      // Verify Cell B is to the right of Cell A (proper horizontal ordering)
      expect(cellBRect.left, greaterThan(cellARect.right - 1),
        reason: 'Cell B should be positioned to the right of Cell A');

      // The cells should have roughly equal widths in our implementation
      // (allowing some tolerance for text rendering differences)
      final cellAWidth = cellARect.width;
      final cellBWidth = cellBRect.width;
      expect(cellAWidth, closeTo(cellBWidth, 1.0),
        reason: 'Cell A and Cell B should have similar widths');
    });

    testWidgets('Verify table header style is applied to first row (single column)', (tester) async {
      await tester.pumpWidget(const TableTestApp(
        initialDelta: [
          {'insert': 'Header Cell A'},
          {'insert': '\n', 'attributes': {'table': 'row-1'}},
          {'insert': 'Regular Cell A'},
          {'insert': '\n', 'attributes': {'table': 'row-2'}},
          {'insert': '\n'},
        ],
      ));

      // Find the text widgets for header and regular cells
      final findHeaderCellA = find.text('Header Cell A', findRichText: true);
      final findRegularCellA = find.text('Regular Cell A', findRichText: true);

      // Get the rich text widgets to check their styles
      final headerARichText = tester.widget<RichText>(findHeaderCellA);
      final regularARichText = tester.widget<RichText>(findRegularCellA);

      // Check that header cells have bold styling (our custom header style)
      expect(headerARichText.text.style?.fontWeight, equals(FontWeight.bold),
        reason: 'Header A should be bold');

      // The regular cells should not have bold styling
      expect(regularARichText.text.style?.fontWeight, isNot(equals(FontWeight.bold)),
        reason: 'Regular A should not be bold');
    });

     testWidgets('Verify table header style is applied to first row', (tester) async {
      await tester.pumpWidget(const TableTestApp(
        initialDelta: [
          {'insert': 'Header Cell A'},
          {'insert': '\n', 'attributes': {'table': 'row-1'}},
          {'insert': 'Header Cell B'},
          {'insert': '\n', 'attributes': {'table': 'row-1'}},
          {'insert': 'Regular Cell A'},
          {'insert': '\n', 'attributes': {'table': 'row-2'}},
          {'insert': 'Regular Cell B'},
          {'insert': '\n', 'attributes': {'table': 'row-2'}},
          {'insert': '\n'},
        ],
      ));

      // Find the text widgets for header and regular cells
      final findHeaderCellA = find.text('Header Cell A', findRichText: true);
      final findHeaderCellB = find.text('Header Cell B', findRichText: true);
      final findRegularCellA = find.text('Regular Cell A', findRichText: true);
      final findRegularCellB = find.text('Regular Cell B', findRichText: true);

      // Get the rich text widgets to check their styles
      final headerARichText = tester.widget<RichText>(findHeaderCellA);
      final headerBRichText = tester.widget<RichText>(findHeaderCellB);
      final regularARichText = tester.widget<RichText>(findRegularCellA);
      final regularBRichText = tester.widget<RichText>(findRegularCellB);

      // Check that header cells have bold styling (our custom header style)
      expect(headerARichText.text.style?.fontWeight, equals(FontWeight.bold),
        reason: 'Header A should be bold');
      expect(headerBRichText.text.style?.fontWeight, equals(FontWeight.bold),
        reason: 'Header B should be bold');

      // The regular cells should not have bold styling
      expect(regularARichText.text.style?.fontWeight, isNot(equals(FontWeight.bold)),
        reason: 'Regular A should not be bold');
      expect(regularBRichText.text.style?.fontWeight, isNot(equals(FontWeight.bold)),
        reason: 'Regular B should not be bold');
    });

    testWidgets(
        'renders a document whose table attribute value is not a String '
        'without crashing', (tester) async {
      // Other Quill implementations / legacy data may carry a non-String
      // table id (e.g. an int). The document must still render — previously
      // deriving the scroll key cast the value to String and threw.
      await tester.pumpWidget(const TableTestApp(
        initialDelta: [
          {'insert': 'Cell A'},
          {'insert': '\n', 'attributes': {'table': 1}},
          {'insert': 'Cell B'},
          {'insert': '\n', 'attributes': {'table': 2}},
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(EditableTextTable), findsWidgets);
      expect(find.text('Cell A', findRichText: true), findsOneWidget);
      expect(find.text('Cell B', findRichText: true), findsOneWidget);
    });

    testWidgets('Debug childAtOffset method', (tester) async {
      final controller = QuillController(
        document: Document.fromJson([
          {'insert': 'Cell A'},
          {'insert': '\n', 'attributes': {'table': 'row-1'}},
          {'insert': 'Cell B'},
          {'insert': '\n', 'attributes': {'table': 'row-1'}},
          {'insert': 'Cell C'},
          {'insert': '\n', 'attributes': {'table': 'row-1'}},
        ]),
        selection: const TextSelection.collapsed(offset: 0),
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QuillEditor.basic(
            controller: controller,
            config: const QuillEditorConfig(
              autoFocus: false,
            ),
          ),
        ),
      ));

      await tester.pumpAndSettle();

       // Find the table cells
      final cellAFinder = find.text('Cell A', findRichText: true);
      final cellBFinder = find.text('Cell B', findRichText: true);
      final cellCFinder = find.text('Cell C', findRichText: true);

      expect(cellAFinder, findsOneWidget);
      expect(cellBFinder, findsOneWidget);
      expect(cellCFinder, findsOneWidget);

      // Tap on Cell A
      await tester.tap(cellAFinder);
      await tester.pumpAndSettle(const Duration(milliseconds: 350));

      // Check if cursor is in Cell A (offset 0-6)
      expect(controller.selection.baseOffset, lessThanOrEqualTo(6)); // Cell A content + newline

      // Tap on Cell B
      await tester.tap(cellBFinder);
      await tester.pumpAndSettle(const Duration(milliseconds: 350));

      // Check if cursor moved to Cell B (offset should be around 7-13)
      expect(controller.selection.baseOffset, greaterThanOrEqualTo(7));
      expect(controller.selection.baseOffset, lessThanOrEqualTo(13));

      // Tap on Cell C
      await tester.tap(cellCFinder);
      await tester.pumpAndSettle(const Duration(milliseconds: 350));

      // Check if cursor moved to Cell C (offset should be around 14-20)
      expect(controller.selection.baseOffset, greaterThanOrEqualTo(14));
    });
  });

  group('Table horizontal scroll & minCellWidth', () {
    testWidgets('columns are floored at minCellWidth on a narrow viewport',
        (tester) async {
      await tester.pumpWidget(TableTestApp(
        editorWidth: 200,
        tableStyle: const DefaultTableStyle(minCellWidth: 100),
        initialDelta: [
          ...tableRow(['A', 'B', 'C', 'D'], 'row-1'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final table = tester.renderObject<RenderEditableTextTable>(
          find.byType(EditableTextTable).first);

      expect(table.cellWidthForTest, greaterThanOrEqualTo(100),
          reason: 'columns should never be narrower than minCellWidth');
      expect(table.contentWidthForTest, greaterThan(table.size.width),
          reason:
              '4 columns at >=100px each should overflow a 200px-wide viewport');
    });

    testWidgets('the default minCellWidth applies when no custom style is set',
        (tester) async {
      await tester.pumpWidget(TableTestApp(
        editorWidth: 150,
        initialDelta: [
          ...tableRow(['A', 'B', 'C'], 'row-1'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final table = tester.renderObject<RenderEditableTextTable>(
          find.byType(EditableTextTable).first);

      // 150px / 3 columns = 50px/column, well under the 80px default floor.
      expect(table.cellWidthForTest, closeTo(80, 0.5));
    });

    testWidgets('a table that fits its viewport does not scroll',
        (tester) async {
      await tester.pumpWidget(TableTestApp(
        // A generous width relative to the default 100px minCellWidth and 2
        // columns, so the table fits without flooring or overflowing.
        editorWidth: 400,
        initialDelta: [
          ...tableRow(['A', 'B'], 'row-1'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final table = tester.renderObject<RenderEditableTextTable>(
          find.byType(EditableTextTable).first);
      expect(table.contentWidthForTest, lessThanOrEqualTo(table.size.width));

      // With exactly 2 equal columns the row's geometric center falls
      // exactly on the gutter between them; since the table doesn't
      // overflow, hitTestSelf correctly reports false there (nothing to
      // scroll), so the drag may legitimately miss the widget entirely.
      await tester.drag(
          find.byType(EditableTextTable).first, const Offset(-300, 0),
          warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(table.rowShiftForTest, 0,
          reason: 'a table with no overflow must not claim the drag gesture');
    });

    testWidgets('dragging scrolls the table and clamps at both ends',
        (tester) async {
      await tester.pumpWidget(TableTestApp(
        editorWidth: 200,
        tableStyle: const DefaultTableStyle(minCellWidth: 100),
        initialDelta: [
          ...tableRow(['A', 'B', 'C', 'D'], 'row-1'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final table = tester.renderObject<RenderEditableTextTable>(
          find.byType(EditableTextTable).first);
      final maxScroll = table.contentWidthForTest - table.size.width;
      expect(maxScroll, greaterThan(0));

      // Drag far past the end: the shift should clamp at maxScroll.
      await tester.drag(find.byType(EditableTextTable).first,
          Offset(-(maxScroll + 500), 0));
      await tester.pumpAndSettle();
      expect(table.rowShiftForTest, closeTo(maxScroll, 0.5));

      // Drag back past the start: the shift should clamp at 0.
      await tester.drag(
          find.byType(EditableTextTable).first, const Offset(1000, 0));
      await tester.pumpAndSettle();
      expect(table.rowShiftForTest, 0);
    });

    testWidgets(
        'scroll position is synchronized across every row of the same table',
        (tester) async {
      await tester.pumpWidget(TableTestApp(
        editorWidth: 200,
        tableStyle: const DefaultTableStyle(minCellWidth: 100),
        initialDelta: [
          ...tableRow(['A1', 'B1', 'C1', 'D1'], 'row-1'),
          ...tableRow(['A2', 'B2', 'C2', 'D2'], 'row-2'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final rows = tester
          .renderObjectList<RenderEditableTextTable>(
              find.byType(EditableTextTable))
          .toList();
      expect(rows, hasLength(2));

      await tester.drag(
          find.byType(EditableTextTable).first, const Offset(-120, 0));
      await tester.pumpAndSettle();

      expect(rows[0].rowShiftForTest, greaterThan(0));
      expect(rows[1].rowShiftForTest, closeTo(rows[0].rowShiftForTest, 0.01),
          reason: 'both rows share one scroll state and must move together');
    });

    testWidgets('scrolling repaints in place without dirtying layout',
        (tester) async {
      await tester.pumpWidget(TableTestApp(
        editorWidth: 200,
        tableStyle: const DefaultTableStyle(minCellWidth: 100),
        initialDelta: [
          ...tableRow(['A', 'B', 'C', 'D'], 'row-1'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final table = tester.renderObject<RenderEditableTextTable>(
          find.byType(EditableTextTable).first);

      // Start the drag: the first move only crosses the touch slop to make
      // the gesture arena accept the drag (one frame); no scroll yet.
      final gesture = await tester.startGesture(
          tester.getCenter(find.byType(EditableTextTable).first));
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump();
      expect(table.debugNeedsLayout, isFalse,
          reason: 'clean once the accepting frame settles');

      // The drag is now active, so a further move dispatches onUpdate — and
      // thus the scroll — synchronously, before any frame. A scroll must only
      // mark paint; dirtying layout here would relayout the whole document on
      // every pointer-move tick.
      await gesture.moveBy(const Offset(-40, 0));
      expect(table.rowShiftForTest, greaterThan(0),
          reason: 'the drag scrolled the table synchronously');
      expect(table.debugNeedsLayout, isFalse,
          reason: 'a scroll must not request a relayout');

      await gesture.up();
    });

    testWidgets('two tables separated by a paragraph scroll independently',
        (tester) async {
      await tester.pumpWidget(TableTestApp(
        editorWidth: 200,
        tableStyle: const DefaultTableStyle(minCellWidth: 100),
        initialDelta: [
          ...tableRow(['A1', 'B1', 'C1', 'D1'], 'row-1'),
          {'insert': 'separator\n'},
          ...tableRow(['A2', 'B2', 'C2', 'D2'], 'row-2'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final tables = tester
          .renderObjectList<RenderEditableTextTable>(
              find.byType(EditableTextTable))
          .toList();
      expect(tables, hasLength(2));

      await tester.drag(
          find.byType(EditableTextTable).first, const Offset(-120, 0));
      await tester.pumpAndSettle();

      expect(tables[0].rowShiftForTest, greaterThan(0));
      expect(tables[1].rowShiftForTest, 0,
          reason: 'the paragraph breaks the table run, so the second table '
              'has its own scroll state and must not move');
    });

    testWidgets(
        'two tables sharing a first-row id (copy-pasted) scroll independently',
        (tester) async {
      await tester.pumpWidget(TableTestApp(
        editorWidth: 200,
        tableStyle: const DefaultTableStyle(minCellWidth: 100),
        initialDelta: [
          // Two separate tables whose rows carry the SAME id, as a
          // copy-pasted table would (paste duplicates row ids verbatim).
          // Keying scroll state on the row id would couple them; keying on
          // document position must keep them independent.
          ...tableRow(['A1', 'B1', 'C1', 'D1'], 'dup'),
          {'insert': 'separator\n'},
          ...tableRow(['A2', 'B2', 'C2', 'D2'], 'dup'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final tables = tester
          .renderObjectList<RenderEditableTextTable>(
              find.byType(EditableTextTable))
          .toList();
      expect(tables, hasLength(2));

      await tester.drag(
          find.byType(EditableTextTable).first, const Offset(-120, 0));
      await tester.pumpAndSettle();

      expect(tables[0].rowShiftForTest, greaterThan(0));
      expect(tables[1].rowShiftForTest, 0,
          reason: 'tables are keyed by document position, so a shared row id '
              'must not couple their scroll state');
    });

    testWidgets(
        "deleting a table's first row preserves the remaining scroll offset",
        (tester) async {
      final controller = QuillController(
        document: Document.fromJson([
          ...tableRow(['A', 'B', 'C', 'D'], 'row-1'),
          ...tableRow(['E', 'F', 'G', 'H'], 'row-2'),
          {'insert': '\n'},
        ]),
        selection: const TextSelection.collapsed(offset: 0),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 400,
            child: QuillEditor.basic(
              controller: controller,
              config: const QuillEditorConfig(
                autoFocus: false,
                customStyles: DefaultStyles(
                  table: DefaultTableStyle(minCellWidth: 100),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      var tables = tester
          .renderObjectList<RenderEditableTextTable>(
              find.byType(EditableTextTable))
          .toList();
      expect(tables, hasLength(2), reason: 'one table with two rows');
      final maxScroll = tables[0].contentWidthForTest - tables[0].size.width;
      expect(maxScroll, greaterThan(0));

      await tester.drag(find.byType(EditableTextTable).first,
          Offset(-(maxScroll + 500), 0));
      await tester.pumpAndSettle();
      final scrolledShift = tables[1].rowShiftForTest;
      expect(scrolledShift, greaterThan(0));

      // Delete the entire first row ('A\nB\nC\nD\n' = 8 chars). Put the caret
      // in the last cell 'H' (offset 6 in the remaining 'E\nF\nG\nH\n'), which
      // is already visible at the scrolled offset, so the C2 caret-reveal
      // leaves the table where it is and this test isolates C1's state
      // preservation.
      controller.replaceText(
          0, 8, '', const TextSelection.collapsed(offset: 6));
      await tester.pumpAndSettle();

      tables = tester
          .renderObjectList<RenderEditableTextTable>(
              find.byType(EditableTextTable))
          .toList();
      expect(tables, hasLength(1), reason: 'only the second row remains');
      expect(tables[0].rowShiftForTest, closeTo(scrolledShift, 0.5),
          reason: 'the table keeps its ordinal-based key, so its scroll offset '
              'survives deleting the first row');
    });

    testWidgets('hit-testing accounts for the current scroll offset',
        (tester) async {
      final controller = QuillController(
        document: Document.fromJson(tableRow(['A', 'B', 'C', 'D'], 'row-1')),
        selection: const TextSelection.collapsed(offset: 0),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 400,
            child: QuillEditor.basic(
              controller: controller,
              config: const QuillEditorConfig(
                autoFocus: false,
                customStyles: DefaultStyles(
                  table: DefaultTableStyle(minCellWidth: 100),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final table = tester.renderObject<RenderEditableTextTable>(
          find.byType(EditableTextTable).first);
      final maxScroll = table.contentWidthForTest - table.size.width;
      expect(maxScroll, greaterThan(0));

      await tester.drag(find.byType(EditableTextTable).first,
          Offset(-(maxScroll + 500), 0));
      await tester.pumpAndSettle();
      expect(table.rowShiftForTest, closeTo(maxScroll, 0.5));

      // Tap near the right edge of the (now fully scrolled) row: it should
      // land in the last column, 'D' (document offsets 6-7).
      final rowRect = tester.getRect(find.byType(EditableTextTable).first);
      await tester.tapAt(rowRect.topRight + Offset(-2, rowRect.height / 2));
      await tester.pumpAndSettle(const Duration(milliseconds: 350));

      expect(controller.selection.baseOffset, greaterThanOrEqualTo(6));
      expect(controller.selection.baseOffset, lessThanOrEqualTo(7));
    });
  });

  group('Table horizontal scroll indicator', () {
    testWidgets('hidden by default, even when the table overflows',
        (tester) async {
      await tester.pumpWidget(TableTestApp(
        editorWidth: 200,
        tableStyle: const DefaultTableStyle(minCellWidth: 100),
        initialDelta: [
          ...tableRow(['A', 'B', 'C', 'D'], 'row-1'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final table = tester.renderObject<RenderEditableTextTable>(
          find.byType(EditableTextTable).first);
      expect(table.contentWidthForTest, greaterThan(table.size.width),
          reason: 'the table does overflow');
      expect(table.indicatorOpacityForTest, 0,
          reason: 'the indicator only reveals once the user interacts');
      expect(table.scrollbarThumbRectForTest, isNull);
    });

    testWidgets('no indicator when the table fits its viewport',
        (tester) async {
      await tester.pumpWidget(TableTestApp(
        editorWidth: 400,
        initialDelta: [
          ...tableRow(['A', 'B'], 'row-1'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final table = tester.renderObject<RenderEditableTextTable>(
          find.byType(EditableTextTable).first);
      expect(table.contentWidthForTest, lessThanOrEqualTo(table.size.width));

      // With exactly 2 equal columns the row's geometric center falls on
      // the gutter between them; since the table doesn't overflow, the
      // drag may legitimately miss the widget (nothing to scroll there).
      await tester.drag(
          find.byType(EditableTextTable).first, const Offset(-300, 0),
          warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(table.indicatorOpacityForTest, 0);
      expect(table.scrollbarThumbRectForTest, isNull);
    });

    testWidgets('dragging reveals the indicator immediately',
        (tester) async {
      await tester.pumpWidget(TableTestApp(
        editorWidth: 200,
        tableStyle: const DefaultTableStyle(minCellWidth: 100),
        initialDelta: [
          ...tableRow(['A', 'B', 'C', 'D'], 'row-1'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final table = tester.renderObject<RenderEditableTextTable>(
          find.byType(EditableTextTable).first);

      // Drive the gesture manually (rather than tester.drag, which also
      // ends it) so we can inspect the mid-drag state.
      final gesture = await tester.startGesture(
          tester.getCenter(find.byType(EditableTextTable).first));
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();

      expect(table.indicatorOpacityForTest, 1,
          reason: 'shows the instant a drag starts, no linger beforehand');
      expect(table.scrollbarThumbRectForTest, isNotNull);

      await gesture.up();
    });

    testWidgets('lingers then fades out automatically once the drag ends',
        (tester) async {
      await tester.pumpWidget(TableTestApp(
        editorWidth: 200,
        tableStyle: const DefaultTableStyle(minCellWidth: 100),
        initialDelta: [
          ...tableRow(['A', 'B', 'C', 'D'], 'row-1'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final table = tester.renderObject<RenderEditableTextTable>(
          find.byType(EditableTextTable).first);
      final maxScroll = table.contentWidthForTest - table.size.width;

      // tester.drag() performs a full down-move-up gesture, so onEnd (and
      // the fade-out scheduling it triggers) has already fired by the time
      // it returns.
      await tester.drag(find.byType(EditableTextTable).first,
          Offset(-(maxScroll + 500), 0));
      await tester.pump();
      expect(table.indicatorOpacityForTest, 1,
          reason: 'still fully visible right after the drag ends');

      // Still within the linger window (600ms) — not fading yet.
      await tester.pump(const Duration(milliseconds: 500));
      expect(table.indicatorOpacityForTest, 1);

      // Cross the linger threshold: the fade-out timer fires as part of
      // advancing the clock past 600ms and starts the reverse animation,
      // but its value only reflects elapsed time on a *subsequent* tick —
      // a zero-duration pump() reports zero elapsed animation time, so an
      // extra small-but-nonzero pump is needed to observe real progress.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 16));
      expect(table.indicatorOpacityForTest, lessThan(1));

      // Let the fade finish.
      await tester.pump(const Duration(milliseconds: 300));
      expect(table.indicatorOpacityForTest, 0);
      expect(table.scrollbarThumbRectForTest, isNull);
    });

    testWidgets(
        'a ragged table reflects table-wide scroll state on its last row',
        (tester) async {
      await tester.pumpWidget(TableTestApp(
        editorWidth: 200,
        tableStyle: const DefaultTableStyle(minCellWidth: 100),
        initialDelta: [
          ...tableRow(['A1', 'B1', 'C1', 'D1'], 'row-1'),
          ...tableRow(['A2'], 'row-2'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final rows = tester
          .renderObjectList<RenderEditableTextTable>(
              find.byType(EditableTextTable))
          .toList();
      expect(rows, hasLength(2));
      // Row 2 (single column) never overflows on its own.
      expect(
          rows[1].contentWidthForTest, lessThanOrEqualTo(rows[1].size.width));

      // Dragging the wider first row scrolls the shared state; row 2's own
      // layout shift stays 0 (it fits by itself), but since both rows share
      // one TableHorizontalScrollState, its indicator still reveals — and
      // only the LAST row (row 2) actually paints it.
      await tester.drag(
          find.byType(EditableTextTable).first, const Offset(-120, 0));
      await tester.pump();

      expect(rows[1].rowShiftForTest, 0,
          reason: "a single-column row's own content never overflows");
      expect(rows[0].indicatorOpacityForTest, 1);
      expect(rows[1].indicatorOpacityForTest, 1,
          reason: 'both rows share one scroll state, including its fade');
      expect(rows[1].scrollbarThumbRectForTest, isNotNull,
          reason: 'only the last row paints the shared indicator');
      expect(rows[0].scrollbarThumbRectForTest, isNull,
          reason: 'earlier rows never paint it, even while visible');
    });

    testWidgets('scrollbarEnabled: false disables the indicator entirely',
        (tester) async {
      await tester.pumpWidget(TableTestApp(
        editorWidth: 200,
        tableStyle: const DefaultTableStyle(
          minCellWidth: 100,
          scrollbarEnabled: false,
        ),
        initialDelta: [
          ...tableRow(['A', 'B', 'C', 'D'], 'row-1'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final table = tester.renderObject<RenderEditableTextTable>(
          find.byType(EditableTextTable).first);
      final maxScroll = table.contentWidthForTest - table.size.width;

      await tester.drag(find.byType(EditableTextTable).first,
          Offset(-(maxScroll + 500), 0));
      await tester.pump();

      // Dragging still scrolls the table — only the visual indicator is
      // suppressed.
      expect(table.rowShiftForTest, greaterThan(0));
      expect(table.scrollbarThumbRectForTest, isNull,
          reason: 'the indicator itself is disabled');
    });

    testWidgets('custom thickness and color are honored', (tester) async {
      const thumbColor = Color(0xFF445566);
      await tester.pumpWidget(TableTestApp(
        editorWidth: 200,
        tableStyle: const DefaultTableStyle(
          minCellWidth: 100,
          scrollbarThickness: 6,
          scrollbarColor: thumbColor,
        ),
        initialDelta: [
          ...tableRow(['A', 'B', 'C', 'D'], 'row-1'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final table = tester.renderObject<RenderEditableTextTable>(
          find.byType(EditableTextTable).first);
      final maxScroll = table.contentWidthForTest - table.size.width;

      await tester.drag(find.byType(EditableTextTable).first,
          Offset(-(maxScroll + 500), 0));
      await tester.pump();

      expect(table.scrollbarThumbRectForTest!.height, 6);
      expect(table, paints..rrect(color: thumbColor));
    });

    testWidgets('scrollbarMinThumbWidth floors the thumb width',
        (tester) async {
      await tester.pumpWidget(TableTestApp(
        editorWidth: 200,
        tableStyle: const DefaultTableStyle(
          minCellWidth: 100,
          scrollbarMinThumbWidth: 150,
        ),
        initialDelta: [
          ...tableRow(['A', 'B', 'C', 'D'], 'row-1'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final table = tester.renderObject<RenderEditableTextTable>(
          find.byType(EditableTextTable).first);
      final maxScroll = table.contentWidthForTest - table.size.width;

      final gesture = await tester.startGesture(
          tester.getCenter(find.byType(EditableTextTable).first));
      // Move past the touch slop so the drag is actually recognized.
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump();

      // The natural (unfloored) width here is well under 150.
      expect(table.scrollbarThumbRectForTest!.width, closeTo(150, 0.5));

      await gesture.moveBy(Offset(-(maxScroll + 500), 0));
      await tester.pump();
      final trackRight = table.size.width - 2; // 2px inset from the edge
      expect(table.scrollbarThumbRectForTest!.right, closeTo(trackRight, 0.5),
          reason: 'even a floored-width thumb must still reach the end');

      await gesture.up();
    });

    testWidgets('scrollbarBottomPadding positions the indicator',
        (tester) async {
      await tester.pumpWidget(TableTestApp(
        editorWidth: 200,
        tableStyle: const DefaultTableStyle(
          minCellWidth: 100,
          scrollbarBottomPadding: 12,
        ),
        initialDelta: [
          ...tableRow(['A', 'B', 'C', 'D'], 'row-1'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final table = tester.renderObject<RenderEditableTextTable>(
          find.byType(EditableTextTable).first);

      await tester.drag(
          find.byType(EditableTextTable).first, const Offset(-40, 0));
      await tester.pump();

      expect(table.scrollbarThumbRectForTest!.bottom,
          closeTo(table.size.height - 12, 0.5));
    });

    testWidgets('default thickness and bottom padding match the design spec',
        (tester) async {
      await tester.pumpWidget(TableTestApp(
        editorWidth: 200,
        tableStyle: const DefaultTableStyle(minCellWidth: 100),
        initialDelta: [
          ...tableRow(['A', 'B', 'C', 'D'], 'row-1'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final table = tester.renderObject<RenderEditableTextTable>(
          find.byType(EditableTextTable).first);

      await tester.drag(
          find.byType(EditableTextTable).first, const Offset(-40, 0));
      await tester.pump();

      expect(table.scrollbarThumbRectForTest!.height, 4);
      expect(table.scrollbarThumbRectForTest!.bottom,
          closeTo(table.size.height - 8, 0.5));
    });

    testWidgets(
        'default scrollbar color follows the light theme when overflowing',
        (tester) async {
      final controller = QuillController(
        document: Document.fromJson([
          ...tableRow(['A', 'B', 'C', 'D'], 'row-1'),
          {'insert': '\n'},
        ]),
        selection: const TextSelection.collapsed(offset: 0),
      );
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.light),
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 400,
            child: QuillEditor.basic(
              controller: controller,
              config: const QuillEditorConfig(autoFocus: false),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final table = tester.renderObject<RenderEditableTextTable>(
          find.byType(EditableTextTable).first);
      final maxScroll = table.contentWidthForTest - table.size.width;
      await tester.drag(find.byType(EditableTextTable).first,
          Offset(-(maxScroll + 500), 0));
      await tester.pump();

      expect(table, paints..rrect(color: const Color(0x59000000)));
    });

    testWidgets(
        'default scrollbar color follows the dark theme when overflowing',
        (tester) async {
      final controller = QuillController(
        document: Document.fromJson([
          ...tableRow(['A', 'B', 'C', 'D'], 'row-1'),
          {'insert': '\n'},
        ]),
        selection: const TextSelection.collapsed(offset: 0),
      );
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 400,
            child: QuillEditor.basic(
              controller: controller,
              config: const QuillEditorConfig(autoFocus: false),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final table = tester.renderObject<RenderEditableTextTable>(
          find.byType(EditableTextTable).first);
      final maxScroll = table.contentWidthForTest - table.size.width;
      await tester.drag(find.byType(EditableTextTable).first,
          Offset(-(maxScroll + 500), 0));
      await tester.pump();

      expect(table, paints..rrect(color: const Color(0x80FFFFFF)));
    });

    testWidgets(
        'dark theme is honored even when the app supplies its own custom '
        'table style (regression: DefaultStyles.merge replaces the whole '
        "table style, so the app's style must not silently pin the light "
        'color)', (tester) async {
      await tester.pumpWidget(TableTestApp(
        editorWidth: 200,
        theme: ThemeData(brightness: Brightness.dark),
        // A custom style set for an unrelated reason (minCellWidth) that
        // does not itself specify scrollbarColor — it must still resolve
        // to the dark-theme color, not silently fall back to light.
        tableStyle: const DefaultTableStyle(minCellWidth: 100),
        initialDelta: [
          ...tableRow(['A', 'B', 'C', 'D'], 'row-1'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final table = tester.renderObject<RenderEditableTextTable>(
          find.byType(EditableTextTable).first);
      final maxScroll = table.contentWidthForTest - table.size.width;
      await tester.drag(find.byType(EditableTextTable).first,
          Offset(-(maxScroll + 500), 0));
      await tester.pump();

      expect(table, paints..rrect(color: DefaultTableStyle.defaultDarkScrollbarColor));
    });

    testWidgets(
        'indicator top is floored at 0 on a short row with large bottom '
        'padding (never paints over the previous row)', (tester) async {
      await tester.pumpWidget(TableTestApp(
        editorWidth: 200,
        tableStyle: const DefaultTableStyle(
          minCellWidth: 100,
          // Deliberately larger than a single-line row's own height, which
          // would drive an unclamped thumbTop negative.
          scrollbarBottomPadding: 500,
          scrollbarThickness: 6,
        ),
        initialDelta: [
          ...tableRow(['A', 'B', 'C', 'D'], 'row-1'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final table = tester.renderObject<RenderEditableTextTable>(
          find.byType(EditableTextTable).first);

      await tester.drag(
          find.byType(EditableTextTable).first, const Offset(-40, 0));
      await tester.pump();

      final thumb = table.scrollbarThumbRectForTest;
      expect(thumb, isNotNull);
      expect(thumb!.top, greaterThanOrEqualTo(0),
          reason: 'thumbTop must not go negative and paint into the row above');
    });
  });

  group('Table striped background', () {
    testWidgets('stripe is painted on row index 2 with the configured color',
        (tester) async {
      const stripeColor = Color(0xFF112233);
      await tester.pumpWidget(TableTestApp(
        tableStyle: const DefaultTableStyle(stripeColor: stripeColor),
        initialDelta: [
          ...tableRow(['R0C0'], 'row-1'),
          ...tableRow(['R1C0'], 'row-2'),
          ...tableRow(['R2C0'], 'row-3'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final rows = tester
          .renderObjectList<RenderEditableTextTable>(
              find.byType(EditableTextTable))
          .toList();
      expect(rows, hasLength(3));

      // Row 0 (header) — no stripe
      expect(rows[0], isNot(paints..rect(color: stripeColor)));
      // Row 1 — no stripe (rowIndex 1, odd)
      expect(rows[1], isNot(paints..rect(color: stripeColor)));
      // Row 2 — stripe (rowIndex 2, even and > 1)
      expect(rows[2], paints..rect(color: stripeColor));
    });

    testWidgets('no stripe when stripeColor is null', (tester) async {
      await tester.pumpWidget(TableTestApp(
        tableStyle: const DefaultTableStyle(stripeColor: null),
        initialDelta: [
          ...tableRow(['R0C0'], 'row-1'),
          ...tableRow(['R1C0'], 'row-2'),
          ...tableRow(['R2C0'], 'row-3'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final rows = tester
          .renderObjectList<RenderEditableTextTable>(
              find.byType(EditableTextTable))
          .toList();
      expect(rows, hasLength(3));

      // No row should paint any rect (borders are strokes, not rects)
      for (var i = 0; i < rows.length; i++) {
        expect(rows[i], isNot(paints..rect()),
            reason: 'row $i should not paint a filled rect');
      }
    });

    testWidgets('stripe alternates on rows 2 and 4 only', (tester) async {
      const stripeColor = Color(0xFF445566);
      await tester.pumpWidget(TableTestApp(
        tableStyle: const DefaultTableStyle(stripeColor: stripeColor),
        initialDelta: [
          ...tableRow(['R0C0'], 'row-1'),
          ...tableRow(['R1C0'], 'row-2'),
          ...tableRow(['R2C0'], 'row-3'),
          ...tableRow(['R3C0'], 'row-4'),
          ...tableRow(['R4C0'], 'row-5'),
          {'insert': '\n'},
        ],
      ));
      await tester.pumpAndSettle();

      final rows = tester
          .renderObjectList<RenderEditableTextTable>(
              find.byType(EditableTextTable))
          .toList();
      expect(rows, hasLength(5));

      // Rows 0, 1, 3 — no stripe
      expect(rows[0], isNot(paints..rect(color: stripeColor)));
      expect(rows[1], isNot(paints..rect(color: stripeColor)));
      expect(rows[3], isNot(paints..rect(color: stripeColor)));
      // Rows 2, 4 — stripe
      expect(rows[2], paints..rect(color: stripeColor));
      expect(rows[4], paints..rect(color: stripeColor));
    });
  });

  group('Table accessibility', () {
    testWidgets('off-screen cells stay reachable in the semantics tree',
        (tester) async {
      final handle = tester.ensureSemantics();
      final controller = QuillController(
        document: Document.fromJson([
          // Table at the top (vertically visible) with a unique horizontally
          // off-screen cell 'ZZZ'; filler below forces vertical overflow so the
          // scroll viewport applies its semantics clip.
          ...tableRow(['AAA', 'BBB', 'CCC', 'ZZZ'], 'row-1'),
          ...List.generate(60, (i) => {'insert': 'filler line $i\n'}),
          {'insert': '\n'},
        ]),
        selection: const TextSelection.collapsed(offset: 0),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 300,
            child: QuillEditor.basic(
              controller: controller,
              config: const QuillEditorConfig(
                autoFocus: false,
                customStyles: DefaultStyles(
                  table: DefaultTableStyle(minCellWidth: 100),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Collect every label in the table's semantics subtree (including hidden
      // nodes retained by the scroll region, which label-finders skip).
      final labels = <String>[];
      void collect(SemanticsNode node) {
        final label = node.getSemanticsData().label;
        if (label.isNotEmpty) labels.add(label);
        node.visitChildren((child) {
          collect(child);
          return true;
        });
      }

      collect(tester.getSemantics(find.byType(EditableTextTable).first));

      // Sanity: a horizontally-visible cell is present in the semantics tree.
      expect(labels.any((l) => l.contains('AAA')), isTrue);
      // The horizontally off-screen cell must also be retained — the table
      // exposes horizontal scroll semantics so AT can reach it, instead of the
      // vertical viewport's clip dropping it. Fails without the C5 fix.
      expect(labels.any((l) => l.contains('ZZZ')), isTrue,
          reason: 'off-screen table cell must remain in the semantics tree');

      handle.dispose();
    });
  });

  group('Table caret reveal', () {
    testWidgets('moving the caret into an off-screen cell reveals it',
        (tester) async {
      final controller = QuillController(
        document: Document.fromJson(tableRow(['A', 'B', 'C', 'D'], 'row-1')),
        selection: const TextSelection.collapsed(offset: 0),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 400,
            child: QuillEditor.basic(
              controller: controller,
              config: const QuillEditorConfig(
                autoFocus: true,
                customStyles: DefaultStyles(
                  table: DefaultTableStyle(minCellWidth: 100),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final table = tester.renderObject<RenderEditableTextTable>(
          find.byType(EditableTextTable).first);
      expect(table.contentWidthForTest, greaterThan(table.size.width));
      expect(table.rowShiftForTest, 0);

      // Move the caret into the rightmost cell 'D' (offset 6), which is
      // scrolled off the right edge at rest.
      controller.updateSelection(
          const TextSelection.collapsed(offset: 6), ChangeSource.local);
      await tester.pumpAndSettle();

      expect(table.rowShiftForTest, greaterThan(0),
          reason: 'the table auto-scrolled to bring the caret into view');
      final caret = table.getLocalRectForCaret(const TextPosition(offset: 6));
      expect(caret.left, greaterThanOrEqualTo(0));
      expect(caret.right, lessThanOrEqualTo(table.size.width + 8.5),
          reason: 'caret now within the visible band (plus the reveal margin)');
    });

    testWidgets('a caret in an already-visible cell does not scroll',
        (tester) async {
      final controller = QuillController(
        document: Document.fromJson(tableRow(['A', 'B', 'C', 'D'], 'row-1')),
        selection: const TextSelection.collapsed(offset: 0),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 400,
            child: QuillEditor.basic(
              controller: controller,
              config: const QuillEditorConfig(
                autoFocus: true,
                customStyles: DefaultStyles(
                  table: DefaultTableStyle(minCellWidth: 100),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final table = tester.renderObject<RenderEditableTextTable>(
          find.byType(EditableTextTable).first);

      // Cell 'B' (offset 2) is within the viewport at rest — no scroll needed.
      controller.updateSelection(
          const TextSelection.collapsed(offset: 2), ChangeSource.local);
      await tester.pumpAndSettle();

      expect(table.rowShiftForTest, 0,
          reason: 'a caret in a visible cell must not move the table');
    });
  });

  group('Table scroll state internals', () {
    test('maxScrollExtent ignores sub-epsilon floating-point overflow', () {
      final state = TableHorizontalScrollState(vsync: const TestVSync());
      addTearDown(state.dispose);
      final row = RenderLimitedBox();

      // Evenly dividing a width can make (width / n) * n exceed width by a
      // few ULPs. Such residue must not make a visually-fitting table report
      // as scrollable (which would let it steal horizontal swipes/wheels).
      state.reportRowGeometry(row, 100 + 1e-9, 100);
      expect(state.maxScrollExtent, 0);
      expect(state.canScroll, isFalse);

      // A real overflow beyond the tolerance still scrolls.
      state.reportRowGeometry(row, 150, 100);
      expect(state.maxScrollExtent, closeTo(50, 1e-6));
      expect(state.canScroll, isTrue);
    });

    test('DefaultTableStyle has value equality so unchanged rebuilds do not '
        'force a repaint', () {
      // build() resolves a null scrollbarColor via copyWith on every rebuild;
      // with value equality two such resolutions compare equal, so the render
      // object's `value == _tableStyle` guard short-circuits instead of
      // repainting every table row on every keystroke.
      const base = DefaultTableStyle(minCellWidth: 100);
      final resolvedOnce = base.copyWith(
          scrollbarColor: DefaultTableStyle.defaultLightScrollbarColor);
      final resolvedAgain = base.copyWith(
          scrollbarColor: DefaultTableStyle.defaultLightScrollbarColor);

      expect(resolvedOnce, equals(resolvedAgain));
      expect(resolvedOnce.hashCode, equals(resolvedAgain.hashCode));

      // A genuine change is still detected.
      expect(resolvedOnce, isNot(equals(base.copyWith(minCellWidth: 120))));
    });

    test('canScrollBy reflects remaining room in each direction', () {
      final state = TableHorizontalScrollState(vsync: const TestVSync());
      addTearDown(state.dispose);
      final row = RenderLimitedBox();
      state.reportRowGeometry(row, 300, 100); // maxScrollExtent = 200

      // At offset 0: room to scroll right (positive delta), none to the left.
      // A clamped edge must not be claimed, so a scrollable ancestor gets it.
      expect(state.offset, 0);
      expect(state.canScrollBy(10), isTrue);
      expect(state.canScrollBy(-10), isFalse);
      expect(state.canScrollBy(0), isFalse);

      // In the middle: both directions have room.
      state.scrollTo(100);
      expect(state.canScrollBy(10), isTrue);
      expect(state.canScrollBy(-10), isTrue);

      // At the max extent: room left, none to the right.
      state.scrollTo(1000); // clamps to 200
      expect(state.offset, 200);
      expect(state.canScrollBy(10), isFalse);
      expect(state.canScrollBy(-10), isTrue);
    });
  });
}

class TableTestApp extends StatelessWidget {
  const TableTestApp({
    super.key,
    this.initialDelta = const [{'insert': '\n'}],
    this.editorWidth,
    this.tableStyle,
    this.theme,
  });

  final List<dynamic> initialDelta;

  /// When set, constrains the editor to this width instead of letting it
  /// fill the available space, so tests can force narrow-viewport layouts.
  final double? editorWidth;

  /// Overrides the default table style (e.g. to set a custom
  /// [DefaultTableStyle.minCellWidth]).
  final DefaultTableStyle? tableStyle;

  /// Overrides the app's theme, e.g. to test dark-theme behavior.
  final ThemeData? theme;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        appBar: AppBar(title: const Text('Table Test')),
        body: TableTestWidget(
          initialDelta: initialDelta,
          editorWidth: editorWidth,
          tableStyle: tableStyle,
        ),
      ),
    );
  }
}

class TableTestWidget extends StatefulWidget {
  const TableTestWidget({
    super.key,
    this.initialDelta = const [{'insert': '\n'}],
    this.editorWidth,
    this.tableStyle,
  });

  final List<dynamic> initialDelta;
  final double? editorWidth;
  final DefaultTableStyle? tableStyle;

  @override
  State<TableTestWidget> createState() => _TableTestWidgetState();
}

class _TableTestWidgetState extends State<TableTestWidget> {
  late final QuillController controller;

  @override
  void initState() {
    super.initState();

    final doc = Document.fromJson(widget.initialDelta);

    controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editor = QuillEditor.basic(
      controller: controller,
      config: QuillEditorConfig(
        customStyles: DefaultStyles(
          table: widget.tableStyle ??
              DefaultTableStyle(
                border: TableBorder.all(),
                cellPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                stripeColor: Colors.grey.shade400,
                headerStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (widget.editorWidth != null)
            SizedBox(width: widget.editorWidth, height: 400, child: editor)
          else
            Expanded(child: editor),
        ],
      ),
    );
  }
}