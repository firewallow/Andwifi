import 'dart:async';
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

int chan(int f) => f >= 5000 ? (f - 5000) ~/ 5 : (f == 2484 ? 14 : (f - 2407) ~/ 5);

class _SurveyState extends State<Survey> {
  File? plan;
  final pts = <Pt>[];
  List<WiFiAccessPoint> aps = [];
  String? target;
  String status = 'Ağlar taranıyor...';
  bool busy = false, scanning = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
    timer = Timer.periodic(const Duration(seconds: 25), (_) => _scan());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _msg(String m) {
    if (mounted) setState(() => status = m);
  }

  Future<bool> _scan() async {
    if (scanning) return aps.isNotEmpty;
    scanning = true;
    try {
      final perm = await Permission.locationWhenInUse.request();
      if (!perm.isGranted) {
        _msg('Konum izni verilmedi. Ayarlar > Uygulamalar > Turquan Site Survey > İzinler > Konum: İzin ver.');
        if (perm.isPermanentlyDenied) await openAppSettings();
        return false;
      }
      if (!await Permission.locationWhenInUse.serviceStatus.isEnabled) {
        _msg('Telefonun KONUM (GPS) özelliği kapalı. Android, Wi-Fi taraması için bunu açmanızı ister.');
        return false;
      }
      final can = await WiFiScan.instance.canStartScan();
      if (can == CanStartScan.yes) {
        await WiFiScan.instance.startScan();
        await Future.delayed(const Duration(seconds: 2));
      }
      final canGet = await WiFiScan.instance.canGetScannedResults();
      if (canGet != CanGetScannedResults.yes) {
        _msg('Sonuç alınamadı: ${canGet.name}');
        return false;
      }
      final r = await WiFiScan.instance.getScannedResults();
      r.sort((a, b) => b.level.compareTo(a.level));
      if (!mounted) return false;
      setState(() {
        aps = r;
        status = r.isEmpty
            ? 'Hiç ağ bulunamadı. Wi-Fi açık mı? Emülatör/tablet sanal Wi-Fi taramayı desteklemez, gerçek telefonda deneyin.'
            : '${r.length} ağ bulundu. Listeden ağ seçin, sonra plana dokunup ölçün.';
      });
      return r.isNotEmpty;
    } catch (e) {
      _msg('Tarama hatası: $e');
      return false;
    } finally {
      scanning = false;
    }
  }

  Future<void> _measure(Offset p, Size s) async {
    if (plan == null || busy) return;
    setState(() => busy = true);
    if (await _scan()) {
      final ap = target == null
          ? aps.first
          : aps.firstWhere((a) => a.ssid == target, orElse: () => aps.first);
      pts.add(Pt(p.dx / s.width, p.dy / s.height, ap.level, ap.ssid));
      _msg('Ölçüldü: ${ap.ssid}  ${ap.level} dBm  |  ${ap.frequency} MHz  |  ${pts.length} nokta');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _pick() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f != null) setState(() { plan = File(f.path); pts.clear(); });
  }

  Widget _panel() {
    final ssids = aps.map((a) => a.ssid).where((x) => x.isNotEmpty).toSet().toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade900)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DropdownButton<String>(
          isExpanded: true,
          hint: Text(ssids.isEmpty ? 'Ağ bulunamadı (yenile ↻)' : 'Ölçülecek ağı seçin'),
          value: ssids.contains(target) ? target : null,
          items: ssids.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
          onChanged: (v) => setState(() => target = v),
        ),
        Expanded(
          child: aps.isEmpty
              ? const Center(child: Text('Liste boş', style: TextStyle(color: Colors.white38)))
              : ListView.builder(
                  itemCount: aps.length,
                  itemBuilder: (c, i) {
                    final a = aps[i];
                    final name = a.ssid.isEmpty ? '(gizli ağ)' : a.ssid;
                    return ListTile(
                      dense: true,
                      selected: a.ssid == target,
                      selectedTileColor: Colors.red.withOpacity(0.2),
                      leading: Icon(Icons.wifi, color: rssiColor(a.level)),
                      title: Text(name),
                      subtitle: Text('${a.bssid}  •  Kanal ${chan(a.frequency)}  •  ${a.frequency} MHz', style: const TextStyle(fontSize: 11)),
                      trailing: Text('${a.level} dBm', style: TextStyle(color: rssiColor(a.level), fontWeight: FontWeight.bold)),
                      onTap: a.ssid.isEmpty ? null : () => setState(() => target = a.ssid),
                    );
                  }),
        ),
        Text(status, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }

  Widget _map() => Container(
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
              return Center(child: ElevatedButton.icon(onPressed: _pick, icon: const Icon(Icons.upload), label: const Text('KAT PLANI YÜKLE')));
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
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: Padding(padding: const EdgeInsets.all(6), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/icon.png'))),
        title: const Text('TURQUAN SITE SURVEY', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          IconButton(icon: const Icon(Icons.map), onPressed: _pick, tooltip: 'Kat planı seç'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _scan, tooltip: 'Ağları tara'),
          PopupMenuButton<String>(
            onSelected: (v) => setState(() {
              if (v == 'undo' && pts.isNotEmpty) pts.removeLast();
              if (v == 'clear') pts.clear();
              if (v == 'plan') { plan = null; pts.clear(); }
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'undo', child: Text('Son noktayı sil')),
              PopupMenuItem(value: 'clear', child: Text('Tüm noktaları sil')),
              PopupMenuItem(value: 'plan', child: Text('Kat planını kaldır')),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(builder: (c, b) {
        if (b.maxWidth > b.maxHeight) {
          return Row(children: [Expanded(child: _map()), SizedBox(width: 340, child: _panel())]);
        }
        return Column(children: [Expanded(child: _map()), SizedBox(height: 260, child: _panel())]);
      }),
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
