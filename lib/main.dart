import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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

  factory Player.fromCsv(List<String> row) {
    return Player(
      name: row[0],
      rating: int.tryParse(row[1]) ?? 0,
      position: row[2],
    );
  }
}

// Simple avatar URL service
String avatarUrl(String name) {
  final n = Uri.encodeComponent(name.trim());
  return 'https://ui-avatars.com/api/?name=$n&size=256&background=random';
}

/// --- FUTBIN LINKS ---

// Option 1: Simple search
Uri futbinUrlSimple(String name) {
  return Uri.https('www.futbin.com', '/players', {
    'page': '1',
    'search': name.trim(),
  });
}

// Option 2: Normalized search (better for accented names)
String normalize(String s) {
  final map = {
    'á': 'a','à': 'a','ä': 'a','â': 'a','ã': 'a',
    'é': 'e','è': 'e','ë': 'e','ê': 'e',
    'í': 'i','ì': 'i','ï': 'i','î': 'i',
    'ó': 'o','ò': 'o','ö': 'o','ô': 'o','õ': 'o',
    'ú': 'u','ù': 'u','ü': 'u','û': 'u',
    'ñ': 'n','ç': 'c','ß': 'ss','ø': 'o','å': 'a'
  };
  return s.split('').map((ch) => map[ch] ?? ch).join();
}

Uri futbinUrlNormalized(String name) {
  final q = normalize(name).trim();
  return Uri.https('www.futbin.com', '/players', {
    'page': '1',
    'search': q,
  });
}

// Single launcher function (swap method here)
Future<void> openFutbin(String name) async {
  // 👉 Choose which one you want active:
  final url = futbinUrlNormalized(name);
  // final url = futbinUrlSimple(name);

  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    throw Exception('Could not launch $url');
  }
}

class PlayerListScreen extends StatefulWidget {
  const PlayerListScreen({super.key});

  @override
  State<PlayerListScreen> createState() => _PlayerListScreenState();
}

class _PlayerListScreenState extends State<PlayerListScreen> {
  List<Player> players = [];
  List<Player> filtered = [];
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCsv();
    searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = searchController.text.toLowerCase();
    setState(() {
      filtered = players.where((p) => p.name.toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _loadCsv() async {
    final raw = await rootBundle.loadString('assets/players.csv');
    final lines = const LineSplitter().convert(raw);
    final list = <Player>[];
    for (final line in lines.skip(1)) {
      final parts = line.split(',');
      if (parts.length >= 3) {
        list.add(Player.fromCsv(parts));
      }
    }
    setState(() {
      players = list;
      filtered = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FUT Stickers')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search player…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final p = filtered[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: ClipOval(
                      child: Image.network(
                        avatarUrl(p.name),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => CircleAvatar(
                          radius: 24,
                          child: Text(
                            p.name.isNotEmpty
                                ? p.name.substring(0, 2).toUpperCase()
                                : '?',
                          ),
                        ),
                      ),
                    ),
                    title: Text(p.name),
                    subtitle: Text('Rating: ${p.rating} · Position: ${p.position}'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => openFutbin(p.name),
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
