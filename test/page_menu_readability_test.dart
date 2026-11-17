import 'package:notes_here/ui/common/app_icons.dart';

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/editor/components/page_more_actions_button.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final font = File(
    '${Platform.environment['WINDIR'] ?? 'C:/Windows'}/Fonts/segoeui.ttf',
  );
  setUpAll(() async {
    if (!font.existsSync()) return;
    await (FontLoader('MenuTest')..addFont(
          Future.value(ByteData.sublistView(await font.readAsBytes())),
        ))
        .load();
  });
  for (final language in ['ru', 'en']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '$language $brightness page menu labels fit at 125% text',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildTheme(brightness).copyWith(
                textTheme: buildTheme(brightness).textTheme
                    .apply(fontFamily: 'MenuTest'),
              ),
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(1.25)),
                child: child!,
              ),
              home: Scaffold(
                body: Center(
                  child: PageMoreActionsButton(
                    onCopyPageLink: () {},
                    onExportMarkdown: () {},
                    onImportNotionCsv: () {},
                    onImportMarkdown: () {},
                    onCopyMarkdown: () {},
                    onSaveMarkdownToFile: () {},
                    onOpenBackup: () {},
                    onPageSettingsChanged: (_) {},
                    onSubpageLayoutChanged: (_) {},
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.byType(PageMoreActionsButton));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final element in find.byType(RichText).evaluate()) {
            final paragraph = element.renderObject! as RenderParagraph;
            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason: paragraph.text.toPlainText(),
            );
          }
          expect(find.byIcon(AppIcons.checkMark), findsOneWidget);
        },
        skip: !font.existsSync(),
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }
}
