import 'attribute.dart';

// Attributes that don't conform to standard Quill Delta
// and are not compatible with https://quilljs.com/docs/delta/

/// This attribute represents the space between text lines. The line height can be
/// adjusted using predefined constants or custom values
///
/// The attribute at the json looks like: "attributes":{"line-height": 1.5 }
class LineHeightAttribute extends Attribute<double?> {
  const LineHeightAttribute({double? lineHeight})
      : super('line-height', AttributeScope.block, lineHeight);

  static const Attribute<double?> lineHeightNormal =
      LineHeightAttribute(lineHeight: 1);

  static const Attribute<double?> lineHeightTight =
      LineHeightAttribute(lineHeight: 1.15);

  static const Attribute<double?> lineHeightOneAndHalf =
      LineHeightAttribute(lineHeight: 1.5);

  static const Attribute<double?> lineHeightDouble =
      LineHeightAttribute(lineHeight: 2);
}

/// A Quire custom block attribute for nested blockquotes.
class NestedBlockquoteAttribute extends Attribute<int?> {
  const NestedBlockquoteAttribute({int? level})
      : super('nested-blockquote', AttributeScope.block, level);
}

/// A Quire custom block attribute for soft line breaks.
class LineAttribute extends Attribute<bool> {
  const LineAttribute() : super('line', AttributeScope.block, true);
}