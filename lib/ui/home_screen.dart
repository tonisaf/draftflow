import 'common/app_icons.dart';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';

import '../data/db/app_database.dart';
import '../data/model/page_settings.dart';
import '../data/notes_repository.dart';
import '../l10n/locale_controller.dart';
import '../main.dart' show ThemeScope;
import '../modules/core/module_scope.dart';
import '../platform/desktop_services.dart' show macosSidebarWidth;
import 'common/export_import_dialog.dart';
import 'common/page_entrance.dart';
import 'common/page_link_utils.dart';
import 'common/quick_search_dialog.dart';
import 'editor/page_editor_view.dart';
import 'inbox/inbox_models.dart';
import 'inbox/inbox_view.dart';
import 'quick_notes/quick_notes_view.dart';
import 'settings/settings_dialog.dart';
import 'sidebar/sidebar.dart';
import 'theme.dart';
import 'trash/trash_view.dart';

sealed class NavLocation {
  const NavLocation();
}

class PageNavLocation extends NavLocation {
  final String pageId;
  const PageNavLocation(this.pageId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PageNavLocation && other.pageId == pageId;

  @override
  int get hashCode => pageId.hashCode;
}

class QuickNotesNavLocation extends NavLocation {
  const QuickNotesNavLocation();

  @override
  bool operator ==(Object other) => other is QuickNotesNavLocation;

  @override
  int get hashCode => 0;
}

class InboxNavLocation extends NavLocation {
  const InboxNavLocation();

  @override
  bool operator ==(Object other) => other is InboxNavLocation;

  @override
  int get hashCode => 2;
}

class TrashNavLocation extends NavLocation {
  const TrashNavLocation();

  @override
  bool operator ==(Object other) => other is TrashNavLocation;

  @override
  int get hashCode => 1;
}

class ModuleNavLocation extends NavLocation {
  final String moduleId;
  const ModuleNavLocation(this.moduleId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModuleNavLocation && other.moduleId == moduleId;

  @override
  int get hashCode => moduleId.hashCode;
}

class HomeScreen extends StatefulWidget {
  final NotesRepository repository;

  const HomeScreen({super.key, required this.repository});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedPageId;
  String? _selectedModuleId;
  bool _isShowingTrash = false;
  bool _isShowingQuickNotes = false;
  bool _isShowingInbox = false;
  bool _isSidebarVisible = true;

  final List<NavLocation> _backStack = [];
  final List<NavLocation> _forwardStack = [];

  bool get _isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

  NavLocation? get _currentLocation {
    if (_selectedModuleId != null) return ModuleNavLocation(_selectedModuleId!);
    if (_isShowingTrash) return const TrashNavLocation();
    if (_isShowingQuickNotes) return const QuickNotesNavLocation();
    if (_isShowingInbox) return const InboxNavLocation();
    if (_selectedPageId != null) return PageNavLocation(_selectedPageId!);
    return null;
  }

  bool get _canNavigateBack => _backStack.isNotEmpty;
  bool get _canNavigateForward => _forwardStack.isNotEmpty;

  void _navigateTo(NavLocation target) {
    final current = _currentLocation;
    if (current == target) return;
    if (current != null) {
      _backStack.add(current);
      if (_backStack.length > 50) _backStack.removeAt(0);
    }
    _forwardStack.clear();
    _applyLocation(target);
  }

  void _navigateBack() {
    if (!_canNavigateBack) return;
    final current = _currentLocation;
    final target = _backStack.removeLast();
    if (current != null) {
      _forwardStack.add(current);
    }
    _applyLocation(target);
  }

  void _navigateForward() {
    if (!_canNavigateForward) return;
    final current = _currentLocation;
    final target = _forwardStack.removeLast();
    if (current != null) {
      _backStack.add(current);
    }
    _applyLocation(target);
  }

  void _applyLocation(NavLocation target) {
    setState(() {
      switch (target) {
        case PageNavLocation(:final pageId):
          _isShowingTrash = false;
          _isShowingQuickNotes = false;
          _isShowingInbox = false;
          _selectedModuleId = null;
          _selectedPageId = pageId;
        case QuickNotesNavLocation():
          _isShowingTrash = false;
          _isShowingQuickNotes = true;
          _isShowingInbox = false;
          _selectedModuleId = null;
        case InboxNavLocation():
          _isShowingTrash = false;
          _isShowingQuickNotes = false;
          _isShowingInbox = true;
          _selectedModuleId = null;
        case TrashNavLocation():
          _isShowingQuickNotes = false;
          _isShowingInbox = false;
          _isShowingTrash = true;
          _selectedModuleId = null;
        case ModuleNavLocation(:final moduleId):
          _isShowingTrash = false;
          _isShowingQuickNotes = false;
          _isShowingInbox = false;
          _selectedModuleId = moduleId;
      }
    });
  }

  void _handleToggleSidebar() {
    setState(() => _isSidebarVisible = !_isSidebarVisible);
  }

  Future<void> _handleNewRootPage() async {
    final newId = await widget.repository.createPage(title: 'Untitled');
    if (!mounted) return;
    _navigateTo(PageNavLocation(newId));
  }

  Future<void> _handleNewSubpage(String parentId) async {
    final newId = await widget.repository.createPage(
      title: 'Untitled',
      parentId: parentId,
    );
    if (!mounted) return;
    _navigateTo(PageNavLocation(newId));
  }

  void _handleSelectPage(String pageId) {
    _navigateTo(PageNavLocation(pageId));
  }

  void _handleTrashPage(String pageId) async {
    await widget.repository.trashPage(pageId);
    _backStack.removeWhere(
      (loc) => loc is PageNavLocation && loc.pageId == pageId,
    );
    _forwardStack.removeWhere(
      (loc) => loc is PageNavLocation && loc.pageId == pageId,
    );
    if (_selectedPageId == pageId && mounted) {
      if (_canNavigateBack) {
        _navigateBack();
      } else {
        setState(() {
          _selectedPageId = null;
        });
      }
    }
  }

  void _handleToggleTrash() {
    if (_isShowingTrash) {
      if (_canNavigateBack) {
        _navigateBack();
      } else {
        setState(() => _isShowingTrash = false);
      }
    } else {
      _navigateTo(const TrashNavLocation());
    }
  }

  void _handleToggleQuickNotes() {
    if (_isShowingQuickNotes) {
      if (_canNavigateBack) {
        _navigateBack();
      } else {
        setState(() => _isShowingQuickNotes = false);
      }
    } else {
      _navigateTo(const QuickNotesNavLocation());
    }
  }

  void _handleToggleInbox() {
    if (_isShowingInbox) {
      if (_canNavigateBack) {
        _navigateBack();
      } else {
        setState(() => _isShowingInbox = false);
      }
    } else {
      _navigateTo(const InboxNavLocation());
    }
  }

  Future<void> _handleMovePage(
    String pageId, {
    String? targetParentId,
    String? prevOrderKey,
    String? nextOrderKey,
  }) async {
    await widget.repository.reorderPage(
      pageId: pageId,
      targetParentId: targetParentId,
      prevOrderKey: prevOrderKey,
      nextOrderKey: nextOrderKey,
    );
  }

  Future<void> _handleOpenSearch() async {
    final result = await showQuickSearchDialog(
      context,
      repository: widget.repository,
    );

    if (!mounted || result == null) return;

    if (result is OpenPageResult) {
      _handleSelectPage(result.pageId);
    } else if (result is CreatePageResult) {
      final newId = await widget.repository.createPage(
        title: result.title.trim().isEmpty ? 'Untitled' : result.title.trim(),
      );
      if (mounted) {
        _navigateTo(PageNavLocation(newId));
      }
    } else if (result is ExecuteCommandResult) {
      await _executeQuickCommand(result.command);
    }
  }

  Future<void> _executeQuickCommand(QuickCommand command) async {
    switch (command) {
      case QuickCommand.newRootPage:
        await _handleNewRootPage();
      case QuickCommand.newQuickNote:
        final newId = await widget.repository.createQuickNote(
          title: 'Новая заметка',
          body: null,
        );
        if (mounted) {
          _handleSelectPage(newId);
        }
      case QuickCommand.toggleSidebar:
        _handleToggleSidebar();
      case QuickCommand.openQuickNotes:
        if (!_isShowingQuickNotes) {
          _handleToggleQuickNotes();
        }
      case QuickCommand.openTrash:
        if (!_isShowingTrash) {
          _handleToggleTrash();
        }
      case QuickCommand.openBackup:
        _handleOpenBackup();
      case QuickCommand.toggleTheme:
        ThemeScope.of(context).cycleNext();
      case QuickCommand.toggleLanguage:
        LocaleScope.of(context).cycleNext();
    }
  }

  void _handleOpenBackup() {
    showExportImportDialog(
      context,
      repository: widget.repository,
      currentPageId: _selectedPageId,
      initialMode: ExportImportMode.workspace,
      onNavigateToPage: _handleSelectPage,
    );
  }

  void _handleExportPage(String pageId) {
    showExportImportDialog(
      context,
      repository: widget.repository,
      currentPageId: pageId,
      initialMode: ExportImportMode.page,
      onNavigateToPage: _handleSelectPage,
    );
  }

  void _handleImportNotionCsv(String pageId) {
    showExportImportDialog(
      context,
      repository: widget.repository,
      currentPageId: pageId,
      initialMode: ExportImportMode.notionCsv,
      onNavigateToPage: _handleSelectPage,
    );
  }

  void _handleCopyPageLink(String pageId) async {
    final page = await widget.repository.getPage(pageId);
    if (page != null && mounted) {
      copyPageLinkToClipboard(context, page);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyN):
            const _NewPageIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN):
            const _NewPageIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK):
            const _QuickSearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
            const _QuickSearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyP):
            const _QuickSearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyP):
            const _QuickSearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyE):
            const _ExportPageIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyE):
            const _ExportPageIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyI):
            const _ImportCsvIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyI):
            const _ImportCsvIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.alt,
          LogicalKeyboardKey.keyL,
        ): const _CopyPageLinkIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.alt,
          LogicalKeyboardKey.keyL,
        ): const _CopyPageLinkIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.comma):
            const _OpenSettingsIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.comma):
            const _OpenSettingsIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.keyK,
        ): const _QuickNotesIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.keyK,
        ): const _QuickNotesIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.bracketLeft):
            const _NavigateBackIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.bracketLeft):
            const _NavigateBackIntent(),
        LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.arrowLeft):
            const _NavigateBackIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.bracketRight):
            const _NavigateForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.bracketRight):
            const _NavigateForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.arrowRight):
            const _NavigateForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.backslash):
            const _ToggleSidebarIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.backslash):
            const _ToggleSidebarIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NewPageIntent: CallbackAction<_NewPageIntent>(
            onInvoke: (_) => _handleNewRootPage(),
          ),
          _NavigateBackIntent: CallbackAction<_NavigateBackIntent>(
            onInvoke: (_) {
              if (_canNavigateBack) _navigateBack();
              return null;
            },
          ),
          _NavigateForwardIntent: CallbackAction<_NavigateForwardIntent>(
            onInvoke: (_) {
              if (_canNavigateForward) _navigateForward();
              return null;
            },
          ),
          _ToggleSidebarIntent: CallbackAction<_ToggleSidebarIntent>(
            onInvoke: (_) {
              _handleToggleSidebar();
              return null;
            },
          ),
          _QuickNotesIntent: CallbackAction<_QuickNotesIntent>(
            onInvoke: (_) {
              _handleToggleQuickNotes();
              return null;
            },
          ),
          _QuickSearchIntent: CallbackAction<_QuickSearchIntent>(
            onInvoke: (_) => _handleOpenSearch(),
          ),
          _ExportPageIntent: CallbackAction<_ExportPageIntent>(
            onInvoke: (_) {
              if (_selectedPageId != null) {
                _handleExportPage(_selectedPageId!);
              }
              return null;
            },
          ),
          _ImportCsvIntent: CallbackAction<_ImportCsvIntent>(
            onInvoke: (_) {
              showExportImportDialog(
                context,
                repository: widget.repository,
                currentPageId: _selectedPageId,
                initialMode: ExportImportMode.notionCsv,
                onNavigateToPage: _handleSelectPage,
              );
              return null;
            },
          ),
          _CopyPageLinkIntent: CallbackAction<_CopyPageLinkIntent>(
            onInvoke: (_) {
              if (_selectedPageId != null) {
                _handleCopyPageLink(_selectedPageId!);
              }
              return null;
            },
          ),
          _OpenSettingsIntent: CallbackAction<_OpenSettingsIntent>(
            onInvoke: (_) {
              showSettings(
                context,
                onOpenBackup: _handleOpenBackup,
                repository: widget.repository,
              );
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Palette.transparent,
            body: ColoredBox(
              color: context.skin.sidebar,
              child: SafeArea(
                top: !_isMacOS,
                child: StreamBuilder<List<Page>>(
                    stream: widget.repository.watchActivePages(),
                    builder: (context, activeSnapshot) {
                      return StreamBuilder<List<Page>>(
                        stream: widget.repository.watchTrashedPages(),
                        builder: (context, trashedSnapshot) {
                          final pages = activeSnapshot.data ?? [];
                          final trashedPages = trashedSnapshot.data ?? [];
                          final trashedCount = trashedPages.length;

                          final regularPages = pages
                              .where(
                                (p) =>
                                    !pageSettingsFromProperties(p.properties)
                                        .isQuickNote &&
                                    !inboxItemFromProperties(p.properties)
                                        .isInboxItem,
                              )
                              .toList();
                          final quickNotes = pages
                              .where(
                                (p) =>
                                    pageSettingsFromProperties(p.properties)
                                        .isQuickNote,
                              )
                              .toList();
                          final inboxItems = pages
                              .where(
                                (p) =>
                                    inboxItemFromProperties(p.properties)
                                        .isInboxItem,
                              )
                              .toList();
                          final unreadInboxCount = inboxItems
                              .where(
                                (p) =>
                                    !inboxItemFromProperties(p.properties)
                                        .isArchived,
                              )
                              .length;

                          // Auto-select first page if none selected and not in trash, quick notes, inbox or module
                          if (!_isShowingTrash &&
                              !_isShowingQuickNotes &&
                              !_isShowingInbox &&
                              _selectedModuleId == null &&
                              _selectedPageId == null &&
                              regularPages.isNotEmpty) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted &&
                                  !_isShowingTrash &&
                                  !_isShowingQuickNotes &&
                                  !_isShowingInbox &&
                                  _selectedModuleId == null &&
                                  _selectedPageId == null &&
                                  regularPages.isNotEmpty) {
                                setState(
                                  () => _selectedPageId = regularPages.first.id,
                                );
                              }
                            });
                          }

                          // Find active page
                          final activePage = pages
                              .where((p) => p.id == _selectedPageId)
                              .firstOrNull;

                          final pinnedCount = quickNotes
                              .where(
                                (p) =>
                                    pageSettingsFromProperties(p.properties)
                                        .isPinned,
                              )
                              .length;

                          Widget mainPane;
                          if (_selectedModuleId != null) {
                            final module = AppModuleScope.maybeOf(context)?.getModule(_selectedModuleId!);
                            if (module != null) {
                              mainPane = PageEntrance(
                                key: ValueKey('module_${module.id}'),
                                child: module.buildView(
                                  context,
                                  repository: widget.repository,
                                  onOpenPage: _handleSelectPage,
                                ),
                              );
                            } else {
                              mainPane = const SizedBox.shrink();
                            }
                          } else if (_isShowingTrash) {
                            mainPane = PageEntrance(
                              key: const ValueKey('trash_entrance'),
                              child: TrashView(
                                key: const ValueKey('trash_view'),
                                repository: widget.repository,
                              ),
                            );
                          } else if (_isShowingQuickNotes) {
                            mainPane = PageEntrance(
                              key: const ValueKey('quick_notes_entrance'),
                              child: QuickNotesView(
                                key: const ValueKey('quick_notes_view'),
                                repository: widget.repository,
                                onNavigateToPage: _handleSelectPage,
                              ),
                            );
                          } else if (_isShowingInbox) {
                            mainPane = PageEntrance(
                              key: const ValueKey('inbox_entrance'),
                              child: InboxView(
                                key: const ValueKey('inbox_view'),
                                repository: widget.repository,
                                onNavigateToPage: _handleSelectPage,
                              ),
                            );
                          } else if (activePage != null) {
                            mainPane = PageEditorView(
                              key: ValueKey(activePage.id),
                              repository: widget.repository,
                              pageId: activePage.id,
                              title: activePage.title,
                              initialIcon: activePage.icon,
                              initialCover: activePage.cover,
                              onNavigateToPage: _handleSelectPage,
                            );
                          } else {
                            mainPane = Center(
                              key: const ValueKey('empty_state'),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: UiSpace.s60,
                                    height: UiSpace.s60,
                                    decoration: BoxDecoration(
                                      color: context.skin.hover,
                                      borderRadius: BorderRadius.circular(
                                        UiRadius.popover,
                                      ),
                                    ),
                                    child: Icon(
                                      AppIcons.book,
                                      size: UiSpace.s28,
                                      color: context.skin.muted,
                                    ),
                                  ),
                                  const SizedBox(height: UiSpace.s18),
                                  Text(
                                    context.l10n.noNoteSelected,
                                    style: TextStyle(
                                      fontSize: UiType.editorTitle,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.3,
                                      color: context.skin.text,
                                    ),
                                  ),
                                  const SizedBox(height: UiSpace.s6),
                                  Text(
                                    context.l10n.noNoteSelectedSubtitle,
                                    style: TextStyle(
                                      fontSize: UiType.body,
                                      color: context.skin.muted,
                                    ),
                                  ),
                                  const SizedBox(height: UiSpace.s20),
                                  ElevatedButton.icon(
                                    onPressed: _handleNewRootPage,
                                    icon: const Icon(
                                      AppIcons.plus,
                                      size: UiSpace.s16,
                                    ),
                                    label: Text(context.l10n.newNote),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Palette.accent,
                                      foregroundColor: Palette.onAccent,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: UiSpace.s16,
                                        vertical: UiSpace.s10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          UiRadius.control,
                                        ),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: UiType.body,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final skin = context.skin;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  top: _isMacOS ? 7.0 : 0.0,
                                  bottom: _isMacOS ? 5.0 : 0.0,
                                  left: _isMacOS ? 92.0 : UiSpace.s12,
                                  right: UiSpace.s12,
                                ),
                                child: !_isMacOS && _isSidebarVisible
                                    ? SizedBox(
                                        width: macosSidebarWidth - UiSpace.s12,
                                        height: 40.0,
                                        child: Row(
                                          children: [
                                            Text(
                                              'DraftFlow',
                                              style: TextStyle(
                                                fontSize: 13.0,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: -0.2,
                                                color: skin.text,
                                              ),
                                            ),
                                            const Spacer(),
                                            WindowNavToolbar(
                                              onToggleSidebar:
                                                  _handleToggleSidebar,
                                              isSidebarVisible:
                                                  _isSidebarVisible,
                                              onNavigateBack: _canNavigateBack
                                                  ? _navigateBack
                                                  : null,
                                              canNavigateBack: _canNavigateBack,
                                              onNavigateForward:
                                                  _canNavigateForward
                                                      ? _navigateForward
                                                      : null,
                                              canNavigateForward:
                                                  _canNavigateForward,
                                              onOpenSearch: _handleOpenSearch,
                                            ),
                                          ],
                                        ),
                                      )
                                    : SizedBox(
                                        height: _isMacOS ? null : 40.0,
                                        child: Row(
                                          children: [
                                            WindowNavToolbar(
                                              onToggleSidebar:
                                                  _handleToggleSidebar,
                                              isSidebarVisible: _isSidebarVisible,
                                              onNavigateBack: _canNavigateBack
                                                  ? _navigateBack
                                                  : null,
                                              canNavigateBack: _canNavigateBack,
                                              onNavigateForward:
                                                  _canNavigateForward
                                                      ? _navigateForward
                                                      : null,
                                              canNavigateForward:
                                                  _canNavigateForward,
                                              onOpenSearch: _handleOpenSearch,
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    ClipRect(
                                      child: AnimatedContainer(
                                        duration: Motion.panel,
                                        curve: Curves.easeOutCubic,
                                        width: _isSidebarVisible
                                            ? macosSidebarWidth
                                            : 0,
                                        child: OverflowBox(
                                          minWidth: macosSidebarWidth,
                                          maxWidth: macosSidebarWidth,
                                          alignment: Alignment.topLeft,
                                          child: Sidebar(
                                            pages: regularPages,
                                            selectedPageId: _selectedPageId,
                                            onSelectPage: _handleSelectPage,
                                            onNewRootPage: _handleNewRootPage,
                                            onNewSubpage: _handleNewSubpage,
                                            onTrashPage: _handleTrashPage,
                                            onOpenSearch: _handleOpenSearch,
                                            onMovePage: _handleMovePage,
                                            onToggleSidebar:
                                                _handleToggleSidebar,
                                            isSidebarVisible: _isSidebarVisible,
                                            onNavigateBack: _canNavigateBack
                                                ? _navigateBack
                                                : null,
                                            canNavigateBack: _canNavigateBack,
                                            onNavigateForward:
                                                _canNavigateForward
                                                    ? _navigateForward
                                                    : null,
                                            canNavigateForward:
                                                _canNavigateForward,
                                            isShowingTrash: _isShowingTrash,
                                            trashedCount: trashedCount,
                                            onToggleTrash: _handleToggleTrash,
                                            isShowingInbox: _isShowingInbox,
                                            inboxCount: unreadInboxCount,
                                            onToggleInbox: _handleToggleInbox,
                                            isShowingQuickNotes:
                                                _isShowingQuickNotes,
                                            pinnedCount: pinnedCount,
                                            onToggleQuickNotes:
                                                _handleToggleQuickNotes,
                                            selectedModuleId: _selectedModuleId,
                                            onSelectModule: (modId) {
                                              _navigateTo(ModuleNavLocation(modId));
                                            },
                                            onOpenBackup: _handleOpenBackup,
                                            onOpenSettings: () {
                                              showSettings(
                                                context,
                                                onOpenBackup: _handleOpenBackup,
                                                repository: widget.repository,
                                              );
                                            },
                                            onExportPage: _handleExportPage,
                                            onImportNotionCsv:
                                                _handleImportNotionCsv,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: _ContentCard(
                                        hasLeftMargin: !_isSidebarVisible,
                                        child: mainPane,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final Widget child;
  final bool hasLeftMargin;

  const _ContentCard({
    required this.child,
    this.hasLeftMargin = false,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final shape = UiRadius.squircle(
      UiRadius.notice,
      side: BorderSide(color: skin.hairlineBorder),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        hasLeftMargin ? UiSpace.s10 : 0,
        0,
        UiSpace.s10,
        UiSpace.s10,
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: skin.surface,
          shape: shape,
          shadows: skin.cardShadows,
        ),
        child: ClipPath(
          clipper: ShapeBorderClipper(
            shape: UiRadius.squircle(UiRadius.notice),
          ),
          // Live editors own focus, overlays and save sessions. Unmount the old
          // page immediately rather than painting two documents in a crossfade.
          child: child,
        ),
      ),
    );
  }
}

class _NewPageIntent extends Intent {
  const _NewPageIntent();
}

class _QuickSearchIntent extends Intent {
  const _QuickSearchIntent();
}

class _ExportPageIntent extends Intent {
  const _ExportPageIntent();
}

class _ImportCsvIntent extends Intent {
  const _ImportCsvIntent();
}

class _CopyPageLinkIntent extends Intent {
  const _CopyPageLinkIntent();
}

class _OpenSettingsIntent extends Intent {
  const _OpenSettingsIntent();
}

class _QuickNotesIntent extends Intent {
  const _QuickNotesIntent();
}

class _NavigateBackIntent extends Intent {
  const _NavigateBackIntent();
}

class _NavigateForwardIntent extends Intent {
  const _NavigateForwardIntent();
}

class _ToggleSidebarIntent extends Intent {
  const _ToggleSidebarIntent();
}
