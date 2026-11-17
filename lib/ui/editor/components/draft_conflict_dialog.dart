import '../../common/app_dialog.dart';
import '../../common/app_icons.dart';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

import '../../../data/db/app_database.dart';
import '../../../data/notes_repository.dart';
import '../../../l10n/locale_controller.dart';
import '../../common/modern_dialog.dart';
import '../../theme.dart';

/// The document remains editable only after the user leaves this comparison.
Future<bool?> showDraftConflictDialog(
  BuildContext context, {
  required NotesRepository repository,
  required String pageId,
  required Document localDocument,
  required Future<bool> Function(String version) useLocal,
  required Future<void> Function(String version) useSaved,
}) => showAppDialog<bool>(
  context: context,
  animationStyle: Motion.dialogStyle(context),
  barrierColor: context.skin.scrim,
  barrierDismissible: false,
  builder: (_) => _DraftConflictDialog(
    repository: repository,
    pageId: pageId,
    localDocument: localDocument,
    useLocal: useLocal,
    useSaved: useSaved,
  ),
);

class _DraftConflictDialog extends StatefulWidget {
  const _DraftConflictDialog({
    required this.repository,
    required this.pageId,
    required this.localDocument,
    required this.useLocal,
    required this.useSaved,
  });
  final NotesRepository repository;
  final String pageId;
  final Document localDocument;
  final Future<bool> Function(String) useLocal;
  final Future<void> Function(String) useSaved;

  @override
  State<_DraftConflictDialog> createState() => _DraftConflictDialogState();
}

class _DraftConflictDialogState extends State<_DraftConflictDialog> {
  ({Document document, String version})? _saved;
  bool _busy = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await widget.repository.loadPageSnapshot(widget.pageId);
      if (mounted) {
        setState(() {
          _saved = saved;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Could not load the saved version. Try again.';
          _busy = false;
        });
      }
    }
  }

  Future<void> _choose(bool local) async {
    final saved = _saved;
    if (_busy || saved == null) return;
    setState(() => _busy = true);
    try {
      if (local) {
        if (!await widget.useLocal(saved.version)) {
          throw DocumentConflictException(widget.pageId);
        }
      } else {
        await widget.useSaved(saved.version);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _message = 'Could not apply this choice. Review the latest saved version and try again. Your draft is kept.',
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final secondaryStyle = TextButton.styleFrom(
      foregroundColor: skin.accentText,
      disabledForegroundColor: skin.muted,
      textStyle: const TextStyle(fontSize: DesktopUx.menuTextSize),
    );
    return PopScope(
      canPop: !_busy,
      child: ModernDialog(
        title: 'Resolve document conflict',
        allowClose: !_busy,
        icon: AppIcons.arrowRightArrowLeft,
        maxWidth: DesktopUx.conflictDialogWidth,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your draft is stored on this device. Compare both versions before choosing which one to continue with.',
              style: TextStyle(
                color: skin.text,
                fontSize: DesktopUx.menuTextSize,
              ),
            ),
            const SizedBox(height: DesktopUx.menuHorizontalPadding),
            if (_message != null)
              Text(_message!, style: TextStyle(color: skin.destructive)),
            if (_saved != null)
              LayoutBuilder(
                builder: (context, constraints) {
                  final local = _preview(
                    context,
                    'Local draft',
                    widget.localDocument,
                  );
                  final saved = _preview(
                    context,
                    'Saved version',
                    _saved!.document,
                  );
                  return constraints.maxWidth < DesktopUx.conflictStackWidth
                      ? Column(
                          children: [
                            local,
                            const SizedBox(height: DesktopUx.spacing),
                            saved,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: local),
                            const SizedBox(
                              width: DesktopUx.menuHorizontalPadding,
                            ),
                            Expanded(child: saved),
                          ],
                        );
                },
              ),
            const SizedBox(height: DesktopUx.menuHorizontalPadding),
            if (_busy)
              TickerMode(
                enabled: !MediaQuery.disableAnimationsOf(context),
                child: LinearProgressIndicator(
                  color: Palette.accent,
                  backgroundColor: skin.hover,
                ),
              ),
            Wrap(
              spacing: DesktopUx.spacing,
              children: [
                TextButton(
                  style: secondaryStyle,
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: Text(context.l10n.decideLater),
                ),
                if (_saved == null)
                  TextButton(
                    style: secondaryStyle,
                    onPressed: _busy ? null : _load,
                    child: Text(context.l10n.retry),
                  ),
                TextButton(
                  style: secondaryStyle,
                  onPressed: _busy || _saved == null
                      ? null
                      : () => _choose(false),
                  child: Text(context.l10n.useSavedVersion),
                ),
                FilledButton(
                  onPressed: _busy || _saved == null
                      ? null
                      : () => _choose(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.accent,
                    foregroundColor: Palette.onAccent,
                    disabledBackgroundColor: skin.hover,
                    disabledForegroundColor: skin.muted,
                    textStyle: const TextStyle(
                      fontSize: DesktopUx.menuTextSize,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesktopUx.radius),
                    ),
                  ),
                  child: Text(context.l10n.useLocalDraft),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _preview(BuildContext context, String title, Document document) {
  final skin = context.skin;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: TextStyle(color: skin.text, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: DesktopUx.spacing),
      Container(
        height: DesktopUx.conflictPreviewHeight,
        padding: const EdgeInsets.all(DesktopUx.menuHorizontalPadding),
        decoration: BoxDecoration(
          color: skin.sidebar,
          border: Border.all(color: skin.divider),
          borderRadius: BorderRadius.circular(DesktopUx.radius),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            _documentText(document),
            style: TextStyle(
              color: skin.text,
              fontSize: DesktopUx.menuTextSize,
            ),
          ),
        ),
      ),
    ],
  );
}

String _documentText(Document document) {
  final lines = <String>[];
  void visit(Node node, String indent) {
    final text = node.delta?.toPlainText() ?? '';
    final String preview;
    if (node.type == 'code') {
      preview = 'Code (${node.attributes['language'] ?? ''}):\n$text';
    } else if (node.type == 'database') {
      preview = 'Table: ${node.attributes['title'] ?? 'Database'}';
    } else {
      final copy = Node.fromJson({
        ...node.toJson(),
        'children': <Map<String, Object>>[],
      });
      final markdown = documentToMarkdown(
        Document(root: pageNode(children: [copy])),
      ).trim();
      preview = markdown.isEmpty ? text : markdown;
    }
    lines.add('$indent$preview');
    for (final child in node.children) {
      visit(child, '$indent  ');
    }
  }

  for (final node in document.root.children) {
    visit(node, '');
  }
  return lines.join('\n\n');
}
