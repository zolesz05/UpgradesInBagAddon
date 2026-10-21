Moteve Upgrade 0.2.2 - WoW Forever (Interface 16001)

Telepites
  Masold a "MoteveUpgrade" mappat a WoW Forever Interface\AddOns mappajaba.

Mit csinal
  - A taskaban az upgrade itemek vastag teal keretet, a slot kore kifele
    sugarzo, lukteto glow-t es enyhe teal szinezest kapnak.
  - A bal felso sarokban badge mutatja, mennyivel jobb: pl. "+12%".
    "NEW" = arra a slotra most nincs semmi felveve.
  - Az item tooltipjeben megjelenik: "Moteve  <profil>   +12.4% upgrade",
    alatta pedig, hogy melyik felvett itemet valtana.
  - Csak olyan itemet jelol, amit a jatek szerint hasznalni tudsz
    (a tooltipben nincs piros sor: class, pancel-/fegyvertipus, szint).

Hogyan dont
  Minden statot sulyoz a classod profilja szerint (Weights.lua), es osszeveti
  azzal, ami rajtad van. Gyuruk/trinketek: a gyengebbikhez. Ket kezes fegyver:
  a fo- es mellekkez osszegehez. Egykezes vs. felvett ket kezes: nem hasonlit.
  A sulyok kiindulo ertekek, nem szimulaciok - finomithatod oket.

Parancsok: /mup
  /mup profile [n]         szerep valasztasa (pl. Warrior: DPS vagy Tank)
  /mup weights             aktualis sulyok
  /mup weight hit 15       egy suly modositasa
  /mup resetweights        alapertekek
  /mup threshold 2         minimum %, ami mar upgrade-nek szamit (alap: 1)
  /mup glow on|off         taska-jeloles
  /mup badge on|off        szazalek-badge a slot sarkaban
  /mup tooltip on|off      tooltip sor

Korlatok
  - Procokat, on-use hatasokat, set bonuszokat es stat-capeket nem szamol.
  - A spect nem ismeri fel automatikusan: a profilt egyszer allitsd be.
  - Az "Equip:" sorok szovegbol valo kiolvasasa angol klienshez keszult.

HIBAKERESÉS
  /mup diag  megmutatja a profilt, hány táska-gombot és tárgyat lát az addon, hány upgrade-et
             talált, és az utolsó hibát.

ÜRES HELY ÉS ARMOR
  - Ha egy helyen nincs felszerelt tárgyad, minden hordható tárgy upgrade-nek számít ("ÚJ").
  - Ha két tárgy statjai egyformák (alacsony szinten gyakran csak armor van rajtuk),
    a több armor nyer ("+N% ARM" jelzés).
