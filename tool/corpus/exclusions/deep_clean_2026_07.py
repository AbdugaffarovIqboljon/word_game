#!/usr/bin/env python3
"""WS-DC: 2026-07 answer-pool deep clean — curated removal list.

Validates every term against the current answer pool, then appends the
categorised block to non_answers.txt (idempotent: skips terms already there).
Run once; the list itself is the reviewable artifact for owner sign-off.
Borderline keeps (deeply-assimilated everyday loans allowed in tier 1-2) are
listed in BORDERLINE_KEEP for the report — they are NOT excluded.
"""

import os

HERE = os.path.dirname(os.path.abspath(__file__))

# --- owner-requested (explicit) ---------------------------------------------
EXPLICIT = ["dalla", "bobiy", "vosit", "iddao", "aqoid", "dungan", "chuvash",
            "miting", "balon", "manot"]

# --- Russian / European raw loans (science, tech, objects, sports, food) -----
RU_EU_LOANS = """
abort adres afisha akril albit albom aldol algol alibi allil amorf ampel amper
ampir angina aorta apart aprel areal arena ariya arsen arshin artel arxiv astma
astra atlet avans avtor aktor bagaj balet balka banjo barbi barin barit bariy
barja barka baron batat baton bayan bazal bazis bekon beret betel beyza birja
bitum bizon boyar bozon bubon bufer bufet buket bulla bulon butik butil butsa
buxta chagas chayka dafna dayka debay debit dekan delta demon derbi derma detal
dipol disko dizel dogma domen domna donna donor doping dukat durang epoxa elita
eskiz etika etnos etyud fagot faner fanta fasad fauna fenil fenol ferma fermi
fikus filtr final finish firma fizik fokus folat folga fonon forel forma forum
furan galit gamma gavan gayka geliy gemma genom geoid getto gidra girish goboy
gumin gumus gusar gutta ikona indiy iprit ivrit iyena jabra jersi jilet jiraf
joker jokey kabel kadet kagor kakar kalka kamer kamin kanat kanna kanoe kanon
kanva kapot karat kargo karma karst kasta kater katod kazus kifoz kinda kirka
kisel kista koala kobra kodak kolba kolit kolon konik konki konus kopra korol
koyot kubik kubok kucher kulon kupon kuzov lager lapsha largo lasso latun lazer
legat lemur liman limfa limit linza lizin logos lokus losos magma major maket
makro malva mamma manat manej manna manor manta manto manul marja marli marta
marti mason massa mayor mazut messa metan metil metis metod meyoz milya minor
minus mitan mitoz model modem monax morze motel motet motiv movut neper netto
nikel nimfa nomen nomos norka norma novus obraz obzor ocherk ofort ofset oksid
okrug oktan olein oliva omega oniks opera opium orden order organ pafos panno
parad parez parik parol parom pasta pauza pedal pekan pemza penya petit piano
pikap piket pilot pinta pirit pirog piton pitsa pixta poema pogon polip polis
polka porox potok poxod puding pulpa punkt purin radar radiy radon ralli raman
rampa rancho rastr raund raxit reket renin reniy renta rezba rezus richag
riksha rinit rolik rondo rotor royal rubin rulet rulon rutil rutin salto sambo
sarja satin sauna sazan seans sedan sekta selen senat serin seriy seroz setse
sezon seziy sifon sigma singal sinod sinus siren sista sobol sobor sokol sonet
soplo silos sudak sudya sutka tablo tabor tabun talon taran tayga teizm tekst
tembr tenor tetis tigel timus tiraj tiran titul tobin tokar tomat tonik topaz
toriy totem tovar tumba turne ukrop ustav uyezd vafli valet valik valin vater
veber venoz vesta villa vinil viola viski vokal volta ximik xinin xitin xobbi
xolin xorda xunta xutor yakor yarus yashik yashma yaxta yenot yevro yukka yumor
zebra zefir zenit zombi zonal shanba_KEEP shinel shosse shassi shayba shashka
shaman shamot shankr shixta shekel sharik shaxta_KEEP
"""

# --- ethnonyms / tribes / peoples (proper-noun class) -------------------------
ETHNONYMS = """
abxaz aleut chibcha evenk fulbe gurji laqay latish mayya mongol nanay noʻgʻay
noʻgʻoy olmon olchin qiyot qoʻmiq semit tagal talish tangut uyshun xakas xanti
xausa habash bayot
"""

# --- person names / titles / places that leaked back in ----------------------
NAMES_PLACES = """
abror akram amiri aziza begim bobir bobov elbek elxon erjon erkan eshvoy firuz
fotih jobir jovid matin molik munir muhib mufid najib nazir nigor nisor niyoz
nozim nuriy odina orifa oygul parpi rafiq raisa rashod rasul rifat rogʻib salor
shomil solim surur turob vodil chinoz buxor balxi choʻbin chokar koʻhak oqgul
oqkoʻl oqsuv oqtosh oqbosh oʻzboʻy yovon zakiy zokir zarin yamin xalaf farah
gʻoziy hoziq irshod ismat soqiy voliy vosil
"""

# --- religious proper nouns / divine names / rites ---------------------------
RELIGIOUS = """
olloh iblis yosin zabur ashuro miraj xoliq mavlo zuhal majus sirot
"""

# --- Arabic plurals & literary/prosody terms (not concrete noun stems) -------
ARABIC_LITERARY = """
abjad ahbob ahkom ahmar ahsan amlok asror axbor bayoz funun futuh hazaj isnod
izofa jazba kadar kalan kisva kunya lozim matla nujum najas naqib navob nihon
nisba nozil nukta_KEEP rajaz ramal saboh sabur salaf saqqo shuaro sidra suluk
ulamo ushshoq uzlat_KEEP valad vallo vojib volid zabar zuhur muboh girya hojib
huqna aqrab hamal javzo dinor
"""

# --- Persian/Tajik-only forms & non-standard variants -------------------------
PERSIAN_VARIANTS = """
bahar basta bilik chahor dalli digar donish falon ganda hazor hilla kalon
kuloh_KEEP miyon namak nihol_KEEP padar poshsho rabod ravot sahil sufiy sutun
tabar tamal xanda_KEEP xotun zabon zinda nomoz doyra mavze mugʻom shaydo
"""

# --- inflected / non-stem forms that leaked (stem-only violation) -------------
INFLECTED = """
akasi bargi bolam boshcha bogʻot boʻlis boʻluk haqqi ichdan ichida ichiga jonim
koʻkcha marza_KEEP misli oylar sayli sharcha shoʻrcha tilda tongda tunda yemak
"""

# --- junk / unidentifiable / not real Uzbek lexemes ---------------------------
JUNK = """
assit agava agora akula abbat afsar afshar arxey aymoq bachki bakra_KEEP barak_KEEP
barda bardi barik barot bovar burak chetki chiyal chuhra cherik erlik ertan
fincha girih_KEEP karash katar novak qutchi saban saros sulla tabas tabla takya
tegin tolib erman_KEEP yelik yakan_KEEP
"""

# --- borderline KEEPS: deeply-assimilated everyday loans, allowed tier 1-2 ----
BORDERLINE_KEEP = """
adyol atlas banan banka beton bilet bochka bomba bogʻcha choʻtka choʻyan damba
divan doska doʻppi ekran fonar fonus garaj gilos kakao kalish kanal kanop karam
karta kassa kefir kepka kurka lampa langar lenta lider limon marka maska mayoq
mebel medal menyu metro minut motor muzey nasos okean palto pechka pochta poxol
qarta radio ramka rejim robot ruchka salat salon shapka shifer sirop sumka
summa taksi teatr tonna tufli turma vagon vanna video vilka yubka zavod
"""


def parse(block):
    return [w for w in block.split() if not w.endswith("_KEEP")]


def main():
    answers = set()
    with open(os.path.join(HERE, "..", "out", "answers.txt"), encoding="utf-8") as f:
        answers = {line.strip() for line in f if line.strip()}

    sections = [
        ("owner-requested explicit exclusions (2026-07 deep clean)", EXPLICIT),
        ("Russian / European raw loans", parse(RU_EU_LOANS)),
        ("ethnonyms / peoples", parse(ETHNONYMS)),
        ("person names / titles / places (2nd sweep)", parse(NAMES_PLACES)),
        ("religious proper nouns / rites (2nd sweep)", parse(RELIGIOUS)),
        ("Arabic plurals / literary & prosody terms", parse(ARABIC_LITERARY)),
        ("Persian-Tajik-only forms / non-standard variants", parse(PERSIAN_VARIANTS)),
        ("inflected non-stem forms", parse(INFLECTED)),
        ("junk / non-lexemes", parse(JUNK)),
    ]

    existing = set()
    non_ans = os.path.join(HERE, "non_answers.txt")
    with open(non_ans, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                existing.add(line)

    all_terms, missing, dupes = [], [], []
    out_lines = ["", "# ===== 2026-07 deep clean (WS-DC): pure-Uzbek answer pool ====="]
    for title, terms in sections:
        fresh = []
        for t in sorted(set(terms)):
            if t in existing or t in all_terms:
                dupes.append(t)
                continue
            if t not in answers:
                missing.append(t)
                continue
            fresh.append(t)
            all_terms.append(t)
        if fresh:
            out_lines.append(f"# --- {title} ---")
            out_lines.extend(fresh)

    print(f"answers pool: {len(answers)}")
    print(f"new exclusions: {len(all_terms)}")
    print(f"already excluded (skipped): {len(dupes)} {sorted(set(dupes))}")
    print(f"NOT in answer pool (skipped): {len(missing)} {sorted(missing)}")

    borderline = sorted(set(parse(BORDERLINE_KEEP)))
    bl_missing = [w for w in borderline if w not in answers]
    print(f"borderline keeps: {len(borderline)} (not in pool: {bl_missing})")

    with open(non_ans, "a", encoding="utf-8") as f:
        f.write("\n".join(out_lines) + "\n")
    print(f"appended to {non_ans}")


if __name__ == "__main__":
    main()
