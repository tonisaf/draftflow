import 'dart:async';

import 'package:flutter/widgets.dart';

enum TitleSaveStatus { saved, saving, error }

/// A session is bound to one page. Flush captures the text before disposal;
/// in-flight writes may finish without reading a disposed controller.
class TitleEditSession {
  TitleEditSession({
    required String title,
    required this.save,
    this.debounce = const Duration(milliseconds: 300),
  }) : controller = TextEditingController(text: title) {
    focusNode.addListener(_focusChanged);
  }

  final TextEditingController controller;
  final FocusNode focusNode = FocusNode();
  final Future<void> Function(String) save;
  final Duration debounce;
  final status = ValueNotifier(TitleSaveStatus.saved);
  String? _external;
  bool _editedInFocus = false;
  bool _dirty = false;
  bool _disposed = false;
  Timer? _timer;
  Future<void>? _saving;
  String? _pending;

  void edited(String text) {
    _dirty = true;
    _editedInFocus = true;
    _external = null;
    _setStatus(TitleSaveStatus.saving);
    _timer?.cancel();
    _timer = Timer(debounce, flush);
  }

  void receiveExternal(String text) {
    if (_disposed || text == controller.text) return;
    if (focusNode.hasFocus || _dirty || _saving != null) {
      _external = text;
    } else {
      _applyExternal(text);
    }
  }

  void _applyExternal(String text) {
    if (text != controller.text) {
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    _external = null;
  }

  void _focusChanged() {
    if (focusNode.hasFocus) {
      _editedInFocus = false;
      return;
    }
    if (_editedInFocus && _external != null) {
      // The user finished a local edit while a background title was deferred.
      _dirty = true;
      _external = null;
    }
    if (_dirty) {
      unawaited(flush());
    } else if (_external != null) {
      _applyExternal(_external!);
    }
  }

  Future<void> flush() {
    _timer?.cancel();
    if (!_disposed && _editedInFocus && _external != null) {
      _dirty = true;
    }
    if (_disposed || !_dirty) return _saving ?? Future.value();
    _pending = controller.text;
    _external = null;
    _setStatus(TitleSaveStatus.saving);
    return _saving ??= _drain().whenComplete(() => _saving = null);
  }

  Future<void> _drain() async {
    while (_pending != null) {
      final text = _pending!;
      _pending = null;
      try {
        await save(text);
        if (!_disposed) {
          _dirty = controller.text != text;
          _setStatus(_dirty ? TitleSaveStatus.saving : TitleSaveStatus.saved);
        }
      } catch (_) {
        // Keep the latest text dirty for retry; an older completion never marks
        // a newer local edit saved.
        _setStatus(TitleSaveStatus.error);
        if (_pending == null) return;
        // A newer snapshot (including a final flush on disposal) must still
        // get its own attempt after an older write fails.
      }
    }
    if (!_disposed && !_dirty && !focusNode.hasFocus && _external != null) {
      _applyExternal(_external!);
    }
  }

  void _setStatus(TitleSaveStatus value) {
    if (!_disposed) status.value = value;
  }

  void dispose() {
    // Flush is also used on app suspension and blur, so the owner can await it.
    unawaited(flush());
    _disposed = true;
    _timer?.cancel();
    focusNode.removeListener(_focusChanged);
    focusNode.dispose();
    controller.dispose();
    status.dispose();
  }
}
