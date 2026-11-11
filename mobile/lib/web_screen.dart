import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'config.dart';
import 'native_bridge.dart';
import 'orientation_polyfill.dart';
import 'speech_polyfill.dart';

/// Hosts one page of the Virasat platform.
///
/// Each tab keeps its own controller so switching tabs doesn't reload the
/// page (the VR explorer and the map are expensive to boot). Camera + mic
/// requests from the page (scan, voice guide) are granted after the OS
/// permission prompt.
class WebScreen extends StatefulWidget {
  const WebScreen({super.key, required this.page, this.showBack = false});
  final String page;
  final bool showBack;

  /// Set by the shell: return to the native Home tab. Web pages link "Home"
  /// to index.html (the desktop scroll-animation landing), which the app
  /// replaces with its own home screen.
  static VoidCallback? onGoHome;

  @override
  State<WebScreen> createState() => WebScreenState();
}

class WebScreenState extends State<WebScreen>
    with AutomaticKeepAliveClientMixin {
  late final WebViewController _controller;
  late final NativeBridge _bridge;
  double _progress = 0;
  String? _error;

  /// Phone rotation from MainActivity, forwarded into VR pages (see
  /// orientation_polyfill.dart). Only subscribed while a VR page is loaded.
  // One shared platform subscription, even if several tabs show VR pages.
  static final Stream<dynamic> _orientation =
      const EventChannel('virasat/orientation').receiveBroadcastStream();
  StreamSubscription<dynamic>? _orientationSub;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _bridge = NativeBridge(_controller);
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFCFBF8))
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124 Mobile Safari/537.36 VirasatApp/1.0',
      )
      ..addJavaScriptChannel('VirasatNative',
          onMessageReceived: (m) => _bridge.onMessage(m.message))
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p / 100),
        onPageStarted: (_) {
          // Leaving a page: its guide must not keep talking over the next one.
          _bridge.silence();
          setState(() => _error = null);
          // Install the shims before the page's own scripts look for them.
          _controller.runJavaScript(kSpeechPolyfillJs);
          _controller.runJavaScript(kOrientationPolyfillJs);
        },
        onPageFinished: (url) {
          _controller.runJavaScript(kSpeechPolyfillJs);
          _controller.runJavaScript(kOrientationPolyfillJs);
          _syncOrientation(url);
        },
        onUrlChange: (change) => _syncOrientation(change.url),
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) {
            setState(() => _error = e.description);
          }
        },
        onNavigationRequest: (req) {
          // Keep the platform in-app; hand everything else to the OS.
          final u = Uri.parse(req.url);
          final base = Uri.parse(AppConfig.baseUrl);
          if (u.host == base.host && _isWebHome(u.path)) {
            WebScreen.onGoHome?.call();
            return NavigationDecision.prevent;
          }
          if (u.host == base.host ||
              u.scheme == 'about' ||
              u.scheme == 'blob') {
            return NavigationDecision.navigate;
          }
          return NavigationDecision.prevent;
        },
      ));

    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(false);
      platform
        ..setMediaPlaybackRequiresUserGesture(false)
        ..setOnPlatformPermissionRequest(_onPermission)
        ..setOnShowFileSelector(_onFileSelector);
    }

    _controller.loadRequest(AppConfig.page(widget.page));
  }

  static bool _isWebHome(String path) {
    final p = path.toLowerCase();
    return p.isEmpty || p == '/' || p.endsWith('/index.html');
  }

  /// Stream the gyro into the page only while a VR scene is showing.
  void _syncOrientation(String? url) {
    final path = Uri.tryParse(url ?? '')?.path.toLowerCase() ?? '';
    final isVr = path.endsWith('/vr.html') || path.contains('/vr/');
    if (isVr && _orientationSub == null) {
      _orientationSub = _orientation.listen((v) {
        final a = (v as List).cast<double>();
        _controller.runJavaScript(
            'window.__vnOrient&&window.__vnOrient(${a[0]},${a[1]},${a[2]})');
      }, onError: (_) {});
    } else if (!isVr && _orientationSub != null) {
      _orientationSub!.cancel();
      _orientationSub = null;
    }
  }

  /// Quiet this page: stop its guide (browser voice or neural audio) and
  /// the native TTS if it is the one speaking. Used when the tab is hidden.
  void silence() {
    _controller.runJavaScript(
        'window.VirasatGuide&&window.VirasatGuide.stop();'
        'window.speechSynthesis&&window.speechSynthesis.cancel();');
    _bridge.silence();
  }

  @override
  void dispose() {
    _orientationSub?.cancel();
    _bridge.silence();
    super.dispose();
  }

  /// Web page asked for camera/mic → ask the OS once, then grant.
  Future<void> _onPermission(PlatformWebViewPermissionRequest req) async {
    final wants = <Permission>[];
    if (req.types.contains(WebViewPermissionResourceType.camera)) {
      wants.add(Permission.camera);
    }
    if (req.types.contains(WebViewPermissionResourceType.microphone)) {
      wants.add(Permission.microphone);
    }
    if (wants.isEmpty) return req.grant();
    final results = await wants.request();
    final ok = results.values.every((s) => s.isGranted);
    ok ? await req.grant() : await req.deny();
  }

  /// `<input type="file">` on the scan page.
  Future<List<String>> _onFileSelector(FileSelectorParams params) async {
    if (!mounted) return const <String>[];
    return NativeBridge.pickImage(context);
  }

  Future<bool> goBackIfPossible() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return true;
    }
    return false;
  }

  void reload() => _controller.reload();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        if (_error == null)
          WebViewWidget(controller: _controller)
        else
          _ErrorView(
            message: _error!,
            onRetry: () => _controller.loadRequest(AppConfig.page(widget.page)),
          ),
        if (_progress < 1)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: const Color(0xFF9E4733),
            ),
          ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFCFBF8),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 52, color: Color(0xFF9E4733)),
          const SizedBox(height: 16),
          const Text('Can\'t reach Virasat',
              style: TextStyle(
                  color: Color(0xFF1C1917),
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            Platform.isAndroid
                ? 'Make sure the server (node static_server.js) and the tunnel are running.\n\n$message'
                : message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFF57534E), fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
