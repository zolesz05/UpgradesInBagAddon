# Moteve Upgrade

**Moteve Upgrade** egy World of Warcraft addon a WoW Forever klienshez. A táskában kiemeli azokat a használható felszereléseket, amelyek a kiválasztott kaszt- és szerepkörprofil statisztikasúlyai szerint jobbak a jelenleg viselt tárgyaknál.

**Aktuális verzió: 0.2.2**

[Legfrissebb addon letöltése (ZIP)](downloads/MoteveUpgrade.zip?raw=true)

A `downloads` mappában csak a legfrissebb telepíthető `MoteveUpgrade.zip` szerepel. Frissítéskor ugyanaz a letöltési link használható.

## Telepítés

1. Töltsd le és csomagold ki a fenti ZIP-et.
2. Másold a `MoteveUpgrade` mappát a játék `Interface/AddOns/` könyvtárába.
3. A karakterválasztón engedélyezd a **Moteve Upgrade** addont, majd lépj be.
4. Írd be: `/mup profile`, és a felsorolt számokkal válaszd ki a szerepkörödet, például `/mup profile 2`.
5. Nyisd meg a táskát a lehetséges fejlesztések megtekintéséhez.

```text
Interface/
└── AddOns/
    └── MoteveUpgrade/
        ├── MoteveUpgrade.toc
        ├── MoteveUpgrade.lua
        ├── Weights.lua
        └── README.txt
```

A mappanevet tartsd meg: a `MoteveUpgrade.toc` közvetlenül a `MoteveUpgrade` mappában legyen. Ha egy új addon nem jelenik meg a listában, indítsd újra a klienst. Meglévő addon frissítése után `/reload` használható. A `WTF` könyvtárat tartsd meg, mert abban vannak a mentett profilválasztások és beállítások.

## Mit jelöl a táskában?

- Vastag türkiz keret, pulzáló külső ragyogás és enyhe türkiz színezés az upgrade tárgyakon.
- Százalékos jelvény a tárgyhely sarkában, például **+12%**.
- **ÚJ / NEW** jelzés, ha az adott felszerelési hely üres.
- Kiegészítő sor a tárgy súgóbuborékában a profil nevével, a számított javulással és a lecserélendő felszereléssel.
- Azonos súlyozott statoknál a több páncél nyerhet, **+N% ARM** jelzéssel.
- Csak olyan tárgyakat emel ki, amelyeket a játék használhatónak jelez a karakter számára.

A százalék a súlyozott tárgypontszám különbségét jelenti; nem közvetlen DPS- vagy gyógyításnövekedés.

## Hogyan hasonlít össze?

A tárgy statisztikáit a kiválasztott profil súlyaival pontozza, majd az eredményt a viselt felszereléssel veti össze. Az alap küszöb **1%**: ez alatt nem jelöli upgrade-ként a tárgyat. A küszöb 0–100% között állítható, például `/mup threshold 2`.

| Tárgytípus | Összehasonlítás |
| --- | --- |
| Általános páncél és felszerelés | Az adott helyen viselt tárggyal |
| Gyűrű / trinket | A két felszerelt tárgy közül a gyengébbel |
| Kétkezes fegyver | A főkéz és mellékkéz együttes pontszámával |
| Egykezes fegyver, amikor kétkezes van felszerelve | Nem készít közvetlen összehasonlítást |
| Üres felszerelési hely | A hordható tárgyat új fejlesztésnek jelöli |

## Profilok és súlyok

A kaszt szerinti profilok a [Weights.lua](MoteveUpgrade/Weights.lua) fájlban találhatók. A szerepkört **kézzel kell kiválasztani**, a specializációt nem ismeri fel automatikusan.

| Kaszt | Elérhető profilok |
| --- | --- |
| Warrior | Arms / Fury DPS, Protection Tank |
| Paladin | Holy, Retribution, Protection |
| Hunter | Ranged DPS |
| Rogue | Melee DPS |
| Priest | Holy / Discipline, Shadow |
| Shaman | Elemental, Enhancement, Restoration |
| Mage | Caster DPS |
| Warlock | Caster DPS |
| Druid | Balance, Feral Cat, Feral Bear, Restoration |

Az alap súlyok kiindulási értékek. A `/mup weights` megmutatja az aktuális értékeket, a `/mup weight hit 15` például a hit súlyát állítja. A `/mup resetweights` visszaállítja az alap súlyokat.

## Parancsok

| Parancs | Művelet |
| --- | --- |
| `/mup` | Aktív profil és parancsok |
| `/mup profile` | A kaszthoz tartozó profilok listája |
| `/mup profile 2` | A második profil kiválasztása |
| `/mup weights` | Aktuális súlyok kiírása |
| `/mup weight hit 15` | Egy stat súlyának módosítása |
| `/mup resetweights` | Alap súlyok visszaállítása |
| `/mup threshold 2` | Minimum 2%-os javulás jelölése |
| `/mup glow on` / `/mup glow off` | Táskajelölés kapcsolása |
| `/mup badge on` / `/mup badge off` | Százalékos jelvény kapcsolása |
| `/mup tooltip on` / `/mup tooltip off` | Súgóbuborék-kiegészítés kapcsolása |
| `/mup diag` | Profil, látott tárgyak és táskagombok, upgrade-ek és utolsó hiba |

A `/moteveupgrade` a `/mup` alternatívája. A mentések neve `MoteveUpgradeDB` és karakterenként `MoteveUpgradeChar`.

## Kompatibilitás és korlátok

A célkliens **WoW Forever**, a TOC Interface-értéke **16001**.

- A pontozás statisztikasúlyokra épül, nem harci szimuláció.
- A procokat, használható tárgyhatásokat, szettbónuszokat és stat-capeket nem számolja.
- A tárgyak „Equip:” sorainak szöveges feldolgozása angol klienshez készült.
- Más WoW-verziókkal és eltérő táskafelületekkel való működés nincs igazolva.

A csomag a jelenleg telepített **0.2.2-es verzió** változatlan másolata. Feltöltés előtt a fájlok azonosságát, a Lua-szintaxist és a ZIP tartalmát ellenőriztük. A tényleges táskajelölést és tárgyértékelést a feltöltéskor nem teszteltük újra.

## Hibajelentés és forrás

Hibát az [Issues oldalon](https://github.com/zolesz05/UpgradesInBagAddon/issues) jelezhetsz. Add meg a kliens és az addon verzióját, a kasztot és profilt, az érintett tárgyak nevét, a viselt felszerelést és az elvárt eredményt. A `/mup diag` kimenete és képernyőkép segíthet.

- [Teljes addonforrás](MoteveUpgrade/)
- [Részletes használati leírás](MoteveUpgrade/README.txt)
- [Profilok és alap súlyok](MoteveUpgrade/Weights.lua)

## Csomag frissítése

A repository gyökeréből:

```sh
python tools/package_addon.py
```

A csomagoló ellenőrzi a TOC bejegyzéseit és a ZIP tartalmát, lecseréli a `downloads/MoteveUpgrade.zip` fájlt, és eltávolítja a korábbi verziószámos addoncsomagokat ebből a mappából. A forrást, a ZIP-et és a README-t együtt kell feltölteni.
