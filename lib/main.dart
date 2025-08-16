import 'package:flutter/material.dart';

void main() {
  runApp(const StickerBookApp());
}

class StickerBookApp extends StatelessWidget {
  const StickerBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sticker Book',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const StickerHomePage(),
    );
  }
}

class StickerHomePage extends StatelessWidget {
  const StickerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sticker Book'),
      ),
      body: const Center(
        child: Text('Welcome to your Sticker Book!'),
      ),
    );
  }
}
