// Kairos ephemeris: apparent geocentric tropical positions, pure Dart.
//
// Planets: truncated VSOP87 (series from Astronomy Engine, MIT) with light time,
// annual aberration, precession to the ecliptic of date (Meeus 21.5) and nutation.
// Moon: Montenbruck-Pfleger lunar theory (as ported by Astronomy Engine).
// Pluto: Astronomy Engine's gravity-simulated orbit, tabulated every 20 days, 1799..2201.
// Accuracy against the Swiss Ephemeris is checked by test/ephemeris_test.dart.
import 'dart:math' as math;

import 'gen/moon.dart';
import 'gen/pluto.dart';
import 'gen/vsop.dart';

const double deg = math.pi / 180;
const double _arcsec = deg / 3600;
const double _c = 173.1446326846693; // speed of light, AU per day
const double _daysPerMillennium = 365250;

double norm360(double x) {
  final r = x % 360;
  return r < 0 ? r + 360 : r;
}

/// Signed difference a - b folded into (-180, 180].
double angleDiff(double a, double b) {
  var d = (a - b) % 360;
  if (d > 180) d -= 360;
  if (d <= -180) d += 360;
  return d;
}

/// Espenak & Meeus piecewise polynomials for TT - UT, in seconds.
double deltaT(double ut) {
  final y = 2000 + (ut - 14) / 365.24217;
  double u;
  if (y < 1700) {
    u = y - 1600;
    return 120 - 0.9808 * u - 0.01532 * u * u + u * u * u / 7129.0;
  }
  if (y < 1800) {
    u = y - 1700;
    return 8.83 + 0.1603 * u - 0.0059285 * u * u + 0.00013336 * u * u * u - math.pow(u, 4) / 1174000;
  }
  if (y < 1860) {
    u = y - 1800;
    return 13.72 - 0.332447 * u + 0.0068612 * u * u + 0.0041116 * math.pow(u, 3) - 0.00037436 * math.pow(u, 4) +
        0.0000121272 * math.pow(u, 5) - 0.0000001699 * math.pow(u, 6) + 0.000000000875 * math.pow(u, 7);
  }
  if (y < 1900) {
    u = y - 1860;
    return 7.62 + 0.5737 * u - 0.251754 * u * u + 0.01680668 * math.pow(u, 3) - 0.0004473624 * math.pow(u, 4) +
        math.pow(u, 5) / 233174;
  }
  if (y < 1920) {
    u = y - 1900;
    return -2.79 + 1.494119 * u - 0.0598939 * u * u + 0.0061966 * math.pow(u, 3) - 0.000197 * math.pow(u, 4);
  }
  if (y < 1941) {
    u = y - 1920;
    return 21.20 + 0.84493 * u - 0.076100 * u * u + 0.0020936 * math.pow(u, 3);
  }
  if (y < 1961) {
    u = y - 1950;
    return 29.07 + 0.407 * u - u * u / 233 + math.pow(u, 3) / 2547;
  }
  if (y < 1986) {
    u = y - 1975;
    return 45.45 + 1.067 * u - u * u / 260 - math.pow(u, 3) / 718;
  }
  if (y < 2005) {
    u = y - 2000;
    return 63.86 + 0.3345 * u - 0.060374 * u * u + 0.0017275 * math.pow(u, 3) + 0.000651814 * math.pow(u, 4) +
        0.00002373599 * math.pow(u, 5);
  }
  if (y < 2050) {
    u = y - 2000;
    return 62.92 + 0.32217 * u + 0.005589 * u * u;
  }
  u = (y - 1820) / 100;
  if (y < 2150) return -20 + 32 * u * u - 0.5628 * (2150 - y);
  return -20 + 32 * u * u;
}

/// One instant on both time scales, as days since J2000.0 (2000-01-01 12:00).
class Instant {
  Instant.utc(DateTime t)
      : ut = (t.toUtc().microsecondsSinceEpoch / 8.64e10) + 2440587.5 - 2451545.0,
        tt = 0 {
    tt = ut + deltaT(ut) / 86400;
  }
  Instant._(this.ut, this.tt);

  final double ut;
  double tt;

  Instant addDays(double d) => Instant._(ut + d, tt + d);
  double get jdUt => ut + 2451545.0;
}

class Nutation {
  Nutation(this.dpsi, this.deps, this.meanObliquity);
  final double dpsi; // degrees
  final double deps; // degrees
  final double meanObliquity; // degrees
  double get trueObliquity => meanObliquity + deps;

  /// Meeus ch. 22, low-precision series (0.5" in longitude, 0.1" in obliquity).
  factory Nutation.at(double tt) {
    final t = tt / 36525;
    final om = (125.04452 - 1934.136261 * t + 0.0020708 * t * t + t * t * t / 450000) * deg;
    final l = (280.4665 + 36000.7698 * t) * deg;
    final lp = (218.3165 + 481267.8813 * t) * deg;
    final dpsi = -17.20 * math.sin(om) - 1.32 * math.sin(2 * l) - 0.23 * math.sin(2 * lp) + 0.21 * math.sin(2 * om);
    final deps = 9.20 * math.cos(om) + 0.57 * math.cos(2 * l) + 0.10 * math.cos(2 * lp) - 0.09 * math.cos(2 * om);
    final eps0 = 23.0 + 26 / 60 + (21.448 - 46.8150 * t - 0.00059 * t * t + 0.001813 * t * t * t) / 3600;
    return Nutation(dpsi / 3600, deps / 3600, eps0);
  }
}

class _V {
  const _V(this.x, this.y, this.z);
  final double x, y, z;
  _V operator +(_V o) => _V(x + o.x, y + o.y, z + o.z);
  _V operator -(_V o) => _V(x - o.x, y - o.y, z - o.z);
  _V operator *(double k) => _V(x * k, y * k, z * k);
  double get length => math.sqrt(x * x + y * y + z * z);
}

double _vsopFormula(List<List<double>> formula, double t, bool clamp) {
  var tpow = 1.0;
  var coord = 0.0;
  for (final series in formula) {
    var sum = 0.0;
    for (var i = 0; i < series.length; i += 3) {
      sum += series[i] * math.cos(series[i + 1] + series[i + 2] * t);
    }
    var incr = tpow * sum;
    if (clamp) incr = incr % (2 * math.pi);
    coord += incr;
    tpow *= t;
  }
  return coord;
}

/// Heliocentric position on the VSOP87 ecliptic of J2000, AU.
_V _vsopHelio(int planet, double tt) {
  final m = vsop[planet];
  final t = tt / _daysPerMillennium;
  final lon = _vsopFormula(m[0], t, true);
  final lat = _vsopFormula(m[1], t, false);
  final rad = _vsopFormula(m[2], t, false);
  final rc = rad * math.cos(lat);
  return _V(rc * math.cos(lon), rc * math.sin(lon), rad * math.sin(lat));
}

/// Pluto, 4-point Lagrange interpolation in the 20-day table.
_V _plutoHelio(double tt) {
  var f = (tt - plutoT0) / plutoStep;
  f = f.clamp(1.0, plutoCount - 3.0);
  final i = f.floor();
  final u = f - i;
  // Nodes at i-1, i, i+1, i+2 -> u = -1, 0, 1, 2.
  final w = [
    -u * (u - 1) * (u - 2) / 6,
    (u + 1) * (u - 1) * (u - 2) / 2,
    -(u + 1) * u * (u - 2) / 2,
    (u + 1) * u * (u - 1) / 6,
  ];
  var x = 0.0, y = 0.0, z = 0.0;
  for (var k = 0; k < 4; k++) {
    final j = (i - 1 + k) * 3;
    x += w[k] * pluto[j];
    y += w[k] * pluto[j + 1];
    z += w[k] * pluto[j + 2];
  }
  return _V(x, y, z);
}

/// The years the Pluto table covers; the app keeps its date picker inside them.
final DateTime ephemerisStart = DateTime.utc(1800, 1, 1);
final DateTime ephemerisEnd = DateTime.utc(2199, 12, 31, 23, 59);

enum Body { sun, moon, mercury, venus, mars, jupiter, saturn, uranus, neptune, pluto, meanNode, trueNode, lilith }

const _vsopIndex = {
  Body.mercury: 0,
  Body.venus: 1,
  Body.mars: 3,
  Body.jupiter: 4,
  Body.saturn: 5,
  Body.uranus: 6,
  Body.neptune: 7,
};

_V _helio(Body b, double tt) {
  if (b == Body.sun) return const _V(0, 0, 0);
  if (b == Body.pluto) return _plutoHelio(tt);
  return _vsopHelio(_vsopIndex[b]!, tt);
}

/// Ecliptic J2000 (lambda0, beta0) to the mean ecliptic and equinox of date. Meeus 21.5 with T = 0.
(double, double) _precess(double lon0, double lat0, double tt) {
  final t = tt / 36525;
  final eta = (47.0029 * t - 0.03302 * t * t + 0.000060 * t * t * t) * _arcsec;
  final bigPi = 174.876384 * deg + (-869.8089 * t + 0.03536 * t * t) * _arcsec;
  final p = (5029.0966 * t + 1.11113 * t * t - 0.000006 * t * t * t) * _arcsec;
  final a = math.cos(eta) * math.cos(lat0) * math.sin(bigPi - lon0) - math.sin(eta) * math.sin(lat0);
  final b = math.cos(lat0) * math.cos(bigPi - lon0);
  final c = math.cos(eta) * math.sin(lat0) + math.sin(eta) * math.cos(lat0) * math.sin(bigPi - lon0);
  final lon = bigPi + p - math.atan2(a, b);
  return (lon, math.asin(c.clamp(-1.0, 1.0)));
}

/// Apparent geocentric ecliptic longitude and latitude of date, degrees.
(double, double) _apparent(Body b, double tt, Nutation nut) {
  switch (b) {
    case Body.moon:
      final m = _moon(tt);
      return (norm360(m.$1 + nut.dpsi), m.$2);
    case Body.meanNode:
      return (norm360(_meanNode(tt) + nut.dpsi), 0);
    case Body.trueNode:
      return (norm360(_trueNode(tt) + nut.dpsi), 0);
    case Body.lilith:
      final l = _meanApogee(tt);
      return (norm360(l.$1 + nut.dpsi), l.$2);
    default:
      break;
  }
  final earth = _vsopHelio(2, tt);
  var g = _helio(b, tt) - earth;
  for (var i = 0; i < 2; i++) {
    final tau = g.length / _c;
    g = _helio(b, tt - tau) - earth;
  }
  // Annual aberration, first order, from the Earth's heliocentric velocity.
  const h = 0.01;
  final v = (_vsopHelio(2, tt + h) - _vsopHelio(2, tt - h)) * (1 / (2 * h));
  g = g + v * (g.length / _c);
  final lon0 = math.atan2(g.y, g.x);
  final lat0 = math.atan2(g.z, math.sqrt(g.x * g.x + g.y * g.y));
  final (lon, lat) = _precess(lon0, lat0, tt);
  return (norm360(lon / deg + nut.dpsi), lat / deg);
}

class Position {
  const Position(this.body, this.lon, this.lat, this.speed);
  final Body body;

  /// Tropical ecliptic longitude, degrees [0, 360).
  final double lon;
  final double lat;

  /// Degrees per day; negative = retrograde.
  final double speed;
  bool get retrograde => speed < 0;
}

/// Apparent positions of every body at [at].
List<Position> positions(Instant at) {
  final nut = Nutation.at(at.tt);
  final out = <Position>[];
  for (final b in Body.values) {
    // The osculating node turns within days; a short step keeps its speed instantaneous.
    final h = b == Body.trueNode ? 0.02 : 0.5;
    final now = _apparent(b, at.tt, nut);
    final before = _apparent(b, at.tt - h, Nutation.at(at.tt - h));
    final after = _apparent(b, at.tt + h, Nutation.at(at.tt + h));
    out.add(Position(b, now.$1, now.$2, angleDiff(after.$1, before.$1) / (2 * h)));
  }
  return out;
}

// ---- Moon (Montenbruck & Pfleger, "Astronomy on the Personal Computer") ----

(double, double, double) _moon(double tt) {
  final t = tt / 36525;
  final t2 = t * t;
  const arc = 3600.0 * 180 / math.pi;
  double sine(double phi) => math.sin(2 * math.pi * phi);
  double frac(double x) => x - x.floorToDouble();

  final s1 = sine(0.19833 + 0.05611 * t);
  final s2 = sine(0.27869 + 0.04508 * t);
  final s3 = sine(0.16827 - 0.36903 * t);
  final s4 = sine(0.34734 - 5.37261 * t);
  final s5 = sine(0.10498 - 5.37899 * t);
  final s6 = sine(0.42681 - 0.41855 * t);
  final s7 = sine(0.14943 - 5.37511 * t);
  final dl0 = 0.84 * s1 + 0.31 * s2 + 14.27 * s3 + 7.26 * s4 + 0.28 * s5 + 0.24 * s6;
  final dl = 2.94 * s1 + 0.31 * s2 + 14.27 * s3 + 9.34 * s4 + 1.12 * s5 + 0.83 * s6;
  final dls = -6.40 * s1 - 1.89 * s6;
  final df = 0.21 * s1 + 0.31 * s2 + 14.27 * s3 - 88.70 * s4 - 15.30 * s5 + 0.24 * s6 - 1.86 * s7;
  final dd = dl0 - dls;
  final dgam = -3332e-9 * sine(0.59734 - 5.37261 * t) - 539e-9 * sine(0.35498 - 5.37899 * t) -
      64e-9 * sine(0.39943 - 5.37511 * t);

  final l0 = 2 * math.pi * frac(0.60643382 + 1336.85522467 * t - 0.00000313 * t2) + dl0 / arc;
  final l = 2 * math.pi * frac(0.37489701 + 1325.55240982 * t + 0.00002565 * t2) + dl / arc;
  final ls = 2 * math.pi * frac(0.99312619 + 99.99735956 * t - 0.00000044 * t2) + dls / arc;
  final f = 2 * math.pi * frac(0.25909118 + 1342.22782980 * t - 0.00000892 * t2) + df / arc;
  final d = 2 * math.pi * frac(0.82736186 + 1236.85308708 * t - 0.00000397 * t2) + dd / arc;

  // ex[j][i] = FAC_i^j * e^(i*j*ARG_i) for j in -6..6, i in 1..4, stored as (re, im) pairs.
  final re = List.generate(13, (_) => List.filled(5, 0.0));
  final im = List.generate(13, (_) => List.filled(5, 0.0));
  final args = [0.0, l, ls, f, d];
  final maxes = [0, 4, 3, 4, 6];
  final facs = [0.0, 1.000002208, 0.997504612 - 0.002495388 * t, 1.000002708 + 139.978 * dgam, 1.0];
  for (var i = 1; i <= 4; i++) {
    re[6][i] = 1;
    im[6][i] = 0;
    re[7][i] = facs[i] * math.cos(args[i]);
    im[7][i] = facs[i] * math.sin(args[i]);
    for (var j = 2; j <= maxes[i]; j++) {
      re[6 + j][i] = re[5 + j][i] * re[7][i] - im[5 + j][i] * im[7][i];
      im[6 + j][i] = re[5 + j][i] * im[7][i] + im[5 + j][i] * re[7][i];
    }
    for (var j = 1; j <= maxes[i]; j++) {
      re[6 - j][i] = re[6 + j][i];
      im[6 - j][i] = -im[6 + j][i];
    }
  }
  (double, double) term(int p, int q, int r, int s) {
    var zr = 1.0, zi = 0.0;
    void mul(int j, int i) {
      if (j == 0) return;
      final a = re[6 + j][i], b = im[6 + j][i];
      final nr = zr * a - zi * b;
      zi = zr * b + zi * a;
      zr = nr;
    }

    mul(p, 1);
    mul(q, 2);
    mul(r, 3);
    mul(s, 4);
    return (zr, zi);
  }

  var dlam = 0.0, ds = 0.0, gam1c = 0.0, sinpi = 3422.7000;
  for (var k = 0; k < moonSol.length; k += 8) {
    final z = term(moonSol[k + 4].toInt(), moonSol[k + 5].toInt(), moonSol[k + 6].toInt(), moonSol[k + 7].toInt());
    dlam += moonSol[k] * z.$2;
    ds += moonSol[k + 1] * z.$2;
    gam1c += moonSol[k + 2] * z.$1;
    sinpi += moonSol[k + 3] * z.$1;
  }
  double addn(double c, int p, int q, int r, int s) => c * term(p, q, r, s).$2;
  final n = addn(-526.069, 0, 0, 1, -2) +
      addn(-3.352, 0, 0, 1, -4) +
      addn(44.297, 1, 0, 1, -2) +
      addn(-6.000, 1, 0, 1, -4) +
      addn(20.599, -1, 0, 1, 0) +
      addn(-30.598, -1, 0, 1, -2) +
      addn(-24.649, -2, 0, 1, 0) +
      addn(-2.000, -2, 0, 1, -2) +
      addn(-22.571, 0, 1, 1, -2) +
      addn(10.985, 0, -1, 1, -2);
  dlam += 0.82 * sine(0.7736 - 62.5512 * t) +
      0.31 * sine(0.0466 - 125.1025 * t) +
      0.35 * sine(0.5785 - 25.1042 * t) +
      0.66 * sine(0.4591 + 1335.8075 * t) +
      0.64 * sine(0.3130 - 91.5680 * t) +
      1.14 * sine(0.1480 + 1331.2898 * t) +
      0.21 * sine(0.5918 + 1056.5859 * t) +
      0.44 * sine(0.5784 + 1322.8595 * t) +
      0.24 * sine(0.2275 - 5.7374 * t) +
      0.28 * sine(0.2965 + 2.6929 * t) +
      0.33 * sine(0.3132 + 6.3368 * t);
  final sArg = f + ds / arc;
  final latSec = (1.000002708 + 139.978 * dgam) * (18518.511 + 1.189 + gam1c) * math.sin(sArg) -
      6.24 * math.sin(3 * sArg) +
      n;
  final lon = 2 * math.pi * frac((l0 + dlam / arc) / (2 * math.pi));
  // Earth's equatorial radius in AU over the parallax gives the distance.
  final dist = arc * 4.263523270823e-5 / (0.999953253 * sinpi);
  return (lon / deg, latSec / 3600, dist);
}

// ---- Lunar node and apogee (Meeus ch. 47, mean elements of date) ----

double _meanNode(double tt) {
  final t = tt / 36525;
  return norm360(125.0445479 - 1934.1362891 * t + 0.0020754 * t * t + t * t * t / 467441 - t * t * t * t / 60616000);
}

_V _moonRect(double tt) {
  final m = _moon(tt);
  final lo = m.$1 * deg, la = m.$2 * deg;
  return _V(m.$3 * math.cos(la) * math.cos(lo), m.$3 * math.cos(la) * math.sin(lo), m.$3 * math.sin(la));
}

/// True (osculating) node: where the plane of the Moon's instantaneous orbit meets the ecliptic.
double _trueNode(double tt) {
  const h = 0.001;
  final r = _moonRect(tt);
  final v = _moonRect(tt + h) - _moonRect(tt - h);
  // Angular momentum r x v; the ascending node lies along (hz-axis x h).
  final hx = r.y * v.z - r.z * v.y;
  final hy = r.z * v.x - r.x * v.z;
  return norm360(math.atan2(hx, -hy) / deg);
}

/// Black Moon Lilith: the mean lunar apogee, carried from the mean orbit onto the ecliptic.
(double, double) _meanApogee(double tt) {
  final t = tt / 36525;
  final perigee =
      83.3532465 + 4069.0137287 * t - 0.0103200 * t * t - t * t * t / 80053 + t * t * t * t / 18999000;
  final node = _meanNode(tt);
  const inc = 5.1453964 * deg;
  final u = (perigee + 180 - node) * deg;
  final lon = node + math.atan2(math.cos(inc) * math.sin(u), math.cos(u)) / deg;
  return (norm360(lon), math.asin(math.sin(inc) * math.sin(u)) / deg);
}

/// Moon minus Sun in apparent longitude, degrees [0, 360): 0 at new moon, 180 at full.
double moonSunElongation(Instant at) {
  final nut = Nutation.at(at.tt);
  return norm360(_apparent(Body.moon, at.tt, nut).$1 - _apparent(Body.sun, at.tt, nut).$1);
}
