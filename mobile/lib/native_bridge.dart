import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:webview_flutter/webview_flutter.dart';

/// Native services behind the JS polyfill: text-to-speech, speech-to-text
/// and the photo picker for the scan page.
///
/// One instance per WebView. The phone has a single audio output, so the
/// TTS engine itself is shared and whichever page spoke last owns it.
class NativeBridge {
  NativeBridge(this._controller);

  final WebViewController _controller;

  static final FlutterTts _tts = FlutterTts();
  static NativeBridge? _ttsOwner;
  static bool _ttsReady = false;
  static final stt.SpeechToText _stt = stt.SpeechToText();
  static bool _sttReady = false;

  int? _speakingId;

  /// Wire the TTS callbacks once, and route them to the page that is
  /// currently speaking.
  static Future<void> _ensureTts() async {
    if (_ttsReady) return;
    _ttsReady = true;
    await _tts.awaitSpeakCompletion(false);
    _tts.setStartHandler(() => _ttsOwner?._emitTts('tts.start'));
    _tts.setCompletionHandler(() => _ttsOwner?._emitTts('tts.end'));
    _tts.setCancelHandler(
        () => _ttsOwner?._emitTts('tts.error', error: 'interrupted'));
    _tts.setErrorHandler((m) => _ttsOwner?._emitTts('tts.error', error: '$m'));
  }

  /// Cut off whatever is being spoken, app-wide. Called when the visitor
  /// switches tab, opens or closes a page, or a page navigates away — the
  /// phone has one TTS engine, so a hidden page would otherwise keep talking.
  static Future<void> stopSpeaking() async {
    final owner = _ttsOwner;
    if (owner != null && owner._speakingId != null) {
      // Let that page's guide reset its "speaking" state.
      owner._emitTts('tts.error', error: 'interrupted');
    }
    _ttsOwner = null;
    await _tts.stop();
  }

  /// Stop speech only if this page is the one talking (page closed or
  /// navigating). Doesn't message the page — it is going away.
  Future<void> silence() async {
    if (_ttsOwner != this) return;
    _speakingId = null;
    _ttsOwner = null;
    await _tts.stop();
  }

  void _emitTts(String type, {String? error}) {
    final id = _speakingId;
    if (id == null) return;
    if (type != 'tts.start') _speakingId = null;
    _emit({'type': type, 'id': id, if (error != null) 'error': error});
  }

  void _emit(Map<String, dynamic> msg) {
    _controller.runJavaScript(
        'window.__virasat&&window.__virasat.emit(${jsonEncode(msg)})');
  }

  /// Entry point for the `VirasatNative` JavaScript channel.
  Future<void> onMessage(String raw) async {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (msg['type']) {
      case 'tts.speak':
        await _speak(msg);
      case 'tts.stop':
        if (_ttsOwner == this) {
          _speakingId = null;
          await _tts.stop();
        }
      case 'tts.pause':
        if (_ttsOwner == this) await _tts.pause();
      case 'tts.resume':
        // flutter_tts has no resume on Android; the page re-queues on its own.
        break;
      case 'stt.start':
        await _listen(msg);
      case 'stt.stop':
        await _stt.stop();
      case 'stt.cancel':
        await _stt.cancel();
        _emit({'type': 'stt.end'});
    }
  }

  Future<void> _speak(Map<String, dynamic> msg) async {
    await _ensureTts();
    if (_ttsOwner != null && _ttsOwner != this) {
      _ttsOwner!._speakingId = null;
      await _tts.stop();
    }
    _ttsOwner = this;
    _speakingId = msg['id'] as int;

    final lang = _normLang(msg['lang'] as String? ?? 'en-IN');
    await _tts.setLanguage(lang);
    // Web rates are ~0.9–1.1 around a 1.0 baseline; Android's baseline is 0.5.
    final rate = ((msg['rate'] as num?)?.toDouble() ?? 1.0).clamp(0.5, 1.6);
    await _tts.setSpeechRate(0.5 * rate);
    await _tts
        .setPitch(((msg['pitch'] as num?)?.toDouble() ?? 1.0).clamp(0.5, 2.0));
    await _tts.setVolume(
        ((msg['volume'] as num?)?.toDouble() ?? 1.0).clamp(0.0, 1.0));

    final text = (msg['text'] as String? ?? '').trim();
    if (text.isEmpty) {
      _emitTts('tts.end');
      return;
    }
    final r = await _tts.speak(text);
    if (r != 1) _emitTts('tts.error', error: 'synthesis-failed');
  }

  /// `hi` → `hi-IN`, `en` → `en-IN`, keeps full tags as-is.
  static String _normLang(String l) {
    l = l.replaceAll('_', '-');
    if (l.contains('-')) return l;
    const india = {
      'hi',
      'ta',
      'te',
      'kn',
      'ml',
      'mr',
      'gu',
      'bn',
      'pa',
      'or',
      'as',
      'ur',
      'en'
    };
    return india.contains(l) ? '$l-IN' : l;
  }

  Future<void> _listen(Map<String, dynamic> msg) async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _emit({'type': 'stt.error', 'error': 'not-allowed'});
      _emit({'type': 'stt.end'});
      return;
    }
    if (!_sttReady) {
      _sttReady = await _stt.initialize(
        onError: (e) {
          _emit({'type': 'stt.error', 'error': e.errorMsg});
        },
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') _emit({'type': 'stt.end'});
        },
      );
      if (!_sttReady) {
        _emit({'type': 'stt.error', 'error': 'audio-capture'});
        _emit({'type': 'stt.end'});
        return;
      }
    }
    // Pause any narration so it isn't transcribed.
    if (_ttsOwner != null) {
      _ttsOwner!._speakingId = null;
      await _tts.stop();
    }
    final interim = msg['interim'] == true;
    _emit({'type': 'stt.start'});
    await _stt.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId:
            _normLang(msg['lang'] as String? ?? 'en-IN').replaceAll('-', '_'),
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        partialResults: interim,
        cancelOnError: true,
      ),
      onResult: (r) {
        if (!interim && !r.finalResult) return;
        _emit({
          'type': 'stt.result',
          'text': r.recognizedWords,
          'final': r.finalResult
        });
      },
    );
  }

  /// `<input type="file" accept="image/*">` → camera or gallery.
  static Future<List<String>> pickImage(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF12141C),
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded,
                  color: Color(0xFFC9A84C)),
              title: const Text('Take a photo'),
              subtitle: const Text('Point the camera at the monument'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: Color(0xFFC9A84C)),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return const [];
    if (source == ImageSource.camera) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) return const [];
    }
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
    );
    if (picked == null) return const [];
    return [Uri.file(picked.path).toString()];
  }
}
