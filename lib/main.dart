import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const StickerBookApp());

class StickerBookApp extends StatelessWidget {
  const StickerBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sticker Book',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const StickerHome(),
    );
  }
}

class Player {
  final String name;
  final int rating;
  final String position;
  final String imageUrl;   // can be empty
  final String futbinUrl;  // can be empty

  const Player({
    required this.name,
    required this.rating,
    required this.position,
    required this.imageUrl,
    required this.futbinUrl,
  });

  static Player fromMap(Map<String, String> m) {
    String getS(String key) => (m[key] ?? '').trim();
    int getI(String key) {
      final s = getS(key);
      final n = int.tryParse(s);
      return n ?? 0;
    }

    return Player(
      name: getS('name'),
      rating: getI('rating'),
      position: getS('position'),
      imageUrl: getS('imageUrl'),
      futbinUrl: getS('futbinUrl'),
    );
  }
}

class StickerHome extends StatefulWidget {
  const StickerHome({super.key});

  @override
  State<StickerHome> createState() => _StickerHomeState();
}

class _StickerHomeState extends State<StickerHome> {
  late Future<List<Player>> _playersFut;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _playersFut = _loadPlayers();
  }

  Future<List<Player>> _loadPlayers() async {
    final raw = await rootBundle.loadString('assets/players.csv');

    // Parse CSV
    final rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(raw);

    if (rows.isEmpty) return [];

    // Read header -> column indexes by name (case-insensitive)
    final header = rows.first.map((e) => e.toString().trim()).toList();
    int idxOf(String key) {
      final i = header.indexWhere(
        (h) => h.toLowerCase() == key.toLowerCase(),
      );
      return i; // -1 means missing
    }

    final idxName = idxOf('name');
    final idxRating = idxOf('rating');
    final idxPos = idxOf('position');
    final idxImg = idxOf('imageUrl');
    final idxFut = idxOf('futbinUrl');

    List<Player> out = [];
    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];
      String getCell(int idx) =>
          (idx >= 0 && idx < row.length) ? row[idx].toString() : '';

      final map = <String, String>{
        'name': getCell(idxName),
        'rating': getCell(idxRating),
        'position': getCell(idxPos),
        'imageUrl': getCell(idxImg),
        'futbinUrl': getCell(idxFut),
      };

      // Skip empty lines
      if (map['name']!.isEmpty) continue;

      out.add(Player.fromMap(map));
    }

    // Sort by rating desc, then name
    out.sort((a, b) {
      final byRating = b.rating.compareTo(a.rating);
      return byRating != 0 ? byRating : a.name.compareTo(b.name);
    });

    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sticker Book'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search players…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Player>>(
              future: _playersFut,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text('Error: ${snap.error}'),
                  );
                }
                final players = snap.data ?? [];
                final q = _query.trim().toLowerCase();
                final filtered = q.isEmpty
                    ? players
                    : players.where((p) {
                        return p.name.toLowerCase().contains(q) ||
                            p.position.toLowerCase().contains(q) ||
                            p.rating.toString() == q;
                      }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No players found.'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    return ListTile(
                      leading: _Avatar(imageUrl: p.imageUrl, name: p.name),
                      title: Text(p.name),
                      subtitle: Text('Rating: ${p.rating}  •  ${p.position}'),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () async {
                        if (p.futbinUrl.isEmpty) return;
                        final uri = Uri.tryParse(p.futbinUrl);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not open link'),
                              ),
                            );
                          }
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String imageUrl;
  final String name;
  const _Avatar({required this.imageUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return CircleAvatar(
        child: Text(
          _initials(name),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    }
    return CircleAvatar(
      backgroundImage: NetworkImage(imageUrl),
      onBackgroundImageError: (_, __) {},
      child: const SizedBox.shrink(), // keeps layout if image fails
    );
  }

  String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    final init = (first + last).toUpperCase();
    return init.isEmpty ? '?' : init;
    }
}
