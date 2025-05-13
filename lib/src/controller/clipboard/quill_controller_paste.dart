@internal
library;

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../../../flutter_quill.dart';
import '../../../quill_delta.dart';

extension QuillControllerPaste on QuillController {
  @internal
  Future<bool> pastePlainTextOrDelta(
    String? clipboardText, {
    required String pastePlainText,
    required Delta pasteDelta,
  }) async {
    if (clipboardText != null) {
      /// Internal copy-paste preserves styles and embeds
      if (clipboardText == pastePlainText &&
          pastePlainText.isNotEmpty &&
          pasteDelta.isNotEmpty) {
        replaceText(selection.start, selection.end - selection.start,
            pasteDelta, TextSelection.collapsed(offset: selection.end));
      } else {
        // Potix: Introduce onPlainTextPaste2 to insert Delta
        Object? pastedContent = clipboardText;

        final onPlainTextPaste2 = config.clipboardConfig?.onPlainTextPaste2;
        if (onPlainTextPaste2 != null) {
          final delta = await onPlainTextPaste2(clipboardText);
          if (delta != null) {
            pastedContent = delta;
          }
        }

        final newPos = switch (pastedContent) {
          Delta() => pastedContent.transformPosition(selection.end),
          String() => selection.end + pastedContent.length,
          _ => selection.end,
        };

        replaceText(
            selection.start,
            selection.end - selection.start,
            pastedContent,
            TextSelection.collapsed(
                offset: newPos));
      }
      return true;
    }
    return false;
  }

  Future<String> getTextToPaste(String clipboardPlainText) async {
    final onPlainTextPaste = config.clipboardConfig?.onPlainTextPaste;
    if (onPlainTextPaste != null) {
      final plainText = await onPlainTextPaste(clipboardPlainText);
      if (plainText != null) {
        return plainText;
      }
    }
    return clipboardPlainText;
  }
}
