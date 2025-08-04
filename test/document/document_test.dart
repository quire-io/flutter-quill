import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:test/test.dart';

void main() {
  group('collectStyle', () {
    test('No selection', () {
      final delta = Delta()
        ..insert('plain\n')
        ..insert('bold\n', <String, dynamic>{'bold': true})
        ..insert('italic\n', <String, dynamic>{'italic': true});
      final document = Document.fromDelta(delta);
      //
      expect(
          document.getPlainText(0, document.length), 'plain\nbold\nitalic\n');
      expect(document.length, 18);
      //
      for (var index = 0; index < 6; index++) {
        expect(const Style(), document.collectStyle(index, 0));
      }
      //
      for (var index = 6; index < 11; index++) {
        expect(const Style.attr({'bold': Attribute.bold}),
            document.collectStyle(index, 0));
      }
      //
      for (var index = 11; index < document.length; index++) {
        expect(const Style.attr({'italic': Attribute.italic}),
            document.collectStyle(index, 0));
      }
    });

    /// Lists and alignments have the same block attribute key but can have different values.
    /// Changing the format value updates the document but must also update the toolbar button state
    /// by ensuring the collectStyles method returns the attribute selected for the newly entered line.
    test('Change block value type', () {
      void doTest(Map<String, dynamic> start, Attribute attr) {
        /// Create a document with 2 lines of block attribute using [start]
        /// Change the format of the last line using [attr] and verify [change]
        final delta = Delta()
          ..insert('A')
          ..insert('\n', start)
          ..insert('B', {'bold': true})
          ..insert('\n', start);
        final document = Document.fromDelta(delta)

          /// insert a newline
          ..insert(3, '\n');

        /// Verify inserted blank line and block type has not changed
        expect(
            document.toDelta(),
            Delta()
              ..insert('A')
              ..insert('\n', start)
              ..insert('B', {'bold': true})
              ..insert('\n\n', start));

        /// Change format of last (empty) line
        document.format(4, 0, attr);
        expect(
            document.toDelta(),
            Delta()
              ..insert('A')
              ..insert('\n', start)
              ..insert('B', {'bold': true})
              ..insert('\n', start)
              ..insert('\n', {attr.key: attr.value}),
            reason: 'document updated');

        /// Verify that the reported style reflects the newly formatted state
        expect(document.collectStyle(4, 0),
            Style.attr({'bold': Attribute.bold, attr.key: attr}),
            reason: 'collectStyle reporting correct attribute');
      }

      doTest({'list': 'ordered'}, const ListAttribute('bullet'));
      doTest({'list': 'checked'}, const ListAttribute('bullet'));
      doTest({}, const ListAttribute('bullet'));
      doTest({'align': 'center'}, const AlignAttribute('right'));
      doTest({'align': 'left'}, const AlignAttribute('center'));
      doTest({}, const AlignAttribute('center'));
    });

    /// Enter key inserts newline as plain text without inline styles.
    /// collectStyle needs to retrieve style of preceding line
    test('Simulate double enter key at end', () {
      final delta = Delta()
        ..insert('data\n')
        ..insert('second\n', <String, dynamic>{'bold': true})
        ..insert('\n\nplain\n');
      final document = Document.fromDelta(delta);
      //
      expect(document.getPlainText(0, document.length),
          'data\nsecond\n\n\nplain\n');
      expect(document.length, 20);
      //
      expect('data\n', document.getPlainText(0, 5));
      for (var index = 0; index < 5; index++) {
        expect(const Style(), document.collectStyle(index, 0));
      }
      //
      expect('second\n', document.getPlainText(5, 7));
      for (var index = 5; index < 12; index++) {
        expect(const Style.attr({'bold': Attribute.bold}),
            document.collectStyle(index, 0));
      }
      //
      expect('\n\n', document.getPlainText(12, 2));
      for (var index = 12; index < 14; index++) {
        expect(const Style.attr({'bold': Attribute.bold}),
            document.collectStyle(index, 0));
      }
      //
      for (var index = 14; index < document.length; index++) {
        expect(const Style(), document.collectStyle(index, 0));
      }
    });

    test('No selection', () {
      final delta = Delta()
        ..insert('plain\n')
        ..insert('bold\n', <String, dynamic>{'bold': true})
        ..insert('italic\n', <String, dynamic>{'italic': true});
      final document = Document.fromDelta(delta);
      //
      expect(
          document.getPlainText(0, document.length), 'plain\nbold\nitalic\n');
      expect(document.length, 18);
      //
      for (var index = 0; index < 6; index++) {
        expect(const Style(), document.collectStyle(index, 0));
      }
      //
      for (var index = 6; index < 11; index++) {
        expect(const Style.attr({'bold': Attribute.bold}),
            document.collectStyle(index, 0));
      }
      //
      for (var index = 11; index < document.length; index++) {
        expect(const Style.attr({'italic': Attribute.italic}),
            document.collectStyle(index, 0));
      }
    });

    test('Selection', () {
      final delta = Delta()
        ..insert('data\n')
        ..insert('second\n', <String, dynamic>{'bold': true});
      final document = Document.fromDelta(delta);
      //
      expect(const Style(), document.collectStyle(0, 4));
      expect(const Style(), document.collectStyle(1, 3));
      //
      expect(const Style.attr({'bold': Attribute.bold}),
          document.collectStyle(5, 3));
      expect(const Style.attr({'bold': Attribute.bold}),
          document.collectStyle(8, 3));
      //
      expect(const Style(), document.collectStyle(3, 3));
    });

    /// Links do not cross a line boundary
    /// Enter key inserts newline as plain text without inline styles.
    /// collectStyle needs to retrieve style of preceding line
    test('Links and line boundaries', () {
      final delta = Delta()
        ..insert('A link ')
        ..insert('home page', <String, dynamic>{'link': 'https://unknown.com'})
        ..insert('\n\nplain\n');
      final document = Document.fromDelta(delta);
      //
      const linkStyle =
          Style.attr({'link': LinkAttribute('https://unknown.com')});
      //
      expect(document.collectStyle(15, 0), linkStyle, reason: 'Within Link');
      expect(document.collectStyle(16, 0), const Style(),
          reason: 'At end of link');
      expect(document.collectStyle(17, 0), const Style(),
          reason: 'start of blank line');
      expect(document.collectStyle(18, 0), const Style(),
          reason: 'start of blank line');
    });

    /// Test cases for the collectStyle fix in line head
    /// Related to commit: fix document.collectStyle in a line head
    test('collectStyle at line head with empty lines', () {
      final delta = Delta()
        ..insert('first line\n')
        ..insert('\n') // Empty line
        ..insert('third line\n');
      final document = Document.fromDelta(delta);

      // Test collecting style at the beginning of empty line (offset 0)
      expect(document.collectStyle(11, 0), const Style(),
          reason: 'Style at empty line head should be empty');
    });

    test('collectStyle handles empty lines correctly', () {
      final delta = Delta()
        ..insert('styled', <String, dynamic>{'bold': true})
        ..insert('\n')
        ..insert('\n') // Empty line after styled content
        ..insert('normal\n');
      final document = Document.fromDelta(delta);

      // Test style collection at empty line head
      expect(document.collectStyle(7, 0), const Style.attr({'bold': Attribute.bold}),
          reason: 'Empty line should inherit inline styles from previous non-empty line');
    });

    test('collectStyle prevents negative offset calculation', () {
      final delta = Delta()
        ..insert('\n') // Start with empty line
        ..insert('content\n');
      final document = Document.fromDelta(delta);

      // Test at the very beginning (offset 0) - this should not cause negative offset issues
      expect(document.collectStyle(0, 0), const Style(),
          reason: 'Style at document start should not cause negative offset errors');
    });

    test('collectStyle with consecutive empty lines', () {
      final delta = Delta()
        ..insert('styled text', <String, dynamic>{'italic': true})
        ..insert('\n')
        ..insert('\n') // First empty line
        ..insert('\n') // Second empty line
        ..insert('normal\n');
      final document = Document.fromDelta(delta);

      // Test style at first empty line
      expect(document.collectStyle(12, 0), const Style.attr({'italic': Attribute.italic}),
          reason: 'First empty line should inherit from previous styled line');

      // Test style at second empty line
      expect(document.collectStyle(13, 0), const Style.attr({'italic': Attribute.italic}),
          reason: 'Second empty line should also inherit from previous styled line');
    });

    test('collectStyle distinguishes between empty and non-empty lines', () {
      final delta = Delta()
        ..insert('content\n')
        ..insert(' \n') // Line with space (not empty)
        ..insert('\n') // Truly empty line
        ..insert('more\n');
      final document = Document.fromDelta(delta);

      // Test at line with space (not considered empty)
      expect(document.collectStyle(8, 0), const Style(),
          reason: 'Line with space should be treated as non-empty');

      // Test at truly empty line
      expect(document.collectStyle(10, 0), const Style(),
          reason: 'Empty line should follow empty line logic');
    });

    test('collectStyle excludes header attributes from empty lines', () {
      final delta = Delta()
        ..insert('Header text', {'bold': true})
        ..insert('\n', {'header': 1})
        ..insert('\n') // Empty line after header
        ..insert('normal\n');
      final document = Document.fromDelta(delta);

      // Test style collection at empty line head - should inherit inline styles but not header
      final style = document.collectStyle(12, 0);
      expect(style.attributes.containsKey(Attribute.bold.key), isTrue,
          reason: 'Empty line should inherit inline styles like bold');
      expect(style.attributes.containsKey(Attribute.header.key), isFalse,
          reason: 'Empty line should NOT inherit header attributes as they apply only to the active line');
    });

    test('collectStyle includes header attributes at current line head', () {
      final delta = Delta()
        ..insert('Normal text\n')
        ..insert('Header text', {'bold': true})
        ..insert('\n', {'header': 1})
        ..insert('More text\n');
      final document = Document.fromDelta(delta);

      // Test style collection at the head of the header line (position 12)
      final style = document.collectStyle(12, 0);
      expect(style.attributes.containsKey(Attribute.bold.key), isTrue,
          reason: 'Line head should include inline styles');
      expect(style.attributes.containsKey(Attribute.header.key), isTrue,
          reason: 'Line head should include header attributes from the current line');
      expect(style.attributes[Attribute.header.key]?.value, 1,
          reason: 'Header level should be correct');
    });
  });
  group('cachedPlainText', () {
    late Document document;

    setUp(() {
      document = Document();
    });

    test('is null initially', () {
      expect(document.cachedPlainText, isNull);
    });

    test('updates to null when undo is called', () {
      document.cachedPlainText = 'Non-null cached plain text';
      expect(document.cachedPlainText, isNotNull);

      document.undo();
      expect(document.cachedPlainText, isNull);
    });

    test('updates to null when redo is called', () {
      final document = Document()
        ..cachedPlainText = 'Non-null cached plain text';
      expect(document.cachedPlainText, isNotNull);

      document.redo();
      expect(document.cachedPlainText, isNull);
    });

    test('returns cachedPlainText if not null', () {
      const example = 'Hello, World!';
      document.cachedPlainText = example;

      expect(document.cachedPlainText, example);
    });

    test('sets cachedPlainText if null when toPlainText is called', () {
      document.toPlainText();
      expect(document.cachedPlainText, isNotNull);
    });

    test('sets cachedPlainText correctly when toPlainText is called', () {
      const example = 'Hello\n';
      document = Document.fromDelta(Delta()..insert(example))..toPlainText();

      expect(document.cachedPlainText, isNotNull);
      expect(document.cachedPlainText, example);
    });

    test('sets cachedPlainText to null when loadDocument is called', () {
      document.cachedPlainText = 'Not null';
      expect(document.cachedPlainText, isNotNull);

      document.loadDocument(Delta()..insert('Hello\n'));

      expect(document.cachedPlainText, isNull);
    });

    test('sets cachedPlainText to null when compose is called', () {
      document.cachedPlainText = 'Not null';
      expect(document.cachedPlainText, isNotNull);

      document.compose(Delta()..insert('Hello\n'), ChangeSource.local);

      expect(document.cachedPlainText, isNull);
    });

    test('sets cachedPlainText correctly', () {
      // This test is useful in case this property has a getter and setter.
      document.cachedPlainText = 'Not null';
      expect(document.cachedPlainText, isNotNull);

      document.cachedPlainText = null;
      expect(document.cachedPlainText, isNull);
    });
  });
}
