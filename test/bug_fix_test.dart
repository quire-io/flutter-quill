import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_test/flutter_quill_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'common/utils/quill_test_app.dart';
import 'editor/editor_config_utils.dart';

void main() {
  group('Bug fix', () {
    group(
        '1266 - QuillToolbar.basic() custom buttons do not have correct fill'
        'color set', () {
      testWidgets('fillColor of custom buttons and builtin buttons match',
          (tester) async {
        const tooltip = 'custom button';

        final controller = QuillController.basic();

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates:
                FlutterQuillLocalizations.localizationsDelegates,
            home: Scaffold(
              body: QuillSimpleToolbar(
                controller: controller,
                config: const QuillSimpleToolbarConfig(
                  showRedo: false,
                  customButtons: [
                    QuillToolbarCustomButtonOptions(
                      tooltip: tooltip,
                    )
                  ],
                ),
              ),
            ),
          ),
        );

        final builtinFinder = find.descendant(
          of: find.byType(QuillToolbarHistoryButton),
          matching: find.byType(QuillToolbarIconButton),
          matchRoot: true,
        );
        expect(builtinFinder, findsOneWidget);

        final customFinder = find.descendant(
            of: find.byType(QuillSimpleToolbar),
            matching: find.byWidgetPredicate((widget) =>
                widget is QuillToolbarIconButton && widget.tooltip == tooltip),
            matchRoot: true);
        expect(customFinder, findsOneWidget);
      });
    });

    group('1189 - The provided text position is not in the current node', () {
      late QuillController controller;
      late QuillEditor editor;

      setUp(() {
        controller = QuillController.basic();
        editor = QuillEditor.basic(
          controller: controller,
        );
      });

      tearDown(() {
        controller.dispose();
      });

      testWidgets('Refocus editor after controller clears document',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [editor],
            ),
          ),
        );
        await tester.quillEnterText(find.byType(QuillEditor), 'test\n');

        editor.focusNode.unfocus();
        await tester.pump();
        controller.clear();
        editor.focusNode.requestFocus();
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('Refocus editor after removing block attribute',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Column(
            children: [editor],
          ),
        ));
        await tester.quillEnterText(find.byType(QuillEditor), 'test\n');

        controller.formatSelection(Attribute.ul);
        editor.focusNode.unfocus();
        await tester.pump();
        controller.formatSelection(const ListAttribute(null));
        editor.focusNode.requestFocus();
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('Tap checkbox in unfocused editor', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [editor],
            ),
          ),
        );
        await tester.quillEnterText(find.byType(QuillEditor), 'test\n');

        controller.formatSelection(Attribute.unchecked);
        editor.focusNode.unfocus();
        await tester.pump();
        await tester.tap(find.byType(QuillCheckboxPoint));
        expect(tester.takeException(), isNull);
      });
    });
  });

  group('1742 - Disable context menu after selection for desktop platform', () {
    late QuillController controller;

    setUp(() {
      controller = QuillController.basic();
    });

    tearDown(() {
      controller.dispose();
    });

    for (final device in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
      testWidgets(
          '1742 - Disable context menu after selection for desktop platform $device',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: QuillEditor(
              focusNode: FocusNode(),
              scrollController: ScrollController(),
              controller: controller,
              config: const QuillEditorConfig(
                autoFocus: true,
                expands: true,
              ),
            ),
          ),
        );
        if (device == PointerDeviceKind.mouse) {
          expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
          // Long press to show menu
          await tester.longPress(find.byType(QuillEditor), kind: device);
          await tester.pumpAndSettle();

          // Verify custom widget not shows
          expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);

          await tester.tap(find.byType(QuillEditor),
              buttons: kSecondaryButton, kind: device);
          await tester.pumpAndSettle();
          while (find.byType(AdaptiveTextSelectionToolbar).evaluate().isEmpty) {
            await tester.pumpAndSettle();
          }

          // Verify custom widget shows
          expect(find.byType(AdaptiveTextSelectionToolbar), findsAny);
        } else {
          // Long press to show menu
          await tester.longPress(find.byType(QuillEditor), kind: device);
          await tester.pumpAndSettle();

          // Verify custom widget shows
          expect(find.byType(AdaptiveTextSelectionToolbar), findsAny);
        }
      });
    }
  });
  group(
    "2521 - QuillEditor doesn't respect the system keyboard brightness by default on iOS",
    () {
      test('keyboardAppearance defaults to null', () {
        expect(const QuillEditorConfig().keyboardAppearance, null);
        expect(
          createFakeRawEditorConfig().keyboardAppearance,
          null,
        );
      });

      testWidgets('uses the keyboardAppearance from the config if not null',
          (tester) async {
        for (final keyboardAppearanceValue in {
          Brightness.dark,
          Brightness.light
        }) {
          final key = GlobalKey<QuillRawEditorState>();
          await tester.pumpWidget(
            QuillTestApp.home(
              QuillRawEditor(
                key: key,
                config: createFakeRawEditorConfig(
                    keyboardAppearance: keyboardAppearanceValue),
                controller: QuillController.basic(),
              ),
            ),
          );

          final keyboardAppearance =
              key.currentState?.createKeyboardAppearance();

          expect(keyboardAppearance, keyboardAppearanceValue);
        }
      });

      testWidgets(
          'uses the keyboardAppearance from the ThemeData if not declared in the config',
          (tester) async {
        for (final keyboardAppearanceValue in {
          Brightness.dark,
          Brightness.light
        }) {
          final key = GlobalKey<QuillRawEditorState>();
          await tester.pumpWidget(
            QuillTestApp.home(
              CupertinoTheme(
                data: CupertinoThemeData(brightness: keyboardAppearanceValue),
                child: Theme(
                  data: ThemeData(brightness: keyboardAppearanceValue),
                  child: QuillRawEditor(
                    key: key,
                    config: createFakeRawEditorConfig(keyboardAppearance: null),
                    controller: QuillController.basic(),
                  ),
                ),
              ),
            ),
          );

          final keyboardAppearance =
              key.currentState?.createKeyboardAppearance();

          expect(keyboardAppearance, keyboardAppearanceValue);
        }
      });
    },
  );

  group(
    '2487 - Cannot add to a fixed-length list when painting the selection '
    'over an empty non-left-aligned line',
    () {
      testWidgets(
        'does not throw when the selection spans an empty line in an RTL editor',
        (tester) async {
          // In an RTL editor a line with TextAlign.start resolves to
          // right-aligned. Once the editor is laid out and then resized,
          // Flutter's TextPainter keeps the cached paragraph width while
          // updating its content width, so its paintOffset becomes non-zero and
          // TextPainter.getBoxesForSelection returns a fixed-length list. For an
          // empty line contained by the selection, the paint code then appends
          // the empty-line marker rect to that list, which used to throw
          // "Unsupported operation: Cannot add to a fixed-length list".
          // Reproduces the Arabic "Select All" crash from the issue.
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.binding.setSurfaceSize(const Size(800, 600));

          final controller = QuillController(
            document: Document.fromJson([
              {'insert': 'مرحبا'},
              {'insert': '\n'},
              {'insert': '\n'},
              {'insert': 'عالم'},
              {'insert': '\n'},
            ]),
            // Spans the empty line (document offset 6) without reaching the
            // document end, to isolate this crash from the unrelated
            // "text position is not in the current node" assertion.
            selection: const TextSelection(baseOffset: 0, extentOffset: 8),
          );
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            QuillTestApp.home(
              Directionality(
                textDirection: TextDirection.rtl,
                child: QuillEditor.basic(controller: controller),
              ),
            ),
          );

          // Resize the surface so the cached paragraph width no longer matches
          // the content width, forcing a non-zero paintOffset on repaint.
          await tester.binding.setSurfaceSize(const Size(400, 600));
          await tester.pump();

          expect(tester.takeException(), isNull);
        },
      );
    },
  );
}
