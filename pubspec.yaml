import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

void main() {
  runApp(const StickerBookApp());
}

class StickerBookApp extends StatelessWidget {
  const StickerBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FUT Stickers',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const PlayerListPage(),
    );
  }
}

class Player {
  final String name;
  final String rating;
  final String position;
  final String imageUrl;

  Player(this.name, this.rating, this.position, this.imageUrl);
}

class PlayerListPage extends StatefulWidget {
  const PlayerListPage({super.key});

  @override
  State<PlayerListPage> createState() => _PlayerListPageState();
}

class _PlayerListPageState extends State<PlayerListPage> {
  List<Player> players = [];

  @override
  void initState() {
    super.initState();
    _loadCSV();
  }

  Future<void> _loadCSV() async {
    final rawData = await rootBundle.loadString("assets/players.csv");
    List<List<dynamic>> listData = const CsvToListConverter().convert(rawData);

    // Skip header row
    setState(() {
      players = listData.skip(1).map((row) {
        return Player(
          row[0].toString(), // name
          row[1].toString(), // rating
          row[2].toString(), // position
          row[3].toString(), // image url
        );
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("FUT Stickers"),
        centerTitle: true,
      ),
      body: players.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  child: ListTile(
                    leading: player.imageUrl.isNotEmpty
                        ? Image.network(player.imageUrl, width: 50, errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.person);
                          })
                        : const Icon(Icons.person),
                    title: Text(player.name),
                    subtitle: Text("Rating: ${player.rating} • Position: ${player.position}"),
                  ),
                );
              },
            ),
    );
  }
}
