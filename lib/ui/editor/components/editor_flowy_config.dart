import 'dart:async';

import '../../common/app_icons.dart';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart' hide Page;

import '../../../data/notes_repository.dart';
import '../../../l10n/locale_controller.dart';
import '../../../platform/desktop_services.dart';
import '../../common/menu.dart';
import '../../common/page_link_picker_dialog.dart';
import '../../theme.dart';
import 'callout_block_component.dart';
import 'code_block_component.dart';
import 'database_block_component.dart';
import 'html_paste.dart';
import 'image_paste.dart';
import 'markdown_paste.dart';
import 'page_block_reorder.dart';
import 'page_link_block_component.dart';
import 'toggle_block_component.dart';

Widget buildEditorContextMenu(
  BuildContext context,
  Offset position,
  EditorState editorState,
  VoidCallback onPressed,
) {
  final selection = editorState.selection;
  final hasSelection = selection != null && !selection.isCollapsed;

  final media = MediaQuery.maybeOf(context);
  final screenWidth = media?.size.width ?? 1200.0;
  final screenHeight = media?.size.height ?? 800.0;
  final menuWidth = DesktopUx.menuWidth;

  if (hasSelection) {
    const menuEstimatedHeight = 160.0;
    final left = position.dx.clamp(
      8.0,
      (screenWidth - menuWidth - 8.0).clamp(8.0, double.infinity),
    );
    final top = position.dy.clamp(
      8.0,
      (screenHeight - menuEstimatedHeight - 8.0).clamp(8.0, double.infinity),
    );

    return Positioned(
      top: top,
      left: left,
      child: MenuCard(
        alignment: Alignment.topLeft,
        width: menuWidth,
        onClosed: onPressed,
        children: [
          MenuRow(
            label: context.l10n.cut,
            glyph: AppIcons.scissors,
            shortcut: menuShortcut('X'),
            onTap: () {
              onPressed();
              smartCutCommand.handler(editorState);
            },
          ),
          MenuRow(
            label: context.l10n.copy,
            glyph: AppIcons.docOnDoc,
            shortcut: menuShortcut('C'),
            onTap: () {
              onPressed();
              smartCopyCommand.handler(editorState);
            },
          ),
          MenuRow(
            label: context.l10n.paste,
            glyph: AppIcons.docOnClipboard,
            shortcut: menuShortcut('V'),
            onTap: () {
              onPressed();
              smartLinkPasteCommand.handler(editorState);
            },
          ),
          const MenuDivider(),
          MenuRow(
            label: context.l10n.selectAll,
            glyph: AppIcons.selectionPinInOut,
            shortcut: menuShortcut('A'),
            onTap: () {
              onPressed();
              smartSelectAllCommand.handler(editorState);
            },
          ),
        ],
      ),
    );
  }

  // When no text range is selected, present the block-level context menu
  // (Notion / Craft style) for the targeted block.
  final targetPath = selection?.start.path;
  Node? targetNode = targetPath != null && targetPath.isNotEmpty
      ? editorState.getNodeAtPath(targetPath)
      : null;

  if (targetNode == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => onPressed());
    return const SizedBox.shrink();
  }

  Node blockNode = targetNode;
  while (blockNode.parent != null &&
      blockNode.parent != editorState.document.root) {
    blockNode = blockNode.parent!;
  }

  const menuEstimatedHeight = 360.0;
  final left = position.dx.clamp(
    8.0,
    (screenWidth - menuWidth - 8.0).clamp(8.0, double.infinity),
  );
  final top = position.dy.clamp(
    8.0,
    (screenHeight - menuEstimatedHeight - 8.0).clamp(8.0, double.infinity),
  );

  return Positioned(
    top: top,
    left: left,
    child: BlockContextMenuCard(
      editor: editorState,
      node: blockNode,
      onClose: onPressed,
      onPaste: () => smartLinkPasteCommand.handler(editorState),
      width: menuWidth,
    ),
  );
}

SelectionMenuStyle getSelectionMenuStyle(Skin skin, bool isDark) {
  return SelectionMenuStyle(
    selectionMenuBackgroundColor: skin.card,
    selectionMenuItemTextColor: skin.text,
    selectionMenuItemIconColor: skin.muted,
    selectionMenuItemSelectedTextColor: isDark
        ? skin.accentText
        : Palette.accent,
    selectionMenuItemSelectedIconColor: isDark
        ? skin.accentText
        : Palette.accent,
    selectionMenuItemSelectedColor: skin.hover,
    selectionMenuUnselectedLabelColor: skin.muted,
    selectionMenuDividerColor: skin.divider,
    selectionMenuLinkBorderColor: skin.divider,
    selectionMenuInvalidLinkColor: skin.destructive,
    selectionMenuButtonColor: skin.hover,
    selectionMenuButtonTextColor: skin.text,
    selectionMenuButtonIconColor: skin.muted,
    selectionMenuButtonBorderColor: skin.divider,
    selectionMenuTabIndicatorColor: Palette.accent,
  );
}

List<SelectionMenuItem> buildEditorSelectionMenuItems({
  required Skin skin,
  required NotesRepository repository,
  required String pageId,
  required Future<void> Function(EditorState state, {bool isWikilink})
  onInsertPageMention,
  AppLocalizations? l10n,
}) {
  return [
    ...standardSelectionMenuItems,
    SelectionMenuItem(
      getName: () => l10n?.menuCallout ?? 'Callout',
      icon: (editorState, isSelected, style) => Icon(
        AppIcons.exclamationmarkCircle,
        size: UiSpace.s16,
        color: isSelected ? Palette.accent : skin.muted,
      ),
      keywords: [
        'callout',
        'note',
        'info',
        'alert',
        'tip',
        'выноска',
        'плашка',
        'заметка',
      ],
      handler: (editorState, menuService, context) {
        insertNodeAfterSelection(editorState, calloutNode());
      },
    ),
    SelectionMenuItem(
      getName: () => l10n?.menuToggle ?? 'Toggle list',
      icon: (editorState, isSelected, style) => Icon(
        AppIcons.chevronRight,
        size: UiSpace.s16,
        color: isSelected ? Palette.accent : skin.muted,
      ),
      keywords: [
        'toggle',
        'collapse',
        'accordion',
        'details',
        'spoiler',
        'спойлер',
        'сворачиваемый',
        'раздел',
      ],
      handler: (editorState, menuService, context) {
        insertNodeAfterSelection(editorState, toggleNode());
      },
    ),
    SelectionMenuItem(
      getName: () => l10n?.menuCodeBlock ?? 'Code block',
      icon: (editorState, isSelected, style) => Icon(
        AppIcons.chevronLeftSlashChevronRight,
        size: UiSpace.s16,
        color: isSelected ? Palette.accent : skin.muted,
      ),
      keywords: ['code', 'snippet', 'pre', 'script', 'код'],
      handler: (editorState, menuService, context) {
        insertNodeAfterSelection(editorState, codeBlockNode());
      },
    ),
    SelectionMenuItem(
      getName: () => l10n?.menuLinkToPage ?? 'Link to page',
      icon: (editorState, isSelected, style) => Icon(
        AppIcons.link,
        size: UiSpace.s16,
        color: isSelected ? Palette.accent : skin.muted,
      ),
      keywords: ['page', 'link', 'mention', 'wikilink', 'страница', 'ссылка'],
      handler: (editorState, menuService, context) {
        onInsertPageMention(editorState, isWikilink: false);
      },
    ),
    SelectionMenuItem(
      getName: () => l10n?.menuPageCard ?? 'Карточка страницы',
      icon: (editorState, isSelected, style) => Icon(
        AppIcons.docText,
        size: UiSpace.s16,
        color: isSelected ? Palette.accent : skin.muted,
      ),
      keywords: [
        'card',
        'page card',
        'карточка',
        'карточка страницы',
        'ссылка-карточка',
      ],
      handler: (editorState, menuService, context) async {
        final selection = editorState.selection;
        if (selection == null) return;
        final commandNode = editorState.getNodeAtPath(selection.end.path);
        if (commandNode == null) return;
        final commandPath = List<int>.from(commandNode.path);
        final rawText = commandNode.delta?.toPlainText().trim() ?? '';
        final isCommandParagraph =
            commandNode.type == ParagraphBlockKeys.type &&
            (rawText.isEmpty || rawText.startsWith('/'));

        menuService.dismiss();

        final pickedPage = await showPageLinkPickerDialog(
          context,
          repository: repository,
          excludePageId: pageId,
        );
        if (pickedPage == null || editorState.isDisposed) return;
        final card = pageLinkNode(
          pageId: pickedPage.id,
          title: pickedPage.title,
          icon: pickedPage.icon,
        );

        final currentNode = editorState.getNodeAtPath(commandPath);
        final transaction = editorState.transaction;
        if (isCommandParagraph && currentNode != null) {
          transaction.insertNode(commandPath, card);
          transaction.deleteNode(currentNode);
          final next = commandPath.next;
          transaction.insertNode(next, paragraphNode());
          transaction.afterSelection =
              Selection.collapsed(Position(path: next));
        } else {
          final target =
              currentNode ?? editorState.document.root.children.lastOrNull;
          final insertPath = target != null ? target.path.next : [0];
          transaction.insertNode(insertPath, card);
          final next = insertPath.next;
          transaction.insertNode(next, paragraphNode());
          transaction.afterSelection =
              Selection.collapsed(Position(path: next));
        }
        await editorState.apply(transaction);
      },
    ),
    SelectionMenuItem(
      getName: () => l10n?.menuTableView ?? 'Table view / Database',
      icon: (editorState, isSelected, style) => Icon(
        AppIcons.table,
        size: UiSpace.s16,
        color: isSelected ? Palette.accent : skin.muted,
      ),
      keywords: ['table', 'database', 'grid', 'таблица', 'база'],
      handler: (editorState, menuService, context) async {
        final selection = editorState.selection;
        if (selection == null || !selection.isCollapsed) return;
        final commandNode = editorState.getNodeAtPath(selection.end.path);
        if (commandNode == null) return;
        final dbId = await repository.createDatabase(
          title: 'Untitled Table',
          parentPageId: pageId,
        );
        if (editorState.isDisposed ||
            editorState.getNodeAtPath(commandNode.path) != commandNode) {
          return;
        }
        final text = commandNode.delta?.toPlainText();
        final replace =
            commandNode.type == 'paragraph' && (text == '' || text == '/');
        final path = replace ? commandNode.path : commandNode.path.next;
        final transaction = editorState.transaction;
        transaction.insertNode(path, databaseBlockNode(databaseId: dbId));
        if (replace) transaction.deleteNode(commandNode);
        transaction.afterSelection = Selection.collapsed(Position(path: path));
        await editorState.apply(transaction);
      },
    ),
  ];
}

/// Repair the exact legacy artifact left by database insertion. Slash characters
/// in ordinary text, other block types, or elsewhere in a page remain intact.
Future<void> clearOrphanedDatabaseSlash(EditorState state) async {
  final transaction = state.transaction;
  var changed = false;
  void visit(Node parent) {
    final children = parent.children;
    for (var i = 0; i < children.length; i++) {
      final node = children[i];
      if (i + 1 < children.length &&
          node.type == 'paragraph' &&
          node.delta?.toPlainText() == '/' &&
          children[i + 1].type == databaseBlockType) {
        transaction.deleteText(node, 0, 1);
        changed = true;
      }
      visit(node);
    }
  }

  visit(state.document.root);
  if (changed) await state.apply(transaction);
}

List<CharacterShortcutEvent> buildEditorCharacterShortcuts({
  required List<SelectionMenuItem> selectionMenuItems,
  required SelectionMenuStyle selectionMenuStyle,
  required Future<void> Function(EditorState state, {bool isWikilink})
  onInsertPageMention,
}) {
  return [
    CharacterShortcutEvent(
      key: 'insert newline in code block',
      character: '\n',
      handler: (state) async {
        final selection = state.selection?.normalized;
        if (selection == null) {
          return false;
        }
        final node = state.getNodeAtPath(selection.start.path);
        if (node?.type != codeBlockType) return false;

        if (!selection.isCollapsed) {
          await state.deleteSelection(selection);
        }
        await state.insertTextAtPosition('\n', position: selection.start);
        return true;
      },
    ),
    CharacterShortcutEvent(
      key: 'markdown backticks to code block',
      character: ' ',
      handler: (state) async {
        final selection = state.selection;
        if (selection == null || !selection.isCollapsed) {
          return false;
        }
        final node = state.getNodeAtPath(selection.start.path);
        if (node == null || node.type == codeBlockType) {
          return false;
        }

        final text = node.delta?.toPlainText() ?? '';
        final offset = selection.start.offset;

        final prefix = text.substring(0, offset);
        if (prefix.startsWith('```')) {
          final lang = prefix.substring(3).trim();
          final remaining = text.substring(offset);
          final transaction = state.transaction;
          final code = codeBlockNode(
            language: lang.isNotEmpty ? lang.toLowerCase() : 'dart',
            delta: remaining.isNotEmpty ? (Delta()..insert(remaining)) : null,
          );
          transaction.insertNode(node.path, code);
          transaction.deleteNode(node);
          transaction.afterSelection = Selection.collapsed(
            Position(path: node.path),
          );
          await state.apply(transaction);
          return true;
        }
        return false;
      },
    ),
    CharacterShortcutEvent(
      key: 'insert newline in callout block',
      character: '\n',
      handler: (state) => _handleStructuredBlockEnter(state, calloutBlockType),
    ),
    CharacterShortcutEvent(
      key: 'insert newline in toggle block',
      character: '\n',
      handler: (state) => _handleStructuredBlockEnter(state, toggleBlockType),
    ),
    CharacterShortcutEvent(
      key: 'insert paragraph below selected non-text block',
      character: '\n',
      handler: (state) => _handleNonTextBlockEnter(state, after: true),
    ),
    CharacterShortcutEvent(
      key: 'format greater to toggle list',
      character: ' ',
      handler: (state) => formatMarkdownSymbol(
        state,
        (node) => node.type == ParagraphBlockKeys.type,
        (_, text, _) => text == '>',
        (_, node, delta) => [
          toggleNode(
            collapsed: false,
            delta: delta.compose(Delta()..delete(1)),
            children: node.children,
          ),
        ],
      ),
    ),
    ...standardCharacterShortcutEvents.where(
      (e) => e.key != 'show the slash menu',
    ),
    customSlashCommand(selectionMenuItems, style: selectionMenuStyle),
    CharacterShortcutEvent(
      key: 'wikilink shortcut',
      character: '[',
      handler: (state) async {
        final selection = state.selection;
        if (selection == null || !selection.isCollapsed) {
          return false;
        }

        final node = state.getNodeAtPath(selection.start.path);
        if (node == null) return false;

        final text = node.delta?.toPlainText() ?? '';
        final offset = selection.start.offset;

        // Check if previous character is '[' to detect '[['
        if (offset > 0 &&
            text.length >= offset &&
            text.substring(offset - 1, offset) == '[') {
          keepEditorFocusNotifier.increase();
          await state.insertTextAtPosition('[', position: selection.start);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            keepEditorFocusNotifier.decrease();
            onInsertPageMention(state, isWikilink: true);
          });
          return true;
        }
        return false;
      },
    ),
  ];
}

Future<bool> _handleStructuredBlockEnter(
  EditorState state,
  String blockType,
) async {
  final selection = state.selection;
  if (selection == null || !selection.isCollapsed) return false;
  final node = state.getNodeAtPath(selection.start.path);
  if (node == null || node.type != blockType || node.delta == null) {
    return false;
  }

  final delta = node.delta!;
  if (delta.isEmpty && node.children.isEmpty) {
    final transaction = state.transaction
      ..insertNode(node.path, paragraphNode())
      ..deleteNode(node)
      ..afterSelection = Selection.collapsed(Position(path: node.path));
    await state.apply(transaction);
    return true;
  }

  final offset = selection.start.offset.clamp(0, delta.length);
  final leading = delta.slice(0, offset);
  final trailing = delta.slice(offset);
  final transaction = state.transaction
    ..updateNode(node, {blockComponentDelta: leading.toJson()});

  final isExpandedToggle =
      blockType == toggleBlockType &&
      node.attributes[ToggleBlockKeys.collapsed] != true;
  final targetPath = isExpandedToggle ? [...node.path, 0] : node.path.next;
  transaction
    ..insertNode(targetPath, paragraphNode(delta: trailing))
    ..afterSelection = Selection.collapsed(Position(path: targetPath));
  await state.apply(transaction);
  return true;
}

final RegExp _markdownLinkRegex = RegExp(
  r'^\[(.+?)\]\((page://[^\s)]+|https?://[^\s)]+)\)$',
);

final RegExp _barePageLinkRegex = RegExp(r'^page://[^\s)]+$');

final RegExp _bareWebLinkRegex = RegExp(r'^https?://[^\s)]+$');

bool _isSelectedNonTextBlock(EditorState editorState) {
  final selection = editorState.selection?.normalized;
  if (selection == null || !selection.isSingle) return false;
  final node = editorState.getNodeAtPath(selection.start.path);
  if (node == null) return false;
  return node.type == ImageBlockKeys.type || node.type == DividerBlockKeys.type;
}

Future<bool> _handleNonTextBlockEnter(
  EditorState editorState, {
  required bool after,
}) async {
  if (!_isSelectedNonTextBlock(editorState)) return false;
  final path = editorState.selection!.normalized.start.path;
  final node = editorState.getNodeAtPath(path);
  if (node == null) return false;
  await insertParagraphRelative(editorState, node, after: after);
  return true;
}

/// Inserts an editable paragraph immediately below a selected image or divider
/// instead of deleting the selected non-text block on Enter.
final CommandShortcutEvent nonTextBlockEnterCommand = CommandShortcutEvent(
  key: 'insert paragraph below non-text block',
  getDescription: () => 'insert paragraph below selected image or divider',
  command: 'enter',
  handler: (editorState) {
    if (!_isSelectedNonTextBlock(editorState)) {
      return KeyEventResult.ignored;
    }
    unawaited(_handleNonTextBlockEnter(editorState, after: true));
    return KeyEventResult.handled;
  },
);

/// Inserts an editable paragraph immediately above a selected image or divider
/// on Shift+Enter.
final CommandShortcutEvent nonTextBlockInsertAboveCommand =
    CommandShortcutEvent(
      key: 'insert paragraph above non-text block',
      getDescription: () => 'insert paragraph above selected image or divider',
      command: 'shift+enter',
      handler: (editorState) {
        if (!_isSelectedNonTextBlock(editorState)) {
          return KeyEventResult.ignored;
        }
        unawaited(_handleNonTextBlockEnter(editorState, after: false));
        return KeyEventResult.handled;
      },
    );

/// Two-stage select all:
/// 1st Ctrl+A / Cmd+A: selects the entire current block.
/// 2nd Ctrl+A / Cmd+A: selects all blocks on the entire page.
final CommandShortcutEvent smartSelectAllCommand = CommandShortcutEvent(
  key: 'smart two-stage select all',
  getDescription: () => AppFlowyEditorL10n.current.cmdSelectAll,
  command: 'ctrl+a',
  macOSCommand: 'cmd+a',
  handler: _smartSelectAllCommandHandler,
);

KeyEventResult _smartSelectAllCommandHandler(EditorState editorState) {
  if (editorState.document.root.children.isEmpty ||
      editorState.selection == null) {
    return KeyEventResult.ignored;
  }

  final selection = editorState.selection!.normalized;
  final lastSelectable = editorState.getLastSelectable();
  if (lastSelectable == null) {
    return KeyEventResult.handled;
  }

  final docStart = Position(path: [0]);
  final docEnd = lastSelectable.$2.end(lastSelectable.$1);
  final isEntireDocSelected =
      selection.start == docStart && selection.end == docEnd;

  if (isEntireDocSelected) {
    return KeyEventResult.handled;
  }

  // 1. If currently inside a single block, check if the whole block is already selected
  if (selection.isSingle) {
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node != null) {
      final selectable = node.selectable;
      final blockStart =
          selectable?.start() ?? Position(path: node.path, offset: 0);
      final blockEnd = selectable?.end() ??
          Position(
            path: node.path,
            offset: node.delta?.toPlainText().length ?? 1,
          );

      final isEntireBlockSelected =
          selection.start == blockStart && selection.end == blockEnd;

      // If the block is not yet fully selected, select this block first!
      if (!isEntireBlockSelected && blockStart != blockEnd) {
        editorState.updateSelectionWithReason(
          Selection(start: blockStart, end: blockEnd),
          reason: SelectionUpdateReason.selectAll,
        );
        return KeyEventResult.handled;
      }
    }
  }

  // 2. Second press (or multiple blocks already selected): select the whole page
  editorState.updateSelectionWithReason(
    Selection(start: docStart, end: docEnd),
    reason: SelectionUpdateReason.selectAll,
  );
  return KeyEventResult.handled;
}

/// Exits a code block on Shift+Enter, creating an editable paragraph below it.
final CommandShortcutEvent exitCodeBlockOnShiftEnterCommand =
    CommandShortcutEvent(
      key: 'exit code block to new paragraph on shift enter',
      getDescription: () => 'exit code block on shift+enter',
      command: 'shift+enter',
      handler: (editorState) {
        final selection = editorState.selection;
        if (selection == null) return KeyEventResult.ignored;
        final node = editorState.getNodeAtPath(selection.start.path);
        if (node == null || node.type != codeBlockType) {
          return KeyEventResult.ignored;
        }

        final next = node.path.next;
        final transaction = editorState.transaction;
        transaction.insertNode(next, paragraphNode());
        transaction.afterSelection = Selection.collapsed(Position(path: next));
        editorState.apply(transaction);
        return KeyEventResult.handled;
      },
    );

/// Intercepts Cmd+C / Ctrl+C to write both plain text and semantic HTML
/// (including custom `code` blocks) onto the clipboard and macOS pasteboard.
final CommandShortcutEvent smartCopyCommand = CommandShortcutEvent(
  key: 'smart copy rich html and text',
  getDescription: () => AppFlowyEditorL10n.current.cmdCopySelection,
  command: 'ctrl+c',
  macOSCommand: 'cmd+c',
  handler: _smartCopyHandler,
);

/// Intercepts Cmd+X / Ctrl+X to write rich HTML + text before cutting.
final CommandShortcutEvent smartCutCommand = CommandShortcutEvent(
  key: 'smart cut rich html and text',
  getDescription: () => AppFlowyEditorL10n.current.cmdCutSelection,
  command: 'ctrl+x',
  macOSCommand: 'cmd+x',
  handler: _smartCutHandler,
);

KeyEventResult _smartCopyHandler(EditorState editorState) {
  final selection = editorState.selection?.normalized;
  if (selection == null || selection.isCollapsed) {
    return KeyEventResult.ignored;
  }
  () async {
    await _writeRichSelectionToClipboard(editorState, selection);
  }();
  return KeyEventResult.handled;
}

KeyEventResult _smartCutHandler(EditorState editorState) {
  final selection = editorState.selection?.normalized;
  if (selection == null || selection.isCollapsed) {
    return KeyEventResult.ignored;
  }
  () async {
    await _writeRichSelectionToClipboard(editorState, selection);
    await editorState.deleteSelection(selection);
  }();
  return KeyEventResult.handled;
}

Future<void> _writeRichSelectionToClipboard(
  EditorState editorState,
  Selection selection,
) async {
  final text = editorState.getTextInSelection(selection).join('\n');
  final nodes = editorState.getSelectedNodes(selection: selection);
  final document = Document.blank()..insert([0], nodes);
  final html = documentToHTML(
    document,
    customParsers: const [
      HTMLCodeBlockParser(),
      HTMLCalloutNodeParser(),
      HTMLToggleNodeParser(),
      HTMLImageDataUriParser(),
    ],
  );
  final resolvedText = text.isEmpty ? null : text;
  final resolvedHtml = html.isEmpty ? null : html;
  await AppFlowyClipboard.setData(text: resolvedText, html: resolvedHtml);
  await writeClipboardData(text: resolvedText, html: resolvedHtml);
}

/// Intercepts Cmd+V / Ctrl+V to smartly insert markdown links `[Title](url)`
/// or internal page links `[Title](page://id)` as clickable rich links rather
/// than raw text syntax.
final CommandShortcutEvent smartLinkPasteCommand = CommandShortcutEvent(
  key: 'smart paste markdown or internal page link',
  getDescription: () => 'paste markdown link or page link as rich link',
  command: 'ctrl+v',
  macOSCommand: 'cmd+v',
  handler: _smartLinkPasteHandler,
);

KeyEventResult _smartLinkPasteHandler(EditorState editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }

  // If inside a code block, let codeBlockPasteCommand handle it
  final node = editorState.getNodeAtPath(selection.start.path);
  if (node?.type == codeBlockType) {
    return KeyEventResult.ignored;
  }

  () async {
    final data = await AppFlowyClipboard.getData();
    final rawText = data.text;
    final text = rawText?.trim();
    final clipboardHtml = (data.html != null && data.html!.isNotEmpty)
        ? data.html
        : await readClipboardHtml();

    if (text != null && text.isNotEmpty) {
      // 1. If text is a bare `page://...` or `https?://...` URL and user
      // selected single-node text, turn the selection into a clickable link.
      final hasSemanticHtml =
          clipboardHtml != null &&
          clipboardHtml.isNotEmpty &&
          hasRichSemanticHtml(clipboardHtml);
      if (_barePageLinkRegex.hasMatch(text) ||
          (!hasSemanticHtml && _bareWebLinkRegex.hasMatch(text))) {
        final sel = editorState.selection;
        if (sel != null && !sel.isCollapsed && sel.isSingle) {
          final targetNode = editorState.getNodeAtPath(sel.start.path);
          if (targetNode != null &&
              targetNode.delta != null &&
              targetNode.type != codeBlockType) {
            final transaction = editorState.transaction;
            transaction.formatText(targetNode, sel.startIndex, sel.length, {
              AppFlowyRichTextKeys.href: text,
            });
            await editorState.apply(transaction);
            return;
          }
        } else if (sel != null && sel.isCollapsed && _barePageLinkRegex.hasMatch(text)) {
          final targetNode = editorState.getNodeAtPath(sel.start.path);
          final isBlankParagraph = targetNode != null &&
              targetNode.type == ParagraphBlockKeys.type &&
              (targetNode.delta?.toPlainText().trim().isEmpty ?? true);
          if (isBlankParagraph) {
            final pageId = text.substring(7).trim();
            final transaction = editorState.transaction;
            final card = pageLinkNode(pageId: pageId);
            transaction.insertNode(targetNode.path, card);
            transaction.deleteNode(targetNode);
            final next = targetNode.path.next;
            transaction.insertNode(next, paragraphNode());
            transaction.afterSelection = Selection.collapsed(Position(path: next));
            await editorState.apply(transaction);
            return;
          }
        }
      }

      // 2. If text is `[Title](url)` (markdown link or internal page link)
      final match = _markdownLinkRegex.firstMatch(text);
      if (match != null) {
        final label = match.group(1)!;
        final href = match.group(2)!;

        // Delete selection if not collapsed
        final currentSelection = editorState.selection;
        if (currentSelection != null && !currentSelection.isCollapsed) {
          await editorState.deleteSelection(currentSelection);
        }

        final targetSelection = editorState.selection;
        if (targetSelection != null) {
          final targetNode = editorState.getNodeAtPath(
            targetSelection.start.path,
          );
          if (targetNode != null && targetNode.delta != null) {
            if (href.startsWith('page://')) {
              final pageId = href.substring(7).trim();
              final isBlankParagraph = targetNode.type == ParagraphBlockKeys.type &&
                  (targetNode.delta?.toPlainText().trim().isEmpty ?? true);
              if (isBlankParagraph && pageId.isNotEmpty) {
                final transaction = editorState.transaction;
                final card = pageLinkNode(pageId: pageId, title: label);
                transaction.insertNode(targetNode.path, card);
                transaction.deleteNode(targetNode);
                final next = targetNode.path.next;
                transaction.insertNode(next, paragraphNode());
                transaction.afterSelection = Selection.collapsed(Position(path: next));
                await editorState.apply(transaction);
                return;
              }
            }

            final insertOffset = targetSelection.start.offset;
            final transaction = editorState.transaction;
            transaction.insertText(
              targetNode,
              insertOffset,
              label,
              attributes: {AppFlowyRichTextKeys.href: href},
            );
            transaction.afterSelection = Selection.collapsed(
              Position(
                path: targetNode.path,
                offset: insertOffset + label.length,
              ),
            );
            await editorState.apply(transaction);
            return;
          }
        }
      }
    }

    // 3. If clipboard holds an image (screenshot, Finder image file, or "Copy
    // Image" without surrounding HTML prose), compress and insert as base64.
    final clipboardImages = await readClipboardImages();
    final htmlHasRichProse =
        clipboardHtml != null &&
        clipboardHtml.isNotEmpty &&
        hasRichTextAlongsideImages(clipboardHtml);
    if (clipboardImages.isNotEmpty && !htmlHasRichProse) {
      final handled = await pasteImageBytes(editorState, clipboardImages);
      if (handled) {
        return;
      }
    }

    // 4. If clipboard has rich HTML (copied from browser, Notion, or Electron
    // chat clients where plain text is stripped of headings/lists/code),
    // convert HTML to structured editor blocks. Skip non-semantic wrapper HTML
    // when plain text looks like raw Markdown source (e.g. from VS Code).
    if (clipboardHtml != null && clipboardHtml.isNotEmpty) {
      final isSemantic = hasRichSemanticHtml(clipboardHtml);
      if (isSemantic || rawText == null || !looksLikeMarkdown(rawText)) {
        final handled = await pasteHtmlText(editorState, clipboardHtml);
        if (handled) {
          return;
        }
      }
    }

    // 5. If plain text has Markdown syntax (headings, lists, code, bold, etc.),
    // convert to rich AppFlowy blocks and inline formatting instead of raw text.
    if (rawText != null && looksLikeMarkdown(rawText)) {
      final handled = await pasteMarkdownText(editorState, rawText);
      if (handled) {
        return;
      }
    }

    // Fallback: standard AppFlowy paste handler
    pasteCommand.handler(editorState);
  }();

  return KeyEventResult.handled;
}
