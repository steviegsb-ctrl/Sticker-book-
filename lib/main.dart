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
      title: 'Sticker Book x Futbin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const StickerHome(),
    );
  }
}

class StickerHome extends StatefulWidget {
  const StickerHome({super.key});

  @override
  State<StickerHome> createState() => _StickerHomeState();
}

class _StickerHomeState extends State<StickerHome> {
  List<List<dynamic>> players = [];

  @override
  void initState() {
    super.initState();
    _loadCSV();
  }

  Future<void> _loadCSV() async {
    final rawData = await rootBundle.loadString("assets/players.csv");
    List<List<dynamic>> listData =
        const CsvToListConverter().convert(rawData);

    setState(() {
      players = listData;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sticker Book'),
      ),
      body: players.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: players.length,
              itemBuilder: (context, index) {
                final row = players[index];
                return ListTile(
                  title: Text(row[0].toString()), // Player name
                  subtitle: Text("Rating: ${row[1]}"), // Player rating
                );
              },
            ),
    );
  }
}
