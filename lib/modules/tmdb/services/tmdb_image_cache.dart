import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class TmdbImageCache {
  static Directory? _cacheDir;

  static Future<Directory> getCacheDir() async {
    if (_cacheDir != null && await _cacheDir!.exists()) {
      return _cacheDir!;
    }
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/tmdb_images');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  static String _getFileName(String url) {
    final uri = Uri.parse(url);
    final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'img';
    return '${uri.pathSegments.length > 1 ? uri.pathSegments[uri.pathSegments.length - 2] : ""}_$seg';
  }

  static Future<File?> getCachedFile(String url) async {
    try {
      final dir = await getCacheDir();
      final file = File('${dir.path}/${_getFileName(url)}');
      if (await file.exists() && await file.length() > 0) {
        return file;
      }
    } catch (_) {}
    return null;
  }

  static Future<File?> downloadAndCache(String url) async {
    try {
      final dir = await getCacheDir();
      final file = File('${dir.path}/${_getFileName(url)}');
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        await file.writeAsBytes(res.bodyBytes);
        return file;
      }
    } catch (_) {}
    return null;
  }
}

class TmdbCachedImage extends StatefulWidget {
  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const TmdbCachedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<TmdbCachedImage> createState() => _TmdbCachedImageState();
}

class _TmdbCachedImageState extends State<TmdbCachedImage> {
  File? _cachedFile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant TmdbCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    // Check disk cache first
    final file = await TmdbImageCache.getCachedFile(url);
    if (file != null) {
      if (mounted) {
        setState(() {
          _cachedFile = file;
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    // Fetch and save
    final downloaded = await TmdbImageCache.downloadAndCache(url);
    if (mounted) {
      setState(() {
        _cachedFile = downloaded;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_cachedFile != null) {
      content = Image.file(
        _cachedFile!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
      );
    } else if (_isLoading) {
      content = widget.placeholder ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey.withValues(alpha: 0.15),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
    } else {
      content = widget.errorWidget ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey.withValues(alpha: 0.15),
            child: const Center(
              child: Icon(Icons.movie_outlined, size: 28, color: Colors.grey),
            ),
          );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }
    return content;
  }
}
