import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const StickerBookApp());
}

class StickerBookApp extends StatelessWidget {
  const StickerBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sticker Book x Futbin',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const StickerHome(),
    );
  }
}

class StickerHome extends StatefulWidget {
  const StickerHome({super.key});

  @override
  State<StickerHome> createState() => _StickerHomeState();
}

class _StickerHomeState extends State<StickerHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, String>> players = [];
  Set<String> owned = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPlayers();
    _loadOwned();
  }

  Future<void> _loadPlayers() async {
    final raw = await rootBundle.loadString('assets/players.csv');
    final lines = const LineSplitter().convert(raw);
    final headers = lines.first.split(',');
    final data = lines.skip(1).map((line) {
      final values = line.split(',');
      return Map<String, String>.fromIterables(headers, values);
    }).toList();

    setState(() {
      players = data;
    });
  }

  Future<void> _loadOwned() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      owned = prefs.getStringList('owned')?.toSet() ?? {};
    });
  }

  Future<void> _toggleOwned(String name) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (owned.contains(name)) {
        owned.remove(name);
      } else {
        owned.add(name);
      }
    });
    prefs.setStringList('owned', owned.toList());
  }

  Future<void> _openFutbin(String name) async {
    final url = Uri.parse('https://www.futbin.com/search?search=$name');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sticker Book"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Album"),
            Tab(text: "Packs"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Album tab
          ListView.builder(
            itemCount: players.length,
            itemBuilder: (context, index) {
              final p = players[index];
              final name = p['name'] ?? '';
              final rating = p['rating'] ?? '';
              final position = p['position'] ?? '';
              final isOwned = owned.contains(name);

              return ListTile(
                title: Text(name),
                subtitle: Text("Rating: $rating ($position)"),
                trailing: Icon(
                  isOwned ? Icons.check_circle : Icons.circle_outlined,
                  color: isOwned ? Colors.green : null,
                ),
                onTap: () => _toggleOwned(name),
                onLongPress: () => _openFutbin(name),
              );
            },
          ),

          // Packs tab
          Center(
            child: ElevatedButton(
              child: const Text("Open Pack"),
              onPressed: () {
                if (players.isEmpty) return;
                players.shuffle();
                final pack = players.take(5).toList();
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Your Pack"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: pack.map((p) {
                        return ListTile(
                          title: Text(p['name'] ?? ''),
                          subtitle:
                              Text("Rating: ${p['rating']} (${p['position']})"),
                        );
                      }).toList(),
                    ),
                    actions: [
                      TextButton(
                        child: const Text("Close"),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
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
