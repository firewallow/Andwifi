import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Turquan Site Survey',
        theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF0A0A0A),
            colorScheme: const ColorScheme.dark(primary: Color(0xFFD50000))),
        home: const Splash(),
      );
}

class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const Survey()));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Image.asset('assets/logo.png'),
              const SizedBox(height: 8),
              const Text('SITE SURVEY',
                  style: TextStyle(color: Color(0xFFB30000), fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 6)),
            ]),
          ),
        ),
      );
}

class Pt {
  final double x, y; // 0..1 normalize
  final int rssi;
  final String ssid;
  Pt(this.x, this.y, this.rssi, this.ssid);
}

class Survey extends StatefulWidget {
  const Survey({super.key});
  @override
  State<Survey> createState() => _SurveyState();
}

class _SurveyState extends State<Survey> {
  File? plan;
  final pts = <Pt>[];
  List<WiFiAccessPoint> aps = [];
  String? target;
  String status = 'Kat planı yükle, ağ seç, haritaya dokunarak ölç.';
  bool busy = false;

  Future<bool> _scan() async {
    if (!await Permission.locationWhenInUse.request().isGranted) {
      setState(() => status = 'Konum izni gerekli (Android Wi-Fi taraması için).');
      return false;
    }
    final can = await WiFiScan.instance.canStartScan();
    if (can == CanStartScan.yes) await WiFiScan.instance.startScan();
    if (await WiFiScan.instance.canGetScannedResults() != CanGetScannedResults.yes) {
      setState(() => status = 'Tarama sonucu alınamadı (Wi-Fi/Konum açık mı?).');
      return false;
    }
    final r = await WiFiScan.instance.getScannedResults();
    r.sort((a, b) => b.level.compareTo(a.level));
    setState(() => aps = r);
    return true;
  }

  Future<void> _measure(Offset p, Size s) async {
    if (plan == null || busy) return;
    setState(() => busy = true);
    if (await _scan() && aps.isNotEmpty) {
      final ap = target == null
          ? aps.first
          : aps.firstWhere((a) => a.ssid == target, orElse: () => aps.first);
      pts.add(Pt(p.dx / s.width, p.dy / s.height, ap.level, ap.ssid));
      status = '${ap.ssid}  ${ap.level} dBm  |  ${ap.frequency} MHz  |  ${pts.length} nokta';
    }
    setState(() => busy = false);
  }

  Future<void> _pick() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f != null) setState(() { plan = File(f.path); pts.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    final ssids = aps.map((a) => a.ssid).where((s) => s.isNotEmpty).toSet().toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: Padding(padding: const EdgeInsets.all(6), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/icon.png'))),
        title: const Text('TURQUAN SITE SURVEY',
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          IconButton(icon: const Icon(Icons.map), onPressed: _pick, tooltip: 'Kat planı'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _scan, tooltip: 'Ağları tara'),
          IconButton(icon: const Icon(Icons.delete), onPressed: () => setState(pts.clear), tooltip: 'Temizle'),
        ],
      ),
      body: Column(children: [
        if (ssids.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('Ölçülecek ağ (SSID)'),
              value: ssids.contains(target) ? target : null,
              items: ssids.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => target = v),
            ),
          ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red.shade900, width: 2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.25), blurRadius: 18)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LayoutBuilder(builder: (c, box) {
                final size = Size(box.maxWidth, box.maxHeight);
                if (plan == null) {
                  return Center(
                      child: ElevatedButton.icon(
                          onPressed: _pick,
                          icon: const Icon(Icons.upload),
                          label: const Text('KAT PLANI YÜKLE')));
                }
                return GestureDetector(
                  onTapUp: (d) => _measure(d.localPosition, size),
                  child: Stack(fit: StackFit.expand, children: [
                    Image.file(plan!, fit: BoxFit.contain),
                    CustomPaint(painter: HeatPainter(pts)),
                    if (busy) const Center(child: CircularProgressIndicator()),
                  ]),
                );
              }),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          child: Text(status, style: const TextStyle(color: Colors.white70)),
        ),
      ]),
    );
  }
}

Color rssiColor(int r) {
  if (r >= -50) return const Color(0xFF00E676);
  if (r >= -65) return const Color(0xFFC6FF00);
  if (r >= -75) return const Color(0xFFFF9100);
  return const Color(0xFFD50000);
}

class HeatPainter extends CustomPainter {
  final List<Pt> pts;
  HeatPainter(this.pts);
  @override
  void paint(Canvas canvas, Size s) {
    for (final p in pts) {
      final o = Offset(p.x * s.width, p.y * s.height);
      final col = rssiColor(p.rssi);
      final glow = Paint()
        ..shader = RadialGradient(colors: [col.withOpacity(0.75), col.withOpacity(0.0)])
            .createShader(Rect.fromCircle(center: o, radius: 80));
      canvas.drawCircle(o, 80, glow);
      canvas.drawCircle(o, 5, Paint()..color = Colors.white);
      final tp = TextPainter(
          text: TextSpan(text: '${p.rssi}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, o + const Offset(7, -6));
    }
  }

  @override
  bool shouldRepaint(HeatPainter old) => true;
}
