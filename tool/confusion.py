#!/usr/bin/env python3
"""Matrice de confusion a partir de test/golden/out/predictions.csv.

Usage : cd ~/clips && python3 tool/confusion.py
Sorties : rapport texte (paires les plus confondues, categories les plus
fragiles) + test/golden/out/confusion.csv (matrice complete).
"""
import csv, os, sys, collections

SRC = os.path.join(os.path.expanduser(os.environ.get('CLIPS_DIR', '~/clips')),
                   'test/golden/out/predictions.csv')
rows = list(csv.DictReader(open(SRC, encoding='utf8')))
ok = [r for r in rows if r['obtenu'] and r['attendu'] != 'cat_unclear']
conf = collections.Counter((r['attendu'], r['obtenu']) for r in ok)
tot = collections.Counter(r['attendu'] for r in ok)
good = collections.Counter(r['attendu'] for r in ok if r['attendu'] == r['obtenu'])

print(f"{len(rows)} cas, {len(ok)} evalues, "
      f"{sum(good.values())} justes ({100*sum(good.values())/max(1,len(ok)):.1f} %)\n")

pairs = collections.Counter()
ex = collections.defaultdict(list)
for r in ok:
    if r['attendu'] != r['obtenu']:
        k = tuple(sorted((r['attendu'], r['obtenu'])))
        pairs[k] += 1
        ex[k].append(f"{r['titre'][:48]} ({r['attendu'][4:]}→{r['obtenu'][4:]}, {r['confiance']})")
print("PAIRES LES PLUS CONFONDUES (dans les deux sens) :")
for (a, b), n in pairs.most_common(15):
    print(f"  {n:>2}  {a[4:]} ↔ {b[4:]}")
    for e in ex[(a, b)][:2]:
        print(f"        {e}")

print("\nCATEGORIES LES PLUS FRAGILES (rappel, au moins 3 cas) :")
frag = [(good[c] / n, c, n) for c, n in tot.items() if n >= 3]
for rec, c, n in sorted(frag)[:12]:
    print(f"  {100*rec:>5.0f} %  {c[4:]}  ({good[c]}/{n})")

cats = sorted(set(tot) | {o for _, o in conf})
out = os.path.join(os.path.dirname(SRC), 'confusion.csv')
with open(out, 'w', newline='', encoding='utf8') as f:
    w = csv.writer(f)
    w.writerow(['attendu\\obtenu'] + cats)
    for a in cats:
        w.writerow([a] + [conf.get((a, o), 0) for o in cats])
print(f"\nMatrice complete : {out}")
