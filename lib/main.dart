import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const _AppShell());

/// Root app that owns ThemeMode and persists it.
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
      home: StickerHome(
        mode: _mode,
        onChangeTheme: (next) => _setTheme(next),
      ),
    );
  }
}

/// === DATA MODEL ===
class Player {
  final String name;
  final String rating;
  final String position;
  const Player(this.name, this.rating, this.position);
}

/// === HOME WITH 3 TABS ===
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
  String query = '';
  List<Player> lastPack = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // CSV: name,rating,position
    final raw = await rootBundle.loadString('assets/players.csv');
    final lines = const LineSplitter().convert(raw).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return;
    final header = lines.first.split(',').map((e) => e.trim()).toList();
    final iName = header.indexOf('name');
    final iRating = header.indexOf('rating');
    final iPos = header.indexOf('position');

    all = lines.skip(1).map((l) {
      final c = l.split(',');
      String at(int i) => (i >= 0 && i < c.length) ? c[i].trim() : '';
      return Player(at(iName), at(iRating), at(iPos));
    }).where((p) => p.name.isNotEmpty).toList();

    final sp = await SharedPreferences.getInstance();
    owned = (sp.getStringList('owned') ?? []).toSet();

    setState(() {});
  }

  Future<void> _toggleOwned(String name) async {
    final sp = await SharedPreferences.getInstance();
    setState(() => owned.contains(name) ? owned.remove(name) : owned.add(name));
    await sp.setStringList('owned', owned.toList());
  }

  List<Player> get filtered {
    if (query.trim().isEmpty) return all;
    final s = query.toLowerCase();
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

  void _openPack() {
    if (all.isEmpty) return;
    final pool = [...all]..shuffle(rng);
    lastPack = pool.take(5).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PackRevealDialog(
        pack: lastPack,
        isOwned: (n) => owned.contains(n),
        onToggle: _toggleOwned,
        onOpenFutbin: _openFutbin,
      ),
    );
  }

  ThemeMode _nextTheme(ThemeMode m) {
    if (m == ThemeMode.system) return ThemeMode.light;
    if (m == ThemeMode.light) return ThemeMode.dark;
    return ThemeMode.system;
  }

  Icon _themeIcon(ThemeMode m) {
    return Icon(
      m == ThemeMode.system ? Icons.brightness_auto :
      m == ThemeMode.light  ? Icons.light_mode :
                              Icons.dark_mode
    );
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
          bottom: const TabBar(
            tabs: [
              Tab(text: 'List'),
              Tab(text: 'Book'),
              Tab(text: 'Packs'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            /// --- LIST TAB ---
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search name / rating / position',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onChanged: (v) => setState(() => query = v),
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
                        trailing: IconButton(
                          icon: Icon(have ? Icons.remove_circle_outline : Icons.add_circle_outline),
                          onPressed: () => _toggleOwned(p.name),
                        ),
                        onLongPress: () => _openFutbin(p.name),
                      );
                    },
                  ),
                ),
              ],
            ),

            /// --- BOOK (GRID) TAB ---
            LayoutBuilder(
              builder: (ctx, c) {
                final cols = (c.maxWidth ~/ 120).clamp(2, 4); // 2–4 columns
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
                      onTap: () => _toggleOwned(p.name),
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
                          gradient: have
                              ? LinearGradient(
                                  colors: [
                                    Colors.teal.withOpacity(0.18),
                                    Colors.teal.withOpacity(0.04)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: have ? null : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
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
                                    color: have
                                        ? Colors.teal
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              p.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text('⭐ ${p.rating}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                )),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(
                                  have ? Icons.check_circle : Icons.add_circle_outline,
                                  color: have ? Colors.teal : null,
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            /// --- PACKS TAB ---
            Center(
              child: FilledButton.icon(
                onPressed: _openPack,
                icon: const Icon(Icons.card_giftcard),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Open 5-Sticker Pack'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// === PACK REVEAL DIALOG with COLORFUL ANIMATION ===
class PackRevealDialog extends StatefulWidget {
  final List<Player> pack;
  final bool Function(String) isOwned;
  final Future<void> Function(String) onToggle;
  final Future<void> Function(String) onOpenFutbin;

  const PackRevealDialog({
    super.key,
    required this.pack,
    required this.isOwned,
    required this.onToggle,
    required this.onOpenFutbin,
  });

  @override
  State<PackRevealDialog> createState() => _PackRevealDialogState();
}

class _PackRevealDialogState extends State<PackRevealDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController ctrl;
  late final List<_Particle> particles;

  @override
  void initState() {
    super.initState();
    ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();
    final rng = Random();
    particles = List.generate(80, (_) => _Particle.random(rng));
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          children: [
            // Color burst background
            Positioned.fill(
              child: AnimatedBuilder(
                animation: ctrl,
                builder: (_, __) => CustomPaint(
                  painter: _BurstPainter(particles, ctrl.value),
                ),
              ),
            ),
            // Content
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                const Text('Your Pack', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (int i = 0; i < widget.pack.length; i++)
                  _Stagger(
                    delay: 120 * i,
                    child: Card(
                      elevation: 0,
                      child: ListTile(
                        leading: Icon(
                          widget.isOwned(widget.pack[i].name)
                              ? Icons.check_circle
                              : Icons.album_outlined,
                        ),
                        title: Text(widget.pack[i].name),
                        subtitle: Text('Rating: ${widget.pack[i].rating} (${widget.pack[i].position})'),
                        trailing: TextButton(
                          child: Text(widget.isOwned(widget.pack[i].name) ? 'Owned' : 'Add'),
                          onPressed: () => widget.onToggle(widget.pack[i].name),
                        ),
                        onLongPress: () => widget.onOpenFutbin(widget.pack[i].name),
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small helper to stagger child appearance
class _Stagger extends StatefulWidget {
  final int delay; // ms
  final Widget child;
  const _Stagger({required this.delay, required this.child});
  @override
  State<_Stagger> createState() => _StaggerState();
}
class _StaggerState extends State<_Stagger> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 300));
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () => mounted ? c.forward() : null);
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

/// Confetti-like particles for pack reveal
class _Particle {
  final double angle; // radians
  final double distance; // final radius
  final double size;
  final Color color;
  _Particle(this.angle, this.distance, this.size, this.color);
  factory _Particle.random(Random r) {
    final hues = [Colors.teal, Colors.orange, Colors.purple, Colors.blue, Colors.pink, Colors.green];
    return _Particle(
      r.nextDouble() * pi * 2,
      60 + r.nextDouble() * 140,
      4 + r.nextDouble() * 8,
      hues[r.nextInt(hues.length)].withOpacity(0.85),
    );
  }
}
class _BurstPainter extends CustomPainter {
  final List<_Particle> parts;
  final double t; // 0..1
  _BurstPainter(this.parts, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width/2, 80); // burst origin near top
    for (final p in parts) {
      final d = p.distance * Curves.easeOut.transform(t);
      final pos = c + Offset(cos(p.angle) * d, sin(p.angle) * d);
      final paint = Paint()..color = p.color.withOpacity((1 - t).clamp(0, 1));
      canvas.drawCircle(pos, p.size, paint);
    }
  }
  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t || old.parts != parts;
}
