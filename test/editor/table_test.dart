import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

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
}

class TableTestApp extends StatelessWidget {
  const TableTestApp({
    super.key,
    this.initialDelta = const [{'insert': '\n'}],
  });

  final List<dynamic> initialDelta;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Table Test')),
        body: TableTestWidget(initialDelta: initialDelta),
      ),
    );
  }
}

class TableTestWidget extends StatefulWidget {
  const TableTestWidget({
    super.key,
    this.initialDelta = const [{'insert': '\n'}],
  });

  final List<dynamic> initialDelta;

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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: QuillEditor.basic(
              controller: controller,
              config: QuillEditorConfig(
                customStyles: DefaultStyles(
                  table: DefaultTableStyle(
                    border: TableBorder.all(),
                    cellPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    stripeColor: Colors.grey.shade400,
                    headerStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}