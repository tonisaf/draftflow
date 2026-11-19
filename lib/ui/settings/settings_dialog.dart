import 'package:flutter/cupertino.dart'
    show
        CupertinoIcons,
        CupertinoSlidingSegmentedControl;
import 'package:flutter/material.dart';

import '../../account/account_controller.dart';
import '../../account/account_scope.dart';
import '../../data/notes_repository.dart';
import '../../l10n/locale_controller.dart';
import '../../main.dart' show ThemeController, ThemeScope;
import '../../services/app_update_service.dart' show currentAppVersion;
import '../common/app_dialog.dart';
import '../common/quiet_button.dart';
import '../theme.dart';
import 'modules_section.dart';
import 'settings_widgets.dart';
import 'sync_section.dart';
import 'update_section.dart';

const String _appName = 'DraftFlow';
const String _appVersion = currentAppVersion;

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

typedef _Section = (_SectionKind, String, IconData, Widget Function());

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
      CupertinoIcons.gear_alt,
      () => _general(context, onOpenBackup: onOpenBackup),
    ),
    if (account != null)
      (
        _SectionKind.sync,
        l10n.sync,
        CupertinoIcons.arrow_2_circlepath,
        () => _syncTab(context, account),
      ),
    (
      _SectionKind.modules,
      'Модули',
      CupertinoIcons.square_grid_2x2,
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
          constraints.maxWidth < 560 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.15,
      trailing: control,
    ),
  );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (desktop) ...[
        _Caption(l10n.settingsAppearance),
        _ThemeCardsChoice(controller: theme),
        const SizedBox(height: 24),
        _Caption(l10n.workspaceSection),
        SettingsCard(
          children: [
            row(
              l10n.language,
              l10n.languageHelp,
              _LanguageChoice(controller: locale),
            ),
            if (onOpenBackup != null)
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
      ] else ...[
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
      ],
      const SizedBox(height: 14),
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                        padding: const EdgeInsets.fromLTRB(36, 28, 36, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 24),
                              child: Text(
                                current.$2,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (current.$1 == _SectionKind.general)
                              Text(
                                l10n.generalSettingsHelp,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: skin.muted,
                                  height: 1.4,
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
                              current.$4(),
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
                            icon: t.$3,
                            selected: i == index,
                            onTap: () {
                              if (_scroll.hasClients) _scroll.jumpTo(0);
                              setState(() => _tab = i);
                            },
                          ),
                      ],
                    );
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final dialogWidth =
                            constraints.maxWidth.clamp(360.0, 840.0);
                        final dialogHeight =
                            constraints.maxHeight.clamp(420.0, 640.0);
                        return SizedBox(
                          key: const ValueKey('settings-window'),
                          width: dialogWidth,
                          height: dialogHeight,
                          child: Stack(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                key: const ValueKey('settings-sidebar'),
                                width: 196,
                                decoration: BoxDecoration(
                                  color: skin.sidebar,
                                  border: Border(
                                    right: BorderSide(
                                      color: skin.hairlineBorder,
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) =>
                                      SingleChildScrollView(
                                        physics: const ClampingScrollPhysics(),
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          18,
                                          12,
                                          14,
                                        ),
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minHeight:
                                                (constraints.maxHeight - 32)
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
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        letterSpacing: 0.6,
                                                        color: skin.muted,
                                                      ),
                                                    ),
                                                  ),
                                                  navigation(),
                                                ],
                                              ),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  const Padding(
                                                    padding:
                                                        EdgeInsets.fromLTRB(
                                                          8,
                                                          16,
                                                          8,
                                                          8,
                                                        ),
                                                    child: _AboutCompact(),
                                                  ),
                                                  _UserSidebarTile(
                                                    account: AccountScope.maybeOf(context),
                                                    onTap: () {
                                                      final syncIdx = tabs.indexWhere(
                                                        (t) => t.$1 == _SectionKind.sync,
                                                      );
                                                      if (syncIdx >= 0) {
                                                        if (_scroll.hasClients) _scroll.jumpTo(0);
                                                        setState(() => _tab = syncIdx);
                                                      }
                                                    },
                                                  ),
                                                ],
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
                            top: 14,
                            right: 14,
                            child: CloseCross(
                              tooltip: l10n.close,
                              onTap: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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

class _UserSidebarTile extends StatefulWidget {
  const _UserSidebarTile({
    super.key,
    required this.account,
    required this.onTap,
  });

  final AccountController? account;
  final VoidCallback onTap;

  @override
  State<_UserSidebarTile> createState() => _UserSidebarTileState();
}

class _UserSidebarTileState extends State<_UserSidebarTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final user = widget.account?.account;
    final email = user?.email;
    final hasUser = email != null && email.isNotEmpty;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered ? skin.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(UiRadius.control),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Palette.accent.withValues(
                    alpha: skin.isDark ? 0.22 : 0.12,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: hasUser
                    ? Text(
                        email.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Palette.accent,
                        ),
                      )
                    : Icon(
                        CupertinoIcons.person,
                        size: 15,
                        color: skin.muted,
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasUser ? email : 'Локальный режим',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: skin.text,
                      ),
                    ),
                    Text(
                      hasUser ? 'Синхронизировано' : 'Оффлайн',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: skin.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = skin.isDark;
    final isSelected = widget.selected;

    final Color bg = isSelected
        ? (isDark ? const Color(0xFF2E3137) : const Color(0xFFE8EAED))
        : (_hovered
            ? (isDark ? const Color(0xFF26282E) : const Color(0xFFF1F3F5))
            : Colors.transparent);

    final Color fg = isSelected
        ? skin.text
        : (_hovered ? skin.text : skin.text.withValues(alpha: 0.85));
    final Color iconColor = isSelected ? Palette.accent : skin.muted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            constraints: const BoxConstraints(minHeight: 34),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(UiRadius.control),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 16,
                  color: iconColor,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: fg,
                    ),
                  ),
                ),
              ],
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
                for (final (_, label, _, build) in sections)
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
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: context.skin.text,
      ),
    ),
  );
}

class _ThemeCardsChoice extends StatelessWidget {
  const _ThemeCardsChoice({required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = controller.mode;
    final isRu = Localizations.localeOf(context).languageCode == 'ru';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 440;
        final cards = [
          SelectableOptionCard(
            title: l10n.themeAuto,
            description: isRu
                ? 'Следовать теме операционной системы'
                : 'Follow operating system appearance',
            icon: CupertinoIcons.device_desktop,
            selected: current == ThemeMode.system,
            onTap: () => controller.setMode(ThemeMode.system),
          ),
          SelectableOptionCard(
            title: l10n.themeLightShort,
            description: isRu
                ? 'Контрастный дневной интерфейс'
                : 'Crisp high-contrast day palette',
            icon: CupertinoIcons.sun_max,
            selected: current == ThemeMode.light,
            onTap: () => controller.setMode(ThemeMode.light),
          ),
          SelectableOptionCard(
            title: l10n.themeDarkShort,
            description: isRu
                ? 'Комфортная ночная палитра'
                : 'Comfortable low-glare night palette',
            icon: CupertinoIcons.moon,
            selected: current == ThemeMode.dark,
            onTap: () => controller.setMode(ThemeMode.dark),
          ),
        ];

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, card) in cards.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                card,
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, card) in cards.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: card),
            ],
          ],
        );
      },
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    return CupertinoSlidingSegmentedControl<ThemeMode>(
      groupValue: controller.mode,
      backgroundColor: skin.hover,
      thumbColor: skin.card,
      children: {
        ThemeMode.system: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            l10n.themeAuto,
            style: TextStyle(
              fontSize: 12,
              fontWeight: controller.mode == ThemeMode.system
                  ? FontWeight.w600
                  : FontWeight.w400,
              color: skin.text,
            ),
          ),
        ),
        ThemeMode.light: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            l10n.themeLightShort,
            style: TextStyle(
              fontSize: 12,
              fontWeight: controller.mode == ThemeMode.light
                  ? FontWeight.w600
                  : FontWeight.w400,
              color: skin.text,
            ),
          ),
        ),
        ThemeMode.dark: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            l10n.themeDarkShort,
            style: TextStyle(
              fontSize: 12,
              fontWeight: controller.mode == ThemeMode.dark
                  ? FontWeight.w600
                  : FontWeight.w400,
              color: skin.text,
            ),
          ),
        ),
      },
      onValueChanged: (mode) {
        if (mode != null) controller.setMode(mode);
      },
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

typedef _ActionPill = ActionPill;
