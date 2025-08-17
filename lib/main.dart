import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FUT Stickers',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF12121A),
        cardColor: const Color(0xFF1E2030),
        useMaterial3: true,
        colorScheme: ThemeData.dark().colorScheme.copyWith(
              primary: const Color(0xFF6C9EFF),
              secondary: const Color(0xFFFFD166),
            ),
      ),
      home: const HomeTabs(),
    );
  }
}

/* ===================== Shared helpers (avatars + Futbin) ===================== */

String dicebearUrl(String name, {int size = 256}) {
  final seed = Uri.encodeComponent(name.trim());
  return 'https://api.dicebear.com/7.x/initials/png?seed=$seed&radius=50&backgroundType=gradientLinear&size=$size';
}

Widget networkAvatar(String name, {double size = 48}) {
  final primary = dicebearUrl(name, size: size.toInt());
  final fallback = 'https://picsum.photos/seed/${Uri.encodeComponent(name)}/${size.toInt()}';
  return ClipOval(
    child: Image.network(
      primary,
      width: size, height: size, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Image.network(
        fallback,
        width: size, height: size, fit: BoxFit.cover,
        errorBuilder: (_, __2, ___2) => CircleAvatar(
          radius: size / 2,
          child: Text(name.isNotEmpty ? name.substring(0, 2).toUpperCase() : '?'),
        ),
      ),
    ),
  );
}

String normalize(String s) {
  const map = {
    'á':'a','à':'a','ä':'a','â':'a','ã':'a',
    'é':'e','è':'e','ë':'e','ê':'e',
    'í':'i','ì':'i','ï':'i','î':'i',
    'ó':'o','ò':'o','ö':'o','ô':'o','õ':'o',
    'ú':'u','ù':'u','ü':'u','û':'u',
    'ñ':'n','ç':'c','ß':'ss','ø':'o','å':'a'
  };
  return s.split('').map((ch) => map[ch] ?? ch).join();
}

Uri futbinUrlSimple(String name) =>
    Uri.https('www.futbin.com', '/players', {'page': '1', 'search': name.trim()});

Uri futbinUrlNormalized(String name) =>
    Uri.https('www.futbin.com', '/players', {'page': '1', 'search': normalize(name).trim()});

Future<void> openFutbin(String name) async {
  // swap simple/normalized here if needed
  final url = futbinUrlNormalized(name);
  await launchUrl(url, mode: LaunchMode.externalApplication);
}

/* ============================== Data model ============================== */

class Player {
  final String name;
  final int rating;
  final String position;
  const Player({required this.name, required this.rating, required this.position});

  factory Player.fromCsv(List<String> row) => Player(
        name: row[0],
        rating: int.tryParse(row[1]) ?? 0,
        position: row[2],
      );
}

Future<List<Player>> loadPlayers() async {
  final csv = await rootBundle.loadString('assets/players.csv');
  final lines = const LineSplitter().convert(csv);
  final list = <Player>[];
  for (final line in lines.skip(1)) {
    if (line.trim().isEmpty) continue;
    final parts = line.split(',');
    if (parts.length < 3) continue;
    list.add(Player.fromCsv(parts));
  }
  // sort: rating desc, then name
  list.sort((a, b) {
    final r = b.rating.compareTo(a.rating);
    return r != 0 ? r : a.name.compareTo(b.name);
  });
  return list;
}

/* ============================== Persistence ============================= */

class StickerStore {
  static const _key = 'owned_players';

  static Future<Set<String>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const <String>[]).toSet();
  }

  static Future<void> addAll(Iterable<String> names) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(_key) ?? const <String>[]).toSet();
    set.addAll(names);
    await prefs.setStringList(_key, set.toList()..sort());
  }

  static Future<void> add(String name) => addAll([name]);

  static Future<void> remove(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(_key) ?? const <String>[]).toSet();
    set.remove(name);
    await prefs.setStringList(_key, set.toList()..sort());
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/* ============================= Home + Tabs ============================== */

class HomeTabs extends StatefulWidget {
  const HomeTabs({super.key});
  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [PlayersPage(), PacksPage(), StickerBookPage()];
    return Scaffold(
      appBar: AppBar(
        title: const Text('FUT Stickers'),
        actions: [
          IconButton(
            tooltip: 'Open Futbin',
            onPressed: () => launchUrl(
              Uri.parse('https://www.futbin.com/players'),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.public),
          ),
          IconButton(
            tooltip: 'Reset collection',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Clear sticker book?'),
                  content: const Text('This will remove all collected players.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
                  ],
                ),
              );
              if (ok == true) {
                await StickerStore.clear();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sticker book cleared')),
                  );
                  setState(() {}); // refresh pages
                }
              }
            },
            icon: const Icon(Icons.delete_sweep),
          ),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt), label: 'Players'),
          NavigationDestination(icon: Icon(Icons.card_giftcard_outlined), selectedIcon: Icon(Icons.card_giftcard), label: 'Packs'),
          NavigationDestination(icon: Icon(Icons.book_outlined), selectedIcon: Icon(Icons.book), label: 'Sticker Book'),
        ],
      ),
    );
  }
}

/* =============================== Players ================================ */

class PlayersPage extends StatefulWidget {
  const PlayersPage({super.key});
  @override
  State<PlayersPage> createState() => _PlayersPageState();
}

class _PlayersPageState extends State<PlayersPage> {
  List<Player> _players = [];
  List<Player> _filtered = [];
  Set<String> _owned = {};
  final _q = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.wait([loadPlayers(), StickerStore.getAll()]).then((r) {
      _players = r[0] as List<Player>;
      _filtered = _players;
      _owned = r[1] as Set<String>;
      setState(() => _loading = false);
    });
    _q.addListener(_applyFilter);
  }

  void _applyFilter() {
    final term = _q.text.toLowerCase();
    setState(() {
      _filtered = term.isEmpty
          ? _players
          : _players.where((p) =>
              p.name.toLowerCase().contains(term) ||
              p.position.toLowerCase().contains(term) ||
              p.rating.toString() == term).toList();
    });
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: _q,
            decoration: InputDecoration(
              hintText: 'Search players…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final p = _filtered[i];
              final owned = _owned.contains(p.name);
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: networkAvatar(p.name, size: 48),
                  title: Text(p.name),
                  subtitle: Text('Rating: ${p.rating} • ${p.position}${owned ? " • ✅ Owned" : ""}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PlayerDetail(player: p)),
                  ).then((_) async {
                    _owned = await StickerStore.getAll();
                    setState(() {});
                  }),
                  onLongPress: () async {
                    await StickerStore.add(p.name);
                    _owned = await StickerStore.getAll();
                    if (context.mounted) setState(() {});
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('Added ${p.name} to Sticker Book')));
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class PlayerDetail extends StatelessWidget {
  final Player player;
  const PlayerDetail({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    final ownedFuture = StickerStore.getAll();
    return Scaffold(
      appBar: AppBar(title: Text(player.name)),
      body: FutureBuilder<Set<String>>(
        future: ownedFuture,
        builder: (context, snap) {
          final owned = snap.data?.contains(player.name) ?? false;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                networkAvatar(player.name, size: 96),
                const SizedBox(height: 16),
                Text(player.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Rating: ${player.rating} • ${player.position}'),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(owned ? Icons.check : Icons.bookmark_add_outlined),
                        label: Text(owned ? 'In Sticker Book' : 'Add to Sticker Book'),
                        onPressed: owned
                            ? null
                            : () async {
                                await StickerStore.add(player.name);
                                if (context.mounted) Navigator.pop(context);
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('View on Futbin'),
                        onPressed: () => openFutbin(player.name),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/* ================================ Packs ================================ */

class PacksPage extends StatefulWidget {
  const PacksPage({super.key});
  @override
  State<PacksPage> createState() => _PacksPageState();
}

class _PacksPageState extends State<PacksPage> with SingleTickerProviderStateMixin {
  List<Player> _all = [];
  List<Player> _lastPull = [];
  bool _loading = true;
  bool _opening = false;
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    loadPlayers().then((p) => setState(() {
          _all = p;
          _loading = false;
        }));
  }

  Future<void> _openPack() async {
    if (_opening || _all.isEmpty) return;
    setState(() => _opening = true);
    _controller.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 1100));

    // Weighted random by rating (higher rating slightly more likely)
    final rng = Random();
    final bag = <Player>[];
    for (final p in _all) {
      final w = (p.rating / 10).round().clamp(1, 10);
      for (int i = 0; i < w; i++) bag.add(p);
    }
    final picks = <Player>{};
    while (picks.length < 5 && picks.length < _all.length) {
      picks.add(bag[rng.nextInt(bag.length)]);
    }
    _lastPull = picks.toList();

    await StickerStore.addAll(_lastPull.map((e) => e.name));

    if (!mounted) return;
    setState(() => _opening = false);
    await showDialog(
      context: context,
      builder: (_) => _PackResultDialog(players: _lastPull),
    );
    setState(() {}); // refresh page
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: _openPack,
                icon: const Icon(Icons.card_giftcard),
                label: const Text('Open Pack (5)'),
              ),
              const SizedBox(height: 10),
              const Text('Adds pulled players to your Sticker Book'),
              const SizedBox(height: 20),
              if (_lastPull.isNotEmpty) const Text('Last pack:'),
              if (_lastPull.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 10, runSpacing: 10,
                    children: _lastPull
                        .map((p) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                networkAvatar(p.name, size: 56),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: 88,
                                  child: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                                ),
                              ],
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
        if (_opening)
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              final t = _controller.value;
              final pulse = (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
              return IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(0.65 * (1 - t)),
                  child: Center(
                    child: Transform.scale(
                      scale: 0.9 + 0.3 * pulse,
                      child: Opacity(
                        opacity: 0.5 + 0.5 * pulse,
                        child: const Icon(Icons.auto_awesome, size: 160),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _PackResultDialog extends StatelessWidget {
  final List<Player> players;
  const _PackResultDialog({required this.players});
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pack Results'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in players)
              ListTile(
                leading: networkAvatar(p.name, size: 40),
                title: Text(p.name),
                subtitle: Text('${p.position} • ${p.rating}'),
                trailing: const Text('ADDED'),
              ),
          ],
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Nice!'))],
    );
  }
}

/* ============================ Sticker Book ============================= */

class StickerBookPage extends StatefulWidget {
  const StickerBookPage({super.key});
  @override
  State<StickerBookPage> createState() => _StickerBookPageState();
}

class _StickerBookStateData {
  late List<Player> all;
  late Set<String> owned;
}

class _StickerBookPageState extends State<StickerBookPage> {
  final _data = _StickerBookStateData();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.wait([loadPlayers(), StickerStore.getAll()]).then((r) {
      _data.all = r[0] as List<Player>;
      _data.owned = r[1] as Set<String>;
      setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final players = _data.all;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, childAspectRatio: 0.72, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: players.length,
      itemBuilder: (ctx, i) {
        final p = players[i];
        final owned = _data.owned.contains(p.name);
        return InkWell(
          onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => PlayerDetail(player: p))).then((_) async {
            _data.owned = await StickerStore.getAll();
            if (mounted) setState(() {});
          }),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: owned ? 1.0 : 0.35,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: owned ? Colors.tealAccent : Colors.white10, width: 1),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  networkAvatar(p.name, size: 56),
                  const SizedBox(height: 8),
                  Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text('${p.position} • ${p.rating}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
