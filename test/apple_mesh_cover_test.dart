import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/model/page_settings.dart';
import 'package:notes_here/ui/editor/components/page_header.dart';
import 'package:notes_here/ui/editor/cover_presets.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Apple Mesh Cover Presets & Parser', () {
    test('contains macOS Sonoma and Sequoia presets with 4-stop orbs', () {
      expect(kAppleMeshCovers.length, greaterThanOrEqualTo(10));

      final sequoia = kAppleMeshCovers.firstWhere((m) => m.id == 'mesh:sequoia_sunrise');
      expect(sequoia.label, 'Sequoia Sunrise');
      expect(sequoia.orbs.length, 4);

      final sonoma = kAppleMeshCovers.firstWhere((m) => m.id == 'mesh:sonoma_horizon');
      expect(sonoma.label, 'Sonoma Horizon');
      expect(sonoma.orbs.length, 4);

      // parseMeshCoverId matches preset
      final parsed = parseMeshCoverId('mesh:sequoia_forest');
      expect(parsed, isNotNull);
      expect(parsed!.label, 'Sequoia Forest');
    });

    test('generateMeshFromIcon generates tailored harmonized mesh palettes', () {
      // 1. Nature / Plants
      final plantMesh = generateMeshFromIcon('🌿');
      expect(plantMesh.label, 'Sequoia Sage');
      expect(plantMesh.orbs.length, 4);

      // 2. Fire / Warm
      final fireMesh = generateMeshFromIcon('🔥');
      expect(fireMesh.label, 'Sonoma Amber');

      // 3. Water / Ocean
      final waterMesh = generateMeshFromIcon('🌊');
      expect(waterMesh.label, 'Pacific Cyan');

      // 4. Cosmic / Magic
      final cosmicMesh = generateMeshFromIcon('🔮');
      expect(cosmicMesh.label, 'Cosmic Violet');

      // 5. Arbitrary emoji uses universal harmonic generator
      final pizzaMesh = generateMeshFromIcon('🍕');
      expect(pizzaMesh.id.startsWith('mesh:'), isTrue);

      // Custom mesh ID can be round-tripped through parseMeshCoverId
      final parsedCustom = parseMeshCoverId(pizzaMesh.id);
      expect(parsedCustom, isNotNull);
      expect(parsedCustom!.orbs.length, greaterThanOrEqualTo(3));
    });

    test('getCoverDecoration returns valid decoration for mesh covers', () {
      final decor = getCoverDecoration('mesh:sequoia_sunrise');
      expect(decor, isNotNull);
      expect(decor!.gradient, isNotNull);
    });
  });

  group('Cover Repositioning (coverY)', () {
    test('PageSettings persists coverY', () {
      const defaultSettings = PageSettings();
      expect(defaultSettings.coverY, 0.5);

      final shifted = defaultSettings.copyWith(coverY: 0.85);
      expect(shifted.coverY, 0.85);

      // JSON roundtrip
      final jsonStr = '{"_notes_here_page": {"coverY": 0.25, "fullWidth": true}}';
      final parsed = pageSettingsFromProperties(jsonStr);
      expect(parsed.coverY, 0.25);
      expect(parsed.fullWidth, isTrue);
    });

    testWidgets('PageHeader renders reposition button and handles drag', (tester) async {
      double? savedY;
      final controller = TextEditingController(text: 'My Page');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PageHeader(
                titleController: controller,
                onTitleChanged: (_) {},
                icon: '🌿',
                cover: 'mesh:sequoia_forest',
                coverY: 0.5,
                onUpdateCoverY: (newY) => savedY = newY,
                onAddOrChangeIcon: () {},
                onRemoveIcon: () {},
                onAddOrChangeCover: () {},
                onRemoveCover: () {},
              ),
            ),
          ),
        ),
      );

      // Verify cover banner is rendered
      expect(find.byKey(const Key('page_cover_banner')), findsOneWidget);

      // Verify widget renders AppleMeshCoverWidget
      expect(find.byType(AppleMeshCoverWidget), findsOneWidget);

      // Reposition button is in the tree
      final repositionButton = find.byKey(const Key('cover_reposition_button'));
      expect(repositionButton, findsOneWidget);

      // Simulate mouse hover over the cover banner to make buttons visible
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(const Key('page_cover_banner'))));
      await tester.pumpAndSettle();

      // Tap reposition button to enter repositioning mode
      await tester.tap(repositionButton);
      await tester.pumpAndSettle();

      // Guide pill should now be visible
      expect(find.text('Потяните для настройки положения'), findsOneWidget);
      expect(find.text('Сохранить'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);

      // Drag vertically
      await tester.drag(find.byKey(const Key('page_cover_banner')), const Offset(0, -50));
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      expect(savedY, isNotNull);
      expect(savedY, isNot(equals(0.5)));
    });
  });
}
