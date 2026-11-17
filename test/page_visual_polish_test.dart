import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/ui/common/page_icon_view.dart';
import 'package:notes_here/ui/editor/cover_presets.dart';

void main() {
  group('Cover presets tests', () {
    test('getCoverDecoration resolves gradients, patterns and solid colors correctly', () {
      final aurora = getCoverDecoration('gradient:aurora');
      expect(aurora, isNotNull);
      expect(aurora!.gradient, isA<LinearGradient>());

      final studio = getCoverDecoration('pattern:studio_spotlight');
      expect(studio, isNotNull);
      expect(studio!.gradient, isA<RadialGradient>());

      final blue = getCoverDecoration('color:blue');
      expect(blue, isNotNull);
      expect(blue!.color, const Color(0xFF1A73E8));

      final hex = getCoverDecoration('color:#10B981');
      expect(hex, isNotNull);
      expect(hex!.color, const Color(0xFF10B981));
    });

    test('getCoverDecoration returns null for empty or null', () {
      expect(getCoverDecoration(null), isNull);
      expect(getCoverDecoration(''), isNull);
    });
  });

  group('Page icon view & Cupertino parsing tests', () {
    test('formatCupertinoIcon and parseCupertinoIcon roundtrip', () {
      const color = Color(0xFF8B5CF6);
      final formatted = formatCupertinoIcon('star', color);
      expect(formatted, startsWith('icon:star:#'));

      final parsed = parseCupertinoIcon(formatted);
      expect(parsed, isNotNull);
      expect(parsed!.$1, CupertinoIcons.star_fill);
      expect(parsed.$2.toARGB32(), color.toARGB32());
    });

    test('parseCupertinoIcon returns null for emoji string', () {
      expect(parseCupertinoIcon('⚡'), isNull);
      expect(parseCupertinoIcon(''), isNull);
    });

    testWidgets('PageIconView renders Text for emoji and Icon for Cupertino icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PageIconView(icon: '⚡', size: 24),
          ),
        ),
      );
      expect(find.text('⚡'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);

      final iconString = formatCupertinoIcon('star', const Color(0xFF3B82F6));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageIconView(icon: iconString, size: 24),
          ),
        ),
      );
      expect(find.text('⚡'), findsNothing);
      expect(find.byType(Icon), findsOneWidget);
      final iconWidget = tester.widget<Icon>(find.byType(Icon));
      expect(iconWidget.icon, CupertinoIcons.star_fill);
      expect(iconWidget.color?.toARGB32(), const Color(0xFF3B82F6).toARGB32());
    });
  });
}
