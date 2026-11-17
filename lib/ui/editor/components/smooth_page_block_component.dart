import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart';
// The pinned AppFlowy revision exposes its page's list only through src.
// Keep this adapter in sync when updating appflowy_editor.
// ignore: implementation_imports
import 'package:appflowy_editor/src/flutter/scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'code_block_component.dart';
import 'collapsible_heading_component.dart';
import 'inline_code_background.dart';
import 'page_block_reorder.dart';

import '../../common/smooth_wheel_region.dart';
import '../../theme.dart';

class SmoothPageBlockComponentBuilder extends PageBlockComponentBuilder {
  SmoothPageBlockComponentBuilder({this.enableBlockReorder = false});
  final bool enableBlockReorder;
  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) =>
      _SmoothPageBlockComponent(
        key: blockComponentContext.node.key,
        enableBlockReorder: enableBlockReorder,
        node: blockComponentContext.node,
        header: blockComponentContext.header,
        footer: blockComponentContext.footer,
        wrapper: blockComponentContext.wrapper,
      );
}

class _SmoothPageBlockComponent extends PageBlockComponent {
  const _SmoothPageBlockComponent({
    super.key,
    required this.enableBlockReorder,
    required super.node,
    super.header,
    super.footer,
    super.wrapper,
  });

  final bool enableBlockReorder;

  @override
  Widget build(BuildContext context) {
    final editor = context.read<EditorState>();
    final page = super.build(context);
    if (page is ScrollablePositionedList) {
      final builder = page.itemBuilder;
      // Wrap outside the centered item, covering the page's side margins too.
      // Keep AppFlowy's item controllers, virtualization and selection logic.
      return ScrollablePositionedList.builder(
        key: page.key,
        initialScrollIndex: page.initialScrollIndex,
        initialAlignment: page.initialAlignment,
        reverse: page.reverse,
        physics: page.physics,
        semanticChildCount: page.semanticChildCount,
        padding: page.padding,
        addSemanticIndexes: page.addSemanticIndexes,
        addAutomaticKeepAlives: page.addAutomaticKeepAlives,
        addRepaintBoundaries: page.addRepaintBoundaries,
        minCacheExtent: page.minCacheExtent,
        itemCount: page.itemCount,
        itemBuilder: (context, index) {
          final blockIndex = index - (header == null ? 0 : 1);
          if (blockIndex >= 0 && blockIndex < node.children.length) {
            if (isNodeHiddenByCollapsedHeading(node.children, blockIndex)) {
              return const SizedBox.shrink();
            }
          }
          Widget child = builder(context, index);
          final block = blockIndex >= 0 && blockIndex < node.children.length
              ? node.children[blockIndex]
              : null;
          if (block != null &&
              block.type != ParagraphBlockKeys.type &&
              block.type != codeBlockType) {
            child = InlineCodeBackground(
              color: context.skin.inlineCodeSurface,
              child: child,
            );
          }
          if (enableBlockReorder && editor.editable && block != null) {
            final item = child;
            child = LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = math.min(
                  constraints.maxWidth,
                  editor.editorStyle.maxWidth ?? constraints.maxWidth,
                );
                final margin = (constraints.maxWidth - contentWidth) / 2;
                final padding = editor.editorStyle.padding;
                return PageBlockReorderFrame(
                  key: ValueKey(block.id),
                  editor: editor,
                  node: block,
                  contentLeft: margin + padding.left,
                  contentRight: margin + padding.right,
                  child: item,
                );
              },
            );
          }
          return SmoothWheelRegion(child: child);
        },
        shrinkWrap: page.shrinkWrap,
        scrollDirection: page.scrollDirection,
        itemScrollController: page.itemScrollController,
        scrollOffsetController: page.scrollOffsetController,
        itemPositionsListener: page.itemPositionsNotifier,
        scrollOffsetListener: page.scrollOffsetNotifier,
      );
    }
    if (page is SingleChildScrollView) {
      return SingleChildScrollView(
        child: SmoothWheelRegion(child: page.child!),
      );
    }
    return page;
  }
}
