import 'package:flutter/material.dart';

import '../../account/account_controller.dart';
import '../../account/account_scope.dart';
import '../../data/notes_repository.dart';
import '../../l10n/locale_controller.dart';
import '../../main.dart' show ThemeController, ThemeScope;
import '../common/app_dialog.dart';
import '../common/quiet_button.dart';
import '../theme.dart';
import 'modules_section.dart';
import 'settings_widgets.dart';
import 'sync_section.dart';
import 'update_section.dart';

const String _appName = 'DraftFlow';
const String _appVersion = '1.0.1';

/// Wide screens get a fixed-size dialog; narrow screens a full-screen page.
Future<void> showSettings(
  BuildContext context, {
  VoidCallback? onOpenBackup,
  NotesRepository? repository,
  int initialTab = 0,
}) {
  if (MediaQuery.sizeOf(context).width < 600) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MobileSettingsPage(
          onOpenBackup: onOpenBackup,
          repository: repository,
        ),
      ),
    );
  }
  return showSpringDialog<void>(
    context: context,
    barrierColor: Palette.scrim,
    builder: (_) => SettingsDialog(
      onOpenBackup: onOpenBackup,
      repository: repository,
      initialTab: initialTab,
    ),
  );
}

enum _SectionKind { general, sync, modules }

typedef _Section = (_SectionKind, String, Widget Function());

List<_Section> _sections(
  BuildContext context, {
  VoidCallback? onOpenBackup,
  NotesRepository? repository,
}) {
  final l10n = context.l10n;
  final account = AccountScope.maybeOf(context);
  final repo = repository ?? account?.repository;
  return [
    (
      _SectionKind.general,
      l10n.settingsTabGeneral,
      () => _general(context, onOpenBackup: onOpenBackup),
    ),
    if (account != null)
      (
        _SectionKind.sync,
        l10n.sync,
        () => _syncTab(context, account),
      ),
    (
      _SectionKind.modules,
      'Модули',
      () => ModulesSettingsTab(repository: repo),
    ),
  ];
}

Widget _general(
  BuildContext context, {
  VoidCallback? onOpenBackup,
  bool desktop = false,
}) {
  final l10n = context.l10n;
  final theme = ThemeScope.of(context);
  final locale = LocaleScope.of(context);
  Widget row(String title, String subtitle, Widget control) => LayoutBuilder(
    builder: (context, constraints) => SettingRow(
      title: title,
      subtitle: subtitle,
      stacked:
          constraints.maxWidth < 440 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.15,
      trailing: control,
    ),
  );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Caption(l10n.settingsAppearance),
      SettingsCard(
        children: [
          row(l10n.theme, l10n.themeHelp, _ThemeChoice(controller: theme)),
          row(
            l10n.language,
            l10n.languageHelp,
            _LanguageChoice(controller: locale),
          ),
        ],
      ),
      if (onOpenBackup != null) ...[
        const SizedBox(height: 24),
        _Caption(l10n.workspaceSection),
        SettingsCard(
          children: [
            row(
              l10n.workspaceBackup,
              l10n.workspaceBackupHelp,
              _ActionPill(
                label: l10n.openAction,
                onTap: () {
                  Navigator.of(context).pop();
                  onOpenBackup();
                },
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 16),
      Text(
        l10n.settingsAutoApply,
        style: TextStyle(fontSize: 12, color: context.skin.muted),
      ),
      const SizedBox(height: 24),
      const _Caption('Обновления'),
      const AppUpdateSection(),
      if (!desktop) ...[
        const SizedBox(height: 24),
        _Caption(l10n.about),
        const SettingsCard(children: [_AboutCompact()]),
      ],
    ],
  );
}

Widget _syncTab(BuildContext context, AccountController account) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    _Hint(context.l10n.syncHelp),
    SettingsCard(children: [SyncSection(controller: account)]),
  ],
);

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    this.onOpenBackup,
    this.repository,
    this.initialTab = 0,
  });

  final VoidCallback? onOpenBackup;
  final NotesRepository? repository;
  final int initialTab;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late int _tab = widget.initialTab;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final theme = ThemeScope.of(context);
    final locale = LocaleScope.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: GlassSurface(
        radius: UiRadius.modal,
        color: skin.glassStrong,
        child: ListenableBuilder(
                  listenable: Listenable.merge([theme, locale]),
                  builder: (context, _) {
                    final tabs = _sections(
                      context,
                      onOpenBackup: widget.onOpenBackup,
                      repository: widget.repository,
                    );
                    final index = _tab.clamp(0, tabs.length - 1);
                    final current = tabs[index];
                    final content = Scrollbar(
                      controller: _scroll,
                      child: SingleChildScrollView(
                        controller: _scroll,
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: Text(
                                current.$2,
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (current.$1 == _SectionKind.general)
                              Text(
                                l10n.generalSettingsHelp,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: skin.muted,
                                ),
                              ),
                            const SizedBox(height: 24),
                            if (current.$1 == _SectionKind.general)
                              _general(
                                context,
                                onOpenBackup: widget.onOpenBackup,
                                desktop: true,
                              )
                            else
                              current.$3(),
                          ],
                        ),
                      ),
                    );
                    Widget navigation() => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, t) in tabs.indexed)
                          _NavItem(
                            label: t.$2,
                            selected: i == index,
                            onTap: () {
                              if (_scroll.hasClients) _scroll.jumpTo(0);
                              setState(() => _tab = i);
                            },
                          ),
                      ],
                    );
                    return SizedBox(
                      key: const ValueKey('settings-window'),
                      width: 820,
                      height: 620,
                      child: Stack(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                key: const ValueKey('settings-sidebar'),
                                width: 170,
                                color: skin.surfaceVariant,
                                child: LayoutBuilder(
                                  builder: (context, constraints) =>
                                      SingleChildScrollView(
                                        physics: const ClampingScrollPhysics(),
                                        padding: const EdgeInsets.fromLTRB(
                                          10,
                                          20,
                                          10,
                                          18,
                                        ),
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minHeight:
                                                (constraints.maxHeight - 38)
                                                    .clamp(0, double.infinity),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.fromLTRB(
                                                          10,
                                                          0,
                                                          10,
                                                          8,
                                                        ),
                                                    child: Text(
                                                      l10n.settings,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: skin.muted,
                                                      ),
                                                    ),
                                                  ),
                                                  navigation(),
                                                ],
                                              ),
                                              const Padding(
                                                padding: EdgeInsets.fromLTRB(
                                                  10,
                                                  24,
                                                  10,
                                                  0,
                                                ),
                                                child: _AboutCompact(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                              Expanded(child: content),
                            ],
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: CloseCross(
                              tooltip: l10n.close,
                              onTap: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      ),
    );
  }
}

class _AboutCompact extends StatelessWidget {
  const _AboutCompact();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Row(
      children: [
        Expanded(
          child: Text(
            _appName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: skin.text,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          _appVersion,
          textAlign: TextAlign.end,
          style: TextStyle(fontSize: 12, color: skin.muted),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: QuietButton(
        label: label,
        selected: selected,
        onTap: onTap,
        builder:
            (context, {required hover, required focus, required pressed}) =>
                Container(
                  constraints: const BoxConstraints(minHeight: 38),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? skin.sidebarSelected
                        : hover || pressed
                        ? skin.hover
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: focus ? Border.all(color: skin.accentText) : null,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                      color: skin.text,
                    ),
                  ),
                ),
      ),
    );
  }
}

/// Narrow screens: a list of sections, each opening as its own full-screen page.
class MobileSettingsPage extends StatelessWidget {
  const MobileSettingsPage({super.key, this.onOpenBackup, this.repository});

  final VoidCallback? onOpenBackup;
  final NotesRepository? repository;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final sections = _sections(
      context,
      onOpenBackup: onOpenBackup,
      repository: repository,
    );
    return Scaffold(
      backgroundColor: skin.card,
      appBar: AppBar(
        backgroundColor: skin.card,
        scrolledUnderElevation: 0,
        title: Text(
          context.l10n.settings,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SettingsCard(
              children: [
                for (final (_, label, build) in sections)
                  InkWell(
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => _MobileSectionPage(
                          title: label,
                          body: build,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: skin.muted),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileSectionPage extends StatelessWidget {
  const _MobileSectionPage({
    required this.title,
    required this.body,
  });

  final String title;
  final Widget Function() body;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final theme = ThemeScope.of(context);
    final locale = LocaleScope.of(context);
    return Scaffold(
      backgroundColor: skin.card,
      appBar: AppBar(
        backgroundColor: skin.card,
        scrolledUnderElevation: 0,
        title: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([theme, locale]),
          builder: (context, _) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: body(),
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, color: context.skin.muted),
    ),
  );
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: context.skin.text,
      ),
    ),
  );
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsChoice<ThemeMode>(
      label: l10n.theme,
      value: controller.mode,
      choices: {
        ThemeMode.system: l10n.themeAuto,
        ThemeMode.light: l10n.themeLightShort,
        ThemeMode.dark: l10n.themeDarkShort,
      },
      onChanged: controller.setMode,
    );
  }
}

class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({required this.controller});

  final LocaleController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = controller.locale?.languageCode ?? 'system';
    return SettingsChoice<String>(
      label: l10n.language,
      value: current,
      choices: {
        'system': l10n.languageSystem,
        'ru': l10n.languageRu,
        'en': l10n.languageEn,
      },
      onChanged: (code) => controller.setLocale(
        code == 'system' ? null : Locale(code),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: skin.text,
        backgroundColor: Color.alphaBlend(skin.surfaceVariant, skin.surface),
        minimumSize: const Size(138, 34),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        shape: const StadiumBorder(),
      ),
      child: Text(label),
    );
  }
}
