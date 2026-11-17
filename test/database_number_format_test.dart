import 'dart:convert';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/ui/editor/components/database/database_cells.dart';
import 'package:notes_here/ui/editor/components/database/database_models.dart';
import 'package:notes_here/ui/editor/components/database/database_property_menu.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Number formatting unit tests', () {
    test('default NumberColumnConfig', () {
      const config = NumberColumnConfig();
      expect(config.format, 'number');
      expect(config.decimalPlaces, isNull);
      expect(config.showAs, 'number');
      expect(config.maxValue, 100.0);
    });

    test('NumberColumnConfig json serialization and deserialization', () {
      const config = NumberColumnConfig(
        format: 'usd',
        decimalPlaces: 2,
        showAs: 'bar',
        maxValue: 250.0,
      );
      final jsonStr = config.toOptions();
      final parsed = NumberColumnConfig.fromOptions(jsonStr);

      expect(parsed.format, 'usd');
      expect(parsed.decimalPlaces, 2);
      expect(parsed.showAs, 'bar');
      expect(parsed.maxValue, 250.0);
    });

    test('formatNumberValue formats plain number', () {
      const config = NumberColumnConfig(format: 'number');
      expect(formatNumberValue(42, config), '42');
      expect(formatNumberValue(1234.56, config), '1234.56');
      expect(formatNumberValue(-42.5, config), '-42.5');
    });

    test('formatNumberValue with separators', () {
      const config = NumberColumnConfig(format: 'number_with_separators');
      expect(formatNumberValue(1234567.89, config), '1,234,567.89');
      expect(formatNumberValue(-9876543, config), '-9,876,543');
    });

    test('formatNumberValue with percent', () {
      const config = NumberColumnConfig(format: 'percent');
      expect(formatNumberValue(42, config), '42%');
      expect(formatNumberValue(85.5, config), '85.5%');
    });

    test('formatNumberValue with currencies', () {
      expect(
        formatNumberValue(42, const NumberColumnConfig(format: 'usd')),
        r'$42',
      );
      expect(
        formatNumberValue(1234.5, const NumberColumnConfig(format: 'usd', decimalPlaces: 2)),
        r'$1,234.50',
      );
      expect(
        formatNumberValue(500, const NumberColumnConfig(format: 'rub')),
        '₽500',
      );
      expect(
        formatNumberValue(75.2, const NumberColumnConfig(format: 'eur', decimalPlaces: 2)),
        '€75.20',
      );
      expect(
        formatNumberValue(-100, const NumberColumnConfig(format: 'rub')),
        '-₽100',
      );
    });

    test('formatNumberValue with fixed decimal places', () {
      const config0 = NumberColumnConfig(format: 'number', decimalPlaces: 0);
      expect(formatNumberValue(42.7, config0), '43');

      const config3 = NumberColumnConfig(format: 'number', decimalPlaces: 3);
      expect(formatNumberValue(42, config3), '42.000');
    });
  });

  group('Number property menu widget tests', () {
    testWidgets('shows Number format, Decimal places, and Show as cards', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? updatedOptions;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [Skin.of(Brightness.light)]),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDatabasePropertyMenu(
                    context,
                    anchor: const Rect.fromLTWH(100, 100, 150, 40),
                    name: 'Amount',
                    type: 'number',
                    options: null,
                    onOptionsChange: (opts) => updatedOptions = opts,
                  );
                },
                child: const Text('Open Menu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Menu'));
      await tester.pumpAndSettle();

      // Check that "Number format" row exists
      expect(find.text('Number format'), findsOneWidget);
      expect(find.byKey(const ValueKey('number_format_row')), findsOneWidget);

      // Check that "Decimal places" row exists
      expect(find.text('Decimal places'), findsOneWidget);
      expect(find.byKey(const ValueKey('number_decimal_places_row')), findsOneWidget);

      // Check that "Show as" section exists
      expect(find.text('Show as'), findsOneWidget);
      expect(find.byKey(const ValueKey('show_as_number')), findsOneWidget);
      expect(find.byKey(const ValueKey('show_as_bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('show_as_ring')), findsOneWidget);

      // Check caption
      expect(
        find.text('Changes apply to all views showing this property.'),
        findsOneWidget,
      );

      // Tap Bar card
      await tester.tap(find.byKey(const ValueKey('show_as_bar')));
      await tester.pumpAndSettle();

      expect(updatedOptions, isNotNull);
      final decodedBar = jsonDecode(updatedOptions!) as Map<String, dynamic>;
      expect(decodedBar['showAs'], 'bar');

      // Now "Divide by" row appears
      expect(find.text('Divide by'), findsOneWidget);

      // Tap Ring card
      await tester.tap(find.byKey(const ValueKey('show_as_ring')));
      await tester.pumpAndSettle();

      final decodedRing = jsonDecode(updatedOptions!) as Map<String, dynamic>;
      expect(decodedRing['showAs'], 'ring');
    });

    testWidgets('opens Number format picker and filters formats', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? updatedOptions;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [Skin.of(Brightness.light)]),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDatabasePropertyMenu(
                    context,
                    anchor: const Rect.fromLTWH(100, 100, 150, 40),
                    name: 'Cost',
                    type: 'number',
                    options: null,
                    onOptionsChange: (opts) => updatedOptions = opts,
                  );
                },
                child: const Text('Open Menu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Menu'));
      await tester.pumpAndSettle();

      // Tap Number format row
      await tester.tap(find.byKey(const ValueKey('number_format_row')));
      await tester.pumpAndSettle();

      // Check that filter input is shown
      expect(find.byKey(const ValueKey('number_format_filter_input')), findsOneWidget);
      expect(find.text('Filter formats...'), findsOneWidget);

      // Enter 'rub' into filter
      await tester.enterText(find.byKey(const ValueKey('number_format_filter_input')), 'rub');
      await tester.pumpAndSettle();

      // Should find Ruble (RUB)
      expect(find.text('Ruble (RUB)'), findsOneWidget);
      expect(find.text('US Dollar (USD)'), findsNothing);

      // Click Ruble (RUB)
      await tester.tap(find.text('Ruble (RUB)'));
      await tester.pumpAndSettle();

      expect(updatedOptions, isNotNull);
      final decoded = jsonDecode(updatedOptions!) as Map<String, dynamic>;
      expect(decoded['format'], 'rub');

      // The main row should now display Ruble (RUB)
      expect(find.text('Ruble (RUB)'), findsOneWidget);
    });

    testWidgets('opens Decimal places picker and updates places', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? updatedOptions;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [Skin.of(Brightness.light)]),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDatabasePropertyMenu(
                    context,
                    anchor: const Rect.fromLTWH(100, 100, 150, 40),
                    name: 'Points',
                    type: 'number',
                    options: null,
                    onOptionsChange: (opts) => updatedOptions = opts,
                  );
                },
                child: const Text('Open Menu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Menu'));
      await tester.pumpAndSettle();

      // Tap Decimal places row
      await tester.tap(find.byKey(const ValueKey('number_decimal_places_row')));
      await tester.pumpAndSettle();

      // Check decimal options
      expect(find.text('Default'), findsWidgets);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Tap '2'
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      expect(updatedOptions, isNotNull);
      final decoded = jsonDecode(updatedOptions!) as Map<String, dynamic>;
      expect(decoded['decimalPlaces'], 2);
    });
  });

  group('DatabaseNumberCell rendering and editing widget tests', () {
    testWidgets('renders formatted number and switches to textfield on tap', (tester) async {
      dynamic committedVal;

      final col = DatabaseColumn(
        id: 'col_num',
        databaseId: 'db1',
        name: 'Price',
        type: 'number',
        options: jsonEncode({'format': 'usd', 'decimalPlaces': 2}),
        width: 160.0,
        orderKey: 'a',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [Skin.of(Brightness.light)]),
          home: Scaffold(
            body: SizedBox(
              width: 160,
              height: 40,
              child: DatabaseNumberCell(
                column: col,
                cellValue: 42.5,
                onChanged: (val) => committedVal = val,
              ),
            ),
          ),
        ),
      );

      // Should display formatted $42.50
      expect(find.text(r'$42.50'), findsOneWidget);

      // Tap the cell to start editing
      await tester.tap(find.text(r'$42.50'));
      await tester.pumpAndSettle();

      // Should now show TextField with raw 42.5
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('42.5'), findsOneWidget);

      // Enter 99 and submit
      await tester.enterText(find.byType(TextField), '99');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(committedVal, 99);
    });

    testWidgets('renders progress bar when showAs is bar', (tester) async {
      final col = DatabaseColumn(
        id: 'col_bar',
        databaseId: 'db1',
        name: 'Progress',
        type: 'number',
        options: jsonEncode({'showAs': 'bar', 'maxValue': 100, 'format': 'percent'}),
        width: 160.0,
        orderKey: 'a',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [Skin.of(Brightness.light)]),
          home: Scaffold(
            body: SizedBox(
              width: 160,
              height: 40,
              child: DatabaseNumberCell(
                column: col,
                cellValue: 65,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('65%'), findsOneWidget);
      expect(find.byType(FractionallySizedBox), findsOneWidget);
      final fractionBox = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
      expect(fractionBox.widthFactor, closeTo(0.65, 0.001));
    });

    testWidgets('renders progress ring when showAs is ring', (tester) async {
      final col = DatabaseColumn(
        id: 'col_ring',
        databaseId: 'db1',
        name: 'Completion',
        type: 'number',
        options: jsonEncode({'showAs': 'ring', 'maxValue': 100, 'format': 'number'}),
        width: 160.0,
        orderKey: 'a',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [Skin.of(Brightness.light)]),
          home: Scaffold(
            body: SizedBox(
              width: 160,
              height: 40,
              child: DatabaseNumberCell(
                column: col,
                cellValue: 50,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('50'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders duration and parses typed input into seconds', (tester) async {
      dynamic committedVal;

      final col = DatabaseColumn(
        id: 'col_dur',
        databaseId: 'db1',
        name: 'Time Spent',
        type: 'number',
        options: jsonEncode({'format': 'duration_human'}),
        width: 160.0,
        orderKey: 'a',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [Skin.of(Brightness.light)]),
          home: Scaffold(
            body: SizedBox(
              width: 160,
              height: 40,
              child: DatabaseNumberCell(
                column: col,
                cellValue: 9180, // 2h 33m
                onChanged: (val) => committedVal = val,
              ),
            ),
          ),
        ),
      );

      // Should display 2h 33m
      expect(find.text('2h 33m'), findsOneWidget);

      // Tap to edit
      await tester.tap(find.text('2h 33m'));
      await tester.pumpAndSettle();

      // Enter 1d 4h 30m 15s in Russian/English
      await tester.enterText(find.byType(TextField), '1d 4h 30m 15s');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // 1*86400 + 4*3600 + 30*60 + 15 = 102615
      expect(committedVal, 102615);
    });

    testWidgets('duration picker popover allows setting days, hours, mins, secs', (tester) async {
      dynamic committedVal;

      final col = DatabaseColumn(
        id: 'col_dur_pop',
        databaseId: 'db1',
        name: 'Estimate',
        type: 'number',
        options: jsonEncode({'format': 'duration_human'}),
        width: 160.0,
        orderKey: 'a',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [Skin.of(Brightness.light)]),
          home: Scaffold(
            body: SizedBox(
              width: 160,
              height: 40,
              child: DatabaseNumberCell(
                column: col,
                cellValue: 3600, // 1h
                onChanged: (val) => committedVal = val,
              ),
            ),
          ),
        ),
      );

      // Click to enter editing mode
      await tester.tap(find.text('1h'));
      await tester.pumpAndSettle();

      // Click the duration picker button (clock icon)
      expect(find.byKey(const ValueKey('open_duration_picker_btn')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('open_duration_picker_btn')));
      await tester.pumpAndSettle();

      // Check fields in DurationPickerContent
      expect(find.text('Duration'), findsOneWidget);
      expect(find.byKey(const ValueKey('duration_days_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('duration_hours_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('duration_mins_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('duration_secs_input')), findsOneWidget);

      // Set days: 2, hours: 3, mins: 45, secs: 10
      await tester.enterText(find.byKey(const ValueKey('duration_days_input')), '2');
      await tester.enterText(find.byKey(const ValueKey('duration_hours_input')), '3');
      await tester.enterText(find.byKey(const ValueKey('duration_mins_input')), '45');
      await tester.enterText(find.byKey(const ValueKey('duration_secs_input')), '10');

      // Click Apply
      await tester.tap(find.byKey(const ValueKey('apply_duration_btn')));
      await tester.pumpAndSettle();

      // 2*86400 + 3*3600 + 45*60 + 10 = 172800 + 10800 + 2700 + 10 = 186310
      expect(committedVal, 186310);
    });
  });

  group('Duration parsing and formatting unit tests', () {
    test('parseDurationToSeconds with various unit formats', () {
      expect(parseDurationToSeconds('1d 2h 30m 15s'), 95415);
      expect(parseDurationToSeconds('1д 2ч 30м 15с'), 95415);
      expect(parseDurationToSeconds('3 days 5 hours'), 3 * 86400 + 5 * 3600);
      expect(parseDurationToSeconds('45m 20s'), 45 * 60 + 20);
      expect(parseDurationToSeconds('1.5h'), 5400);
      expect(parseDurationToSeconds('01:30:00'), 5400);
      expect(parseDurationToSeconds('05:30'), 330);
      expect(parseDurationToSeconds('500'), 500);
    });

    test('formatDurationHuman formats cleanly', () {
      expect(formatDurationHuman(95415), '1d 2h 30m 15s');
      expect(formatDurationHuman(3600), '1h');
      expect(formatDurationHuman(90), '1m 30s');
      expect(formatDurationHuman(45), '45s');
      expect(formatDurationHuman(0), '0s');
      expect(formatDurationHuman(-3600), '-1h');
    });

    test('formatDurationHms and formatDurationMs format colon notation', () {
      expect(formatDurationHms(5400), '01:30:00');
      expect(formatDurationMs(330), '05:30');
    });
  });
}
