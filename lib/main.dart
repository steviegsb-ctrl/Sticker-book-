import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FUT Stickers',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E2C),
        cardColor: const Color(0xFF2A2A3D),
        primaryColor: Colors.tealAccent,
        colorScheme: ThemeData.dark().colorScheme.copyWith(
              primary: Colors.tealAccent,
              secondary: Colors.tealAccent,
            ),
      ),
      home: const HomeShell(),
    );
  }
}

/// ---- Models ----
class Player {
  final String name;
  final int rating;
  final String position;

  Player({required this.name, required this.rating, required this.position});

  factory Player.fromCsv(List<dynamic> row) {
    return Player(
      name: row[0],
      rating: int.tryParse(row[1].toString()) ?? 0,
      position: row[2],
    );
  }
}

/// ---- Shell with bottom nav ----
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const PlayerListScreen(),
      const AboutScreen(),
    ];

    return Scaffold(
      drawer: const AppDrawer(),
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Players'),
          BottomNavigationBarItem(icon: Icon(Icons.info_outline), label: 'About'),
        ],
      ),
    );
  }
}

/// ---- Drawer ----
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const ListTile(
              title: Text('FUT Stickers', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Demo app with CSV data'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Players'),
              onTap: () {
                Navigator.pop(context);
                // jump to tab 0 by popping until HomeShell and setting index not trivial here
                // easiest: just pop and rely on bottom bar already on Players
              },
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Open FUTBIN'),
              onTap: () async {
                final url = Uri.parse('https://www.futbin.com/players');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// ---- Players list with search + sorting ----
class PlayerListScreen extends StatefulWidget {
  const PlayerListScreen({super.key});

  @override
  State<PlayerListScreen> createState() => _PlayerListScreenState();
}

enum SortMode { rating, name }

class _PlayerListScreenState extends State<PlayerListScreen> {
  List<Player> players = [];
  List<Player> filteredPlayers = [];
  final TextEditingController searchController = TextEditingController();
  SortMode sortMode = SortMode.rating;

  @override
  void initState() {
    super.initState();
    loadCsv();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  Future<void> loadCsv() async {
    final csvData = await rootBundle.loadString('assets/players.csv');
    final lines = LineSplitter().convert(csvData);

    // Convert CSV lines to Player, skip header
    players = lines.skip(1).map((line) {
      final parts = line.split(',');
      // Guard against bad rows
      while (parts.length < 3) {
        parts.add('');
      }
      return Player.fromCsv(parts);
    }).toList();

    _applyFilters();
  }

  void _applyFilters() {
    String query = searchController.text.toLowerCase();
    List<Player> result = players
        .where((p) => p.name.toLowerCase().contains(query))
        .toList();

    // Sort
    if (sortMode == SortMode.rating) {
      result.sort((a, b) => b.rating.compareTo(a.rating));
    } else {
      result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    setState(() => filteredPlayers = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("FUT Stickers"),
        actions: [
          PopupMenuButton<SortMode>(
            icon: const Icon(Icons.sort),
            onSelected: (mode) {
              setState(() {
                sortMode = mode;
              });
              _applyFilters();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: SortMode.rating, child: Text('Sort by Rating')),
              PopupMenuItem(value: SortMode.name, child: Text('Sort by Name')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Search player...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFF2A2A3D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: filteredPlayers.isEmpty
                ? const Center(child: Text('No players found'))
                : ListView.builder(
                    itemCount: filteredPlayers.length,
                    itemBuilder: (context, index) {
                      final player = filteredPlayers[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueGrey,
                            child: Text(
                              player.name.isNotEmpty
                                  ? player.name.substring(0, 2).toUpperCase()
                                  : "?",
                            ),
                          ),
                          title: Text(player.name),
                          subtitle: Text("Rating: ${player.rating} · Position: ${player.position}"),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlayerDetailScreen(player: player),
                              ),
                            );
                          },
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

/// ---- Player detail ----
class PlayerDetailScreen extends StatelessWidget {
  final Player player;

  const PlayerDetailScreen({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    final futbinUrl =
        Uri.parse("https://www.futbin.com/players?q=${Uri.encodeComponent(player.name)}");

    return Scaffold(
      appBar: AppBar(title: Text(player.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              child: Text(
                player.name.substring(0, 2).toUpperCase(),
                style: const TextStyle(fontSize: 28),
              ),
            ),
            const SizedBox(height: 20),
            Text(player.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text("Rating: ${player.rating}"),
            Text("Position: ${player.position}"),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                if (await canLaunchUrl(futbinUrl)) {
                  await launchUrl(futbinUrl, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_browser),
              label: const Text("View on Futbin"),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---- About page ----
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'FUT Stickers\n\nDemo Flutter app that lists players from a CSV, '
            'supports search and sorting, and links to FUTBIN.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
