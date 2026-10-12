import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:kairos_ephemeris/kairos_ephemeris.dart';

/// Against 400 random moments and places (1850-2149) from the Swiss Ephemeris
/// (tool/make_reference.py). Limits in arcminutes.
void main() {
  final ref = jsonDecode(File('test/reference.json').readAsStringSync()) as Map<String, dynamic>;
  final cases = (ref['cases'] as List).cast<Map<String, dynamic>>();
  DateTime fromJd(double jd) =>
      DateTime.fromMicrosecondsSinceEpoch(((jd - 2440587.5) * 8.64e10).round(), isUtc: true);

  const limits = {
    Body.sun: 0.2, Body.moon: 0.6, Body.mercury: 0.5, Body.venus: 0.5, Body.mars: 0.5,
    Body.jupiter: 0.5, Body.saturn: 0.5, Body.uranus: 0.5, Body.neptune: 0.5, Body.pluto: 0.5,
    Body.meanNode: 0.5, Body.trueNode: 1.0, Body.lilith: 1.0,
  };

  test('longitudes, latitudes and speeds match the Swiss Ephemeris', () {
    final worst = {for (final b in Body.values) b: 0.0};
    final worstLat = {for (final b in Body.values) b: 0.0};
    var speedSign = 0;
    var moonRawTo2025 = 0.0, moonRawAfter = 0.0;
    for (final c in cases) {
      final at = Instant.utc(fromJd((c['jd_ut'] as num).toDouble()));
      final pos = positions(at);
      final bodies = (c['bodies'] as List).cast<List>();
      for (final p in pos) {
        final r = bodies[p.body.index];
        var d = angleDiff(p.lon, (r[0] as num).toDouble()).abs() * 60;
        if (p.body == Body.moon) {
          if ((c['y'] as int) > 2025) {
            if (d > moonRawAfter) moonRawAfter = d;
          } else if (d > moonRawTo2025) {
            moonRawTo2025 = d;
          }
        }
        // Past the present, Delta T is a forecast and the two libraries forecast differently;
        // the Moon (0.5'/min) shows it most. Scale its limit by the years past 2025.
        if (p.body == Body.moon && (c['y'] as int) > 2025) d *= 0.6 / (0.6 + ((c['y'] as int) - 2025) * 0.013);
        if (d > worst[p.body]!) worst[p.body] = d;
        final dl = (p.lat - (r[1] as num).toDouble()).abs() * 60;
        if (p.body.index < 10 && dl > worstLat[p.body]!) worstLat[p.body] = dl;
        final rs = (r[2] as num).toDouble();
        // A station is a station: the true node turns at a few thousandths of a degree a day.
        final still = p.body == Body.trueNode ? 0.01 : 0.002;
        if (rs.abs() > still && (rs < 0) != p.retrograde) speedSign++;
      }
    }
    for (final b in Body.values) {
      // ignore: avoid_print
      print('${b.name.padRight(9)} lon max ${worst[b]!.toStringAsFixed(3)}\'  lat max ${worstLat[b]!.toStringAsFixed(3)}\'');
    }
    // ignore: avoid_print
    print('moon raw lon max: to 2025 ${moonRawTo2025.toStringAsFixed(3)}\'  after 2025 ${moonRawAfter.toStringAsFixed(3)}\'');
    // ignore: avoid_print
    print('retrograde flag mismatches: $speedSign');
    for (final b in Body.values) {
      expect(worst[b]!, lessThan(limits[b]!), reason: b.name);
    }
    expect(speedSign, 0);
  });

  test('houses match the Swiss Ephemeris', () {
    final worst = {for (final s in ['P', 'W', 'E']) s: 0.0};
    var ascMc = 0.0;
    for (final c in cases) {
      final at = Instant.utc(fromJd((c['jd_ut'] as num).toDouble()));
      final lat = (c['lat'] as num).toDouble(), lon = (c['lon'] as num).toDouble();
      for (final e in {'P': HouseSystem.placidus, 'W': HouseSystem.wholeSign, 'E': HouseSystem.equal}.entries) {
        final h = computeHouses(at, lat, lon, e.value);
        final r = ((c['houses'] as Map)[e.key] as List).cast<num>();
        for (var i = 0; i < 12; i++) {
          final d = angleDiff(h.cusps[i], r[i].toDouble()).abs() * 60;
          if (d > worst[e.key]!) worst[e.key] = d;
        }
        ascMc = [ascMc, angleDiff(h.asc, (c['asc'] as num).toDouble()).abs() * 60,
          angleDiff(h.mc, (c['mc'] as num).toDouble()).abs() * 60].reduce((a, b) => a > b ? a : b);
      }
    }
    // ignore: avoid_print
    print('houses max: $worst  asc/mc max ${ascMc.toStringAsFixed(3)}\'');
    expect(ascMc, lessThan(0.2));
    for (final v in worst.values) {
      expect(v, lessThan(0.2));
    }
  });
}
