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
      title: 'Sticker Book x Futbin',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal), useMaterial3: true),
      home: const StickerHome(),
    );
  }
}

class Player {
  final String id, name, pos, club, nation, futbinUrl, artUrl;
  Player({required this.id, required this.name, required this.pos, required this.club, required this.nation, required this.futbinUrl, required this.artUrl});
  static Player fromCsv(List<String> h, List<String> r) {
    String g(String k){ final i=h.indexOf(k); return (i>=0 && i<r.length)? r[i].trim():''; }
    final name=g('name'); final club=g('club'); final pos=g('position');
    return Player(
      id: '${name.toLowerCase()}|${club.toLowerCase()}|${pos.toLowerCase()}',
      name: name, pos: pos, club: club, nation: g('nation'),
      futbinUrl: g('futbinUrl'), artUrl: g('stickerArtUrl'),
    );
  }
}

class StickerHome extends StatefulWidget { const StickerHome({super.key}); @override State<StickerHome> createState()=>_StickerHomeState(); }
class _StickerHomeState extends State<StickerHome> {
  List<Player> players=[]; Set<String> collected={}; String q=''; bool loading=true; final rng=Random(); List<Player> lastPack=[];
  @override void initState(){ super.initState(); _init(); }
  Future<void> _init() async { await _loadPlayers(); await _loadCollected(); setState(()=>loading=false); }

  Future<void> _loadPlayers() async {
    final csv = await rootBundle.loadString('assets/players.csv');
    final lines = csv.split('\n').where((l)=>l.trim().isNotEmpty).toList();
    if(lines.isEmpty) return;
    final headers = lines.first.split(',').map((s)=>s.trim()).toList();
    players = lines.skip(1).map((l)=>l.split(',')).map((r)=>Player.fromCsv(headers, r)).where((p)=>p.name.isNotEmpty).toList();
  }

  Future<void> _loadCollected() async { final p=await SharedPreferences.getInstance(); collected=p.getStringList('collectionIds')?.toSet()??{}; }
  Future<void> _toggle(String id) async { final p=await SharedPreferences.getInstance(); setState(()=> collected.contains(id)? collected.remove(id): collected.add(id)); await p.setStringList('collectionIds', collected.toList()); }

  List<Player> get filtered {
    if(q.trim().isEmpty) return players;
    final s=q.toLowerCase();
    return players.where((p)=> p.name.toLowerCase().contains(s)||p.club.toLowerCase().contains(s)||p.nation.toLowerCase().contains(s)||p.pos.toLowerCase().contains(s)).toList();
  }

  void openPack(){ if(players.isEmpty) return; final pool=[...players]..shuffle(rng); lastPack = pool.take(5).toList(); setState((){}); }
  Future<void> _openFutbin(String url) async { if(url.isEmpty) return; final u=Uri.parse(url); if(await canLaunchUrl(u)) await launchUrl(u, mode: LaunchMode.externalApplication); }

  @override
  Widget build(BuildContext context){
    if(loading) return const Scaffold(body: Center(child:CircularProgressIndicator()));
    final total=players.length, have=collected.length.clamp(0, total);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Sticker Book  •  $have/$total'),
          bottom: const TabBar(tabs:[Tab(text:'Album',icon:Icon(Icons.auto_awesome_mosaic)), Tab(text:'Pack',icon:Icon(Icons.card_giftcard))]),
        ),
        body: TabBarView(children:[_album(), _packs()]),
      ),
    );
  }

  Widget _album(){
    final items=filtered;
    return Column(children:[
      Padding(padding: const EdgeInsets.all(12), child: TextField(
        decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText:'Search name, club, nation, position…', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
        onChanged: (v)=>setState(()=>q=v),
      )),
      Expanded(child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .75),
        itemCount: items.length,
        itemBuilder: (_,i){
          final p=items[i]; final have=collected.contains(p.id);
          return InkWell(
            onTap: ()=>Navigator.of(context).push(MaterialPageRoute(builder: (_)=>_Detail(player:p, have:have, onToggle:()=>_toggle(p.id), onFutbin: p.futbinUrl.isNotEmpty? ()=>_openFutbin(p.futbinUrl): null))).then((_)=>setState((){})),
            child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12), color: Colors.white, boxShadow: const [BoxShadow(blurRadius:4,color:Color(0x11000000))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children:[
                Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Stack(fit: StackFit.expand, children:[
                    _ImageOrInitials(url:p.artUrl,label:p.name),
                    if(!have) Container(color: Colors.white.withOpacity(.6)),
                  ]),
                )),
                Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                  Text(p.name, maxLines:1, overflow:TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height:4),
                  Text('${p.pos} • ${p.club}', maxLines:1, overflow:TextOverflow.ellipsis, style: const TextStyle(fontSize:12,color:Colors.black54)),
                ])),
              ]),
            ),
          );
        },
      )),
    ]);
  }

  Widget _packs(){
    return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children:[
      ElevatedButton.icon(onPressed: openPack, icon: const Icon(Icons.local_fire_department), label: const Padding(padding: EdgeInsets.symmetric(vertical:12), child: Text('Open a 5-Sticker Pack'))),
      const SizedBox(height:16),
      if(lastPack.isEmpty) const Center(child: Text('No pack opened yet. Tap the button above.')) else
      Expanded(child: ListView.builder(itemCount:lastPack.length, itemBuilder: (_,i){
        final p=lastPack[i]; final have=collected.contains(p.id);
        return Card(child: ListTile(
          leading: _Avatar(url:p.artUrl,label:p.name),
          title: Text(p.name),
          subtitle: Text('${p.pos} • ${p.club} • ${p.nation}'),
          trailing: IconButton(icon: Icon(have? Icons.check_circle: Icons.add_circle_outline), onPressed: ()=>_toggle(p.id)),
        ));
      })),
    ]));
  }
}

class _Detail extends StatelessWidget{
  final Player player; final bool have; final VoidCallback onToggle; final VoidCallback? onFutbin;
  const _Detail({required this.player, required this.have, required this.onToggle, required this.onFutbin});
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: Text(player.name)), body: ListView(padding: const EdgeInsets.all(16), children:[
      AspectRatio(aspectRatio:1, child: ClipRRect(borderRadius: BorderRadius.circular(20), child:_ImageOrInitials(url:player.artUrl,label:player.name))),
      const SizedBox(height:16),
      Text('${player.pos} • ${player.club} • ${player.nation}', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height:16),
      FilledButton.icon(onPressed:onToggle, icon: Icon(have? Icons.check: Icons.add), label: Text(have? 'In your collection':'Add to collection')),
      const SizedBox(height:12),
      OutlinedButton.icon(onPressed:onFutbin, icon: const Icon(Icons.open_in_new), label: const Text('View on Futbin')),
      if(player.futbinUrl.isEmpty) const Padding(
        padding: EdgeInsets.only(top:8), child: Text('Tip: add a Futbin link in players.csv to enable this.', style: TextStyle(color: Colors.black54)),
      ),
    ]));
  }
}

class _ImageOrInitials extends StatelessWidget{
  final String url,label; const _ImageOrInitials({required this.url, required this.label});
  @override Widget build(BuildContext context){
    if(url.isEmpty) return _Initials(label: label);
    return Image.network(url, fit: BoxFit.cover, errorBuilder: (_,__,___)=>_Initials(label: label),
      loadingBuilder: (c,child,p)=> p==null? child: const Center(child:CircularProgressIndicator()));
  }
}

class _Avatar extends StatelessWidget{
  final String url,label; const _Avatar({required this.url, required this.label});
  @override Widget build(BuildContext context){
    return ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox.square(dimension:44, child:_ImageOrInitials(url:url,label:label)));
  }
}

class _Initials extends StatelessWidget{
  final String label; const _Initials({required this.label});
  @override Widget build(BuildContext context){
    final initials = label.trim().isEmpty ? 'SB' : label.trim().split(RegExp(r'\s+')).take(2).map((e)=>e[0]).join().toUpperCase();
    return Container(color: Colors.grey.shade200, child: Center(child: Text(initials, style: const TextStyle(fontSize:28, fontWeight: FontWeight.bold))));
  }
}
