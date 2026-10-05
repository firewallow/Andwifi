import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'shared.dart';

String joke(int r) => r >= -50
    ? 'Roket hızı! Router seni seviyor 🚀'
    : r >= -60
        ? 'Mükemmel, sinyal dolu dolu 😎'
        : r >= -70
            ? 'İdare eder, bir çay molası kadar ☕'
            : r >= -80
                ? 'Zayıf... biraz dua, biraz yaklaşma 🙏'
                : 'YANIYOR! Router çok çok uzakta 🔥';

Widget led(String t, Color c, double size) => Text(t,
    style: TextStyle(fontFamily: 'monospace', fontSize: size, fontWeight: FontWeight.bold, color: c, letterSpacing: 2, shadows: [Shadow(color: c, blurRadius: 12)]));

class StarPainter extends CustomPainter {
  final double t;
  StarPainter(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final R = s.shortestSide / 2;
    canvas.drawCircle(c, R, Paint()..shader = const RadialGradient(colors: [Color(0xAAFFD600), Color(0x00FFD600)]).createShader(Rect.fromCircle(center: c, radius: R)));
    for (var k = 0; k < 2; k++) {
      final path = Path();
      final rot = t * 2 * pi * (k == 0 ? 0.5 : -0.5);
      final r1 = R * (k == 0 ? 0.9 : 0.55) * (0.92 + 0.08 * sin(t * 2 * pi * 3));
      for (var i = 0; i < 16; i++) {
        final r = i.isEven ? r1 : r1 * 0.3;
        final a = rot + i * pi / 8;
        final p = c + Offset(cos(a) * r, sin(a) * r);
        if (i == 0) { path.moveTo(p.dx, p.dy); } else { path.lineTo(p.dx, p.dy); }
      }
      path.close();
      canvas.drawPath(path, Paint()..color = (k == 0 ? const Color(0xFFFFD600) : const Color(0xFFFF1744)).withOpacity(k == 0 ? 0.9 : 0.8));
    }
    canvas.drawCircle(c, R * 0.12, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(StarPainter o) => true;
}

class FlamePainter extends CustomPainter {
  final double t;
  FlamePainter(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final base = s.height * 0.95;
    canvas.drawCircle(Offset(s.width / 2, base), s.width * 0.45, Paint()..shader = const RadialGradient(colors: [Color(0x88FF3D00), Color(0x00FF3D00)]).createShader(Rect.fromCircle(center: Offset(s.width / 2, base), radius: s.width * 0.45)));
    final cols = [const Color(0xFFD50000), const Color(0xFFFF6D00), const Color(0xFFFFEA00)];
    for (var layer = 0; layer < 3; layer++) {
      for (var i = 0; i < 5; i++) {
        final cx = s.width * (0.2 + i * 0.15);
        final h = s.height * (0.45 + 0.5 * (i == 2 ? 1 : 0.65)) * (1 - layer * 0.25) * (0.75 + 0.25 * sin(t * 2 * pi * (2 + i) + i));
        final w = s.width * 0.11 * (1 - layer * 0.2);
        final sway = sin(t * 2 * pi * 3 + i) * w * 0.8;
        final p = Path()
          ..moveTo(cx - w, base)
          ..quadraticBezierTo(cx - w * 0.3, base - h * 0.5, cx + sway, base - h)
          ..quadraticBezierTo(cx + w * 0.3, base - h * 0.5, cx + w, base)
          ..close();
        canvas.drawPath(p, Paint()..color = cols[layer].withOpacity(0.9));
      }
    }
  }

  @override
  bool shouldRepaint(FlamePainter o) => true;
}

class Analyzer extends StatefulWidget {
  const Analyzer({super.key});
  @override
  State<Analyzer> createState() => _AnalyzerState();
}

class _AnalyzerState extends State<Analyzer> with SingleTickerProviderStateMixin {
  late final AnimationController ctl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  Widget _hero(String title, WiFiAccessPoint a, bool best) {
    final col = best ? const Color(0xFFFFD600) : const Color(0xFFFF5722);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16), border: Border.all(color: col.withOpacity(0.7), width: 1.5), boxShadow: [BoxShadow(color: col.withOpacity(0.25), blurRadius: 16)]),
        child: Column(children: [
          Text(title, style: TextStyle(color: col, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12)),
          SizedBox(height: 100, width: 100, child: CustomPaint(painter: best ? StarPainter(ctl.value) : FlamePainter(ctl.value))),
          led('${a.level}', col, 34),
          const Text('dBm', style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          Text(a.ssid.isEmpty ? '(gizli ağ)' : a.ssid, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(joke(a.level), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _channels(List<WiFiAccessPoint> aps) {
    final cnt = List.filled(14, 0);
    for (final a in aps) {
      if (a.frequency < 3000) {
        final ch = chan(a.frequency);
        if (ch >= 1 && ch <= 13) cnt[ch]++;
      }
    }
    return Container(
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.shade900)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('2.4 GHz KANAL KALABALIĞI', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var ch = 1; ch <= 13; ch++)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(cnt[ch] > 0 ? '${cnt[ch]}' : '', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 6 + cnt[ch] * 16.0,
                    decoration: BoxDecoration(
                        color: cnt[ch] == 0 ? Colors.white12 : (cnt[ch] > 2 ? Colors.red : Colors.orange),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: cnt[ch] > 0 ? [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 8)] : null),
                  ),
                  Text('$ch', style: const TextStyle(fontSize: 10, color: Colors.white38)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _row(WiFiAccessPoint a, bool best, bool worst) {
    final col = rssiColor(a.level);
    final bars = (quality(a.level) / 10).round();
    final band = a.frequency >= 5925 ? '6 GHz' : (a.frequency >= 4900 ? '5 GHz' : '2.4 GHz');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(14), border: Border.all(color: col.withOpacity(0.5))),
      child: Row(children: [
        SizedBox(width: 74, child: led('${a.level}', col, 24)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${best ? '⭐ ' : ''}${worst ? '🔥 ' : ''}${a.ssid.isEmpty ? '(gizli ağ)' : a.ssid}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(children: [
              for (var i = 0; i < 10; i++)
                Container(width: 14, height: 8, margin: const EdgeInsets.only(right: 2), decoration: BoxDecoration(color: i < bars ? col : Colors.white12, borderRadius: BorderRadius.circular(2), boxShadow: i < bars ? [BoxShadow(color: col.withOpacity(0.6), blurRadius: 4)] : null)),
            ]),
            const SizedBox(height: 4),
            Text('Kanal ${chan(a.frequency)} • $band • %${quality(a.level)}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('WI-FI ANALYZER', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => scanNow?.call())],
      ),
      body: ValueListenableBuilder<List<WiFiAccessPoint>>(
        valueListenable: apsNotifier,
        builder: (c, aps, _) {
          if (aps.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Henüz ağ bulunamadı 😴\nSağ üstten ↻ ile tarayın. Gerçek telefonda, Wi-Fi ve Konum açık olmalı.', textAlign: TextAlign.center)));
          }
          final list = [...aps]..sort((a, b) => b.level.compareTo(a.level));
          final best = list.first, worst = list.last;
          return AnimatedBuilder(
            animation: ctl,
            builder: (c, _) => ListView(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _hero('EN İYİ SİNYAL', best, true),
                if (list.length > 1) _hero('EN KÖTÜ SİNYAL', worst, false),
              ]),
              _channels(list),
              for (final a in list) _row(a, identical(a, best), list.length > 1 && identical(a, worst)),
              const SizedBox(height: 16),
            ]),
          );
        },
      ),
    );
  }
}
