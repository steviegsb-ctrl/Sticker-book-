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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E2C),
        cardColor: const Color(0xFF2A2A3D),
      ),
      home: const PlayerListScreen(),
    );
  }
}

class Player {
  final String name;
  final int rating;
  final String position;

  Player({required this.name, required this.rating, required this.position});

  factory Player.fromCsv(List<dynamic> row) {
    return Player(
      name: row[0],
      rating: int.tryParse(row[1]) ?? 0,
      position: row[2],
    );
  }
}

class PlayerListScreen extends StatefulWidget {
  const PlayerListScreen({super.key});

  @override
  State<PlayerListScreen> createState() => _PlayerListScreenState();
}

class _PlayerListScreenState extends State<PlayerListScreen> {
  List<Player> players = [];
  List<Player> filteredPlayers = [];
  final TextEditingController searchController = TextEditingController();

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
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredPlayers = players.where((p) => p.name.toLowerCase().contains(query)).toList();
    });
  }

  Future<void> loadCsv() async {
    final csvData = await rootBundle.loadString('assets/players.csv');
    final lines = LineSplitter().convert(csvData);
    players = lines.skip(1).map((line) {
      final parts = line.split(',');
      return Player.fromCsv(parts);
    }).toList();
    setState(() {
      filteredPlayers = players;
    });
  }

  String _avatarUrl(String name) {
    // UI Avatars service – generates a face-like avatar with initials
    final encoded = Uri.encodeComponent(name);
    return 'https://ui-avatars.com/api/?name=$encoded&background=0D8ABC&color=fff&bold=true&size=128';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("FUT Stickers")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Search player...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredPlayers.length,
              itemBuilder: (context, index) {
                final player = filteredPlayers[index];
                final url = _avatarUrl(player.name);
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      backgroundImage: NetworkImage(url),
                      onBackgroundImageError: (_, __) {}, // fallback handled by child below
                      child: Text(
                        player.name.isNotEmpty
                            ? player.name.substring(0, 2).toUpperCase()
                            : "?",
                        style: const TextStyle(fontWeight: FontWeight.bold),
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

class PlayerDetailScreen extends StatelessWidget {
  final Player player;
  const PlayerDetailScreen({super.key, required this.player});

  Future<void> _openFutbin() async {
    final url = Uri.parse("https://www.futbin.com/players?q=${Uri.encodeComponent(player.name)}");
    // Launch in external browser
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final avatar = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(player.name)}&background=0D8ABC&color=fff&bold=true&size=256';
    return Scaffold(
      appBar: AppBar(title: Text(player.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(radius: 50, backgroundImage: NetworkImage(avatar)),
            const SizedBox(height: 20),
            Text(player.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text("Rating: ${player.rating}"),
            Text("Position: ${player.position}"),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openFutbin,
              icon: const Icon(Icons.open_in_browser),
              label: const Text("View on Futbin"),
            ),
          ],
        ),
      ),
    );
  }
}
