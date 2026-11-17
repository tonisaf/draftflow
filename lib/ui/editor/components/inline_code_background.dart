import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../theme.dart';

/// Paints behind actual text boxes without replacing text with WidgetSpans.
/// UTF-16 offsets, wrapping, caret placement and clipboard text stay native.
class InlineCodeBackground extends SingleChildRenderObjectWidget {
  const InlineCodeBackground({
    super.key,
    required this.color,
    required super.child,
  });
  final Color color;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _InlineCodeBackground(color);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _InlineCodeBackground).color = color;
  }
}

class _InlineCodeBackground extends RenderProxyBox {
  _InlineCodeBackground(this._color);
  Color _color;
  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final paint = Paint()..color = _color;
    void visit(RenderObject object) {
      if (object is RenderParagraph && object.hasSize) {
        var index = 0;
        void spans(InlineSpan span, TextStyle? inherited) {
          final style = inherited?.merge(span.style) ?? span.style;
          if (span is TextSpan) {
            final text = span.text ?? '';
            final start = index;
            index += text.length;
            final mono =
                style?.fontFamily == 'Consolas' || style?.fontFamily == 'Menlo';
            if (text.isNotEmpty &&
                mono &&
                style?.backgroundColor == Palette.transparent) {
              final transform = object.getTransformTo(this);
              for (final box in object.getBoxesForSelection(
                TextSelection(baseOffset: start, extentOffset: index),
              )) {
                final rect = MatrixUtils.transformRect(
                  transform,
                  box.toRect(),
                ).inflate(1.5).shift(offset);
                context.canvas.drawRRect(
                  RRect.fromRectAndRadius(rect, const Radius.circular(3)),
                  paint,
                );
              }
            }
            for (final child in span.children ?? const <InlineSpan>[]) {
              spans(child, style);
            }
          } else if (span is PlaceholderSpan) {
            index++;
          }
        }

        spans(object.text, null);
      }
      object.visitChildren(visit);
    }

    if (child != null) visit(child!);
    super.paint(context, offset);
  }
}
