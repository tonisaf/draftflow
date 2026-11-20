import 'cover_presets.dart';
import 'components/notes_block_builders.dart';
import 'components/notes_text_span_decorator.dart';
import '../common/app_icons.dart';
import '../../account/account_controller.dart';
import '../../account/account_scope.dart';

import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';

import '../../data/db/app_database.dart';
import '../../data/notes_repository.dart';
import '../../l10n/locale_controller.dart';
import '../../platform/desktop_services.dart';
import '../../services/auto_save_service.dart';
import '../../services/title_edit_session.dart';
import '../../services/export_import_service.dart';
import '../common/cover_picker_dialog.dart';
import '../common/emoji_picker_dialog.dart';
import '../common/export_import_dialog.dart';
import '../common/page_link_picker_dialog.dart';
import '../common/page_link_utils.dart';
import '../common/page_entrance.dart';
import '../common/status_pill.dart';
import '../theme.dart';
import 'components/backlinks_section.dart';
import 'components/draft_conflict_dialog.dart';
import 'components/code_block_component.dart';
import 'components/database_block_component.dart';
import 'components/editor_flowy_config.dart';
import 'components/image_paste.dart';
import 'components/page_breadcrumbs.dart';
import 'components/page_header.dart';
import 'components/retina_toolbar_items.dart';
import 'components/subpages_panel.dart';
import '../../data/model/page_settings.dart';
import '../../data/model/database_initial_data.dart';
import 'components/page_more_actions_button.dart';
import 'components/page_stats.dart';

class PageEditorView extends StatefulWidget {
  final NotesRepository repository;
  final String pageId;
  final String title;
  final String? initialIcon;
  final String? initialCover;
  final ValueChanged<String>? onTitleChanged;
  final ValueChanged<String>? onNavigateToPage;
  final Widget Function(BuildContext context, Widget body, Widget actions)?
  frameBuilder;
  final bool compactHeader;

  const PageEditorView({
    super.key,
    required this.repository,
    required this.pageId,
    required this.title,
    this.initialIcon,
    this.initialCover,
    this.onTitleChanged,
    this.onNavigateToPage,
    this.frameBuilder,
    this.compactHeader = false,
  });

  @override
  State<PageEditorView> createState() => _PageEditorViewState();
}

class _PageEditorViewState extends State<PageEditorView>
    with WidgetsBindingObserver {
  late TitleEditSession _titleSession;
  TextEditingController get _titleController => _titleSession.controller;

  String? _icon;
  String? _cover;

  EditorState? _editorState;
  EditorScrollController? _editorScrollController;
  final FocusNode _editorFocusNode = FocusNode();
  AutoSaveService? _autoSaveService;
  List<Page> _breadcrumbs = const [];
  List<Page> _backlinks = const [];
  Page? _initialPage;
  List<Page> _initialChildren = const [];
  Map<String, DatabaseInitialData> _initialDatabases = const {};
  bool _isLoading = true;
  bool _showSpinner = false;
  Timer? _spinnerTimer;
  int _loadGeneration = 0;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _setupLinkHandler();
    _icon = widget.initialIcon;
    _cover = widget.initialCover;
    _titleSession = _createTitleSession();
    WidgetsBinding.instance.addObserver(this);
    DesktopImageDropBridge.registerDropHandler(_handleDroppedImages);
    _loadDocumentAndBreadcrumbs();
  }

  void _setupLinkHandler() {
    editorLaunchUrl = (String? href) async {
      if (href != null && href.startsWith('page://')) {
        final targetPageId = href.substring(7);
        widget.onNavigateToPage?.call(targetPageId);
        return true;
      }
      return safeLaunchUrl(href);
    };
  }

  AccountController? _accountController;
  int? _syncRevision;
  bool _refreshingSync = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AccountScope.maybeOf(context);
    if (controller != _accountController) {
      _accountController?.unregisterSaver(_flushForAccountSwitch);
      _accountController = controller;
      controller?.registerSaver(_flushForAccountSwitch);
      _syncRevision = controller?.syncRevision;
    }
    if (controller != null && _syncRevision != controller.syncRevision) {
      _syncRevision = controller.syncRevision;
      if (controller.syncChangedPages.contains(widget.pageId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_refreshAfterSync());
        });
      }
    }
  }

  Future<void> _refreshAfterSync() async {
    if (_refreshingSync || _isLoading) return;
    _refreshingSync = true;
    final requested = _syncRevision;
    final service = _autoSaveService;
    try {
      await service?.forceSave();
      if (!mounted ||
          service != _autoSaveService ||
          service?.statusNotifier.value == SaveStatus.conflict ||
          service?.statusNotifier.value == SaveStatus.error) {
        return;
      }
      await _loadDocumentAndBreadcrumbs();
    } finally {
      _refreshingSync = false;
      if (mounted && requested != _syncRevision) unawaited(_refreshAfterSync());
    }
  }

  Future<void> _flushForAccountSwitch() async {
    final failureMessage = context.l10n.failedToSaveBeforeAccountSwitch;
    await _titleSession.flush();
    await _autoSaveService?.forceSave();
    if (_titleSession.status.value == TitleSaveStatus.error ||
        _autoSaveService?.statusNotifier.value == SaveStatus.error) {
      throw AccountFailure(failureMessage);
    }
  }

  @override
  void didUpdateWidget(covariant PageEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _setupLinkHandler();
    if (oldWidget.pageId != widget.pageId ||
        oldWidget.repository != widget.repository) {
      _titleSession.dispose();
      _titleSession = _createTitleSession();
      _icon = widget.initialIcon;
      _cover = widget.initialCover;
      _loadDocumentAndBreadcrumbs();
    } else {
      if (oldWidget.title != widget.title) {
        _titleSession.receiveExternal(widget.title);
      }
      if (oldWidget.initialIcon != widget.initialIcon) {
        _icon = widget.initialIcon;
      }
      if (oldWidget.initialCover != widget.initialCover) {
        _cover = widget.initialCover;
      }
    }
  }

  Future<void> _loadDocumentAndBreadcrumbs() async {
    final loadSyncRevision = _accountController?.syncRevision ?? 0;
    _spinnerTimer?.cancel();
    _releaseEditor();
    final pageId = widget.pageId;
    final generation = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _showSpinner = false;
      _loadFailed = false;
    });
    // Показываем индикатор загрузки только если операция занимает больше 140 мс,
    // чтобы при обычном локальном переключении страниц (5-20 мс) не возникало мерцания.
    _spinnerTimer = Timer(const Duration(milliseconds: 140), () {
      if (mounted && generation == _loadGeneration && _isLoading) {
        setState(() => _showSpinner = true);
      }
    });
    final repository = widget.repository;
    late final List<Object> results;
    try {
      results = await Future.wait<Object>([
        repository.loadPageSnapshot(pageId),
        repository.getBreadcrumbs(pageId),
        repository.getBacklinks(pageId),
        repository.getDrafts(pageId),
      ]);
    } catch (_) {
      _spinnerTimer?.cancel();
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _isLoading = false;
          _showSpinner = false;
          _loadFailed = true;
        });
      }
      return;
    }

    if (!mounted || generation != _loadGeneration) {
      _spinnerTimer?.cancel();
      return;
    }

    final snapshot = results[0] as ({Document document, String version});
    final drafts = results[3] as List<EditorDraft>;
    final draft = drafts.firstOrNull;
    final doc = draft == null
        ? snapshot.document
        : widget.repository.documentFromDraft(draft);
    final breadcrumbs = results[1] as List<Page>;
    final backlinks = results[2] as List<Page>;

    // Mount the document only when its inline databases have their first page.
    // Otherwise a zero-height, falsely empty table pushes every following block
    // down as soon as its separate streams finish loading.
    final databaseIds = <String>{};
    void collectDatabases(Node node) {
      if (node.type == databaseBlockType &&
          node.attributes['databaseId'] is String) {
        databaseIds.add(node.attributes['databaseId'] as String);
      }
      for (final child in node.children) {
        collectDatabases(child);
      }
    }

    collectDatabases(doc.root);
    late final List<Object?> presentation;
    try {
      presentation = await Future.wait<Object?>([
        repository.getPage(pageId),
        repository.getChildPages(pageId),
        Future.wait(databaseIds.map(repository.loadDatabaseInitialData)),
      ]);
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
      return;
    }
    if (!mounted || generation != _loadGeneration) return;
    final initialDatabases = presentation[2] as List<DatabaseInitialData>;

    final editorState = EditorState(document: doc);
    final scrollController = EditorScrollController(editorState: editorState);
    final autoSave = AutoSaveService(
      repository: widget.repository,
      pageId: pageId,
      editorState: editorState,
      initialVersion: draft?.baseVersion ?? snapshot.version,
      recoveredDraft: draft,
    );

    await clearOrphanedDatabaseSlash(editorState);
    if (!mounted || generation != _loadGeneration) {
      autoSave.dispose();
      scrollController.dispose();
      editorState.dispose();
      return;
    }

    _spinnerTimer?.cancel();
    setState(() {
      _editorState = editorState;
      _editorScrollController = scrollController;
      _autoSaveService = autoSave;
      _breadcrumbs = breadcrumbs;
      _backlinks = backlinks;
      _initialPage = presentation[0] as Page?;
      _initialChildren = presentation[1] as List<Page>;
      _initialDatabases = Map.fromIterables(databaseIds, initialDatabases);
      _isLoading = false;
      _showSpinner = false;
    });
    if (loadSyncRevision != (_accountController?.syncRevision ?? 0)) {
      unawaited(_refreshAfterSync());
    }
  }

  Future<void> _resolveConflict() async {
    final service = _autoSaveService;
    final state = _editorState;
    if (service == null || state == null) return;
    await service.forceSave();
    if (!mounted || service != _autoSaveService) return;
    final resolved = await showDraftConflictDialog(
      context,
      repository: widget.repository,
      pageId: widget.pageId,
      localDocument: state.document,
      useLocal: service.useLocalVersion,
      useSaved: service.useSavedVersion,
    );
    if (!mounted || service != _autoSaveService || resolved != true) return;
    service.dispose();
    _autoSaveService = null;
    await _loadDocumentAndBreadcrumbs();
  }

  TitleEditSession _createTitleSession() {
    final repository = widget.repository;
    final pageId = widget.pageId;
    final onSaved = widget.onTitleChanged;
    return TitleEditSession(
      title: widget.title,
      save: (text) async {
        await repository.updatePageTitle(pageId, text);
        if (mounted &&
            widget.pageId == pageId &&
            widget.repository == repository) {
          onSaved?.call(text);
        }
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_titleSession.flush());
      unawaited(_autoSaveService?.forceSave() ?? Future.value());
    }
  }

  Future<void> _changeIcon() async {
    final chosen = await showEmojiPickerDialog(context, currentEmoji: _icon);
    if (chosen != null && mounted) {
      final newIcon = chosen.isEmpty ? null : chosen;
      setState(() => _icon = newIcon);
      await widget.repository.updatePageIcon(widget.pageId, newIcon);
      final crumbs = await widget.repository.getBreadcrumbs(widget.pageId);
      if (mounted) setState(() => _breadcrumbs = crumbs);
    }
  }

  Future<void> _removeIcon() async {
    setState(() => _icon = null);
    await widget.repository.updatePageIcon(widget.pageId, null);
    final crumbs = await widget.repository.getBreadcrumbs(widget.pageId);
    if (mounted) setState(() => _breadcrumbs = crumbs);
  }

  Future<void> _changeCover() async {
    final chosen = await showCoverPickerDialog(
      context,
      currentCover: _cover,
      pageIcon: _icon,
    );
    if (chosen != null && mounted) {
      final newCover = chosen.isEmpty ? null : chosen;
      setState(() => _cover = newCover);
      await widget.repository.updatePageCover(widget.pageId, newCover);
    }
  }

  Future<void> _removeCover() async {
    setState(() => _cover = null);
    await widget.repository.updatePageCover(widget.pageId, null);
  }

  Future<void> _openExportDialog(ExportImportMode mode) async {
    await showExportImportDialog(
      context,
      repository: widget.repository,
      currentPageId: widget.pageId,
      currentPageTitle: _titleController.text,
      initialMode: mode,
      onNavigateToPage: widget.onNavigateToPage,
    );
  }

  Future<void> _copyMarkdownDirect() async {
    final service = ExportImportService(repository: widget.repository);
    final md = await service.exportPageToMarkdown(widget.pageId);
    await Clipboard.setData(ClipboardData(text: md));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.markdownCopied),
          duration: Motion.notice,
        ),
      );
    }
  }

  Future<void> _saveMarkdownDirect() async {
    final service = ExportImportService(repository: widget.repository);
    final md = await service.exportPageToMarkdown(widget.pageId);
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : 'untitled';
    final filename =
        '${title.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}.md';
    final file = await ExportImportService.saveExportToFile(md, filename);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.savedTo(file.path)),
          duration: Motion.savedNotice,
        ),
      );
    }
  }

  void _copyPageLink() {
    copyPageLinkDetailsToClipboard(
      context,
      pageId: widget.pageId,
      title: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : widget.title,
      icon: _icon,
    );
  }

  Future<void> _insertPageMention(
    EditorState editorState, {
    bool isWikilink = false,
  }) async {
    final savedSelection = editorState.selection;
    final pickedPage = await showPageLinkPickerDialog(
      context,
      repository: widget.repository,
      excludePageId: widget.pageId,
    );

    if (pickedPage == null || !mounted) return;

    final selection = editorState.selection ?? savedSelection;
    if (selection == null) return;

    final title = pickedPage.title.trim().isEmpty
        ? 'Untitled'
        : pickedPage.title.trim();
    final icon = (pickedPage.icon != null && pickedPage.icon!.isNotEmpty)
        ? '${pickedPage.icon} '
        : '📄 ';
    final linkText = '$icon$title';
    final href = 'page://${pickedPage.id}';

    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final transaction = editorState.transaction;
    final text = node.delta?.toPlainText() ?? '';
    var insertOffset = selection.start.offset;

    if (isWikilink &&
        insertOffset >= 2 &&
        text.substring(insertOffset - 2, insertOffset) == '[[') {
      transaction.deleteText(node, insertOffset - 2, 2);
      insertOffset -= 2;
    }

    transaction.insertText(
      node,
      insertOffset,
      linkText,
      attributes: {AppFlowyRichTextKeys.href: href},
    );

    await editorState.apply(transaction);
  }

  void _releaseEditor() {
    final editor = _editorState;
    final scroll = _editorScrollController;
    unawaited(_autoSaveService?.forceSave() ?? Future.value());
    _autoSaveService?.dispose();
    _autoSaveService = null;
    _editorState = null;
    _editorScrollController = null;
    if (editor != null) {
      // AppFlowy descendants detach their listeners when this frame unmounts.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scroll?.dispose();
        if (!editor.isDisposed) editor.dispose();
      });
    }
  }

  @override
  void dispose() {
    _spinnerTimer?.cancel();
    _accountController?.unregisterSaver(_flushForAccountSwitch);
    WidgetsBinding.instance.removeObserver(this);
    DesktopImageDropBridge.unregisterDropHandler(_handleDroppedImages);
    _titleSession.dispose();
    _editorFocusNode.dispose();
    _loadGeneration++;
    _releaseEditor();
    super.dispose();
  }

  void _handleDroppedImages(List<Uint8List> images) {
    final editorState = _editorState;
    if (!mounted ||
        _isLoading ||
        editorState == null ||
        editorState.isDisposed ||
        !editorState.editable ||
        (_accountController?.applyingRemote ?? false)) {
      return;
    }
    unawaited(pasteImageBytes(editorState, images));
  }

  void _handleTitleSubmitted() {
    unawaited(_titleSession.flush());
    final editorState = _editorState;
    if (editorState == null ||
        editorState.isDisposed ||
        !editorState.editable) {
      return;
    }

    final children = editorState.document.root.children;
    if (children.isEmpty || children.first.delta == null) {
      final transaction = editorState.transaction;
      transaction.insertNode([0], paragraphNode());
      transaction.afterSelection = Selection.collapsed(Position(path: [0]));
      unawaited(editorState.apply(transaction));
    } else {
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0])),
        reason: SelectionUpdateReason.uiEvent,
      );
    }

    _editorFocusNode.requestFocus();
    editorState.service.keyboardService?.enable();
    editorState.service.keyboardService?.enableShortcuts();
  }

  Future<void> _focusOrAppendTrailingParagraph() async {
    final editorState = _editorState;
    if (editorState == null ||
        editorState.isDisposed ||
        !editorState.editable) {
      return;
    }

    final children = editorState.document.root.children;
    final Position target;
    if (children.isEmpty ||
        children.last.delta == null ||
        children.last.delta!.isNotEmpty) {
      final path = [children.length];
      final transaction = editorState.transaction;
      transaction.insertNode(path, paragraphNode());
      transaction.afterSelection = Selection.collapsed(Position(path: path));
      await editorState.apply(transaction);
      target = Position(path: path);
    } else {
      target = Position(path: [children.length - 1]);
    }

    if (!mounted || editorState.isDisposed) return;
    _editorFocusNode.requestFocus();
    editorState.service.keyboardService?.enable();
    editorState.service.keyboardService?.enableShortcuts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || editorState.isDisposed) return;
      editorState.updateSelectionWithReason(
        Selection.collapsed(target),
        reason: SelectionUpdateReason.uiEvent,
      );
    });
  }

  Widget _withFrame(Widget body, {Widget actions = const SizedBox.shrink()}) =>
      widget.frameBuilder?.call(context, body, actions) ?? body;

  Future<void> _changePageSettings(PageSettings settings) async {
    try {
      await widget.repository.updatePageSettings(
        widget.pageId,
        subpageLayout: settings.subpageLayout,
        fullWidth: settings.fullWidth,
        smallText: settings.smallText,
        coverToTop: settings.coverToTop,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.l10n.failedToSavePageSettings)),
        );
      }
    }
  }

  Future<void> _changeSubpageLayout(SubpageLayout layout) async {
    try {
      await widget.repository.updateSubpageLayout(widget.pageId, layout);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.l10n.failedToSaveSubpageLayout)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loadFailed) {
      return _withFrame(
        Center(
          child: TextButton.icon(
            onPressed: _loadDocumentAndBreadcrumbs,
            style: TextButton.styleFrom(foregroundColor: skin.accentText),
            icon: const Icon(AppIcons.arrowClockwise, size: UiSpace.s14),
            label: Text(context.l10n.couldNotLoadPage),
          ),
        ),
      );
    }

    if (_isLoading || _editorState == null || _editorScrollController == null) {
      if (_showSpinner) {
        return _withFrame(
          Center(
            child: SizedBox(
              width: UiSpace.s22,
              height: UiSpace.s22,
              child: TickerMode(
                enabled: !MediaQuery.disableAnimationsOf(context),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Palette.accent.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        );
      }
      return _withFrame(const SizedBox.expand());
    }

    final selectionMenuStyle = getSelectionMenuStyle(skin, isDark);
    final selectionMenuItems = buildEditorSelectionMenuItems(
      skin: skin,
      repository: widget.repository,
      pageId: widget.pageId,
      onInsertPageMention: _insertPageMention,
      l10n: context.l10n,
    );

    return StreamBuilder<Page?>(
      initialData: _initialPage,
      stream: widget.repository.watchPage(widget.pageId),
      builder: (context, pageSnapshot) {
        final pageSettings = pageSettingsFromProperties(
          pageSnapshot.data?.properties,
        );

        final coverAtTop =
            pageSettings.coverToTop &&
            _cover != null &&
            _cover!.isNotEmpty &&
            widget.frameBuilder == null;
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<SaveStatus>(
              valueListenable: _autoSaveService!.statusNotifier,
              builder: (context, status, _) {
                final message = status == SaveStatus.saved
                    ? context.l10n.savedStatus
                    : status == SaveStatus.saving
                    ? context.l10n.savingStatus
                    : status == SaveStatus.conflict
                    ? context.l10n.saveConflictDraft
                    : context.l10n.saveError;
                final attentionTone = status == SaveStatus.conflict
                    ? StatusTone.warning
                    : StatusTone.danger;
                final (attentionBg, attentionFg) = StatusPill.colorsFor(
                  skin,
                  attentionTone,
                );
                final indicator = status == SaveStatus.saving
                    ? SizedBox.square(
                        dimension: UiSpace.s14,
                        child: TickerMode(
                          enabled: !MediaQuery.disableAnimationsOf(context),
                          child: CircularProgressIndicator(
                            strokeWidth: UiSpace.s1_5,
                            color: skin.muted,
                          ),
                        ),
                      )
                    : Icon(
                        status == SaveStatus.saved
                            ? AppIcons.checkmarkCircle
                            : AppIcons.exclamationmarkCircle,
                        size: UiSpace.s16,
                        color: status == SaveStatus.saved
                            ? (coverAtTop ? Palette.onAccent : skin.muted)
                            : attentionFg,
                      );
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (status == SaveStatus.error ||
                        status == SaveStatus.conflict)
                      IconButton(
                        key: const Key('page_save_status'),
                        tooltip: message,
                        style: IconButton.styleFrom(
                          backgroundColor: attentionBg,
                          foregroundColor: attentionFg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          minimumSize: const Size(UiSpace.s28, UiSpace.s28),
                          maximumSize: const Size(UiSpace.s28, UiSpace.s28),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: status == SaveStatus.conflict
                            ? _resolveConflict
                            : () => unawaited(_autoSaveService!.forceSave()),
                        icon: indicator,
                      )
                    else
                      Tooltip(
                        message: message,
                        child: Semantics(
                          label: message,
                          child: AnimatedContainer(
                            key: const Key('page_save_status'),
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOutCubic,
                            width: UiSpace.s28,
                            height: UiSpace.s28,
                            decoration: ShapeDecoration(
                              shape: UiRadius.squircle(UiRadius.control),
                            ),
                            child: Center(child: indicator),
                          ),
                        ),
                      ),
                    if (status == SaveStatus.conflict)
                      TextButton(
                        onPressed: _resolveConflict,
                        child: Text(context.l10n.compareVersions),
                      ),
                  ],
                );
              },
            ),
            ValueListenableBuilder<TitleSaveStatus>(
              valueListenable: _titleSession.status,
              builder: (context, status, _) => status == TitleSaveStatus.error
                  ? TextButton(
                      onPressed: _titleSession.flush,
                      style: TextButton.styleFrom(
                        foregroundColor: skin.destructive,
                      ),
                      child: Text(context.l10n.retryTitleSave),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: UiSpace.s8),
            PageMoreActionsButton(
              iconColor: coverAtTop ? Palette.onAccent : null,
              pageSettings: pageSettings,
              pageStats: PageStats.fromDocument(
                _editorState?.document,
                _titleController.text,
              ),
              onPageSettingsChanged:
                  pageSnapshot.data != null &&
                      pageSnapshot.data!.databaseId == null
                  ? _changePageSettings
                  : null,
              subpageLayout: pageSettings.subpageLayout,
              onSubpageLayoutChanged:
                  pageSnapshot.data != null &&
                      pageSnapshot.data!.databaseId == null
                  ? _changeSubpageLayout
                  : null,
              onCopyPageLink: _copyPageLink,
              onExportMarkdown: () => _openExportDialog(ExportImportMode.page),
              onImportNotionCsv: () =>
                  _openExportDialog(ExportImportMode.notionCsv),
              onImportMarkdown: () =>
                  _openExportDialog(ExportImportMode.markdownImport),
              onCopyMarkdown: _copyMarkdownDirect,
              onSaveMarkdownToFile: _saveMarkdownDirect,
              onOpenBackup: () => _openExportDialog(ExportImportMode.workspace),
            ),
          ],
        );
        final body = ColoredBox(
          color: skin.surface,
          child: Stack(
            key: const Key('page_editor_surface'),
            children: [
              Positioned.fill(
                child: AnimatedPadding(
                  duration: Motion.of(context, Motion.micro),
                  curve: Motion.curve,
                  padding: EdgeInsets.only(
                    top: widget.frameBuilder == null && !coverAtTop
                        ? UiLayout.pageToolbarHeight
                        : 0,
                  ),
                  child: FloatingToolbar(
                    items: [
                      retinaBoldItem,
                      retinaItalicItem,
                      retinaStrikethroughItem,
                      retinaCodeItem,
                      retinaUnderlineItem,
                      retinaLinkItem,
                      buildRetinaHighlightColorItem(),
                      buildRetinaTextColorItem(),
                    ],
                    editorState: _editorState!,
                    editorScrollController: _editorScrollController!,
                    textDirection: TextDirection.ltr,
                    floatingToolbarHeight: 36,
                    padding: const EdgeInsets.symmetric(
                      horizontal: UiSpace.s6,
                      vertical: UiSpace.s2,
                    ),
                    decoration: ShapeDecoration(
                      color: skin.card,
                      shape: UiRadius.squircle(
                        UiRadius.control,
                        side: BorderSide(
                          color: skin.hairlineBorder,
                          width: 0.8,
                        ),
                      ),
                      shadows: [
                        BoxShadow(
                          color: skin.shadow.withValues(
                            alpha: skin.isDark ? 0.35 : 0.12,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: skin.shadow.withValues(
                            alpha: skin.isDark ? 0.20 : 0.05,
                          ),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    style: FloatingToolbarStyle(
                      backgroundColor: Palette.transparent,
                      toolbarActiveColor: Palette.accent,
                      toolbarIconColor: skin.text,
                      toolbarShadowColor: Palette.transparent,
                      toolbarElevation: 0,
                    ),
                    placeHolderBuilder: (context) => ToolbarItem(
                      id: 'editor.placeholder',
                      group: -1,
                      isActive: (editorState) => true,
                      builder: (_, _, _, _, _) {
                        return Container(
                          width: 1,
                          height: 18,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: context.skin.divider,
                        );
                      },
                    ),
                    tooltipBuilder: (context, id, name, onSelected) {
                      final label = switch (id) {
                        'editor.bold' || 'bold' => 'Жирный (⌘B)',
                        'editor.italic' || 'italic' => 'Курсив (⌘I)',
                        'editor.strikethrough' || 'strikethrough' =>
                          'Зачёркнутый (⌘⇧X)',
                        'editor.code' || 'code' => 'Код (⌘E)',
                        'editor.underline' || 'underline' =>
                          'Подчёркнутый (⌘U)',
                        'editor.link' || 'link' => 'Ссылка (⌘K)',
                        'editor.highlightColor' ||
                        'editor.highlight_color' ||
                        'highlightColor' ||
                        'highlight_color' =>
                          'Цвет маркера',
                        'editor.textColor' ||
                        'editor.text_color' ||
                        'textColor' ||
                        'text_color' =>
                          'Цвет текста',
                        _ => name,
                      };
                      return Tooltip(
                        message: label,
                        preferBelow: false,
                        verticalOffset: 24,
                        waitDuration: Motion.tooltipDelay,
                        decoration: ShapeDecoration(
                          color: skin.isDark
                              ? const Color(0xFF1E2024)
                              : const Color(0xFF2C2E33),
                          shape: UiRadius.squircle(UiRadius.badge),
                          shadows: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: _ToolbarItemHoverWrapper(
                          child: onSelected,
                        ),
                      );
                    },
                    child: AppFlowyEditor(
                      focusNode: _editorFocusNode,
                      editable: !(_accountController?.applyingRemote ?? false),
                      editorState: _editorState!,
                      editorScrollController: _editorScrollController!,
                      contextMenuBuilder:
                          (context, position, editorState, onPressed) =>
                              buildEditorContextMenu(
                                context,
                                position,
                                editorState,
                                onPressed,
                              ),
                      blockComponentBuilders: buildNotesBlockComponentBuilders(
                        context,
                        smallText: pageSettings.smallText,
                        repository: widget.repository,
                        initialDatabases: _initialDatabases,
                        onNavigateToPage: widget.onNavigateToPage,
                      ),
                      commandShortcutEvents: [
                        codeBlockPasteCommand,
                        codeBlockPasteWithoutFormattingCommand,
                        exitCodeBlockOnShiftEnterCommand,
                        nonTextBlockInsertAboveCommand,
                        nonTextBlockEnterCommand,
                        smartSelectAllCommand,
                        smartCopyCommand,
                        smartCutCommand,
                        smartLinkPasteCommand,
                        ...standardCommandShortcutEvents,
                      ],
                      editorStyle: EditorStyle.desktop(
                        maxWidth: pageSettings.fullWidth
                            ? null
                            : UiLayout.editorMaxWidth,
                        textSpanDecorator: notesTextSpanDecorator,
                        padding: const EdgeInsets.symmetric(
                          horizontal: UiSpace.s40,
                          vertical: UiSpace.s10,
                        ),
                        cursorColor: Palette.accent,
                        selectionColor: Palette.accent.withValues(alpha: 0.22),
                        textStyleConfiguration: TextStyleConfiguration(
                          lineHeight: UiType.editorLineHeight,
                          text: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(
                                fontSize: pageSettings.smallText
                                    ? UiType.body
                                    : UiType.editorBody,
                                height: UiType.editorLineHeight,
                                fontWeight: FontWeight.w400,
                                color: skin.text,
                              ),
                          bold: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: skin.text,
                          ),
                          code: TextStyle(
                            fontFamily:
                                defaultTargetPlatform == TargetPlatform.macOS
                                ? 'Menlo'
                                : 'Consolas',
                            fontSize: pageSettings.smallText
                                ? UiType.small
                                : UiType.code,
                            height: UiType.editorLineHeight,
                            color: skin.inlineCode,
                            backgroundColor: skin.inlineCodeSurface,
                          ),
                          href: TextStyle(
                            color: Palette.accent,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                            decorationColor: Palette.accent.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                      ),
                      characterShortcutEvents: buildEditorCharacterShortcuts(
                        selectionMenuItems: selectionMenuItems,
                        selectionMenuStyle: selectionMenuStyle,
                        onInsertPageMention: _insertPageMention,
                      ),
                      header: PageHeader(
                        coverToTop: coverAtTop,
                        coverY: pageSettings.coverY,
                        onUpdateCoverY: (newY) => _changePageSettings(
                          pageSettings.copyWith(coverY: newY),
                        ),
                        onToggleCoverToTop:
                            widget.frameBuilder == null &&
                                pageSnapshot.data?.databaseId == null
                            ? () => _changePageSettings(
                                pageSettings.copyWith(
                                  coverToTop: !pageSettings.coverToTop,
                                ),
                              )
                            : null,
                        fullWidth: pageSettings.fullWidth,
                        belowTitle: SubpagesPanel(
                          initialPage: _initialPage,
                          initialChildren: _initialChildren,
                          repository: widget.repository,
                          pageId: widget.pageId,
                          onOpenPage: widget.onNavigateToPage,
                        ),
                        compact: widget.compactHeader || pageSettings.smallText,
                        titleController: _titleController,
                        titleFocusNode: _titleSession.focusNode,
                        onTitleChanged: _titleSession.edited,
                        onTitleSubmitted: _handleTitleSubmitted,
                        icon: _icon,
                        cover: _cover,
                        onAddOrChangeIcon: _changeIcon,
                        onRemoveIcon: _removeIcon,
                        onAddOrChangeCover: _changeCover,
                        onRemoveCover: _removeCover,
                      ),
                      footer: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_backlinks.isNotEmpty)
                            Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: pageSettings.fullWidth
                                      ? double.infinity
                                      : UiLayout.editorMaxWidth,
                                ),
                                child: BacklinksSection(
                                  backlinks: _backlinks,
                                  onNavigateToPage: widget.onNavigateToPage,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(
                              top: UiSpace.s24,
                              bottom: UiSpace.s8,
                            ),
                            child: Center(
                              child: Text(
                                PageStats.fromDocument(
                                  _editorState?.document,
                                  _titleController.text,
                                ).summary,
                                style: TextStyle(
                                  fontSize: UiType.caption,
                                  color: skin.faint,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                          MouseRegion(
                            cursor: SystemMouseCursors.text,
                            child: GestureDetector(
                              key: const Key('page_trailing_tap_area'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  unawaited(_focusOrAppendTrailingParagraph()),
                              child: const SizedBox(
                                width: double.infinity,
                                height: UiSpace.s64 * 3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.frameBuilder == null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: UiLayout.pageToolbarHeight,
                  child: ClipRect(
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: UiLayout.coverHeight,
                          child: DecoratedBox(
                            decoration: coverAtTop
                                ? getCoverDecoration(_cover)!
                                : BoxDecoration(color: skin.surface),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            UiSpace.s16,
                            UiSpace.s8,
                            UiSpace.s16,
                            UiSpace.s8,
                          ),
                          child: Row(
                            children: [
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _titleController,
                                builder: (context, value, _) =>
                                    PageBreadcrumbsBar(
                                      breadcrumbs: _breadcrumbs,
                                      currentTitle: value.text,
                                      onCover: coverAtTop,
                                      onNavigateToPage: widget.onNavigateToPage,
                                    ),
                              ),
                              if (coverAtTop)
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Palette.coverOverlay,
                                    borderRadius: BorderRadius.circular(
                                      UiRadius.control,
                                    ),
                                  ),
                                  child: actions,
                                )
                              else
                                actions,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned.fill(
                child: ValueListenableBuilder<bool>(
                  valueListenable: DesktopImageDropBridge.isHovering,
                  builder: (context, hovering, _) {
                    if (!hovering ||
                        (_accountController?.applyingRemote ?? false)) {
                      return const SizedBox.shrink();
                    }
                    return IgnorePointer(
                      child: Padding(
                        padding: const EdgeInsets.all(UiSpace.s16),
                        child: DecoratedBox(
                          key: const Key('page_image_drop_overlay'),
                          decoration: ShapeDecoration(
                            color: Palette.accent.withValues(alpha: 0.06),
                            shape: UiRadius.squircle(
                              UiRadius.modal,
                              side: BorderSide(
                                color: Palette.accent.withValues(alpha: 0.55),
                                width: UiSpace.s1_5,
                              ),
                            ),
                          ),
                          child: Center(
                            child: DecoratedBox(
                              decoration: ShapeDecoration(
                                color: skin.glassSurface,
                                shape: UiRadius.squircle(
                                  UiRadius.dialog,
                                  side: BorderSide(color: skin.hairlineBorder),
                                ),
                                shadows: skin.popoverShadows,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: UiSpace.s16,
                                  vertical: UiSpace.s10,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      AppIcons.photo,
                                      size: UiSpace.s18,
                                      color: skin.accentText,
                                    ),
                                    const SizedBox(width: UiSpace.s8),
                                    Text(
                                      context.l10n.dropImageHint,
                                      style: TextStyle(
                                        fontSize: UiType.body,
                                        fontWeight: FontWeight.w500,
                                        color: skin.text,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
        return _withFrame(
          PageEntrance(key: ValueKey(widget.pageId), child: body),
          actions: actions,
        );
      },
    );
  }
}

class _ToolbarItemHoverWrapper extends StatefulWidget {
  final Widget child;
  const _ToolbarItemHoverWrapper({required this.child});

  @override
  State<_ToolbarItemHoverWrapper> createState() =>
      _ToolbarItemHoverWrapperState();
}

class _ToolbarItemHoverWrapperState extends State<_ToolbarItemHoverWrapper> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 1.0, vertical: 2.0),
        decoration: ShapeDecoration(
          color: _hovered ? skin.controlHover : Palette.transparent,
          shape: UiRadius.squircle(UiRadius.control),
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}
