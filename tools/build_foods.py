#!/usr/bin/env python3
"""Merge the cloned FODMAP datasets into a single foods.json bundled with the app.

Sources (relative to the repo root, one level above FodmapApp/):
  - fodmap_list/fodmap_repo.json   per-group breakdown + safe serving sizes
  - foodmap/src/data.ts            curated list with emoji, serving sizes, notes
  - basket/*.json                  low / medium / high with daily limits

Run:  python3 FodmapApp/tools/build_foods.py
"""
import glob
import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "FodmapApp", "LowFODMAP", "Resources", "foods.json")

RATING = {"low": 0, "medium": 1, "moderate": 1, "high": 2}
GROUPS = ["fructans", "gos", "lactose", "fructose", "sorbitol", "mannitol"]

# ---------------------------------------------------------------- categories
CATEGORIES = {
    "vegetables": ("Vegetables", "🥕"),
    "fruit": ("Fruit", "🍎"),
    "grains": ("Grains, Bread & Pasta", "🍞"),
    "dairy": ("Dairy & Alternatives", "🥛"),
    "protein": ("Meat, Fish & Eggs", "🥩"),
    "legumes": ("Legumes & Soy", "🫘"),
    "nuts": ("Nuts & Seeds", "🥜"),
    "drinks": ("Drinks", "🥤"),
    "condiments": ("Sauces & Condiments", "🥫"),
    "herbs": ("Herbs, Spices & Oils", "🌿"),
    "sweeteners": ("Sugars & Sweeteners", "🍯"),
    "snacks": ("Snacks & Sweets", "🍫"),
}

LIST_CAT = {
    "Vegetables and legumes": "vegetables",
    "Fruit": "fruit",
    "Breads, Cereals, Grains and Pasta": "grains",
    "Cooking ingredients, Herbs and Spices": "herbs",
    "Drinks": "drinks",
    "Condiments": "condiments",
    "Meat & Substitutes": "protein",
    "Sweeteners": "sweeteners",
    "Nuts and Seeds": "nuts",
    "Cheese": "dairy",
    "Dairy": "dairy",
    "Milk": "dairy",
}
FOODMAP_CAT = {
    "Condiments": "condiments",
    "Drinks": "drinks",
    "Fruit": "fruit",
    "Gluten Free Cereals & Grain": "grains",
    "Meat & Alternatives": "protein",
    "Milk Alternatives": "dairy",
    "Milk Products": "dairy",
    "Nuts, Seeds, & Legumes": "nuts",
    "Snack Foods & Confectionery": "snacks",
    "Sweeteners": "sweeteners",
    "Vegetables": "vegetables",
}
BASKET_CAT = {
    "grain": "grains",
    "fruit": "fruit",
    "dairy": "dairy",
    "drink": "drinks",
    "condiment": "condiments",
    "vegetable": "vegetables",
    "spice": "herbs",
}

# keyword overrides applied last; the source datasets file many items loosely
CATEGORY_KEYWORDS = [
    (r"\b(bean|beans|lentil|lentils|chickpea|chickpeas|pea|peas|tofu|tempeh|edamame|hummus|hommus|houmous|soy ?beans?|falafel|lupin)\b", "legumes"),
    (r"\b(almond|almonds|cashew|cashews|pistachio|pistachios|walnut|walnuts|pecan|pecans|hazelnut|hazelnuts|macadamia|peanut|peanuts|chestnut|chestnuts|seed|seeds|pine nut|pine nuts|brazil nut|brazil nuts|linseed|linseeds)\b", "nuts"),
    (r"\b(chocolate|biscuit|biscuits|cake|cakes|crisps|chips|popcorn|candy|lollies|jelly|cookie|cookies|pretzel|pretzels|muesli bar)\b", "snacks"),
    (r"\b(beef|chicken|pork|lamb|turkey|fish|salmon|tuna|trout|prawns?|shrimp|mussels|oysters|crab|lobster|egg|eggs|bacon|ham|sausages?|meat|kangaroo|veal|cod|sardines?|squid|scallops?)\b", "protein"),
    (r"\b(milk|cheese|yogurt|yoghurt|cream|butter|kefir|custard|ice cream|ghee|brie|camembert|mozzarella|feta|cheddar|parmesan|ricotta|halloumi|cottage)\b", "dairy"),
    (r"\b(juice|tea|coffee|wine|beer|vodka|gin|whisky|whiskey|rum|cider|soda|cola|water|kombucha|chai|espresso|smoothie|cordial|sake|champagne|port|sherry)\b", "drinks"),
    (r"\b(sugar|syrup|honey|stevia|sucralose|aspartame|saccharine?|xylitol|sorbitol|mannitol|maltitol|maltilol|isomalt|agave|molasses|treacle|dextrose|glucose|fructose|acesulfame|erythritol)\b", "sweeteners"),
    (r"\b(oil|pepper, black|salt|cumin|turmeric|paprika|cinnamon|nutmeg|basil|mint|parsley|oregano|thyme|rosemary|coriander|dill|tarragon|chives|cardamom|clove|cloves|curry leaves|saffron|sage|bay leaves?|lemongrass|fenugreek|mustard seeds|asafoetida|garlic powder|onion powder|five spice|star anise|vanilla|allspice|chili powder|chilli powder)\b", "herbs"),
]
# words that must *not* trigger the keyword above (e.g. "peanut butter" is not dairy)
CATEGORY_EXCEPTIONS = {
    "dairy": re.compile(r"(peanut|almond|nut|coconut|seed|apple|cocoa|cacao|shea) (butter|cream|milk)|butternut|butter bean|cream of|cream cheese frosting|coconut cream|coconut milk"),
    "drinks": re.compile(r"water chestnut|watermelon|watercress|coconut water|tea tree"),
    "protein": re.compile(r"egg ?plant|eggplant|egg noodles|egg pasta|fish sauce|oyster (mushroom|sauce)|crab ?apple"),
    "legumes": re.compile(r"snow peas?|sugar snap|green peas?|peas?, fresh|fresh peas|frozen peas|split peas?|chickpea flour|besan|pea protein|green beans?|coffee beans?|vanilla bean|jelly beans?|bean sprouts|butter beans?"),
    "herbs": re.compile(r"bell pepper|pepper, (green|red|yellow)|green pepper|red pepper|sweet pepper|mint (tea|sauce)|salted|sea salt chips|peppermint tea"),
    "snacks": re.compile(r"chocolate milk|potato chips?,? plain"),
    "sweeteners": re.compile(r"honeydew|sugar snap|glucose syrup"),
}

# ---------------------------------------------------------------- aliases
ALIASES = [
    ["eggplant", "aubergine", "brinjal"],
    ["zucchini", "courgette"],
    ["bell pepper", "capsicum", "sweet pepper"],
    ["spring onion", "scallion", "green onion"],
    ["coriander", "cilantro"],
    ["rocket", "arugula"],
    ["chickpea", "garbanzo", "chana", "chick pea"],
    ["prawn", "shrimp"],
    ["rockmelon", "cantaloupe"],
    ["swede", "rutabaga"],
    ["silverbeet", "swiss chard", "chard"],
    ["bok choy", "pak choi", "bok choi"],
    ["wombok", "napa cabbage", "chinese cabbage"],
    ["corn flour", "cornflour", "cornstarch", "corn starch"],
    ["icing sugar", "powdered sugar", "confectioners sugar"],
    ["castor sugar", "caster sugar", "superfine sugar"],
    ["hummus", "hommus", "houmous"],
    ["yoghurt", "yogurt"],
    ["star fruit", "carambola"],
    ["cumquat", "kumquat"],
    ["karela", "bitter melon", "bitter gourd"],
    ["linseed", "flaxseed", "flax seed"],
    ["beetroot", "beet", "beets"],
    ["snow peas", "mangetout"],
    ["besan", "gram flour", "chickpea flour"],
    ["choko", "chayote"],
    ["gai lan", "chinese broccoli", "kai lan"],
    ["mandarin", "tangerine", "clementine"],
    ["passionfruit", "passion fruit", "granadilla"],
    ["lollies", "candy", "sweets"],
    ["biscuit", "cookie"],
    ["chips", "crisps"],
    ["ketchup", "tomato sauce"],
    ["soy sauce", "tamari", "shoyu"],
    ["cheddar", "cheddar cheese"],
    ["brie", "brie cheese"],
    ["camembert", "camembert cheese"],
    ["feta", "feta cheese"],
    ["mozzarella", "mozzarella cheese"],
    ["parmesan", "parmesan cheese"],
    ["swiss", "swiss cheese"],
    ["cow milk", "cows milk", "milk", "regular milk", "dairy milk"],
    ["sheep milk", "sheeps milk"],
    ["strawberry", "strawberries"],
    ["blueberry", "blueberries"],
    ["orange", "oranges"],
    ["tofu", "firm tofu", "tofu drained or firm"],
]

EMOJI_KEYWORDS = [
    ("garlic", "🧄"), ("onion", "🧅"), ("shallot", "🧅"), ("leek", "🧅"), ("mushroom", "🍄"), ("apple", "🍏"),
    ("pear", "🍐"), ("banana", "🍌"), ("grape", "🍇"), ("melon", "🍈"), ("watermelon", "🍉"), ("orange", "🍊"),
    ("lemon", "🍋"), ("lime", "🍋"), ("pineapple", "🍍"), ("mango", "🥭"), ("cherr", "🍒"), ("strawberr", "🍓"),
    ("blueberr", "🫐"), ("kiwi", "🥝"), ("tomato", "🍅"), ("coconut", "🥥"), ("avocado", "🥑"), ("eggplant", "🍆"),
    ("aubergine", "🍆"), ("potato", "🥔"), ("carrot", "🥕"), ("corn", "🌽"), ("chil", "🌶️"), ("pepper", "🫑"),
    ("capsicum", "🫑"), ("cucumber", "🥒"), ("lettuce", "🥬"), ("cabbage", "🥬"), ("spinach", "🥬"), ("kale", "🥬"),
    ("broccoli", "🥦"), ("peanut", "🥜"), ("bread", "🍞"), ("croissant", "🥐"), ("bagel", "🥯"), ("pancake", "🥞"),
    ("waffle", "🧇"), ("cheese", "🧀"), ("egg", "🥚"), ("bacon", "🥓"), ("beef", "🥩"), ("steak", "🥩"),
    ("chicken", "🍗"), ("turkey", "🦃"), ("pork", "🥓"), ("lamb", "🍖"), ("fish", "🐟"), ("salmon", "🐟"),
    ("tuna", "🐟"), ("trout", "🐟"), ("prawn", "🦐"), ("shrimp", "🦐"), ("crab", "🦀"), ("lobster", "🦞"),
    ("oyster", "🦪"), ("squid", "🦑"), ("rice", "🍚"), ("noodle", "🍜"), ("pasta", "🍝"), ("spaghetti", "🍝"),
    ("popcorn", "🍿"), ("salt", "🧂"), ("butter", "🧈"), ("milk", "🥛"), ("coffee", "☕"), ("tea", "🍵"),
    ("wine", "🍷"), ("beer", "🍺"), ("cider", "🍺"), ("whisk", "🥃"), ("vodka", "🥃"), ("gin", "🥃"), ("rum", "🥃"),
    ("juice", "🧃"), ("honey", "🍯"), ("syrup", "🍯"), ("sugar", "🍬"), ("chocolate", "🍫"), ("cake", "🍰"),
    ("cookie", "🍪"), ("biscuit", "🍪"), ("ice cream", "🍨"), ("oat", "🌾"), ("wheat", "🌾"), ("barley", "🌾"),
    ("rye", "🌾"), ("bean", "🫘"), ("lentil", "🫘"), ("chickpea", "🫘"), ("pea", "🫛"), ("olive", "🫒"),
    ("ginger", "🫚"), ("peach", "🍑"), ("nectarine", "🍑"), ("apricot", "🍑"), ("plum", "🍑"), ("almond", "🌰"),
    ("chestnut", "🌰"), ("walnut", "🌰"), ("nut", "🌰"), ("sweet potato", "🍠"), ("tofu", "🧈"), ("water", "💧"),
]

# Which FODMAP groups make a high/moderate food problematic. Used to enrich foods
# with no per-group data, and mirrored in the app's ingredient-label scanner.
GROUP_KEYWORDS = [
    (r"garlic|onion|shallot|leek|spring onion bulb|scallion", ["fructans"]),
    (r"wheat|rye|barley|spelt|couscous|cous-cous|semolina|bread|pasta|noodle|udon|ramen|gnocchi|biscuit|cake|croissant|muffin|cereal|bran|pastr|pizza|cracker|relish|chutney|gravy|stock|pesto", ["fructans"]),
    (r"inulin|chicory|fos\b|artichoke|asparagus|beetroot|dandelion|chamomile|fennel tea", ["fructans"]),
    (r"cashew|pistachio", ["fructans", "gos"]),
    (r"bean|lentil|chickpea|hummus|hommus|houmous|split pea|soy flour|soybean|soy bean|soya bean|lupin|falafel|black eyed", ["gos"]),
    (r"almond", ["gos"]),
    (r"milk|yog|ice cream|custard|cream cheese|ricotta|cottage|kefir|buttermilk|sour cream|condensed|evaporated|quark|mascarpone", ["lactose"]),
    (r"honey|agave|high fructose|fructose|mango|asparagus|sugar snap|fig|boysenberr|tamarillo|juice concentrate|dried fruit|raisin|sultana|date|rum|dessert wine|port|sherry", ["fructose"]),
    (r"apple|pear|watermelon|cherr", ["fructose", "sorbitol"]),
    (r"sorbitol|xylitol|maltitol|maltilol|isomalt|polyol|blackberr|apricot|peach|nectarine|plum|prune|avocado|lychee", ["sorbitol"]),
    (r"mannitol|mushroom|champignon|cauliflower|celery|sweet potato|snow pea", ["mannitol"]),
    (r"pea\b|peas\b", ["gos", "fructans"]),
]


def clean_space(s):
    return re.sub(r"\s+", " ", s).strip()


def display_name(s):
    s = clean_space(s).replace("Mushroooms", "Mushrooms").replace("Dessicated", "Desiccated")
    s = s.replace("Maltilol", "Maltitol").replace("tracle", "treacle").replace("Brussel", "Brussels")
    if s and s[0].islower():
        s = s[0].upper() + s[1:]
    return s


def norm_key(s):
    s = s.lower()
    s = s.replace("&", "and").replace("brussel ", "brussels ").replace("mushroooms", "mushrooms")
    s = re.sub(r"\(.*?\)", "", s)
    s = re.sub(r"[^a-z0-9 ]", " ", s)
    words = []
    for w in s.split():
        if w == "s":  # possessive left over from "cow's"
            continue
        w = WORD_CANON.get(w, w)
        if len(w) > 3 and w.endswith("ies"):
            w = w[:-3] + "y"
        elif len(w) > 3 and w.endswith("oes"):
            w = w[:-2]
        elif len(w) > 3 and w.endswith("s") and not w.endswith("ss") and w not in ("hummus", "couscous", "asparagus", "citrus", "molasses", "swiss"):
            w = w[:-1]
        words.append(w)
    return " ".join(words)


WORD_CANON = {"yogurt": "yoghurt", "kiwi": "kiwifruit", "chili": "chilli", "chilies": "chilli", "chillies": "chilli",
              "soya": "soy", "mushroooms": "mushrooms", "hommus": "hummus", "houmous": "hummus", "gf": "gluten free"}


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def pretty_qty(q):
    q = clean_space(q)
    q = q.replace("1/2", "½").replace("1/4", "¼").replace("1/3", "⅓").replace("2/3", "⅔").replace("3/4", "¾")
    if re.fullmatch(r"\d+", q):
        return f"{q} pieces"
    if q.startswith("max "):
        q = q[4:]
    return q.replace("squares/day", " squares/day").replace("  ", " ")


# ---------------------------------------------------------------- load
ALIAS_INDEX = {}
for _group in ALIASES:
    for _a in _group:
        ALIAS_INDEX[norm_key(_a)] = _group

foods = {}  # key -> record


def canonical(key):
    group = ALIAS_INDEX.get(key)
    if not group:
        # "zucchini courgette" (from "Zucchini / courgette") -> every word is the same alias group
        groups = {id(ALIAS_INDEX.get(w)) for w in key.split()}
        if len(groups) == 1 and ALIAS_INDEX.get(key.split()[0]):
            group = ALIAS_INDEX[key.split()[0]]
    return norm_key(group[0]) if group else key


def get(key, name):
    key = canonical(key)
    rec = foods.get(key)
    if rec is None:
        rec = {
            "name": display_name(name),
            "cat": None,
            "cat_src": 9,
            "ratings": {},
            "serving": None,
            "groups": {},
            "notes": [],
            "emoji": None,
        }
        foods[key] = rec
    return rec


def add_note(rec, note):
    note = clean_space(note)
    if not note:
        return
    if not note.endswith("."):
        note += "."
    note = note[0].upper() + note[1:]
    if note.lower() not in [n.lower() for n in rec["notes"]]:
        rec["notes"].append(note)


# 1. fodmap_list — most detailed, highest priority for name/category
for x in json.load(open(os.path.join(ROOT, "fodmap_list", "fodmap_repo.json"))):
    rec = get(norm_key(x["name"]), x["name"])
    rec["name"] = display_name(x["name"])
    rec["ratings"]["fodmap_list"] = RATING[x["fodmap"]]
    rec["cat"], rec["cat_src"] = LIST_CAT[x["category"]], 0
    if x.get("qty"):
        rec["serving"] = pretty_qty(x["qty"])
    d = x.get("details") or {}
    if d:
        if d.get("oligos"):
            # the dataset lumps fructans + GOS; attribute to GOS for legumes, fructans otherwise
            g = "gos" if re.search(r"bean|lentil|chickpea|pea|hummus|hommus|soy", x["name"].lower()) else "fructans"
            rec["groups"][g] = max(rec["groups"].get(g, 0), d["oligos"])
        if d.get("fructose"):
            rec["groups"]["fructose"] = d["fructose"]
        if d.get("polyols"):
            g = "mannitol" if re.search(r"mushroom|cauliflower|celery|sweet potato|snow pea", x["name"].lower()) else "sorbitol"
            rec["groups"][g] = d["polyols"]
        if d.get("lactose"):
            rec["groups"]["lactose"] = d["lactose"]
        rec["groups_known"] = True

# 2. foodmap — curated, has emoji + serving sizes + notes
t = open(os.path.join(ROOT, "foodmap", "src", "data.ts")).read()
t = t[t.index("export const data"):]
pat = re.compile(r'\{\s*name: "(.*?)",\s*category: "(.*?)",\s*avoid: (true|false),\s*measurement: "(.*?)",\s*notes: "(.*?)",(?:\s*emoji: "(.*?)",)?\s*\}', re.S)
for name, cat, avoid, meas, notes, emoji in pat.findall(t):
    if name == "Honeydew" and cat == "Sweeteners":
        name = "Honey"  # data-entry slip in the source
    key = norm_key(name)
    rec = get(key, name)
    # the source lists some items twice (e.g. Leek as green-tops-ok and bulb-avoid)
    prev = rec["ratings"].get("foodmap")
    r = 2 if avoid == "true" else 0
    rec["ratings"]["foodmap"] = r if prev is None else min(prev, r)
    if rec["cat_src"] > 1:
        rec["cat"], rec["cat_src"] = FOODMAP_CAT[cat], 1
    if meas and meas.lower() not in ("green only",):
        m = meas.replace("> ", "More than ").replace("Up to ", "")
        if avoid == "true" and m.startswith("More than"):
            add_note(rec, f"High in FODMAPs in servings {m[0].lower() + m[1:]}")
        elif not rec["serving"]:
            rec["serving"] = pretty_qty(m)
    elif meas.lower() == "green only":
        add_note(rec, "Only the green part is low FODMAP")
    add_note(rec, notes)
    if emoji:
        rec["emoji"] = emoji

# 3. basket — adds medium ratings and daily limits
for f in sorted(glob.glob(os.path.join(ROOT, "basket", "*.json"))):
    for name, x in json.load(open(f)).items():
        rec = get(norm_key(name), name)
        rec["ratings"]["basket"] = RATING[x["fodmap"]]
        if rec["cat_src"] > 2:
            rec["cat"], rec["cat_src"] = BASKET_CAT.get(x["category"], "condiments"), 2
        if x.get("condition"):
            cond = pretty_qty(x["condition"])
            if not re.search(r"\d|½|¼|⅓|small", cond):
                add_note(rec, cond)
            elif not rec["serving"]:
                rec["serving"] = cond
        add_note(rec, x.get("note", ""))

# ---------------------------------------------------------------- merge
alias_index = ALIAS_INDEX

out = []
used_ids = set()
for key, rec in foods.items():
    vals = list(rec["ratings"].values())
    lo, hi = min(vals), max(vals)
    if lo == hi:
        rating = lo
    elif hi - lo == 2:
        rating = 1  # one says low, another high -> caution
    else:
        rating = hi  # low vs moderate -> moderate; moderate vs high -> high
    disagree = lo != hi

    name_l = rec["name"].lower()
    cat = rec["cat"] or "condiments"
    for pattern, c in CATEGORY_KEYWORDS:
        if re.search(pattern, name_l) and not (c in CATEGORY_EXCEPTIONS and CATEGORY_EXCEPTIONS[c].search(name_l)):
            # only override loosely-sourced categories, or obviously wrong ones
            if rec["cat_src"] >= 2 or (cat in ("dairy", "condiments", "grains") and c in ("legumes", "nuts", "protein", "snacks")) \
                    or (cat in ("vegetables", "nuts") and c == "legumes"):
                cat = c
            break

    groups = dict(rec["groups"])
    if rating > 0 and not groups:
        for pattern, gs in GROUP_KEYWORDS:
            if re.search(pattern, name_l):
                for g in gs:
                    groups[g] = rating
                break

    emoji = rec["emoji"]
    if not emoji:
        for kw, e in EMOJI_KEYWORDS:
            if re.search(r"\b" + kw, name_l):
                emoji = e
                break
    emoji = emoji or CATEGORIES[cat][1]

    aliases = set()
    for w in [key] + key.split():
        if w in alias_index:
            for a in alias_index[w]:
                aliases.add(a)
    for group in ALIASES:
        for a in group:
            if re.search(r"\b" + re.escape(a) + r"\b", name_l):
                aliases.update(group)
    aliases.discard(name_l)

    fid = slug(rec["name"])
    while fid in used_ids:
        fid += "-2"
    used_ids.add(fid)

    out.append({
        "id": fid,
        "name": rec["name"],
        "category": cat,
        "emoji": emoji,
        "rating": ["low", "moderate", "high"][rating],
        "serving": rec["serving"],
        "groups": {g: groups[g] for g in GROUPS if groups.get(g)},
        "notes": rec["notes"],
        "aliases": sorted(aliases),
        "sources": sorted(rec["ratings"].keys()),
        "sourcesDisagree": disagree,
    })

out.sort(key=lambda f: f["name"].lower())
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w") as fh:
    json.dump({
        "categories": [{"id": k, "name": v[0], "emoji": v[1]} for k, v in CATEGORIES.items()],
        "foods": out,
    }, fh, ensure_ascii=False, indent=1)

from collections import Counter
print(f"wrote {len(out)} foods -> {OUT}")
print(Counter(f["rating"] for f in out))
print(Counter(f["category"] for f in out))
print("disagreements:", sum(f["sourcesDisagree"] for f in out))
print("multi-source:", sum(len(f["sources"]) > 1 for f in out))
