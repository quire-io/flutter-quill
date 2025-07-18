import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Table Test', () {
    testWidgets('Render a table', (tester) async {
      await tester.pumpWidget(const TableTestApp());
      expect(find.text('This is a test with a table block below:', findRichText: true), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('Cell A', findRichText: true), findsOneWidget);
      expect(find.text('Cell B', findRichText: true), findsOneWidget);
    });
  });
}

class TableTestApp extends StatelessWidget {
  const TableTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Table Test')),
        body: const TableTestWidget(),
      ),
    );
  }
}

class TableTestWidget extends StatefulWidget {
  const TableTestWidget({super.key});

  @override
  State<TableTestWidget> createState() => _TableTestWidgetState();
}

class _TableTestWidgetState extends State<TableTestWidget> {
  late QuillController controller;

  @override
  void initState() {
    super.initState();

    final doc = Document.fromJson([
      {
        'insert': 'This is a test with a table block below:\n',
      },
      {
        'insert': 'Cell A',
      },
      {
        'insert': '\n',
        'attributes': {'table': '1'},
      },
      {
        'insert': 'Cell B',
      },
      {
        'insert': '\n',
        'attributes': {'table': '1'},
      },
      {
        'insert': 'End of test',
      },
      {
        'insert': '\n',
      },
    ]);

    controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true, // Make it read-only for this test
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
          const Text(
            'Testing table support',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: QuillEditor.basic(
              controller: controller,
            ),
          ),
        ],
      ),
    );
  }
}
