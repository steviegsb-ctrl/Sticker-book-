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
        scaffoldBackgroundColor: const Color(0xFF12121a),
        cardColor: const Color(0xFF1e2130),
        useMaterial3: true,
        colorScheme: ThemeData.dark().colorScheme.copyWith(
              primary: Colors.tealAccent,
              secondary: Colors.tealAccent,
            ),
      ),
      home: const HomeShell(),
    );
  }
}

/* ----------------------------- DATA MODELS ----------------------------- */

class Player {
  final String name;
  final int rating;
  final String position;

  const Player({
    required this.name,
    required this.rating,
    required this.position,
  });

  factory Player.fromCsv(List<String> row) {
    String get(int i) => (i < row.length ? row[i] : '').trim();
    return Player(
      name: get(0),
      rating: int.tryParse(get(1)) ?? 0,
      position: get(2),
    );
  }

  String get avatarUrl {
    final q = Uri.encodeComponent(name);
    return 'https://ui-avatars.com/api/?name=$q&size=256&background=2D3A4A&color=fff&rounded=true';
  }

  String get futbinUrl {
    final q = Uri.encodeComponent(name);
    // Futbin search is reliable without scraping:
    return 'https://www.futbin.com/players?page=1&search=$q';
  }
}

/* ----------------------------- APP STATE ------------------------------ */

class AppRepo {
  AppRepo._();

  static final AppRepo I = AppRepo._();

  List<Player> allPlayers = [];
  Set<String> owned = {};

  Future<void> load() async {
    // Load CSV (expects header: name,rating,position)
    final raw = await rootBundle.loadString('assets/players.csv');
    final lines = const LineSplitter().convert(raw);
    final List<Player> list = [];
    for (int i = 1; i < lines.length; i++) {
      final parts = lines[i].split(',').map((e) => e.trim()).toList();
      if (parts.isEmpty || parts[0].isEmpty) continue;
      list.add(Player.fromCsv(parts));
    }
    list.sort((a, b) {
      final r = b.rating.compareTo(a.rating);
      return r != 0 ? r : a.name.compareTo(b.name);
    });
    allPlayers = list;

    // Load owned
    final prefs = await SharedPreferences.getInstance();
    owned = (prefs.getStringList('owned') ?? []).toSet();
  }

  Future<void> addOwned(Iterable<String> names) async {
    owned.addAll(names);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('owned', owned.toList()..sort());
  }

  bool isOwned(String name) => owned.contains(name);
}

/* --------------------------- MAIN NAV SHELL --------------------------- */

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    AppRepo.I.load().then((_) {
      setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = <Widget>[
      const PlayersPage(),
      const StickerBookPage(),
      const PacksPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('FUT Stickers'),
        actions: [
          if (_index == 0) _SortMenu(onChange: (_) => setState(() {})),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person_search), label: 'Players'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'Sticker Book'),
          BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: 'Packs'),
        ],
      ),
      drawer: const _AppDrawer(),
    );
  }
}

/* ------------------------------- DRAWER ------------------------------- */

class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const ListTile(
              title: Text('FUT Stickers', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Sticker book + packs + Futbin links'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Open FUTBIN'),
              onTap: () async {
                final u = Uri.parse('https://www.futbin.com/players');
                if (await canLaunchUrl(u)) {
                  await launchUrl(u, mode: LaunchMode.externalApplication);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: const Text('Clear Sticker Book (reset)'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Reset collection?'),
                    content: const Text('This will remove all collected players.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
                    ],
                  ),
                );
                if (ok == true) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('owned');
                  AppRepo.I.owned.clear();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sticker book cleared')));
                    Navigator.pop(context); // close drawer
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------ PLAYERS ------------------------------- */

enum SortMode { ratingDesc, nameAsc }

class _SortMenu extends StatefulWidget {
  final void Function(SortMode) onChange;
  const _SortMenu({required this.onChange});

  @override
  State<_SortMenu> createState() => _SortMenuState();
}

class _SortMenuState extends State<_SortMenu> {
  SortMode mode = SortMode.ratingDesc;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SortMode>(
      initialValue: mode,
      onSelected: (m) {
        setState(() => mode = m);
        widget.onChange(m);
      },
      itemBuilder: (ctx) => const [
        PopupMenuItem(value: SortMode.ratingDesc, child: Text('Sort by Rating')),
        PopupMenuItem(value: SortMode.nameAsc, child: Text('Sort by Name')),
      ],
      icon: const Icon(Icons.sort),
    );
  }
}

class PlayersPage extends StatefulWidget {
  const PlayersPage({super.key});
  @override
  State<PlayersPage> createState() => _PlayersPageState();
}

class _PlayersPageState extends State<PlayersPage> {
  final _search = TextEditingController();
  SortMode _mode = SortMode.ratingDesc;

  List<Player> _apply(List<Player> src) {
    final q = _search.text.toLowerCase();
    var out = q.isEmpty
        ? List<Player>.from(src)
        : src.where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.position.toLowerCase().contains(q) ||
            p.rating.toString() == q).toList();

    if (_mode == SortMode.ratingDesc) {
      out.sort((a, b) => b.rating.compareTo(a.rating));
    } else {
      out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final players = _apply(AppRepo.I.allPlayers);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
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
            itemCount: players.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final p = players[i];
              final owned = AppRepo.I.isOwned(p.name);
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundImage: NetworkImage(p.avatarUrl),
                    onBackgroundImageError: (_, __) {},
                  ),
                  title: Text(p.name),
                  subtitle: Text('Rating: ${p.rating} • ${p.position}${owned ? " • ✅ Owned" : ""}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerDetail(player: p))),
                  onLongPress: () async {
                    await AppRepo.I.addOwned([p.name]);
                    if (context.mounted) {
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${p.name} to sticker book')));
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

  Future<void> _openFutbin() async {
    final uri = Uri.parse(player.futbinUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owned = AppRepo.I.isOwned(player.name);
    return Scaffold(
      appBar: AppBar(title: Text(player.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: NetworkImage(player.avatarUrl),
              onBackgroundImageError: (_, __) {},
            ),
            const SizedBox(height: 16),
            Text('Rating: ${player.rating}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('Position: ${player.position}', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(owned ? Icons.check : Icons.add),
                    label: Text(owned ? 'In Sticker Book' : 'Add to Sticker Book'),
                    onPressed: owned
                        ? null
                        : () async {
                            await AppRepo.I.addOwned([player.name]);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Added ${player.name} to sticker book')));
                              Navigator.pop(context);
                            }
                          },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View on Futbin'),
                    onPressed: _openFutbin,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------- STICKER BOOK ---------------------------- */

class StickerBookPage extends StatefulWidget {
  const StickerBookPage({super.key});
  @override
  State<StickerBookPage> createState() => _StickerBookPageState();
}

class _StickerBookPageState extends State<StickerBookPage> {
  @override
  Widget build(BuildContext context) {
    final players = AppRepo.I.allPlayers;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, childAspectRatio: 0.72, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: players.length,
      itemBuilder: (ctx, i) {
        final p = players[i];
        final owned = AppRepo.I.isOwned(p.name);
        return InkWell(
          onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => PlayerDetail(player: p))),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
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
                  CircleAvatar(
                    radius: 36,
                    backgroundImage: NetworkImage(p.avatarUrl),
                    onBackgroundImageError: (_, __) {},
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
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

/* ------------------------------ PACKS -------------------------------- */

class PacksPage extends StatefulWidget {
  const PacksPage({super.key});
  @override
  State<PacksPage> createState() => _PacksPageState();
}

class _PacksPageState extends State<PacksPage> with SingleTickerProviderStateMixin {
  bool _opening = false;
  List<Player> _lastPull = [];
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  Future<void> _openPack() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _lastPull = [];
    });
    _controller.forward(from: 0);

    // Simulate full-screen pack flare
    await Future.delayed(const Duration(milliseconds: 1200));

    // Pick 5 random players (weighted slightly by rating)
    final rng = Random();
    final src = AppRepo.I.allPlayers;
    final List<Player> pool = [];
    for (final p in src) {
      final weight = (p.rating / 10).round().clamp(1, 10);
      for (int i = 0; i < weight; i++) {
        pool.add(p);
      }
    }
    final Set<Player> picks = {};
    while (picks.length < 5 && picks.length < src.length) {
      picks.add(pool[rng.nextInt(pool.length)]);
    }
    _lastPull = picks.toList();
    await AppRepo.I.addOwned(_lastPull.map((e) => e.name));

    if (mounted) {
      setState(() => _opening = false);
      await showDialog(
        context: context,
        builder: (_) => _PackResultDialog(players: _lastPull),
      );
      setState(() {}); // refresh sticker book badges in other tabs when back
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: _openPack,
                  icon: const Icon(Icons.card_giftcard),
                  label: const Text('Open Pack'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                ),
                const SizedBox(height: 12),
                const Text('Opens a 5-card pack and adds pulls to your Sticker Book'),
              ],
            ),
          ),
        ),
        // Full-screen opening animation overlay
        if (_opening)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              return IgnorePointer(
                ignoring: true,
                child: Container(
                  color: Colors.black.withOpacity(0.7 * (1 - t)),
                  child: Center(
                    child: Transform.scale(
                      scale: 0.8 + 0.4 * (1 - (t - 0.5).abs() * 2).clamp(0, 1),
                      child: Opacity(
                        opacity: 0.5 + 0.5 * (1 - (t - 0.5).abs() * 2).clamp(0, 1),
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
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(p.avatarUrl),
                  onBackgroundImageError: (_, __) {},
                ),
                title: Text(p.name),
                subtitle: Text('${p.position} • ${p.rating}'),
                trailing: const Text('ADDED'),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Nice!')),
      ],
    );
  }
}
