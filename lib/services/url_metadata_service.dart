import 'dart:async';
import 'package:http/http.dart' as http;

class InboxUrlMetadata {
  final String url;
  final String domain;
  final String title;
  final String? description;
  final String? imageUrl;
  final String faviconUrl;

  const InboxUrlMetadata({
    required this.url,
    required this.domain,
    required this.title,
    this.description,
    this.imageUrl,
    required this.faviconUrl,
  });
}

class UrlMetadataService {
  static final RegExp _urlRegex = RegExp(
    r'^(?:https?:\/\/)?(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:\/[^\s]*)?$',
    caseSensitive: false,
  );

  static bool isUrl(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.contains('\n') || trimmed.contains(' ')) {
      return false;
    }
    return _urlRegex.hasMatch(trimmed);
  }

  static String normalizeUrl(String text) {
    var trimmed = text.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }
    return trimmed;
  }

  static String extractDomain(String url) {
    try {
      final uri = Uri.parse(normalizeUrl(url));
      var host = uri.host.toLowerCase();
      if (host.startsWith('www.')) {
        host = host.substring(4);
      }
      return host.isNotEmpty ? host : 'web';
    } catch (_) {
      return 'web';
    }
  }

  static String getFaviconUrl(String domain) {
    return 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
  }

  static Future<InboxUrlMetadata> fetchMetadata(String inputUrl) async {
    final cleanUrl = normalizeUrl(inputUrl);
    final domain = extractDomain(cleanUrl);
    final fallbackFavicon = getFaviconUrl(domain);

    String title = domain;
    String? description;
    String? imageUrl;
    String faviconUrl = fallbackFavicon;

    try {
      final uri = Uri.parse(cleanUrl);
      final response = await http.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = response.body;

        // OG Image: <meta property="og:image" content="..."
        final ogImageMatch = RegExp(
          r'<meta\s+[^>]*property=["'']og:image["'']\s+content=["'']([^"'']+)["'']',
          caseSensitive: false,
        ).firstMatch(body) ??
            RegExp(
              r'<meta\s+[^>]*content=["'']([^"'']+)["'']\s+property=["'']og:image["'']',
              caseSensitive: false,
            ).firstMatch(body);

        if (ogImageMatch != null) {
          var img = ogImageMatch.group(1)?.trim();
          if (img != null && img.isNotEmpty) {
            if (img.startsWith('//')) {
              img = 'https:$img';
            } else if (img.startsWith('/')) {
              img = uri.resolve(img).toString();
            }
            imageUrl = img;
          }
        }

        // OG Title or <title>
        final ogTitleMatch = RegExp(
          r'<meta\s+[^>]*property=["'']og:title["'']\s+content=["'']([^"'']+)["'']',
          caseSensitive: false,
        ).firstMatch(body) ??
            RegExp(
              r'<meta\s+[^>]*content=["'']([^"'']+)["'']\s+property=["'']og:title["'']',
              caseSensitive: false,
            ).firstMatch(body);

        if (ogTitleMatch != null) {
          title = _cleanHtmlEntities(ogTitleMatch.group(1) ?? domain);
        } else {
          final titleTagMatch = RegExp(
            r'<title[^>]*>([^<]+)<\/title>',
            caseSensitive: false,
          ).firstMatch(body);
          if (titleTagMatch != null) {
            title = _cleanHtmlEntities(titleTagMatch.group(1) ?? domain);
          }
        }

        // OG Description or <meta name="description">
        final ogDescMatch = RegExp(
          r'<meta\s+[^>]*property=["'']og:description["'']\s+content=["'']([^"'']+)["'']',
          caseSensitive: false,
        ).firstMatch(body) ??
            RegExp(
              r'<meta\s+[^>]*name=["'']description["'']\s+content=["'']([^"'']+)["'']',
              caseSensitive: false,
            ).firstMatch(body);

        if (ogDescMatch != null) {
          description = _cleanHtmlEntities(ogDescMatch.group(1) ?? '');
        }
      }
    } catch (_) {
      // Graceful fallback to domain metadata
    }

    return InboxUrlMetadata(
      url: cleanUrl,
      domain: domain,
      title: title.isNotEmpty ? title : domain,
      description: description,
      imageUrl: imageUrl,
      faviconUrl: faviconUrl,
    );
  }

  static String _cleanHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}
