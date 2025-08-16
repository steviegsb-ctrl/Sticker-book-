import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const StickerBookApp());

class StickerBookApp extends StatelessWidget {
  const StickerBookApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sticker Book',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const StickerHome(),
    );
  }
}

class Player {
  final String name;
  final String rating;
  final String position;
  const Player(this.name, this.rating, this.position);
}

class StickerHome extends StatefulWidget {
  const StickerHome({super.key});
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
    // load csv
    final raw = await rootBundle.loadString('assets/players.csv');
    final lines = const LineSplitter().convert(raw).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return;
    final header = lines.first.split(',').map((e) => e.trim()).toList();
    final iName = header.indexOf('name');
    final iRating = header.indexOf('rating');
    final iPos = header.indexOf('position');

    all = lines.skip(1).map((l) {
      final cols = l.split(',');
      String at(int i) => (i >= 0 && i < cols.length) ? cols[i].trim() : '';
      return Player(at(iName), at(iRating), at(iPos));
    }).where((p) => p.name.isNotEmpty).toList();

    // load owned
    final sp = await SharedPreferences.getInstance();
    owned = (sp.getStringList('owned') ?? []).toSet();

    setState(() {});
  }

  Future<void> _toggleOwned(String name) async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      if (owned.contains(name)) {
        owned.remove(name);
      } else {
        owned.add(name);
      }
    });
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

  void openPack() {
    if (all.isEmpty) return;
    final pool = [...all]..shuffle(rng);
    lastPack = pool.take(5).toList();
    setState(() {});
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Your Pack'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: lastPack.map((p) => ListTile(
            leading: Icon(owned.contains(p.name) ? Icons.check_circle : Icons.album_outlined),
            title: Text(p.name),
            subtitle: Text('Rating: ${p.rating} (${p.position})'),
            trailing: TextButton(
              child: Text(owned.contains(p.name) ? 'Owned' : 'Add'),
              onPressed: () => _toggleOwned(p.name),
            ),
            onLongPress: () => _openFutbin(p.name),
          )).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))
        ],
      ),
    );
  }

  Future<void> _openFutbin(String name) async {
    final uri = Uri.parse('https://www.futbin.com/search?search=${Uri.encodeComponent(name)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = all.length;
    final have = owned.length.clamp(0, total);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Sticker Book  •  $have/$total'),
          bottom: const TabBar(tabs: [Tab(text: 'Album'), Tab(text: 'Packs')]),
        ),
        body: TabBarView(
          children: [
            // Album tab
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

            // Packs tab
            Center(
              child: FilledButton.icon(
                onPressed: openPack,
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
