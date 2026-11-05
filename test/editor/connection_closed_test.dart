import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_test/flutter_quill_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late QuillController controller;

  setUp(() {
    controller = QuillController.basic();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    controller.dispose();
  });

  // #26148: iOS closes the connection on its own (e.g. app inactive) while the
  // editor keeps focus
  testWidgets('Platform-closed connection is cleared and reopened on resume',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuillEditor.basic(
          controller: controller,
          config: const QuillEditorConfig(autoFocus: true),
        ),
      ),
    );
    await tester.tap(find.byType(QuillEditor));
    await tester.pump();
    expect(tester.testTextInput.hasAnyClients, isTrue);

    tester.testTextInput.log.clear();
    tester.testTextInput.closeConnection();
    await tester.pump();
    expect(
      tester.testTextInput.log.map((call) => call.method),
      contains('TextInput.clearClient'),
    );

    tester.testTextInput.log.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(
      tester.testTextInput.log.map((call) => call.method),
      contains('TextInput.setClient'),
    );

    await tester.quillEnterText(find.byType(QuillEditor), 'ok\n');
    expect(controller.document.toPlainText(), 'ok\n');

    // flutter_test checks foundation overrides before tearDown runs
    debugDefaultTargetPlatformOverride = null;
  });
}
