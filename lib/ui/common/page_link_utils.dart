import 'app_icons.dart';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';

import '../../data/db/app_database.dart';
import '../theme.dart';

String formatPageLinkDetails({
  required String id,
  required String title,
  String? icon,
}) {
  final cleanTitle = title.trim().isEmpty ? 'Untitled' : title.trim();
  final cleanIcon = (icon != null && icon.isNotEmpty) ? '$icon ' : '';
  return '[$cleanIcon$cleanTitle](page://$id)';
}

String formatPageLink(Page page) =>
    formatPageLinkDetails(id: page.id, title: page.title, icon: page.icon);

Future<void> copyPageLinkDetailsToClipboard(
  BuildContext context, {
  required String pageId,
  required String title,
  String? icon,
}) async {
  final link = formatPageLinkDetails(id: pageId, title: title, icon: icon);
  await Clipboard.setData(ClipboardData(text: link));
  if (context.mounted) {
    final cleanTitle = title.trim().isEmpty ? 'Untitled' : title.trim();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.link, size: UiSpace.s16, color: Palette.accent),
            const SizedBox(width: UiSpace.s8),
            Flexible(
              child: Text(
                'Link to "$cleanTitle" copied to clipboard',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: Motion.notice,
        width: UiLayout.linkNoticeWidth,
      ),
    );
  }
}

Future<void> copyPageLinkToClipboard(BuildContext context, Page page) =>
    copyPageLinkDetailsToClipboard(
      context,
      pageId: page.id,
      title: page.title,
      icon: page.icon,
    );
