import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';

final apsNotifier = ValueNotifier<List<WiFiAccessPoint>>([]);
Future<bool> Function()? scanNow;

Color rssiColor(int r) {
  if (r >= -50) return const Color(0xFF00E676);
  if (r >= -65) return const Color(0xFFC6FF00);
  if (r >= -75) return const Color(0xFFFF9100);
  return const Color(0xFFD50000);
}

int chan(int f) => f >= 5000 ? (f - 5000) ~/ 5 : (f == 2484 ? 14 : (f - 2407) ~/ 5);
int quality(int r) => (2 * (r + 100)).clamp(0, 100).toInt();
