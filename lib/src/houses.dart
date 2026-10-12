// House cusps, Ascendant and Midheaven for a moment and a place.
import 'dart:math' as math;

import 'ephemeris.dart';

enum HouseSystem { placidus, wholeSign, equal, porphyry }

class Houses {
  Houses(this.system, this.cusps, this.asc, this.mc, this.armc, {this.fellBack = false});

  /// The system actually used; Placidus falls back to Porphyry inside the polar circles.
  final HouseSystem system;

  /// Twelve cusp longitudes, house 1 first.
  final List<double> cusps;
  final double asc, mc, armc;
  final bool fellBack;

  /// House number (1..12) of an ecliptic longitude.
  int houseOf(double lon) {
    for (var i = 0; i < 12; i++) {
      final a = cusps[i], b = cusps[(i + 1) % 12];
      final span = norm360(b - a);
      if (norm360(lon - a) < span) return i + 1;
    }
    return 1;
  }
}

/// Apparent sidereal time at Greenwich, degrees (IAU 1982 GMST + equation of the equinoxes).
double greenwichSidereal(Instant at, Nutation nut) {
  final d = at.ut;
  final t = d / 36525;
  final gmst = 280.46061837 + 360.98564736629 * d + 0.000387933 * t * t - t * t * t / 38710000;
  return norm360(gmst + nut.dpsi * math.cos(nut.trueObliquity * deg));
}

double _ascendant(double armc, double eps, double lat) {
  final r = armc * deg, e = eps * deg, p = lat * deg;
  final y = math.cos(r);
  final x = -(math.sin(r) * math.cos(e) + math.tan(p) * math.sin(e));
  return norm360(math.atan2(y, x) / deg);
}

double _mc(double armc, double eps) {
  final r = armc * deg;
  return norm360(math.atan2(math.sin(r), math.cos(r) * math.cos(eps * deg)) / deg);
}

/// Ecliptic longitude of the point with right ascension [ra] (degrees).
double _lonFromRa(double ra, double eps) =>
    norm360(math.atan2(math.sin(ra * deg), math.cos(ra * deg) * math.cos(eps * deg)) / deg);

/// Placidus cusp: the ecliptic point whose hour angle east of the meridian is [frac] of its
/// diurnal semi-arc (above the horizon) or, with [below], of its nocturnal arc past the ascendant.
double? _placidusCusp(double armc, double eps, double lat, double frac, bool below) {
  final e = eps * deg, p = lat * deg;
  var lon = norm360(armc + (below ? 90 + 90 * frac : 90 * frac));
  for (var i = 0; i < 50; i++) {
    final dec = math.asin(math.sin(e) * math.sin(lon * deg));
    final x = -math.tan(p) * math.tan(dec);
    if (x.abs() > 1) return null;
    final sa = math.acos(x) / deg; // diurnal semi-arc
    final ra = below ? armc + sa + (180 - sa) * frac : armc + sa * frac;
    final next = _lonFromRa(ra, eps);
    if (angleDiff(next, lon).abs() < 1e-7) return next;
    lon = next;
  }
  return lon;
}

Houses computeHouses(Instant at, double lat, double lonEast, HouseSystem system) {
  final nut = Nutation.at(at.tt);
  final eps = nut.trueObliquity;
  final armc = norm360(greenwichSidereal(at, nut) + lonEast);
  final asc = _ascendant(armc, eps, lat);
  final mc = _mc(armc, eps);
  List<double> porphyry() {
    final q1 = norm360(asc - mc), q2 = norm360(mc + 180 - asc);
    return [
      asc,
      norm360(asc + q2 / 3),
      norm360(asc + 2 * q2 / 3),
      norm360(mc + 180),
      norm360(mc + 180 + q1 / 3),
      norm360(mc + 180 + 2 * q1 / 3),
      norm360(asc + 180),
      norm360(asc + 180 + q2 / 3),
      norm360(asc + 180 + 2 * q2 / 3),
      mc,
      norm360(mc + q1 / 3),
      norm360(mc + 2 * q1 / 3),
    ];
  }

  switch (system) {
    case HouseSystem.wholeSign:
      final first = (asc / 30).floor() * 30.0;
      return Houses(system, [for (var i = 0; i < 12; i++) norm360(first + 30.0 * i)], asc, mc, armc);
    case HouseSystem.equal:
      return Houses(system, [for (var i = 0; i < 12; i++) norm360(asc + 30.0 * i)], asc, mc, armc);
    case HouseSystem.porphyry:
      return Houses(system, porphyry(), asc, mc, armc);
    case HouseSystem.placidus:
      final c11 = _placidusCusp(armc, eps, lat, 1 / 3, false);
      final c12 = _placidusCusp(armc, eps, lat, 2 / 3, false);
      final c2 = _placidusCusp(armc, eps, lat, 1 / 3, true);
      final c3 = _placidusCusp(armc, eps, lat, 2 / 3, true);
      if (c11 == null || c12 == null || c2 == null || c3 == null || lat.abs() >= 90 - eps) {
        return Houses(HouseSystem.porphyry, porphyry(), asc, mc, armc, fellBack: true);
      }
      return Houses(system, [
        asc,
        c2,
        c3,
        norm360(mc + 180),
        norm360(c11 + 180),
        norm360(c12 + 180),
        norm360(asc + 180),
        norm360(c2 + 180),
        norm360(c3 + 180),
        mc,
        c11,
        c12,
      ], asc, mc, armc);
  }
}
