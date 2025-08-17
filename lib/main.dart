import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FUT Stickers',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E2C),
        cardColor: const Color(0xFF2A2A3D),
        useMaterial3: true,
      ),
      home: const PlayerListScreen(),
    );
  }
}

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
    return 'https://www.futbin.com/players?page=1&search=$q';
  }
}

class PlayerListScreen extends StatefulWidget {
  const PlayerListScreen({super.key});

  @override
  State<PlayerListScreen> createState() => _PlayerListScreenState();
}

class _PlayerListScreenState extends State<PlayerListScreen> {
  List<Player> _players = [];
  List<Player> _filtered = [];
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCsv();
    _search.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _players
          : _players.where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.position.toLowerCase().contains(q) ||
              p.rating.toString() == q).toList();
    });
  }

  Future<void> _loadCsv() async {
    final raw = await rootBundle.loadString('assets/players.csv');
    final lines = LineSplitter.split(raw).toList();
    if (lines.isEmpty) return;

    // Skip header, split safely
    final List<Player> list = [];
    for (var i = 1; i < lines.length; i++) {
      final parts = lines[i].split(',');
      if (parts.isEmpty || parts[0].trim().isEmpty) continue;
      list.add(Player.fromCsv(parts.map((e) => e.trim()).toList()));
    }

    // Optional: sort by rating desc then name
    list.sort((a, b) {
      final r = b.rating.compareTo(a.rating);
      return r != 0 ? r : a.name.compareTo(b.name);
    });

    setState(() {
      _players = list;
      _filtered = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("FUT Stickers")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: "Search players…",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(child: Text("No players found"))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = _filtered[i];
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlayerDetailScreen(player: p),
                            ),
                          );
                        },
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 26,
                              backgroundImage: NetworkImage(p.avatarUrl),
                              onBackgroundImageError: (_, __) {},
                              child: const SizedBox.shrink(),
                            ),
                            title: Text(p.name),
                            subtitle: Text(
                                "Rating: ${p.rating}  •  Position: ${p.position}"),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class PlayerDetailScreen extends StatelessWidget {
  final Player player;
  const PlayerDetailScreen({super.key, required this.player});

  Future<void> _openFutbin() async {
    final uri = Uri.parse(player.futbinUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text('Rating: ${player.rating}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('Position: ${player.position}',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openFutbin,
                icon: const Icon(Icons.open_in_new),
                label: const Text('View on Futbin'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
