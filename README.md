# Low FODMA

A SwiftUI app for living on a low FODMAP diet: look up foods fast, check whole meals and ingredient labels, track symptoms, and work through the reintroduction phase.

## Features

**Foods**

- Instant search over 700+ foods, merged from the three open-source datasets in this folder, with typo tolerance ("brocoli", "strawberies") and regional names (aubergine/eggplant, capsicum/bell pepper, courgette/zucchini…).
- Traffic-light ratings (low / moderate / high) with safe serving sizes.
- Breakdown by FODMAP group (fructans, GOS, lactose, fructose, sorbitol, mannitol).
- Low FODMAP swaps (garlic → garlic-infused oil, chives; honey → maple syrup…).
- Browse by category, favourites, recently viewed and a "common traps" shelf.
- Record your own reaction to a food ("works for me" / "some symptoms" / "avoid"). It overrides the general rating everywhere in the app.

**Check**

- **Meal check:** add every ingredient and get a verdict for the whole plate. It warns about FODMAP stacking, where two moderate foods from the same group add up to a high serve.
- **Label scanner:** point the camera at an ingredient list (live text on device), pick a photo, or paste the text. Hidden triggers are flagged: onion and garlic powder, inulin, chicory root, honey, HFCS, sorbitol, milk solids, "natural flavours" and more. Safe look-alikes are recognised: garlic-infused oil, lactose-free dairy, soy lecithin, glucose syrup.

**Diary**

- Log meals (from the food guide or free text) and symptom check-ins: bloating, pain, gas, nausea, stress and Bristol stool type.
- Insights: a 14-day symptom chart and "possible triggers", meaning foods that tend to show up in the 24 hours before bad check-ins.
- CSV export to share with your dietitian.

**Reintroduce**

- Guided 3-day challenges for each FODMAP group (sorbitol, lactose, fructose, mannitol, fructans × wheat/garlic/onion, GOS) with increasing doses.
- Daily reminders, stop guidance, a 3-day washout tracker and a personal tolerance profile. The profile then personalises food ratings, e.g. high-lactose foods show as OK if you passed the lactose challenge.

**More**

- Shopping list that flags high FODMAP items as you type.
- Learn guides: what FODMAPs are, the 3-step diet, reading traffic lights, hidden FODMAPs, eating out, easy swaps.
- Diet-phase setting and onboarding.

## Running

Open `LowFODMAP.xcodeproj` in Xcode 26 and run on an iPhone or simulator (iOS 17+). The project uses synchronized folders, so any new file under `LowFODMAP/` is picked up automatically.

To try the camera scanner on your own phone, pick your team under _Signing & Capabilities_.

The merge script:

- dedupes foods across sources by normalised name and known aliases;
- unifies the categories;
- keeps serving sizes and notes;
- where sources disagree, picks the more cautious rating and flags it;
- infers FODMAP groups for high-rated foods that have no per-group data.

## Disclaimer

Ratings come from community datasets. They are not Monash University data and not medical advice.
