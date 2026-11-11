import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config.dart';
import 'design/heritage_backdrop.dart';
import 'design/theme.dart';
import 'design/tokens.dart';
import 'screens/ask_sheet.dart';
import 'screens/explore_screen.dart';
import 'screens/home_screen.dart';
import 'screens/intro_screen.dart';
import 'screens/scan_screen.dart';
import 'native_bridge.dart';
import 'web_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  SystemChrome.setSystemUIOverlayStyle(virasatOverlayStyle);
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(const VirasatApp());
}

class VirasatApp extends StatelessWidget {
  const VirasatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virasat',
      debugShowCheckedModeBanner: false,
      theme: buildVirasatTheme(),
      home: const SplashScreen(),
    );
  }
}

// ── Splash ──────────────────────────────────────────────────────────────

/// A quiet opening: the wordmark drawn on the same paper the app is made of,
/// over the ghosted monument. No spinner — it holds for one beat and lifts.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      // Captured now: this State is replaced by the push below, so looking
      // the navigator up again from its context afterwards would throw.
      final nav = Navigator.of(context);
      nav.pushReplacement(_fade(
        IntroScreen(
            onDone: () => nav.pushReplacement(_fade(const ShellScreen()))),
      ));
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    final rise = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

    return Scaffold(
      body: HeritageBackdrop(
        opacity: 0.085,
        alignment: Alignment.center,
        child: Center(
          child: FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: rise,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: VColor.ink,
                      borderRadius: BorderRadius.circular(VRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: Text('V',
                        style: VFont.serif(
                            size: 36, weight: 600, color: Colors.white)),
                  ),
                  const SizedBox(height: VSpace.xl),
                  Text('VIRASAT',
                      style: VFont.sansStyle(
                          size: 24,
                          weight: 800,
                          color: VColor.ink,
                          letterSpacing: 7)),
                  const SizedBox(height: VSpace.sm),
                  Text('HERITAGE, LIVE',
                      style: VFont.sansStyle(
                          size: 10,
                          weight: 600,
                          color: VColor.inkMuted,
                          letterSpacing: 3.4)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The entry flow's page transition: a plain cross-fade, so splash → intro →
/// shell reads as one continuous surface rather than three pushed screens.
PageRouteBuilder<void> _fade(Widget page) => PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 520),
    );

// ── Shell ───────────────────────────────────────────────────────────────

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon, {this.page});
  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// null → a native screen; otherwise the web page this tab hosts while the
  /// screen is being ported.
  final String? page;
}

const _tabs = <_Tab>[
  _Tab('Home', Icons.auto_stories_outlined, Icons.auto_stories_rounded),
  _Tab('Explore', Icons.map_outlined, Icons.map_rounded),
  _Tab('Scan', Icons.center_focus_weak_rounded,
      Icons.center_focus_strong_rounded),
  _Tab('Market', Icons.storefront_outlined, Icons.storefront_rounded,
      page: 'marketplace.html'),
  _Tab('More', Icons.grid_view_outlined, Icons.grid_view_rounded),
];

const _moreItems = <(String, IconData, String)>[
  ('Virtual tours', Icons.threed_rotation_rounded, 'vr.html'),
  ('Community', Icons.forum_outlined, 'community.html'),
  ('Events & festivals', Icons.celebration_outlined, 'events.html'),
  ('Language studio', Icons.translate_rounded, 'language.html'),
  ('Report a site', Icons.flag_outlined, 'report.html'),
  ('Artisan portal', Icons.handyman_outlined, 'artisan.html'),
  ('Your profile', Icons.person_outline_rounded, 'profile.html'),
];

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});
  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;
  final _webKeys = <int, GlobalKey<WebScreenState>>{};

  // A web page's "Home" link → close any pushed pages, show native Home.
  /// Switching feature: no page may keep narrating in the background.
  void _silenceAll() {
    for (final k in _webKeys.values) {
      k.currentState?.silence();
    }
    NativeBridge.stopSpeaking();
  }

  void _goHome() {
    if (!mounted) return;
    _silenceAll();
    Navigator.of(context).popUntil((r) => r.isFirst);
    setState(() => _index = 0);
  }

  @override
  void initState() {
    super.initState();
    WebScreen.onGoHome = _goHome;
  }

  @override
  void dispose() {
    // A replacement shell may already have installed its own handler.
    if (WebScreen.onGoHome == _goHome) WebScreen.onGoHome = null;
    super.dispose();
  }

  GlobalKey<WebScreenState> _keyFor(int i) =>
      _webKeys.putIfAbsent(i, () => GlobalKey<WebScreenState>());

  Future<bool> _onPop() async {
    final tab = _tabs[_index];
    if (tab.page != null) {
      final st = _keyFor(_index).currentState;
      if (st != null && await st.goBackIfPossible()) return false;
    }
    if (_index != 0) {
      setState(() => _index = 0);
      return false;
    }
    return true;
  }

  void _openPage(String page, String title) {
    _silenceAll();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WebPage(page: page, title: title)),
    );
  }

  void _openMore() {
    showModalBottomSheet(
      context: context,
      // The menu is taller than the default 9/16-screen cap — let it size to
      // its content, and scroll if a small screen still can't fit it.
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    VSpace.gutter, VSpace.sm, VSpace.gutter, VSpace.md),
                child: Text('Everything else', style: VFont.title),
              ),
              for (final (label, icon, page) in _moreItems)
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: VColor.surfaceMuted,
                      borderRadius: BorderRadius.circular(VRadius.sm),
                    ),
                    child: Icon(icon, size: 19, color: VColor.ink),
                  ),
                  title: Text(label, style: VFont.label),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: VColor.inkMuted, size: 20),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openPage(page, label);
                  },
                ),
              const Divider(height: VSpace.xl),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: VColor.surfaceMuted,
                    borderRadius: BorderRadius.circular(VRadius.sm),
                  ),
                  child: const Icon(Icons.dns_outlined,
                      size: 19, color: VColor.inkMuted),
                ),
                title: Text('Server address', style: VFont.label),
                subtitle: Text(AppConfig.baseUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VFont.caption),
                onTap: () {
                  Navigator.pop(ctx);
                  _editServer();
                },
              ),
              const SizedBox(height: VSpace.sm),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editServer() async {
    final ctrl = TextEditingController(text: AppConfig.baseUrl);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server address'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(hintText: 'https://…'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await AppConfig.save(ctrl.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ShellScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // _onPop unwinds web history, then tabs. Only when there is nothing
        // left to go back to does back actually leave the app.
        if (await _onPop()) SystemNavigator.pop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < _tabs.length; i++)
              if (_tabs[i].page == null)
                switch (_tabs[i].label) {
                  'Home' => HomeScreen(onOpenPage: _openPage),
                  'Explore' => const ExploreScreen(),
                  'Scan' => const ScanScreen(),
                  // "More" opens a sheet and has no page of its own.
                  _ => const SizedBox.shrink(),
                }
              else
                SafeArea(
                  bottom: false,
                  child: WebScreen(key: _keyFor(i), page: _tabs[i].page!),
                ),
          ],
        ),
        floatingActionButton: _tabs[_index].label == 'More'
            ? null
            : FloatingActionButton(
                onPressed: () => AskSheet.open(
                  context,
                  about: 'The visitor is browsing Virasat, an Indian '
                      'heritage app. They may ask about monuments, cities, '
                      'crafts, festivals or food.',
                  opener: 'Namaste. Ask me about any monument, craft or '
                      'city in India — or what to see where you are.',
                  suggestions: const [
                    'What should I see in one day in Jaipur?',
                    'Why do the Taj Mahal’s minarets lean outward?',
                    'Which craft is Kutch known for?',
                  ],
                ),
                backgroundColor: VColor.ink,
                foregroundColor: Colors.white,
                elevation: 2,
                tooltip: 'Ask the guide',
                child: const Icon(Icons.auto_awesome_rounded, size: 21),
              ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: VColor.hairline, width: 1)),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) {
              if (_tabs[i].label == 'More') return _openMore();
              if (i != _index) _silenceAll();
              setState(() => _index = i);
            },
            destinations: [
              for (final t in _tabs)
                NavigationDestination(
                  icon: Icon(t.icon),
                  selectedIcon: Icon(t.activeIcon),
                  label: t.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A web page pushed as its own route, with a native header.
class WebPage extends StatelessWidget {
  const WebPage({super.key, required this.page, required this.title});
  final String page;
  final String title;

  @override
  Widget build(BuildContext context) {
    final key = GlobalKey<WebScreenState>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final went = await key.currentState?.goBackIfPossible() ?? false;
        if (!went) nav.pop();
      },
      child: Scaffold(
        backgroundColor: VColor.canvas,
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => key.currentState?.reload(),
            ),
            const SizedBox(width: VSpace.xs),
          ],
        ),
        body: WebScreen(key: key, page: page),
      ),
    );
  }
}
