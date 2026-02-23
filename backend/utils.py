"""
LLM call layer — priority order:
  1. Groq cloud API  (free, any city, no install — needs GROQ_API_KEY in .env)
  2. Ollama HTTP API (local, any city — needs ollama running on port 11434)
  3. Smart mock      (offline fallback, only works well for pre-loaded cities)
"""
import os
import json
import subprocess
import urllib.request
import urllib.error
from dotenv import load_dotenv

_ENV_PATH = os.path.join(os.path.dirname(__file__), "..", ".env")
load_dotenv(_ENV_PATH)  # reads .env from project root

# ── Config ────────────────────────────────────────────────────────────────────
def get_groq_key():
    load_dotenv(_ENV_PATH, override=True)
    return os.getenv("GROQ_API_KEY", "")

GROQ_MODEL     = "llama-3.3-70b-versatile"
GROQ_API_URL   = "https://api.groq.com/openai/v1/chat/completions"

OLLAMA_API_URL = "http://127.0.0.1:11434/api/generate"
def get_ollama_model():
    load_dotenv(_ENV_PATH, override=True)
    return os.getenv("OLLAMA_MODEL", "mistral")

# Mode Switch
def get_prefer_local():
    load_dotenv(_ENV_PATH, override=True)
    return os.getenv("PREFER_LOCAL_LLM", "true").lower() == "true"

# Vision Models
def get_groq_vision_model():
    load_dotenv(_ENV_PATH, override=True)
    return os.getenv("GROQ_VISION_MODEL", "llama-3.2-11b-vision-preview")

def get_ollama_vision_model():
    load_dotenv(_ENV_PATH, override=True)
    return os.getenv("OLLAMA_VISION_MODEL", "llama3.2-vision")

# ── Real city knowledge (offline fallback only) ───────────────────────────────
CITY_DATA = {
    "jaipur": {
        "landmarks": [
            "Amber Fort (Amer Fort) — 16th-century Rajput hill fort, 11 km from city; arrive by 8am to avoid crowds",
            "Hawa Mahal — 5-storey 953-window honeycomb façade; best photographed from the tea stall opposite on Badi Choupar",
            "City Palace — royal residence turned museum with Mubarak Mahal, Diwan-i-Khas; Maharaja still lives in private quarters",
            "Jantar Mantar — UNESCO World Heritage astronomical observatory; 19 instruments built by Sawai Jai Singh II in 1734",
            "Nahargarh Fort — best sunset viewpoint over the Pink City; rooftop café 'Padao' with panoramic views",
            "Jaigarh Fort — houses 'Jaivana', world's largest wheeled cannon; connected to Amber by underground passage",
            "Albert Hall Museum — Indo-Saracenic building; largest Egyptian mummy collection in India, ₹40 entry",
            "Panna Meena Ka Kund — stunning 16th-century geometric step-well, virtually tourist-free before 8am",
            "Galtaji (Monkey Temple) — natural spring kunds, thousands of monkeys, 10 km east of city",
        ],
        "street_food": [
            "Pyaaz ki Kachori at Rawat Misthan Bhandar, Station Road (since 1944) — crispy onion-stuffed pastry, ₹20 each, opens 6am",
            "Lassiwala's thick rabri lassi, Shop No. 312 MI Road (since 1944) — closes when it runs out, go before noon",
            "Dal Baati Churma thali at Chokhi Dhani village resort, Tonk Road — authentic Rajasthani feast on charpoys, ₹600",
            "Mirchi Bada (giant green chilli fritter) at Samera Bada Wala near Tripolia Gate, ₹15 each",
            "Ghewar (disc-shaped milk sweet) at LMB — Laxmi Misthan Bhandar, Johari Bazaar, ₹40/piece",
            "Makhaniya Lassi (saffron + malai) at Kishan Lal Govind Narayan Agarwal, Tripolia Bazaar",
        ],
        "markets": [
            "Johari Bazaar — Jaipur's jewellery street, kundan-meenakari sets, polki; negotiate hard",
            "Bapu Bazaar — block-print dupattas, juttis (mojris), bangles at factory prices",
            "Tripolia Bazaar — lac bangles, brass items; watch artisans work in tiny roadside workshops",
            "Rajasthali Govt. Emporium, MI Road — authentic crafts at fixed, fair prices; blue pottery, textiles",
        ],
        "hidden_gems": [
            "Panna Meena Ka Kund step-well — almost always empty, stunning chevron-pattern geometry, free entry",
            "Sisodiya Rani Bagh — terraced Mughal garden with painted murals, nearly zero tourists, ₹20 entry",
            "The Wind View Café opposite Hawa Mahal — local chai ₹15, free balcony view of the palace façade",
            "Early-morning cycle-rickshaw ride through the old walled city lanes before 7am — ₹50 for 30 min",
        ],
    },
    "jaisalmer": {
        "landmarks": [
            "Jaisalmer Fort (Sonar Quila, Golden Fort) — one of world's only living forts; 4,000+ people reside inside",
            "Patwon Ki Haveli — 5 interconnected havelis with intricate yellow sandstone carvings, 1805 CE",
            "Gadisar Lake — 14th-century reservoir; sunrise boat ride ₹50, painted ghats, temple complex",
            "Sam Sand Dunes — 45 km west; camel safari at sunset ₹300, overnight desert camp experience",
            "Kuldhara Abandoned Village — 400-year-old deserted Paliwal Brahmin village; eerie, atmospheric",
            "Bada Bagh — royal cenotaphs (chhatris) of Jaisalmer rulers; best sunset photography spot",
            "Thar Heritage Museum — 50,000+ personal artefacts by local historian Mr. Sharma, ₹50 entry",
        ],
        "street_food": [
            "Mirchi Bada at stalls inside Jaisalmer Fort near the Jain temple complex, ₹15 each",
            "Ker Sangri (desert beans & berries curry) at Trio Restaurant near Fort entrance",
            "Rajasthani Thali (unlimited) at Desert Boy's Dhani — seated on charpoys, ₹150",
            "Mawa Lassi (thick, sweet) at Hotel Pleasant Haveli's rooftop café",
            "Camel milk ice cream at the stall near Sam Dunes base camp",
        ],
        "markets": [
            "Sadar Bazaar (Gandhi Chowk) — silver jewellery, mirror-work bags, camel leather goods",
            "Fort lanes — hand-stitched camel leather journals, pashmina stoles, puppet sets",
        ],
        "hidden_gems": [
            "Vyas Chhatri (cremation towers) — climb at sunset for 360° unobstructed desert panorama, free, zero tourists",
            "Inside the Fort at 6am — watch locals sweep streets and open temples before tourists arrive",
        ],
    },
    "delhi": {
        "landmarks": [
            "Red Fort (Lal Qila) — Mughal marvel on river Yamuna; Sound & Light show evenings (₹60 Hindi, ₹80 English)",
            "Qutub Minar — world's tallest brick minaret (72.5m), 12th century, UNESCO; arrive before 9am",
            "Humayun's Tomb — UNESCO site, direct inspiration for the Taj Mahal; sunrise is breathtaking",
            "India Gate — war memorial; evening bustle, children playing, bhel puri vendors all around",
            "Agrasen Ki Baoli — 60-step haunted step-well hidden in the heart of Connaught Place, free",
            "Mehrauli Archaeological Park — 100+ monuments spread across one park, almost zero tourists",
            "Jama Masjid — India's largest mosque; climb minaret for Old Delhi aerial view, ₹100",
            "Lodi Garden — ancient tombs amid manicured gardens, morning joggers and picnickers, free",
        ],
        "street_food": [
            "Paranthe Wali Gali, Chandni Chowk — 200-year-old eateries; aloo-mooli-paneer stuffed paranthas with rabdi, ₹50",
            "Karim's Restaurant, Gali Kababian near Jama Masjid (since 1913) — mutton burra, seekh kebab",
            "Chole Bhature at Sita Ram Diwan Chand, Paharganj (since 1950) — open only till noon, always a queue",
            "Jalebi from Old Famous Jalebi Wala, Dariba Kalan, Chandni Chowk — crispy, fresh, ₹80/250g",
            "Chaat at Natraj Dahi Bhalle Wala, Chandni Chowk — dahi bhalle + aloo tikki",
        ],
        "markets": [
            "Chandni Chowk — silver, spices, electronics, saris; arrive at 9am before it becomes chaos",
            "Dilli Haat, INA — 30+ states' crafts under one roof, government-run, fixed price, ₹30 entry",
            "Sarojini Nagar Market — export surplus fashion at factory prices; Saturdays are busiest",
            "Janpath Market — Tibetan market near Connaught Place, handmade jewellery, vintage finds",
        ],
        "hidden_gems": [
            "Nizamuddin Dargah qawwali night — every Thursday evening, free, transcendent Sufi music",
            "Tughlaqabad Fort — massive 14th-century ruined city, dramatic setting, almost no tourists",
            "Khotachiwadi — 200-year-old Portuguese-era wooden bungalows hidden in Girgaon",
        ],
    },
    "mumbai": {
        "landmarks": [
            "Gateway of India — 1924 colonial arch on waterfront; ferry to Elephanta Caves from here",
            "Elephanta Caves — 5th-6th century rock-cut Shiva temples, UNESCO, 1-hr ferry ₹220 return",
            "Chhatrapati Shivaji Maharaj Terminus (CST) — Victorian Gothic railway station, UNESCO",
            "Marine Drive (Queen's Necklace) — 3.6km promenade; magical at dusk when the arc lights up",
            "Dharavi — Asia's most entrepreneurial slum; responsible tours show a 1-billion-dollar export economy",
            "Banganga Tank, Walkeshwar — ancient temple tank with herons, total silence 3km from Marine Drive",
        ],
        "street_food": [
            "Vada Pav at Shivaji Vada Pav, Dadar Station west exit (since 1966), ₹15 — Mumbai's soul food",
            "Pav Bhaji at Sardar Pav Bhaji, Tardeo — legendary, butter-loaded, ₹80",
            "Bhel Puri on Chowpatty Beach by the sea — Babulnath end vendors, ₹30",
            "Keema Pav at Bademiya, Tulloch Road Colaba (since 1946) — open until 3am",
            "Misal Pav at Aaswad, Dadar — Maharashtrian breakfast institution",
        ],
        "markets": [
            "Chor Bazaar, Mutton Street — vintage furniture, Bollywood posters, antique cameras",
            "Crawford Market — colonial building; fresh produce, exotic pets, spices",
            "Linking Road, Bandra — street fashion, copies, handicrafts for budget shoppers",
        ],
        "hidden_gems": [
            "Sassoon Docks at 5:30am — massive wholesale fish market; surreal photography, no tourists",
            "Khotachiwadi — 200-year-old Portuguese wooden bungalows hidden behind Girgaon main road",
            "Promenade Plantée equivalent: Bandra Fort viewpoint at sunset, rock-climbers and couples only",
        ],
    },
    "goa": {
        "landmarks": [
            "Basilica of Bom Jesus, Old Goa — UNESCO church housing St. Francis Xavier's remains",
            "Fort Aguada — 17th-century Portuguese fort with intact lighthouse; Sinquerim Beach below",
            "Dudhsagar Falls — 310m waterfall in jungle; accessible by jeep from Collem station (Oct–May)",
            "Anjuna Flea Market (Wednesday) — the original hippie market since the 1970s",
            "Cabo de Rama Fort — ruined fort on dramatic sea cliffs, utter solitude, 360° ocean views",
        ],
        "street_food": [
            "Fish Thali at Ritz Classic, Panaji — whole pomfret curry, rice, sol kadhi, ₹180",
            "Chorizo Poi (spicy sausage in hollow Goan bread) at Saturday Night Market, Arpora",
            "Bebinca (layered coconut milk dessert) at Mrs. Maria's Home Bakery, Calangute",
            "Cashew Feni tasting at Cazulo Premium Feni, Neura — guided tasting ₹250",
        ],
        "markets": [
            "Mapusa Friday Market — locals buy fish, produce, pickles, cashew; most authentic market in Goa",
            "Anjuna Flea Market — handmade jewellery, vintage clothes, antiques",
        ],
        "hidden_gems": [
            "Butterfly Beach, Canacona — accessible only by boat from Palolem, nesting turtles Oct–Feb",
            "Divar Island — cross by ferry from Old Goa, cycling through Portuguese villas, zero tourists",
        ],
    },
    "agra": {
        "landmarks": [
            "Taj Mahal — UNESCO World Heritage, best at sunrise; buy tickets online to skip queues (₹1100 foreigners / ₹50 Indians)",
            "Agra Fort — red sandstone Mughal fort with stunning Taj views from the Octagonal Tower",
            "Fatehpur Sikri — UNESCO abandoned Mughal capital 37 km away; Buland Darwaza is Asia's largest gateway",
            "Itimad-ud-Daulah (Baby Taj) — the first Mughal structure entirely built in marble, less crowded than the Taj",
            "Mehtab Bagh — moonlit garden directly north of the Taj; best sunset view, no entry fee at dusk",
        ],
        "street_food": [
            "Petha (ash gourd sweet) at Panchi Petha, Sadar Bazaar — the original since 1885, dozens of varieties",
            "Bedai (fried bread) + Jalebi at Deviram Sweets, Sadar Bazaar — Agra's signature breakfast",
            "Mughlai Biryani at Pinch of Spice, Fatehabad Road — slow-cooked dum biryani",
            "Dalmoth (spiced lentil snack) fresh from any halwai near Taj Mahal East Gate",
        ],
        "markets": [
            "Sadar Bazaar — leather goods, marble inlay work, petha shops all in one strip",
            "Kinari Bazaar — bridal jewellery, zardosi work, Mughal-era embroidery near Jama Masjid",
        ],
        "hidden_gems": [
            "Mehtab Bagh at sunset — direct Taj reflection view across Yamuna, ₹300, very few tourists",
            "Taj Nature Walk, Eastern Gate — forested trail with Taj views, ₹5, almost always empty",
        ],
    },
    "paris": {
        "landmarks": [
            "Eiffel Tower — book timed tickets online weeks ahead; summit at sunset or 11pm light show",
            "Musée du Louvre — arrive at 9am sharp; Mona Lisa room crowded by 10am; free first Sunday of month",
            "Musée d'Orsay — Impressionist masterpieces in a converted railway station; quieter than the Louvre",
            "Sainte-Chapelle — 13th-century Gothic chapel with 1000 sq m of stained glass; best at 2pm",
            "Palace of Versailles — 40 min by RER C; book Grand Trianon to avoid main palace queues",
            "Promenade Plantée — 4.7km elevated railway garden (Paris's High Line), free, always quiet",
        ],
        "street_food": [
            "Croissant at Du Pain et des Idées, Canal Saint-Martin — named Paris's best bakery, arrive by 8am",
            "Falafel at L'As du Fallafel, Rue des Rosiers, Le Marais — queue outside, worth every minute",
            "Macarons at Pierre Hermé, Rue Bonaparte — the actual best, not tourist-trap Ladurée",
        ],
        "markets": [
            "Marché d'Aligre — cheapest fresh produce and vintage books in Paris, locals only vibes",
            "Saint-Ouen Flea Market (weekends) — world's largest antique market",
        ],
        "hidden_gems": [
            "Parc des Buttes-Chaumont — real Parisians' park (not tourists); cliff, lake, temple, free",
            "Passage des Panoramas — 1800s covered arcade, vintage stamps, old coins, food stalls",
        ],
    },
    "tokyo": {
        "landmarks": [
            "Senso-ji Temple, Asakusa — Tokyo's oldest temple; Nakamise shopping lane, arrive at 6am before crowds",
            "Shibuya Crossing — world's busiest pedestrian crossing; watch from Starbucks 2F window opposite",
            "teamLab Borderless digital art museum — book months ahead, 1.5–2 hours minimum",
            "Meiji Jingu Shrine — forested oasis in Harajuku; free, peaceful, wedding processions on weekends",
            "Tsukiji Outer Market — traditional food stalls (inner tuna auction moved to Toyosu)",
        ],
        "street_food": [
            "Taiyaki (fish-shaped waffle with red bean) from Naniwaya Sohonten, Azabu-Juban (since 1909), ¥200",
            "Ramen at Ichiran, Shinjuku — solo booth dining, tonkotsu broth, ¥980",
            "Sushi breakfast at Toyosu Market — 5am, freshest in the world, sushi set ¥1500",
        ],
        "markets": [
            "Nakamise Shopping Street, Asakusa — traditional souvenirs; ningyo-yaki sweets, sensu fans",
            "Shimokitazawa — Tokyo's hipster area; vintage clothes, indie music record shops",
        ],
        "hidden_gems": [
            "Yanaka Ginza — old shitamachi shopping street, feels like 1960s Tokyo, cats everywhere, free",
            "Omoide Yokocho — tiny alley of yakitori stalls under Shinjuku station, post-war atmosphere",
        ],
    },
}


def _get_city_key(destination: str) -> str | None:
    d = destination.lower().strip()
    for key in CITY_DATA:
        if key in d or d in key:
            return key
    return None


# ─────────────────────────────────────────────────────────────────────────────
# 1. GROQ CLOUD LLM  (primary — works for ANY city input)
# ─────────────────────────────────────────────────────────────────────────────
def _call_groq(prompt: str) -> str:
    key = get_groq_key()
    if not key or key.lower() in ["your_groq_api_key_here", "your_key"]:
        raise ValueError("GROQ_API_KEY not set in .env")

    body = json.dumps({
        "model": GROQ_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.7,
        "max_tokens": 4096,
    }).encode("utf-8")

    req = urllib.request.Request(
        GROQ_API_URL,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {key}",
            "User-Agent": "TravelBuddy/2.0"
        },
        method="POST",
    )
    try:
        print(f"[LLM] Sending request to Groq API...")
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            text = data["choices"][0]["message"]["content"].strip()
            if not text:
                raise ValueError("Empty Groq response")
            print(f"[LLM] Groq OK — {len(text)} chars")
            return text
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        print(f"[LLM] Groq API Error ({e.code}): {err_body}")
        raise
    except Exception as e:
        print(f"[LLM] Groq connection failed: {e}")
        raise


# ─────────────────────────────────────────────────────────────────────────────
# 2. OLLAMA LOCAL HTTP  (secondary — works for ANY city if ollama is running)
# ─────────────────────────────────────────────────────────────────────────────
def _call_ollama_http(prompt: str) -> str:
    model = get_ollama_model()
    body = json.dumps({
        "model": model,
        "prompt": prompt,
        "stream": False,
    }).encode("utf-8")
    req = urllib.request.Request(
        OLLAMA_API_URL,
        data=body,
        headers={
            "Content-Type": "application/json",
            "User-Agent": "TravelBuddy/2.0"
        },
        method="POST",
    )
    print(f"[LLM] Calling Ollama HTTP for {model}...")
    with urllib.request.urlopen(req, timeout=600) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        text = data.get("response", "").strip()
        if not text:
            raise ValueError("Empty Ollama response")
        print(f"[LLM] Ollama HTTP OK — {len(text)} chars")
        return text


# ─────────────────────────────────────────────────────────────────────────────
# 3. OLLAMA SUBPROCESS  (tertiary)
# ─────────────────────────────────────────────────────────────────────────────
def _call_ollama_subprocess(prompt: str) -> str:
    model = get_ollama_model()
    result = subprocess.run(
        ["ollama", "run", model],
        input=prompt, text=True,
        capture_output=True, timeout=600,
    )
    if result.returncode == 0 and result.stdout.strip():
        print(f"[LLM] Ollama subprocess OK ({model})")
        return result.stdout.strip()
    raise RuntimeError(result.stderr.strip() or "empty subprocess output")


# ─────────────────────────────────────────────────────────────────────────────
# 4. SMART MOCK  (last resort — good for pre-loaded cities, generic for others)
# ─────────────────────────────────────────────────────────────────────────────
def _build_smart_itinerary(destination: str, days: int, budget: str) -> dict:
    key  = _get_city_key(destination)
    city = CITY_DATA.get(key) if key else None
    dest_title = destination.title()

    if city is None:
        note = (
            f"⚠️ Offline mode — no pre-loaded data for {dest_title}. "
            "Add your GROQ_API_KEY to .env for real AI-generated results."
        )
        return {
            f"Day {i+1}": [
                f"🌅 MORNING: Arrive in {dest_title}, check in, orientation walk in the old town",
                f"☀️ AFTERNOON: Visit the most famous landmark of {dest_title} — ask your hotel for best options",
                f"🌆 EVENING: Explore the main market street and try local street food",
                f"💡 NOTE: {note}",
            ] for i in range(min(days, 7))
        }

    lm = city["landmarks"]
    sf = city["street_food"]
    mk = city["markets"]
    gm = city["hidden_gems"]
    budget_tips = {
        "Low":    f"Use shared autos/buses (₹10–30), eat at street stalls, stick to free monuments",
        "Medium": f"Auto-rickshaws for comfort, mid-range restaurants, pay entry fees for top monuments",
        "High":   f"Private car + guide (₹1500–2500/day), rooftop restaurants, premium experiences",
    }

    itinerary = {}
    lp = sp = mp = gp = 0
    for day_num in range(1, min(days, 7) + 1):
        lm1 = lm[lp % len(lm)]; lp += 1
        lm2 = lm[lp % len(lm)]; lp += 1
        food= sf[sp % len(sf)]; sp += 1
        mkt = mk[mp % len(mk)]; mp += 1
        gem = gm[gp % len(gm)]; gp += 1
        tip = budget_tips.get(budget, budget_tips["Medium"])

        acts = [
            f"🌅 MORNING: {lm1}",
            f"☀️ AFTERNOON: {lm2}",
            f"🍽 STREET FOOD: {food}",
            f"🛍 MARKET/SHOP: {mkt}",
            f"🔍 HIDDEN GEM: {gem}",
            f"💡 BUDGET TIP ({budget}): {tip}",
        ]
        if day_num == 1:
            acts[0] = (
                f"🌅 MORNING: Arrive in {dest_title}, check in, grab chai from a roadside stall and "
                f"take an orientation walk through the old city to get your bearings"
            )
            acts.insert(1, f"🏛 MID-MORNING: {lm1}")
        itinerary[f"Day {day_num}"] = acts
    return itinerary


def _smart_mock(prompt: str) -> str:
    prompt_lower = prompt.lower()

    if any(k in prompt_lower for k in ["itinerary", "day-wise", "tour guide", "travel plan"]):
        dest, days, budget = "the destination", 3, "Medium"
        for line in prompt.splitlines():
            s = line.strip().lstrip("-* ")
            sl = s.lower()
            if sl.startswith("destination:"):
                v = s.split(":", 1)[-1].strip()
                if v and "{" not in v:
                    dest = v
            elif sl.startswith("duration:"):
                try: days = int(''.join(filter(str.isdigit, s.split(":",1)[-1])))
                except: pass
            elif sl.startswith("budget:"):
                v = s.split(":", 1)[-1].strip().title()
                if v in ("Low", "Medium", "High"): budget = v
        return json.dumps(_build_smart_itinerary(dest, days, budget), indent=2, ensure_ascii=False)

    if any(k in prompt_lower for k in ["narration", "reel", "story", "cinematic"]):
        dest = "this destination"
        for line in prompt.splitlines():
            s = line.strip().lstrip("-* ")
            if s.lower().startswith("destination:"):
                v = s.split(":", 1)[-1].strip()
                if v and "{" not in v:
                    dest = v.title()
                    break
        return json.dumps({
            "title": f"Chasing Light in {dest}",
            "narration": (
                f"Some places don't just fill your camera roll — they fill your soul. "
                f"{dest} is one of them.\n\n"
                f"It greets you with golden skies and leaves you with a heart full of stories — "
                f"every narrow lane a chapter, every stranger a character you won't forget.\n\n"
                f"The flavours here are unlike anything you've tasted. The colours, unlike anything "
                f"you've seen. And the silence — even in the bustle — is something you carry home.\n\n"
                f"You arrive as a tourist. You leave as a storyteller.\n"
                f"This is {dest}. And once you've been, a part of it stays with you forever."
            ),
            "captions": [
                f"Hello, {dest} 🌍", "Where every corner is a postcard",
                "Chasing the golden hour ✨", "Flavours you'll dream about",
                "Ancient streets, fresh beginnings", "This view though 😍",
                "Wanderlust fully activated", "Memories in the making 🎬",
            ],
            "hashtags": [
                f"#{dest.replace(' ', '')}", f"#Visit{dest.replace(' ', '')}",
                "#TravelReel", "#CinematicTravel", "#WanderlustVibes",
                "#TravelBuddy", "#ExploreMore", "#ReelItFeelIt",
            ],
        }, indent=2, ensure_ascii=False)

    return '{"error": "LLM unavailable. Add GROQ_API_KEY to .env for real AI results."}'


# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC: call_llm  —  tries all providers in order
# ─────────────────────────────────────────────────────────────────────────────
def call_llm(prompt: str, model: str = None) -> str:
    """Entry point for Text LLM calls (Cloud vs Local)"""
    prefer_local = get_prefer_local()
    
    if prefer_local:
        print("[LLM] Preference: LOCAL")
        # Try Local first
        try: 
            return _call_ollama_http(prompt)
        except Exception as e:
            print(f"[LLM] Ollama HTTP failed: {e}")
        
        try: 
            return _call_ollama_subprocess(prompt)
        except Exception as e:
            print(f"[LLM] Ollama subprocess failed: {e}")
        
        # Fallback to API if local failed
        print("[LLM] Falling back to Cloud API...")
        try: 
            return _call_groq(prompt)
        except Exception as e:
            print(f"[LLM] Groq fallback failed: {e}")
    else:
        print("[LLM] Preference: CLOUD")
        # Try API first
        try: 
            return _call_groq(prompt)
        except Exception as e:
            print(f"[LLM] Groq primary call failed: {e}")
        
        # Fallback to local
        print("[LLM] Falling back to Local AI...")
        try: 
            return _call_ollama_http(prompt)
        except Exception as e:
            print(f"[LLM] Ollama fallback failed: {e}")

    # ── 3. Smart mock (true last resort for pre-loaded cities) ────────────────
    print("[LLM] All live AI providers unavailable — using offline knowledge base")
    return _smart_mock(prompt)
def call_vision_llm(image_path: str, prompt: str) -> str:
    """Entry point for Vision LLM calls (Cloud vs Local)"""
    prefer_local = get_prefer_local()
    
    if prefer_local:
        model = get_ollama_vision_model()
        print(f"[Vision] Preference: LOCAL ({model})")
        try:
            return _call_ollama_vision(image_path, prompt)
        except Exception as e:
            print(f"[Vision] Local failed: {e}. Falling back to Cloud...")
            return _call_groq_vision(image_path, prompt)
    else:
        model = get_groq_vision_model()
        print(f"[Vision] Preference: CLOUD ({model})")
        try:
            return _call_groq_vision(image_path, prompt)
        except Exception as e:
            print(f"[Vision] Cloud failed: {e}. Falling back to Local...")
            return _call_ollama_vision(image_path, prompt)

def _call_groq_vision(image_path: str, prompt: str) -> str:
    import base64
    key = get_groq_key()
    if not key: raise ValueError("No Groq API Key")

    with open(image_path, "rb") as image_file:
        base64_image = base64.b64encode(image_file.read()).decode('utf-8')

    body = json.dumps({
        "model": get_groq_vision_model(),
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"}}
                ]
            }
        ],
        "response_format": {"type": "json_object"}
    }).encode("utf-8")

    req = urllib.request.Request(
        GROQ_API_URL,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {key}",
            "User-Agent": "TravelBuddy/2.0"
        },
        method="POST"
    )
    
    with urllib.request.urlopen(req) as response:
        res = json.loads(response.read().decode("utf-8"))
        return res["choices"][0]["message"]["content"]

def _call_ollama_vision(image_path: str, prompt: str) -> str:
    import base64
    with open(image_path, "rb") as image_file:
        base64_image = base64.b64encode(image_file.read()).decode('utf-8')

    body = json.dumps({
        "model": get_ollama_vision_model(),
        "prompt": prompt,
        "images": [base64_image],
        "stream": False,
        "format": "json"
    }).encode("utf-8")

    req = urllib.request.Request(
        "http://127.0.0.1:11434/api/generate",
        data=body,
        headers={"Content-Type": "application/json", "User-Agent": "TravelBuddy/2.0"},
        method="POST"
    )
    
    with urllib.request.urlopen(req) as response:
        res = json.loads(response.read().decode("utf-8"))
        return res["response"]
