import 'package:flutter/material.dart';
import '../../../theme.dart';

/// A container that pins the gutter and Title column to the left edge of the
/// horizontal scroll viewport while allowing remaining columns to scroll underneath.
class DatabaseStickyPane extends StatelessWidget {
  final ScrollController? horizontalScrollController;
  final double width;
  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final bool isFrozen;

  const DatabaseStickyPane({
    super.key,
    this.horizontalScrollController,
    required this.width,
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    this.isFrozen = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isFrozen || horizontalScrollController == null) {
      return SizedBox(
        width: width,
        child: child,
      );
    }

    return AnimatedBuilder(
      animation: horizontalScrollController!,
      builder: (context, _) {
        final offset = horizontalScrollController!.hasClients
            ? horizontalScrollController!.offset
            : 0.0;
        final hasScrolled = offset > 0.5;

        return Transform.translate(
          offset: Offset(offset, 0),
          child: Container(
            width: width,
            decoration: BoxDecoration(
              color: backgroundColor,
              boxShadow: hasScrolled
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 4,
                        offset: const Offset(2, 0),
                      ),
                    ]
                  : null,
            ),
            foregroundDecoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: borderColor,
                  width: UiSpace.s0_8,
                ),
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }
}
