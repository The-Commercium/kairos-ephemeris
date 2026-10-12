#!/usr/bin/env python3
"""Reference positions from the Swiss Ephemeris (Moshier mode, no data files) for test/reference.json.
Test-only: Swiss Ephemeris is never linked into the app.
Usage: PYTHONPATH=<dir with pyswisseph> python3 tool/make_reference.py
"""
import json, os, random
import swisseph as swe

random.seed(369)
F = swe.FLG_MOSEPH | swe.FLG_SPEED
BODIES = list(range(10)) + [swe.MEAN_NODE, swe.TRUE_NODE, swe.MEAN_APOG]
cases = []
for i in range(400):
    y = random.randint(1850, 2149); m = random.randint(1, 12); d = random.randint(1, 28)
    h = random.uniform(0, 24)
    lat = random.uniform(-60, 65) if i % 10 else random.choice([0.0, 51.5074, 41.0082, -33.8688, 64.1466])
    lon = random.uniform(-180, 180)
    jd = swe.julday(y, m, d, h)
    bodies = []
    for b in BODIES:
        (lo, la, dist, slo, sla, sd), _ = swe.calc_ut(jd, b, F)
        bodies.append([lo, la, slo])
    houses = {}
    for hs in 'PWE':
        cusps, ascmc = swe.houses_ex(jd, lat, lon, hs.encode())
        houses[hs] = list(cusps[:12])
    _, ascmc = swe.houses_ex(jd, lat, lon, b'P')
    cases.append({'jd_ut': jd, 'y': y, 'lat': lat, 'lon': lon, 'bodies': bodies, 'houses': houses,
                  'asc': ascmc[0], 'mc': ascmc[1], 'armc': ascmc[2]})
out = os.path.join(os.path.dirname(__file__), '..', 'test', 'reference.json')
json.dump({'source': f'Swiss Ephemeris {swe.version} Moshier, apparent geocentric, tropical',
           'bodies': ['sun','moon','mercury','venus','mars','jupiter','saturn','uranus','neptune','pluto','meanNode','trueNode','lilith'],
           'cases': cases}, open(out, 'w'))
print(len(cases), 'cases ->', out)
