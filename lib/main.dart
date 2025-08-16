import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const _AppShell());

/// Root app with simple light/dark/system toggle persisted.
class _AppShell extends StatefulWidget {
  const _AppShell({super.key});
  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  ThemeMode _mode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString('themeMode') ?? 'system';
    setState(() {
      _mode = {'light': ThemeMode.light, 'dark': ThemeMode.dark}[s] ?? ThemeMode.system;
    });
  }

  Future<void> _setTheme(ThemeMode m) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('themeMode', switch (m) { ThemeMode.light => 'light', ThemeMode.dark => 'dark', _ => 'system' });
    setState(() => _mode = m);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sticker Book',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: StickerHome(mode: _mode, onChangeTheme: _setTheme),
    );
  }
}

/* ============================ DATA MODEL ============================ */

class Player {
  final String name;
  final String rating;
  final String position;
  const Player(this.name, this.rating, this.position);
}

/* ============================ HOME SCREEN =========================== */

class StickerHome extends StatefulWidget {
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChangeTheme;
  const StickerHome({super.key, required this.mode, required this.onChangeTheme});

  @override
  State<StickerHome> createState() => _StickerHomeState();
}

class _StickerHomeState extends State<StickerHome> {
  final rng = Random();

  List<Player> all = [];
  Set<String> owned = {};
  String q = '';
  List<Player> lastPack = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadPlayers();
    await _loadOwned();
    setState(() {});
  }

  Future<void> _loadPlayers() async {
    // expects assets/players.csv with header: name,rating,position
    final raw = await rootBundle.loadString('assets/players.csv');
    final lines = const LineSplitter()
        .convert(raw)
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return;

    final headers = lines.first.split(',').map((s) => s.trim().toLowerCase()).toList();
    int ix(String k) => headers.indexOf(k);

    final iName = ix('name'), iRating = ix('rating'), iPos = ix('position');

    all = lines.skip(1).map((l) {
      final c = l.split(',');
      String at(int i) => (i >= 0 && i < c.length) ? c[i].trim() : '';
      return Player(at(iName), at(iRating), at(iPos));
    }).where((p) => p.name.isNotEmpty).toList();
  }

  Future<void> _loadOwned() async {
    final sp = await SharedPreferences.getInstance();
    owned = (sp.getStringList('owned') ?? []).toSet();
  }

  Future<void> _saveOwned() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList('owned', owned.toList());
  }

  List<Player> get filtered {
    if (q.trim().isEmpty) return all;
    final s = q.toLowerCase();
    return all.where((p) =>
      p.name.toLowerCase().contains(s) ||
      p.position.toLowerCase().contains(s) ||
      p.rating.toLowerCase().contains(s)
    ).toList();
  }

  Future<void> _openFutbin(String name) async {
    final uri = Uri.parse('https://www.futbin.com/search?search=${Uri.encodeComponent(name)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  ThemeMode _nextTheme(ThemeMode m) => m == ThemeMode.system ? ThemeMode.light : (m == ThemeMode.light ? ThemeMode.dark : ThemeMode.system);
  Icon _themeIcon(ThemeMode m) => Icon(m == ThemeMode.system ? Icons.brightness_auto : m == ThemeMode.light ? Icons.light_mode : Icons.dark_mode);

  void _openPack({int size = 5}) {
    if (all.isEmpty) return;
    final pool = [...all]..shuffle(rng);
    lastPack = pool.take(size).toList();

    // Auto-add all pulled players to collection
    for (final p in lastPack) {
      owned.add(p.name);
    }
    _saveOwned();
    setState(() {});

    // Full-screen reveal
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      pageBuilder: (_, __, ___) => PackRevealScreen(pack: lastPack, onFutbin: _openFutbin),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final total = all.length;
    final have = owned.length.clamp(0, total);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Sticker Book  •  $have/$total'),
          actions: [
            IconButton(
              tooltip: 'Theme',
              icon: _themeIcon(widget.mode),
              onPressed: () => widget.onChangeTheme(_nextTheme(widget.mode)),
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'List'),
            Tab(text: 'Book'),
            Tab(text: 'Packs'),
          ]),
        ),
        body: TabBarView(children: [
          _listTab(),
          _bookTab(),
          _packsTab(),
        ]),
      ),
    );
  }

  /* ------------------------------ TABS ------------------------------ */

  Widget _listTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search name / rating / position',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onChanged: (v) => setState(() => q = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final p = filtered[i];
              final have = owned.contains(p.name);
              return ListTile(
                leading: Icon(have ? Icons.check_circle : Icons.circle_outlined,
                    color: have ? Colors.teal : null),
                title: Text(p.name),
                subtitle: Text('Rating: ${p.rating} (${p.position})'),
                onLongPress: () => _openFutbin(p.name),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _bookTab() {
    return LayoutBuilder(
      builder: (ctx, c) {
        final cols = (c.maxWidth ~/ 120).clamp(2, 4);
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: all.length,
          itemBuilder: (_, i) {
            final p = all[i];
            final have = owned.contains(p.name);
            return GestureDetector(
              onLongPress: () => _openFutbin(p.name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: have ? Colors.teal : Theme.of(context).colorScheme.outline,
                    width: have ? 3 : 1.2,
                  ),
                  color: have
                      ? Colors.teal.withOpacity(0.15)
                      : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.30),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          p.position,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: have ? Colors.teal : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    Text(p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('⭐ ${p.rating}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _packsTab() {
    return Center(
      child: FilledButton.icon(
        onPressed: () => _openPack(size: 5),
        icon: const Icon(Icons.card_giftcard),
        label: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Open 5-Sticker Pack'),
        ),
      ),
    );
  }
}

/* ======================= FULL-SCREEN PACK REVEAL ======================= */

class PackRevealScreen extends StatefulWidget {
  final List<Player> pack;
  final Future<void> Function(String) onFutbin;
  const PackRevealScreen({super.key, required this.pack, required this.onFutbin});

  @override
  State<PackRevealScreen> createState() => _PackRevealScreenState();
}

class _PackRevealScreenState extends State<PackRevealScreen> with SingleTickerProviderStateMixin {
  late final AnimationController ctrl;
  late final List<_Particle> parts;

  @override
  void initState() {
    super.initState();
    ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();
    final r = Random();
    parts = List.generate(100, (_) => _Particle.random(r));
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.80),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: ctrl,
              builder: (_, __) => CustomPaint(painter: _BurstPainter(parts, ctrl.value)),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Your Pack',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 12),
                  for (int i = 0; i < widget.pack.length; i++)
                    _Stagger(
                      delay: 150 * i,
                      child: Card(
                        child: ListTile(
                          title: Text(widget.pack[i].name),
                          subtitle: Text('Rating: ${widget.pack[i].rating} (${widget.pack[i].position})'),
                          onLongPress: () => widget.onFutbin(widget.pack[i].name),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Continue'),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ===================== ANIMATION UTILITIES ===================== */

class _Stagger extends StatefulWidget {
  final int delay; // ms
  final Widget child;
  const _Stagger({required this.delay, required this.child});
  @override
  State<_Stagger> createState() => _StaggerState();
}
class _StaggerState extends State<_Stagger> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 350));
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) c.forward(); });
  }
  @override
  void dispose() { c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: c, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: c, child: widget.child),
    );
  }
}

class _Particle {
  final double angle, dist, size;
  final Color color;
  _Particle(this.angle, this.dist, this.size, this.color);
  factory _Particle.random(Random r) {
    final hues = [Colors.teal, Colors.orange, Colors.purple, Colors.blue, Colors.pink, Colors.green];
    return _Particle(
      r.nextDouble() * pi * 2,
      60 + r.nextDouble() * 160,
      4 + r.nextDouble() * 8,
      hues[r.nextInt(hues.length)].withOpacity(0.85),
    );
  }
}
class _BurstPainter extends CustomPainter {
  final List<_Particle> ps;
  final double t; // 0..1
  _BurstPainter(this.ps, this.t);
  @override
  void paint(Canvas c, Size s) {
    final center = Offset(s.width/2, s.height/2);
    for (final p in ps) {
      final d = p.dist * Curves.easeOut.transform(t);
      final pos = center + Offset(cos(p.angle) * d, sin(p.angle) * d);
      final paint = Paint()..color = p.color.withOpacity((1 - t).clamp(0, 1));
      c.drawCircle(pos, p.size, paint);
    }
  }
  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.t != t || old.ps != ps;
}
