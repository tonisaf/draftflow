import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/extensions/native.dart';

import '../../model/database_query.dart';
import '../../search/fuzzy_matcher.dart';
import '../app_database.dart';
import 'dao_shared.dart';

String _extractPlainBlockText(String rawContent) {
  if (rawContent.isEmpty) return '';
  try {
    final decoded = jsonDecode(rawContent);
    if (decoded is Map) {
      final data = decoded['data'] ?? decoded['attributes'] ?? decoded;
      if (data is Map && data['delta'] != null) {
        return _extractDeltaText(data['delta']);
      }
    } else if (decoded is List) {
      return _extractDeltaText(decoded);
    }
  } catch (_) {
    return rawContent;
  }
  return '';
}

String _extractDeltaText(dynamic delta) {
  if (delta is List) {
    final sb = StringBuffer();
    for (final op in delta) {
      if (op is Map && op['insert'] != null) {
        sb.write(op['insert']);
      }
    }
    return sb.toString();
  } else if (delta is String) {
    return delta;
  }
  return '';
}

String? _extractSnippetAround(
  String fullText,
  String query, {
  int radius = 40,
}) {
  if (fullText.trim().isEmpty || query.trim().isEmpty) return null;
  final lowerText = fullText.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final idx = lowerText.indexOf(lowerQuery);
  if (idx == -1) return null;

  final start = (idx - radius).clamp(0, fullText.length);
  final end = (idx + query.length + radius).clamp(0, fullText.length);

  var sub = fullText
      .substring(start, end)
      .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
      .trim();
  if (start > 0) sub = '...$sub';
  if (end < fullText.length) sub = '$sub...';
  return sub;
}

class PagesDao extends DatabaseAccessor<AppDatabase> {
  PagesDao(super.db);

  $PagesTable get pages => db.pages;
  $BlocksTable get blocks => db.blocks;
  $DatabasesTable get databases => db.databases;

  Future<void> upsertPage(PagesCompanion page) =>
      into(pages).insertOnConflictUpdate(withSearchFields(page));

  PagesCompanion withSearchFields(PagesCompanion page) => page.copyWith(
    titleFolded: page.title.present
        ? Value(page.title.value.toLowerCase())
        : const Value.absent(),
    propertiesFolded: page.properties.present
        ? Value(foldProperties(page.properties.value))
        : const Value.absent(),
  );

  Future<void> refreshRowSearchData() async {
    final stored = await getAllPages();
    await batch((batch) {
      for (final page in stored) {
        batch.update(
          pages,
          PagesCompanion(
            titleFolded: Value(page.title.toLowerCase()),
            propertiesFolded: Value(foldProperties(page.properties)),
          ),
          where: (t) => t.id.equals(page.id),
        );
      }
    });
  }

  Stream<List<Page>> watchActivePages() {
    return (select(pages)
          ..where((tbl) => tbl.trashedAt.isNull() & tbl.databaseId.isNull())
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.orderKey),
            (tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .watch();
  }

  Stream<List<Page>> watchTrashedPages() {
    return (select(pages)
          ..where((tbl) => tbl.trashedAt.isNotNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.trashedAt)]))
        .watch();
  }

  Future<Page?> getPageById(String pageId) {
    return (select(pages)..where((tbl) => tbl.id.equals(pageId)))
        .getSingleOrNull();
  }

  Stream<Page?> watchPageById(String pageId) {
    return (select(pages)..where((tbl) => tbl.id.equals(pageId)))
        .watchSingleOrNull();
  }

  Future<List<PageMatchRecord>> searchPagesWithMatches(String query) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      final recent = await (select(pages)
            ..where((tbl) => tbl.trashedAt.isNull())
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
            ..limit(25))
          .get();
      return recent.map((p) => PageMatchRecord(page: p)).toList();
    }

    final resultMap = <String, PageMatchRecord>{};

    // 1. Search page titles (both folded and Unicode case-insensitive)
    final titleMatches = await (select(pages)
          ..where(
            (tbl) =>
                tbl.trashedAt.isNull() &
                (tbl.titleFolded.contains(clean) |
                    tbl.title.containsCase(clean, caseSensitive: false) |
                    tbl.title.contains(query.trim())),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
          ..limit(40))
        .get();

    for (final page in titleMatches) {
      final lowerTitle = page.title.trim().toLowerCase();
      int score = 70;
      if (lowerTitle == clean) {
        score = 100;
      } else if (lowerTitle.startsWith(clean)) {
        score = 85;
      }
      resultMap[page.id] = PageMatchRecord(
        page: page,
        isContentMatch: false,
        score: score,
      );
    }

    // 2. Search block contents (case-insensitive for Cyrillic and Unicode)
    final words =
        clean.split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();
    final blockMatches = await (select(blocks)
          ..where((tbl) {
            Expression<bool> contentPredicate =
                tbl.content.containsCase(clean, caseSensitive: false);
            if (words.length > 1) {
              Expression<bool> allWords =
                  tbl.content.containsCase(words[0], caseSensitive: false);
              for (int i = 1; i < words.length; i++) {
                allWords = allWords &
                    tbl.content.containsCase(words[i], caseSensitive: false);
              }
              contentPredicate = contentPredicate | allWords;
            }
            return tbl.trashedAt.isNull() & contentPredicate;
          })
          ..limit(80))
        .get();

    for (final block in blockMatches) {
      final plainText = _extractPlainBlockText(block.content);
      var snippet = _extractSnippetAround(plainText, clean);
      if (snippet == null && words.isNotEmpty) {
        for (final word in words) {
          snippet = _extractSnippetAround(plainText, word);
          if (snippet != null) break;
        }
      }
      if (snippet == null) continue;

      if (resultMap.containsKey(block.pageId)) {
        final existing = resultMap[block.pageId]!;
        if (existing.snippet == null) {
          resultMap[block.pageId] = PageMatchRecord(
            page: existing.page,
            snippet: snippet,
            isContentMatch: existing.isContentMatch,
            isFuzzyMatch: existing.isFuzzyMatch,
            matchedTerm: existing.matchedTerm,
            score: existing.score + 15,
          );
        }
      } else {
        final page = await (select(pages)
              ..where(
                (tbl) => tbl.id.equals(block.pageId) & tbl.trashedAt.isNull(),
              ))
            .getSingleOrNull();
        if (page != null) {
          resultMap[page.id] = PageMatchRecord(
            page: page,
            snippet: snippet,
            isContentMatch: true,
            isFuzzyMatch: false,
            score: 40,
          );
        }
      }
    }

    // 3. Phase 2: Fuzzy & Typo tolerance matching on titles
    if (resultMap.length < 25 && clean.length >= 3) {
      final allPages = await (select(pages)
            ..where((tbl) => tbl.trashedAt.isNull())
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
            ..limit(120))
          .get();

      final queryWords = FuzzyMatcher.tokenize(clean);
      for (final p in allPages) {
        if (resultMap.containsKey(p.id)) continue;
        final titleWords = FuzzyMatcher.tokenize(p.title);
        if (titleWords.isEmpty) continue;

        int bestScore = 0;
        String? bestTerm;
        bool isFuzzy = false;

        for (final qW in queryWords) {
          for (final tW in titleWords) {
            final match = FuzzyMatcher.matchWord(qW, tW);
            if (match != null) {
              int score = 0;
              if (match.isExact) {
                score = 70;
              } else if (match.isPrefix || match.isStem) {
                score = 65;
                isFuzzy = true;
                bestTerm = tW;
              } else if (match.distance == 1) {
                score = 55;
                isFuzzy = true;
                bestTerm = tW;
              } else if (match.distance == 2) {
                score = 45;
                isFuzzy = true;
                bestTerm = tW;
              }
              if (score > bestScore) {
                bestScore = score;
              }
            }
          }
        }

        if (bestScore > 0) {
          resultMap[p.id] = PageMatchRecord(
            page: p,
            isContentMatch: false,
            isFuzzyMatch: isFuzzy,
            matchedTerm: bestTerm,
            score: bestScore,
          );
        }
      }
    }

    // 4. Phase 2: Fuzzy matching on blocks if results are still sparse
    if (resultMap.length < 15 && clean.length >= 4) {
      final recentBlocks = await (select(blocks)
            ..where((tbl) => tbl.trashedAt.isNull())
            ..limit(160))
          .get();

      for (final b in recentBlocks) {
        if (resultMap.containsKey(b.pageId)) continue;
        final plain = _extractPlainBlockText(b.content);
        final fuzzySnippet = FuzzyMatcher.extractFuzzySnippet(plain, clean);
        if (fuzzySnippet != null) {
          final page = await (select(pages)
                ..where(
                  (tbl) => tbl.id.equals(b.pageId) & tbl.trashedAt.isNull(),
                ))
              .getSingleOrNull();
          if (page != null) {
            resultMap[page.id] = PageMatchRecord(
              page: page,
              snippet: fuzzySnippet.snippet,
              isContentMatch: true,
              isFuzzyMatch: fuzzySnippet.isFuzzy,
              matchedTerm: fuzzySnippet.matchedTerm,
              score: fuzzySnippet.isFuzzy ? 32 : 40,
            );
          }
        }
      }
    }

    final list = resultMap.values.toList();
    list.sort((a, b) {
      final scoreCmp = b.score.compareTo(a.score);
      if (scoreCmp != 0) return scoreCmp;
      return b.page.createdAt.compareTo(a.page.createdAt);
    });

    return list;
  }

  Future<List<Page>> searchPages(String query) async {
    final matches = await searchPagesWithMatches(query);
    return matches.map((m) => m.page).toList();
  }

  Future<List<Page>> getBacklinksForPage(String targetPageId) async {
    final needle = 'page://$targetPageId';
    final referencingBlocks = await (select(blocks)
          ..where(
            (tbl) =>
                tbl.trashedAt.isNull() &
                tbl.content.contains(needle) &
                tbl.pageId.equals(targetPageId).not(),
          ))
        .get();

    final pageIds = referencingBlocks.map((b) => b.pageId).toSet();
    if (pageIds.isEmpty) return [];

    return (select(pages)
          ..where((tbl) => tbl.trashedAt.isNull() & tbl.id.isIn(pageIds))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  Future<void> updatePageTitle(String pageId, String title) {
    return (update(pages)..where((tbl) => tbl.id.equals(pageId))).write(
      PagesCompanion(
        title: Value(title),
        titleFolded: Value(title.toLowerCase()),
      ),
    );
  }

  Future<void> updatePageParent(String pageId, String? parentId) {
    return (update(pages)..where((tbl) => tbl.id.equals(pageId))).write(
      PagesCompanion(parentId: Value(parentId)),
    );
  }

  Future<void> updatePageParentAndOrder(
    String pageId,
    String? parentId,
    String? orderKey,
  ) {
    return (update(pages)..where((tbl) => tbl.id.equals(pageId))).write(
      PagesCompanion(parentId: Value(parentId), orderKey: Value(orderKey)),
    );
  }

  Future<void> updatePageIcon(String pageId, String? icon) {
    return (update(pages)..where((tbl) => tbl.id.equals(pageId))).write(
      PagesCompanion(icon: Value(icon)),
    );
  }

  Future<void> updatePageCover(String pageId, String? cover) {
    return (update(pages)..where((tbl) => tbl.id.equals(pageId))).write(
      PagesCompanion(cover: Value(cover)),
    );
  }

  Future<List<Page>> getAllPages() => select(pages).get();
}
