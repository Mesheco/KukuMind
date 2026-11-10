"""KukuMind farm agents - the 7-agent team and its farm graph (server side).

Used by main.jac (web app, `jac start main.jac`) and demo.jac (terminal demo, `jac run demo.jac`)."""

import os;
import math;
import from byllm.lib { Model, Image }
glob llm = Model(model_name="claude-haiku-4-5-20251001");      # reads messages and numbers (fast, cheap)

# Model that WRITES replies to farmers. For better Kiswahili, change it to "claude-sonnet-4-6",
# run the live test, and if you get an error change it back to "claude-haiku-4-5-20251001".
glob WRITER_MODEL = "claude-sonnet-4-6";
glob writer = Model(model_name=WRITER_MODEL);
glob WRITER_STATE: dict = {"status": ""};     # "" = not checked yet, then the model in use

"""Reply with the single word OK."""
def writer_ping() -> str by writer();

# Check once that the writing model works; if not, quietly use Haiku for replies instead.
# No `global` statement here: the newer Jac on JacHammer does not accept it, so the model is
# switched by changing its name and the status is kept in a dict (works on every Jac version).
def ensure_writer() {
    if WRITER_STATE["status"] != "" or writer is llm { return; }
    try {
        writer_ping();
        WRITER_STATE["status"] = WRITER_MODEL;
    } except Exception as e {
        print(f"Writer model {WRITER_MODEL} not available ({e}); using claude-haiku-4-5 for replies.");
        writer.model_name = "claude-haiku-4-5-20251001";
        WRITER_STATE["status"] = "claude-haiku-4-5-20251001 (fallback)";
    }
    print(f"KukuMind replies are written by: {WRITER_STATE['status']}");
}

# ---------- LANGUAGE (shared by every agent) ----------
glob LANGUAGE_GUIDE = """
Farmers and workers write in English, Kiswahili, Sheng, or a mix of all three.
Read all of them. Always reply in the SAME language and style the person used:
English -> English, Kiswahili -> simple Kiswahili, Sheng or mixed -> friendly Sheng/Kiswahili mix.
Keep replies short and simple, like a WhatsApp message.

Common poultry words:
kuku = chickens; vifaranga = chicks; mayai = eggs; trei = egg tray (30 eggs);
chakula / feed / msosi = feed; gunia / bag = feed bag (50 kg unless the person says otherwise);
vifo / zimekufa / zimeenda / zime-die = deaths; wagonjwa / hawako poa = sick;
dhaifu = weak; kuhara = diarrhoea; kukohoa = coughing; uzito = weight;
leo = today; jana = yesterday; nyumba / banda = poultry house.
Swahili numbers: moja 1, mbili 2, tatu 3, nne 4, tano 5, sita 6, saba 7, nane 8, tisa 9,
kumi 10, ishirini 20, thelathini 30, arobaini 40, hamsini 50, mia 100, elfu 1000.
Compound numbers use "na": thelathini na mbili = 32, ishirini na tano = 25,
mia moja na hamsini = 150, elfu moja na mia mbili = 1200.
Sheng money/numbers: mbao = 20, soo = 100, thao = 1000.

HOW TO WRITE EVERY REPLY:
- Plain text only. NO markdown: no ** or *, no # headings, no bullet or numbered lists, no tables.
- 2 to 4 short sentences, like one WhatsApp message. At most one emoji.
- Use only numbers you were given. Never change or recalculate them.
- Always write numbers as digits (35, not "thelathini na tano").
- Kiswahili must be correct, simple Kenyan Kiswahili. Use these correct phrases:
  "Piga simu daktari wa mifugo (vet) leo" = call a vet today;
  "Usiuze wala usihamishe kuku" = do not sell or move birds;
  "Tenga kuku wagonjwa" = isolate sick birds; "Ondoa mizoga mara moja" = remove dead birds at once;
  "kukohoa" = coughing (never "kuhoa"); "wiki hii" (two words); "joto" = heat/temperature;
  "Tumehifadhi ripoti yako" = we have saved your report; "kuku hai" = birds alive;
  "ugonjwa" = disease, "ugonjwa hatari" = a serious disease; "dalili" = signs/symptoms;
  "kuku wanapata joto" or "kuku wanakaa karibu na joto" = chicks staying near the heat.
  "Mwite daktari wa mifugo" = call the vet (never "mwaliko", which means invitation);
  "hadi daktari aruhusu" = until the vet allows it (never "akome", which means stops);
  "idadi" = number/quantity (never "uzamili", which means a master's degree).
- NEVER use these words: "kaswende" (it means syphilis), "bonyeza" for water (say "wape maji safi"),
  "mwaliko", "akome", "uzamili", "wanapika" (cooking).
- Never add up, average or calculate numbers yourself. Only repeat numbers exactly as given.
- Kiswahili replies must be PURE Kiswahili. Do not mix in English words. Use:
  "siku ya 10" (not "day 10"), "tayari" (not "ready"), "sawa" or "salama" (not "poa"),
  "kundi B1" or "B1" (not "batch"), "malipo" (not "payment"), "chakula" (not "feed"),
  "daktari wa mifugo" (not "vet"), "uzito" (not "weight"), "mauzo" (not "sales").
  Keep sentences short and grammatical; kuku takes "wa/za" agreement: "kuku wako" (people-like) is accepted, but be consistent in one reply.
- English replies must be plain English only.
- Sheng replies: friendly Nairobi mix of Kiswahili and English, still clear and correct.
""";

# The farmer can choose the reply language on the web page; "" or "Auto" = reply in the language they wrote in
def reply_lang(chosen: str, detected: str) -> str {
    if chosen in ["English", "Kiswahili", "Sheng"] { return chosen; }
    return detected if detected in ["English", "Kiswahili", "Sheng"] else "English";
}

# Safety net: strip markdown the AI may still add (WhatsApp/SMS show it as raw symbols)
def plain_text(t: str) -> str {
    out: list[str] = [];
    for line in t.replace("**", "").replace("__", "").split("\n") {
        l = line.strip();
        while l.startswith("#") { l = l[1:].strip(); }
        if l.startswith("- ") or l.startswith("* ") { l = l[2:]; }
        if l != "" { out.append(l); }
    }
    return "\n".join(out);
}

# ---------- AI: read a worker's report in any of the 3 languages ----------
obj ParsedReport {
    has batch_id: str;          # must be one of the farm's batch IDs, or "" if unclear
    has deaths: int;
    has feed_bags: float;       # number of feed bags/gunia mentioned (0 if none)
    has feed_kg: float;         # kilograms of feed mentioned directly (0 if none)
    has egg_trays: int;         # number of egg trays/trei mentioned (0 if none)
    has loose_eggs: int;        # eggs counted one by one, not in trays (0 if none)
    has avg_weight_kg: float;
    has note: str;              # anything else worth keeping, translated to English
    has language: str;          # "English", "Kiswahili" or "Sheng"
}

# The code (not the AI) does the arithmetic, so numbers are always right
def total_feed_kg(r: ParsedReport) -> float {
    return r.feed_bags * 50.0 + r.feed_kg;
}
def total_eggs(r: ParsedReport) -> int {
    return r.egg_trays * 30 + r.loose_eggs;
}

"""Read a poultry worker's short daily report and copy out the numbers exactly as said.
Use the language guide to understand English, Kiswahili and Sheng number words
(for example "trei thelathini na mbili" means egg_trays = 32).
Do NOT do any arithmetic: put trays in egg_trays and single eggs in loose_eggs;
put bags/gunia in feed_bags and kilograms in feed_kg.
batch_id must be exactly one of batch_ids; use "" if you cannot tell which batch.
Use 0 for anything not mentioned. Write note in English.
Set language: "Sheng" if the worker mixes Kiswahili with English or slang (manze, msosi, ime-die, poa),
"Kiswahili" if it is plain Kiswahili, "English" if English."""
def parse_report(text: str, batch_ids: list[str], language_guide: str) -> ParsedReport by llm();

"""Write a short confirmation to the worker, in the language given, following the language guide.
Follow HOW TO WRITE EVERY REPLY. Say what was saved (use the exact numbers in saved) and how many birds are alive in that batch.
If deaths_high is True, gently add that they should watch the flock and tell the farm manager.
If deaths_high is False, do NOT say deaths are high. Never recommend medicine."""
def confirm_message(saved: str, alive: int, deaths_high: bool, language: str, language_guide: str) -> str by writer();

"""Ask the worker, in the language given, which batch their report is for, listing the batch IDs.
Follow HOW TO WRITE EVERY REPLY in the language guide. One or two sentences."""
def ask_which_batch(batch_ids: list[str], language: str, language_guide: str) -> str by writer();

# ---------- NODES (the farm graph) ----------
node Farm {
    has name: str;
    has owner: str;
    has phone: str = "";     # the owner's phone
    has last_tick: str = ""; # last date the bird ages / incubator days were moved forward
}

# Bird ages and incubator days follow the real calendar: every time the farm is opened,
# each day that has passed since the last visit is added (age 10 on Monday -> age 13 on Thursday).
def catch_up(f: Farm) {
    t = today();
    last = str(getattr(f, "last_tick", "") or "");
    if last == "" {
        f.last_tick = t;
        return;
    }
    if last >= t { return; }
    try {
        days = (date.fromisoformat(t) - date.fromisoformat(last)).days;
    } except Exception as e {
        f.last_tick = t;
        return;
    }
    if days > 0 {
        for b in [f -->[?:House] -->[?:Batch]] { b.age_days += days; }
        for s in [f -->[?:EggSet]] {
            if not s.done { s.day += days; }
        }
    }
    f.last_tick = t;
}

# The farm's phone (farms saved before this field existed have none)
def farm_phone(f: Farm) -> str {
    return str(getattr(f, "phone", "") or "");
}

node House {
    has name: str;
    has capacity: int;
}

node Batch {
    has batch_id: str;
    has bird_type: str;      # broiler, layer, kienyeji
    has start_count: int;
    has alive: int;
    has age_days: int;
    has added: str = "";     # date the birds arrived ("" = on the farm when KukuMind started)
}

node Record {
    has date: str;
    has deaths: int = 0;
    has feed_kg: float = 0.0;
    has eggs: int = 0;
    has avg_weight_kg: float = 0.0;
    has note: str = "";
}

# ---------- Saved records can come back in any order: always sort by date ----------
def records_of(b: Batch) -> list[Record] {
    recs = [b -->[?:Record]];
    pairs = sorted([(recs[i].date, i) for i in range(len(recs))]);
    return [recs[p[1]] for p in pairs];
}

# One total per day (a morning and an evening report on the same day are added together),
# so "today's" deaths, feed and eggs are compared day with day, not report with report.
obj DayTotal {
    has date: str;
    has deaths: int = 0;
    has feed_kg: float = 0.0;
    has eggs: int = 0;
}

def daily_totals(b: Batch) -> list[DayTotal] {
    out: list[DayTotal] = [];
    for r in records_of(b) {
        if len(out) > 0 and out[-1].date == r.date {
            out[-1].deaths += r.deaths;
            out[-1].feed_kg += r.feed_kg;
            out[-1].eggs += r.eggs;
        } else {
            out.append(DayTotal(date=r.date, deaths=r.deaths, feed_kg=r.feed_kg, eggs=r.eggs));
        }
    }
    return out;
}

node FeedStore {
    has stock_kg: float;
}

node Vet {
    has name: str;
    has phone: str;          # Kenyan number, e.g. 0714297727
}

node VetAlert {
    has date: str;
    has batch_id: str;
    has message: str;
}

node Buyer {
    has name: str;
    has phone: str;
    has wants: str;
}

# ---------- WALKER 1: build the demo farm ----------
walker build_demo_farm {
    can build with Root entry {
        if [here -->[?:Farm]] {
            catch_up([here -->[?:Farm]][0]);       # move ages forward to today's date
            disengage;
        }
        farm = here ++> Farm(name="Meshack Poultry Farm", owner="Meshack", phone="0722434939", last_tick=today());
        f = farm[0];

        h1 = f ++> House(name="House A", capacity=2000);
        h2 = f ++> House(name="House B", capacity=1500);

        h1[0] ++> Batch(batch_id="B1", bird_type="broiler", start_count=1000, alive=1000, age_days=10);
        h1[0] ++> Batch(batch_id="B2", bird_type="broiler", start_count=800, alive=800, age_days=35);
        h2[0] ++> Batch(batch_id="B3", bird_type="layer", start_count=1200, alive=1200, age_days=150);

        f ++> FeedStore(stock_kg=2500.0);
        f ++> Buyer(name="Mama Njeri Hotel", phone="0712000001", wants="broilers");
        f ++> Buyer(name="Kamau Eggs Supply", phone="0712000002", wants="eggs");
        f ++> Vet(name="Dr. Timothy Wambua (farm vet)", phone="0714297727");

        print("Demo farm built: Meshack Poultry Farm");
    }
}

# ---------- WALKER 2: flock records agent (log a worker report) ----------
walker save_report {
    has batch_id: str;
    has date: str;
    has deaths: int = 0;
    has feed_kg: float = 0.0;
    has eggs: int = 0;
    has avg_weight_kg: float = 0.0;
    has note: str = "";
    has alive_after: int = -1;     # filled in once saved
    has feed_left: float = -1.0;   # feed store after this report
    has saved: bool = False;
    has problem: str = "";         # why the report was NOT saved
    has feed_short: float = 0.0;   # feed reported as used but not in the store (a delivery was not recorded)

    can start with Root entry {
        visit [-->];
    }

    can walk_farm with Farm entry {
        visit [-->[?:House]];
    }

    can walk_house with House entry {
        visit [-->[?:Batch]];
    }

    can save with Batch entry {
        if here.batch_id == self.batch_id {
            if self.deaths < 0 or self.feed_kg < 0 or self.eggs < 0 {
                self.problem = f"Numbers cannot be negative. Report for {here.batch_id} NOT saved.";
                print(self.problem);
                disengage;
            }
            if self.deaths > here.alive {
                self.problem = f"{here.batch_id} has only {here.alive} birds alive, so {self.deaths} deaths is not possible. Report NOT saved - please check the number.";
                print(self.problem);
                disengage;
            }
            here ++> Record(
                date=self.date, deaths=self.deaths, feed_kg=self.feed_kg,
                eggs=self.eggs, avg_weight_kg=self.avg_weight_kg, note=self.note
            );
            here.alive = here.alive - self.deaths;
            self.alive_after = here.alive;
            self.saved = True;
            # feed used comes out of the feed store
            stores = [here <--[?:House] <--[?:Farm] -->[?:FeedStore]];
            if len(stores) > 0 and self.feed_kg > 0 {
                if self.feed_kg > stores[0].stock_kg {
                    self.feed_short = self.feed_kg - stores[0].stock_kg;
                }
                stores[0].stock_kg = max(0.0, stores[0].stock_kg - self.feed_kg);
                self.feed_left = stores[0].stock_kg;
            }
            print(f"Saved for {here.batch_id}: {self.deaths} deaths, {self.feed_kg} kg feed, {self.eggs} eggs. Alive now: {here.alive}");
            disengage;
        }
    }
}

# ---------- WALKER 2b: worker sends a plain message (any language) ----------
walker worker_message {
    has text: str;
    has date: str;
    has reply: str = "";
    has language: str = "";      # chosen reply language ("" = same as the message)

    can handle with Root entry {
        batch_ids = [b.batch_id for b in [here -->[?:Farm] -->[?:House] -->[?:Batch]]];
        r = parse_report(self.text, batch_ids, LANGUAGE_GUIDE);
        r.language = reply_lang(self.language, r.language);

        if r.batch_id not in batch_ids {
            self.reply = plain_text(ask_which_batch(batch_ids, r.language, LANGUAGE_GUIDE));
        } else {
            feed = total_feed_kg(r);
            eggs = total_eggs(r);
            w = here spawn save_report(
                batch_id=r.batch_id, date=self.date, deaths=r.deaths,
                feed_kg=feed, eggs=eggs, avg_weight_kg=r.avg_weight_kg, note=r.note
            );
            if not w.saved {
                self.reply = plain_text(confirm_action(w.problem, r.language, LANGUAGE_GUIDE));
                print(f"\nWorker: {self.text}\nKukuMind: {self.reply}");
                disengage;
            }
            saved = f"Batch {r.batch_id}: {r.deaths} deaths, {feed:.0f} kg feed, {eggs} eggs";
            if w.feed_short > 0 { saved = saved + f". The feed store only had {feed - w.feed_short:.0f} kg: please record the feed delivery that came in"; }
            if r.avg_weight_kg > 0 { saved = saved + f", average weight {r.avg_weight_kg} kg"; }
            if r.note { saved = saved + f". Note: {r.note}"; }
            high = w.alive_after > 0 and r.deaths >= 0.003 * (w.alive_after + r.deaths);
            self.reply = plain_text(confirm_message(saved, w.alive_after, high, r.language, LANGUAGE_GUIDE));
        }
        print(f"\nWorker: {self.text}\nKukuMind: {self.reply}");
    }
}

# ---------- WALKER 3: show the flock summary ----------
walker flock_summary {
    can start with Root entry {
        visit [-->];
    }

    can show_farm with Farm entry {
        print(f"\n=== {here.name} ===");
        visit [-->];
    }

    can show_house with House entry {
        print(f"\n{here.name} (capacity {here.capacity})");
        for b in [here -->[?:Batch]] {
            recs = [b -->[?:Record]];
            total_deaths = sum([r.deaths for r in recs]);
            total_feed = sum([r.feed_kg for r in recs]);
            total_eggs = sum([r.eggs for r in recs]);
            mortality = 100.0 * total_deaths / b.start_count if b.start_count > 0 else 0.0;
            print(f"  {b.batch_id} | {b.bird_type} | day {b.age_days} | alive {b.alive}/{b.start_count} | mortality {mortality:.1f}% | feed {total_feed} kg | eggs {total_eggs} | reports {len(recs)}");
        }
    }
}


# =====================================================================
# STEP 2: HATCHERY + ADVISOR
# =====================================================================

# ---------- HATCHERY NODES ----------
node EggSet {
    has set_id: str;
    has bird_type: str;          # broiler, layer, kienyeji
    has eggs_set: int;
    has day: int = 0;            # incubation day (0 = set today)
    has fertile: int = -1;       # filled after candling
    has hatched: int = -1;       # filled after hatch
    has done: bool = False;
}

# What to do on each incubation day
def hatchery_task(day: int) -> str {
    if day == 7 {
        return "CANDLE #1 today: remove clear (infertile) eggs and record how many are fertile.";
    }
    if day == 14 {
        return "CANDLE #2 today: remove eggs that stopped developing (dead germ).";
    }
    if day == 18 {
        return "LOCKDOWN today: stop turning, move eggs to hatching trays, raise humidity. Do not open the incubator.";
    }
    if day >= 19 and day <= 20 {
        return "Lockdown: keep the incubator closed. Chicks may start pipping.";
    }
    if day == 21 {
        return "HATCH DAY: count chicks, leave them to dry in the incubator, then move to the brooder.";
    }
    if day > 21 {
        return "Past day 21: record the hatch result now.";
    }
    return f"Day {day}: keep turning eggs and check temperature and humidity.";
}

# ---------- ADVISOR: typical Kenyan schedule (confirm with your vet / hatchery) ----------
glob SCHEDULE = {
    "broiler": [
        [1, "Marek's (usually done at the hatchery) + start brooding at 32-35 C"],
        [7, "Newcastle + IB vaccine (eye/nose drop or drinking water)"],
        [14, "Gumboro vaccine (drinking water)"],
        [21, "Gumboro booster + Newcastle booster"],
        [28, "Brooder heat off for most farms; check weights"],
        [35, "Check market weight; plan sales (usually ready day 35-42)"]
    ],
    "layer": [
        [1, "Marek's (usually done at the hatchery) + start brooding at 32-35 C"],
        [7, "Newcastle + IB vaccine"],
        [14, "Gumboro vaccine"],
        [21, "Gumboro booster + Newcastle booster"],
        [42, "Fowl pox vaccine (wing web); first deworming"],
        [56, "Fowl typhoid vaccine"],
        [112, "Move to layer feed / layer house before laying (week 16-18)"],
        [120, "Newcastle booster (repeat about every 3 months while laying)"],
        [180, "Deworm (repeat about every 2-3 months)"]
    ],
    "kienyeji": [
        [1, "Marek's (if not done at hatchery) + start brooding at 32-35 C"],
        [7, "Newcastle + IB vaccine"],
        [14, "Gumboro vaccine"],
        [21, "Gumboro booster + Newcastle booster"],
        [42, "Fowl pox vaccine; first deworming"],
        [56, "Fowl typhoid vaccine"],
        [90, "Newcastle booster (repeat about every 3 months)"]
    ]
};

def brooding_temp(age_days: int) -> str {
    if age_days <= 7 { return "Brooder 32-35 C"; }
    if age_days <= 14 { return "Brooder 29-32 C"; }
    if age_days <= 21 { return "Brooder 26-29 C"; }
    if age_days <= 28 { return "Brooder 24-26 C (start weaning off heat)"; }
    return "No brooder heat needed for most farms";
}

# Tasks due for a batch from today up to `ahead` days ahead
def due_tasks(bird_type: str, age_days: int, ahead: int) -> list[str] {
    out: list[str] = [];
    for item in SCHEDULE.get(bird_type, []) {
        due_day = item[0];
        if due_day >= age_days and due_day <= age_days + ahead {
            gap = due_day - age_days;
            when = "TODAY" if gap == 0 else ("tomorrow" if gap == 1 else f"in {gap} days");
            out.append(f"{when}: {item[1]}");
        }
    }
    return out;
}

"""Answer a poultry farmer's question as a friendly farm advisor.
Use farm_info (the farm's batches, ages and upcoming tasks) so the answer fits THIS farm.
Reply in the language given (English, Kiswahili or Sheng; "Auto" = the language the farmer used), following HOW TO WRITE EVERY REPLY in the language guide.
Use exactly the temperatures and days in farm_info; do not invent other numbers.
For vaccines and medicine: give general guidance only and say to confirm doses with a vet.
If the question sounds like sick birds, tell them to use the disease check and call a vet."""
def advise(question: str, farm_info: str, language: str, language_guide: str) -> str by writer();

# ---------- WALKER: set eggs in the incubator ----------
walker set_eggs {
    has bird_type: str;
    has eggs: int;
    has set_id: str = "";          # "" = give it the next free name (E1, E2, ...)
    has day: int = 0;
    has note: str = "";

    can add with Root entry {
        f = [here -->[?:Farm]][0];
        if self.eggs <= 0 {
            self.note = "How many eggs went into the incubator? Egg set NOT saved.";
            print(self.note);
            disengage;
        }
        if self.set_id == "" {
            self.set_id = next_ref("E", [e.set_id for e in [f -->[?:EggSet]]]);
        }
        f ++> EggSet(set_id=self.set_id, bird_type=self.bird_type, eggs_set=self.eggs, day=self.day);
        self.note = f"Egg set {self.set_id} saved: {self.eggs} {self.bird_type} eggs in the incubator (day {self.day}). Candling on day 7 and 14, lockdown day 18, hatch day 21.";
        print(self.note);
    }
}

# ---------- WALKER: record candling ----------
walker record_candling {
    has set_id: str;
    has fertile: int;
    has note: str = "";

    can update with Root entry {
        self.note = f"No egg set called {self.set_id}. Candling NOT saved.";
        for s in [here -->[?:Farm] -->[?:EggSet]] {
            if s.set_id == self.set_id and (self.fertile < 0 or self.fertile > s.eggs_set) {
                self.note = f"{s.set_id} has {s.eggs_set} eggs, so {self.fertile} fertile eggs is not possible. Candling NOT saved - please check the count.";
            } elif s.set_id == self.set_id and s.eggs_set > 0 {
                s.fertile = self.fertile;
                pct = 100.0 * s.fertile / s.eggs_set;
                self.note = f"Candling saved for {s.set_id}: {s.fertile} of {s.eggs_set} eggs fertile ({pct:.0f}%). Remove the clear eggs.";
            }
        }
        print(self.note);
    }
}

# ---------- WALKER: record hatch -> chicks become a new batch ----------
walker record_hatch {
    has set_id: str;
    has hatched: int;
    has house_name: str;
    has note: str = "";

    can update with Root entry {
        f = [here -->[?:Farm]][0];
        self.note = f"No egg set called {self.set_id}. Hatch NOT saved.";
        for s in [f -->[?:EggSet]] {
            if s.set_id == self.set_id and s.done {
                self.note = f"{s.set_id} was already hatched - nothing to do.";
                print(self.note);
            } elif s.set_id == self.set_id and (self.hatched < 0 or self.hatched > s.eggs_set or (s.fertile >= 0 and self.hatched > s.fertile)) {
                most = s.fertile if s.fertile >= 0 else s.eggs_set;
                self.note = f"{s.set_id} had {s.eggs_set} eggs" + (f" and {s.fertile} fertile at candling" if s.fertile >= 0 else "") + f", so {self.hatched} chicks is not possible (at most {most}). Hatch NOT saved - please check the count.";
                print(self.note);
                disengage;
            } elif s.set_id == self.set_id {
                houses = [h for h in [f -->[?:House]] if h.name == self.house_name];
                if len(houses) == 0 and self.hatched > 0 {
                    names = [h.name for h in [f -->[?:House]]];
                    self.note = f"No house called '{self.house_name}'. Houses on this farm: {names}. Hatch NOT saved - try again.";
                    print(self.note);
                    disengage;
                }
                s.hatched = self.hatched;
                s.done = True;
                rate = 100.0 * s.hatched / s.eggs_set;
                msg = f"{s.set_id} hatched: {s.hatched}/{s.eggs_set} eggs = {rate:.0f}% hatch rate";
                if s.fertile > 0 {
                    msg = msg + f", {100.0 * s.hatched / s.fertile:.0f}% of fertile eggs";
                }
                print(msg + ".");
                self.note = msg + ".";

                if self.hatched <= 0 {
                    self.note = f"No chicks hatched from {s.set_id} - no new batch created. Check incubator temperature and humidity.";
                    print(self.note);
                    disengage;
                }
                # egg -> farm: the chicks become a new batch
                new_id = next_batch_id(f);
                for h in [f -->[?:House]] {
                    if h.name == self.house_name {
                        h ++> Batch(batch_id=new_id, bird_type=s.bird_type,
                                    start_count=self.hatched, alive=self.hatched, age_days=1, added=today());
                        print(f"New batch {new_id} created in {h.name} with {self.hatched} chicks.");
                        self.note = self.note + f" New batch {new_id} created in {h.name} with {self.hatched} chicks - start brooding at 32-35 C.";
                    }
                }
            }
        }
    }
}

# ---------- WALKER: move the farm forward one day (for the demo) ----------
walker new_day {
    can tick with Root entry {
        f = [here -->[?:Farm]][0];
        for b in [f -->[?:House] -->[?:Batch]] { b.age_days += 1; }
        for s in [f -->[?:EggSet]] {
            if not s.done { s.day += 1; }
        }
        print("A new day has started on the farm.");
    }
}

# ---------- WALKER: today's hatchery + advisor tasks ----------
walker today_tasks {
    has tasks: list[str] = [];
    has quiet: bool = False;

    can collect with Root entry {
        f = [here -->[?:Farm]][0];
        for s in [f -->[?:EggSet]] {
            if not s.done {
                self.tasks.append(f"[Hatchery {s.set_id}, day {s.day}] {hatchery_task(s.day)}");
            }
        }
        for b in [f -->[?:House] -->[?:Batch]] {
            for t in due_tasks(b.bird_type, b.age_days, 3) {
                self.tasks.append(f"[{b.batch_id} {b.bird_type}, day {b.age_days}] {t}");
            }
            if b.age_days <= 28 {
                self.tasks.append(f"[{b.batch_id}] {brooding_temp(b.age_days)}");
            }
        }
        if not self.quiet {
            print("\n--- TODAY'S TASKS ---");
            for t in self.tasks { print(t); }
        }
    }
}

# ---------- WALKER: farmer asks the advisor a question (any language) ----------
walker ask_advisor {
    has question: str;
    has reply: str = "";
    has language: str = "";

    can answer with Root entry {
        f = [here -->[?:Farm]][0];
        lines: list[str] = [];
        for b in [f -->[?:House] -->[?:Batch]] {
            lines.append(f"{b.batch_id}: {b.bird_type}, day {b.age_days}, {b.alive} alive. {brooding_temp(b.age_days)}. Upcoming: {due_tasks(b.bird_type, b.age_days, 7)}");
        }
        for s in [f -->[?:EggSet]] {
            if not s.done {
                lines.append(f"Egg set {s.set_id}: {s.eggs_set} {s.bird_type} eggs, incubation day {s.day}. {hatchery_task(s.day)}");
            }
        }
        self.reply = plain_text(advise(self.question, "\n".join(lines), self.language if self.language in ["English", "Kiswahili", "Sheng"] else "Auto", LANGUAGE_GUIDE));
        print(f"\nFarmer: {self.question}\nKukuMind: {self.reply}");
    }
}



# =====================================================================
# STEP 3: DISEASE DETECTOR (early warnings + RED/AMBER/GREEN triage)
# =====================================================================

node HealthCheck {
    has date: str;
    has level: str;          # RED, AMBER, GREEN
    has summary: str;
    has had_photo: bool = False;
}

obj Triage {
    has level: str;                  # exactly "RED", "AMBER" or "GREEN"
    has possible_problems: list[str];  # possible causes to discuss with a vet - NOT a diagnosis
    has do_now: list[str];           # safe farm actions only (no drugs, no doses)
    has call_vet: bool;
    has reply: str;                  # short message to the farmer in THEIR language
    has language: str;               # "English", "Kiswahili" or "Sheng"
}

glob TRIAGE_RULES = """
You are a poultry health triage helper for Kenyan farmers. You are NOT a vet.
Choose a level:
RED = urgent. Examples: many sudden deaths, twisted necks / paralysis / circling,
swollen or bluish head/comb/wattles, bloody diarrhoea in many birds, gasping in many birds,
sharp drop in eggs together with breathing signs, or the early warnings say deaths are very high.
RED means: call a vet or the county veterinary officer TODAY, stop moving or selling birds,
no visitors. Newcastle disease and bird flu are notifiable in Kenya and must be reported.
AMBER = watch closely: a few sick birds, mild breathing signs, mild diarrhoea, feed or egg drop,
deaths slightly above normal. Isolate sick birds, check water, feed, heat and litter,
recheck in 24 hours, call a vet if it gets worse.
GREEN = looks normal or a simple management issue (heat, crowding, water) with no sickness signs.
Safety rules - always:
- NEVER name a medicine, antibiotic, dewormer, vaccine to give as treatment, or any dose.
- possible_problems are possibilities for the vet, never a diagnosis. Use words like "could be".
- Write possible_problems and do_now in simple ENGLISH (they are for the farm record and the vet).
  Only reply is written in the farmer's language.
- do_now only lists safe actions: isolate sick birds, remove and safely dispose of dead birds,
  clean fresh water, dry litter, correct heat/ventilation, restrict visitors, disinfect footwear,
  keep a few fresh dead birds cool for the vet, stop moving or selling birds if RED.
- If unsure between two levels, choose the more serious one.
- reply must be in reply_language (if reply_language is "Auto", use the farmer's language) and follow HOW TO WRITE EVERY REPLY in the language guide,
  and must say clearly whether to call a vet.
- Only give a brooder temperature if batch_info gives one, and use exactly that temperature.
""";

"""Triage a poultry health concern from the farmer's description.
Use batch_info (bird type, age, vaccines that should be done by now) and
warnings (patterns found in the farm records). Follow the triage rules and language guide."""
def triage_symptoms(description: str, batch_info: str, warnings: list[str], reply_language: str,
                    triage_rules: str, language_guide: str) -> Triage by writer();

"""Triage a poultry health concern from a photo of the birds or droppings, plus the farmer's description.
Describe what you can see in the photo inside the reply in simple words.
Use batch_info and warnings. Follow the triage rules and language guide."""
def triage_photo(photo: Image, description: str, batch_info: str, warnings: list[str], reply_language: str,
                 triage_rules: str, language_guide: str) -> Triage by writer();

# ---------- How many birds a batch had on a given day (from today's count, adding back later deaths and sales) ----------
def birds_end_of(b: Batch, d: str) -> int {
    later_deaths = sum([r.deaths for r in [b -->[?:Record]] if r.date > d]);
    later_sold = sum([x.qty for x in [b -->[?:Sale]] if x.item != "eggs" and x.date > d]);
    return b.alive + later_deaths + later_sold;
}

def birds_morning_of(b: Batch, d: str) -> int {
    deaths = sum([r.deaths for r in [b -->[?:Record]] if r.date == d]);
    sold = sum([x.qty for x in [b -->[?:Sale]] if x.item != "eggs" and x.date == d]);
    return birds_end_of(b, d) + deaths + sold;
}

# Birds that ate that day: birds left at the end of the day + those that died during it
# (birds sold that day usually leave in the morning, so they are not counted as eating that day's feed)
def birds_fed_on(b: Batch, d: str) -> int {
    deaths = sum([r.deaths for r in [b -->[?:Record]] if r.date == d]);
    return birds_end_of(b, d) + deaths;
}

# Age of a batch on a past day (ages follow the calendar)
def age_on(b: Batch, d: str) -> int {
    try {
        return max(1, b.age_days - (date.fromisoformat(today()) - date.fromisoformat(d)).days);
    } except Exception as e {
        return b.age_days;
    }
}

# Feed the batch should have eaten on that day: kg per bird for its age that day x birds that morning
def feed_need_on(b: Batch, d: str) -> float {
    return expected_feed_per_bird(b.bird_type, age_on(b, d)) * birds_fed_on(b, d);
}

# Laying rate: eggs collected that day / hens that morning x 100
def laying_rate(b: Batch, d: str, eggs: int) -> float {
    hens = birds_morning_of(b, d);
    return 100.0 * eggs / hens if hens > 0 else 0.0;
}

# ---------- Early warnings from the records (no AI) ----------
# Every comparison is PER BIRD, so selling or losing birds does not look like a feed or egg drop.
def early_warnings(b: Batch) -> list[str] {
    out: list[str] = [];
    recs = daily_totals(b);
    if len(recs) == 0 { return out; }
    last = recs[-1];
    prev = recs[:-1][-7:];          # the 7 days before the last report

    # 1. Deaths on the last day vs flock size that morning (normal is about 0.1% a day or less)
    flock = birds_morning_of(b, last.date);
    if flock > 0 {
        pct = 100.0 * last.deaths / flock;
        if pct >= 1.0 {
            out.append(f"VERY HIGH deaths on {last.date}: {last.deaths} birds ({pct:.1f}% of the flock).");
        } elif pct >= 0.3 {
            out.append(f"Deaths above normal on {last.date}: {last.deaths} birds ({pct:.1f}%).");
        }
    }

    # 2. Deaths rising 3 days in a row
    if len(recs) >= 3 {
        a = recs[-3].deaths;
        m = recs[-2].deaths;
        z = recs[-1].deaths;
        if z > m and m > a {
            out.append(f"Deaths rising 3 days in a row: {a} -> {m} -> {z}.");
        }
    }

    # 3. Feed intake drop per bird (sick birds eat less). Young broilers eat more every day, so a drop is a real sign.
    per_bird = [1000.0 * r.feed_kg / birds_fed_on(b, r.date) for r in prev if r.feed_kg > 0 and birds_fed_on(b, r.date) > 0];
    last_flock = birds_fed_on(b, last.date);
    if len(per_bird) > 0 and last.feed_kg > 0 and last_flock > 0 {
        avg_g = sum(per_bird) / len(per_bird);
        now_g = 1000.0 * last.feed_kg / last_flock;
        if now_g < 0.85 * avg_g {
            drop = 100.0 * (avg_g - now_g) / avg_g;
            out.append(f"Feed intake dropped {drop:.0f}% per bird ({now_g:.0f} g a bird on {last.date} vs {avg_g:.0f} g a bird on the days before).");
        }
    }

    # 4. Egg drop (layers): laying rate today vs the days before
    rates = [laying_rate(b, r.date, r.eggs) for r in prev if r.eggs > 0];
    if len(rates) > 0 and last.eggs > 0 {
        avg_r = sum(rates) / len(rates);
        now_r = laying_rate(b, last.date, last.eggs);
        if avg_r > 0 and now_r < 0.9 * avg_r {
            drop_e = 100.0 * (avg_r - now_r) / avg_r;
            out.append(f"Egg production dropped {drop_e:.0f}% (laying rate {now_r:.0f}% on {last.date}, {last.eggs} eggs, vs {avg_r:.0f}% on the days before).");
        }
    }
    return out;
}

def batch_health_info(b: Batch) -> str {
    done = [item[1] for item in SCHEDULE.get(b.bird_type, []) if item[0] <= b.age_days];
    recent = [f"{r.date}: {r.deaths} deaths, {r.feed_kg} kg feed, {r.eggs} eggs. {r.note}" for r in records_of(b)[-5:]];
    return (f"Batch {b.batch_id}: {b.bird_type}, {b.age_days} days old, {b.alive} alive of {b.start_count}. "
            + f"Correct heat for this age: {brooding_temp(b.age_days)} (use exactly this, do not give another temperature). "
            + f"Vaccines that should be done by now (not confirmed by farmer): {done}. "
            + f"Recent reports: {recent}");
}

# ---------- VET ALERT: ready-to-send message, built from the records by code ----------
# The farm's vet (added automatically for farms created before this feature)
def farm_vet(f: Farm) -> Vet {
    vets = [f -->[?:Vet]];
    if len(vets) == 0 {
        f ++> Vet(name="Dr. Timothy Wambua (farm vet)", phone="0714297727");
        vets = [f -->[?:Vet]];
    }
    return vets[0];
}

# 0712 345 678 -> 254712345678 (for WhatsApp links)
def intl_phone(phone: str) -> str {
    p = phone.replace(" ", "").replace("+", "");
    if p.startswith("0") { return "254" + p[1:]; }
    return p;
}

def whatsapp_link(phone: str, text: str) -> str {
    import from urllib.parse { quote }
    return "https://wa.me/" + intl_phone(phone) + "?text=" + quote(text);
}

def write_vet_message(f: Farm, b: Batch, description: str, t: Triage, warnings: list[str]) -> str {
    recs = records_of(b)[-5:];
    deaths = ", ".join([f"{r.date}: {r.deaths}" for r in recs]) if len(recs) > 0 else "no reports yet";
    vaccine_words = ["vaccine", "booster", "Marek"];
    due = [f"day {item[0]}: " + str(item[1]).split(" + start")[0].split(" (")[0]
           for item in SCHEDULE.get(b.bird_type, [])
           if item[0] <= b.age_days and any([w in str(item[1]) for w in vaccine_words])];
    lines = [
        f"KukuMind alert - URGENT poultry case ({t.level})",
        f"Farm: {f.name} (owner {f.owner}{', ' + farm_phone(f) if farm_phone(f) else ''})",
        f"Batch {b.batch_id}: {b.bird_type}, {b.age_days} days old, {b.alive} alive of {b.start_count}.",
        f"Deaths in recent reports: {deaths}.",
        f"Farmer reports: {description}"
    ];
    if len(warnings) > 0 { lines.append("Record warnings: " + " ".join(warnings)); }
    if len(t.possible_problems) > 0 {
        lines.append("KukuMind triage (not a diagnosis): " + "; ".join(t.possible_problems) + ".");
    }
    if len(due) > 0 { lines.append("Vaccinations that should be done by this age (not confirmed by farmer): " + "; ".join(due) + "."); }
    lines.append("Farmer has been advised to isolate sick birds, keep fresh dead birds cool for you, and not move or sell birds.");
    lines.append("Please call or visit today.");
    return "\n".join(lines);
}

# ---------- WALKER: health check for one batch (text, or text + photo) ----------
walker health_check {
    has batch_id: str;
    has description: str;
    has date: str;
    has photo_path: str = "";        # optional, e.g. "sick_bird.jpg" in the KUKUMIND folder
    has result: Triage | None = None;
    has vet_message: str = "";       # ready-to-send message for the vet (RED or call-vet cases)
    has vet_link: str = "";          # WhatsApp link that opens the message to the vet
    has language: str = "";          # chosen reply language ("" = same as the farmer)

    can check with Root entry {
        found = [b for b in [here -->[?:Farm] -->[?:House] -->[?:Batch]] if b.batch_id == self.batch_id];
        if len(found) == 0 {
            print(f"No batch called {self.batch_id}.");
            disengage;
        }
        b = found[0];
        warnings = early_warnings(b);
        info = batch_health_info(b);

        if self.photo_path and not os.path.exists(self.photo_path) {
            print(f"Photo '{self.photo_path}' not found - checking from the description only.");
            self.photo_path = "";
        }
        if self.photo_path {
            t = triage_photo(Image(url=self.photo_path), self.description, info, warnings, self.language or "Auto", TRIAGE_RULES, LANGUAGE_GUIDE);
        } else {
            t = triage_symptoms(self.description, info, warnings, self.language or "Auto", TRIAGE_RULES, LANGUAGE_GUIDE);
        }

        t.reply = plain_text(t.reply);

        # Safety net: very high deaths in the records always means at least RED
        if any(["VERY HIGH" in w for w in warnings]) and t.level != "RED" {
            t.level = "RED";
            t.call_vet = True;
        }

        b ++> HealthCheck(date=self.date, level=t.level,
                          summary=f"{self.description} | {t.possible_problems}",
                          had_photo=bool(self.photo_path));
        self.result = t;

        # Alert the vet: write the message for every RED / call-vet case
        if t.level == "RED" or t.call_vet {
            f = [here -->[?:Farm]][0];
            vet = farm_vet(f);
            self.vet_message = write_vet_message(f, b, self.description, t, warnings);
            self.vet_link = whatsapp_link(vet.phone, self.vet_message);
            b ++> VetAlert(date=self.date, batch_id=b.batch_id, message=self.vet_message);
        }

        icon = {"RED": "[RED - URGENT]", "AMBER": "[AMBER - WATCH]", "GREEN": "[GREEN - OK]"}.get(t.level, t.level);
        print(f"\n=== HEALTH CHECK {b.batch_id} {icon} ===");
        print(f"Farmer: {self.description}");
        for w in warnings { print(f"  Record warning: {w}"); }
        print(f"  Could be (for the vet): {t.possible_problems}");
        print(f"  Do now: {t.do_now}");
        print(f"  Call vet: {'YES' if t.call_vet else 'not yet'}");
        print(f"KukuMind: {t.reply}");
        if self.vet_message {
            print(f"\n  --- Message for the vet (ready to send) ---\n{self.vet_message}\n  WhatsApp: {self.vet_link}");
        }
    }
}

# ---------- WALKER: scan all batches for early warnings (used by the manager later) ----------
walker early_warning_scan {
    has alerts: list[str] = [];
    has quiet: bool = False;

    can scan with Root entry {
        for b in [here -->[?:Farm] -->[?:House] -->[?:Batch]] {
            for w in early_warnings(b) {
                self.alerts.append(f"{b.batch_id}: {w}");
            }
        }
        if self.quiet { disengage; }
        print("\n--- EARLY WARNINGS ---");
        if len(self.alerts) == 0 { print("No warnings. All batches look normal in the records."); }
        for a in self.alerts { print(a); }
    }
}



# =====================================================================
# STEP 4: FEED & INVENTORY + SALES & MARKETING
# =====================================================================

node FeedDelivery {
    has date: str;
    has kg: float;
    has cost_ksh: float = 0.0;
}

node Sale {
    has date: str;
    has buyer: str;
    has item: str;           # "broilers", "eggs", "kienyeji"
    has qty: int;            # birds, or eggs
    has price_each: float;   # KSh per bird, or per egg
    has total: float;
}

# A cost paid for one batch (feed is counted separately, from what the batch ate)
node Expense {
    has date: str;
    has kind: str;           # Chicks, Vaccines, Vet & medicine, Labour, Transport, Other
    has amount: float;       # KSh
    has note: str = "";
}

glob EXPENSE_KINDS = ["Chicks", "Vaccines", "Vet & medicine", "Labour", "Transport", "Other"];

# Find a buyer by name (ignores case; "Mama Njeri" matches "Mama Njeri Hotel"); adds a new buyer if none
def find_or_add_buyer(f: Farm, name: str, item: str) -> str {
    n = name.strip();
    if n == "" or n == "buyer not named" { return "buyer not named"; }
    low = n.lower();
    for b in [f -->[?:Buyer]] {
        bl = b.name.lower();
        if bl == low or bl.startswith(low) or low.startswith(bl) { return b.name; }
    }
    f ++> Buyer(name=n, phone="", wants="eggs" if item == "eggs" else item);
    return n;
}

# Rough feed guide in kg per bird per day (Kenyan farm averages - adjust to your feed supplier's chart)
def expected_feed_per_bird(bird_type: str, age_days: int) -> float {
    if bird_type == "broiler" {
        if age_days <= 7 { return 0.02; }
        if age_days <= 14 { return 0.045; }
        if age_days <= 21 { return 0.075; }
        if age_days <= 28 { return 0.11; }
        if age_days <= 35 { return 0.15; }
        return 0.17;
    }
    if bird_type == "layer" {
        if age_days <= 7 { return 0.012; }
        if age_days <= 42 { return 0.035; }
        if age_days <= 126 { return 0.07; }
        return 0.12;
    }
    # kienyeji (improved indigenous)
    if age_days <= 7 { return 0.012; }
    if age_days <= 42 { return 0.03; }
    return 0.08;
}

# Every batch on the farm, in order B1, B2, B3...
def batch_number(bid: str) -> int {
    n = bid[1:];
    return int(n) if n.isdigit() else 9999;
}

def farm_batches(f: Farm) -> list[Batch] {
    found = [f -->[?:House] -->[?:Batch]];
    pairs = sorted([(batch_number(found[i].batch_id), i) for i in range(len(found))]);
    return [found[p[1]] for p in pairs];
}

# "B1" -> next free id "B4" (looks at the highest number used so far)
def next_batch_id(f: Farm) -> str {
    top = 0;
    for b in farm_batches(f) {
        num = b.batch_id[1:];
        if num.isdigit() and int(num) > top { top = int(num); }
    }
    return f"B{top + 1}";
}

# A name farmers understand: "B1 · Broiler chicks · 10 days"
def batch_label(b: Batch) -> str {
    kind = "Birds";
    if b.bird_type == "broiler" {
        kind = "Broiler chicks" if b.age_days <= 21 else "Broilers";
    } elif b.bird_type == "layer" {
        kind = "Layer chicks" if b.age_days <= 42 else ("Layer pullets" if b.age_days <= 126 else "Layer hens");
    } elif b.bird_type == "kienyeji" {
        kind = "Kienyeji chicks" if b.age_days <= 42 else "Kienyeji";
    }
    return f"{b.batch_id} · {kind} · {b.age_days} days";
}

# Latest health level for a batch ("GREEN" if never checked)
def latest_health(b: Batch) -> str {
    checks = [b -->[?:HealthCheck]];
    if len(checks) == 0 { return "GREEN"; }
    latest = checks[0];
    for c in checks {
        if c.date >= latest.date { latest = c; }
    }
    return latest.level;
}

# What a batch can sell now ("" if nothing)
def market_offer(b: Batch) -> str {
    if b.bird_type == "broiler" and b.age_days >= 35 {
        return f"{b.alive} broilers ready for market ({b.age_days} days old)";
    }
    if b.bird_type == "kienyeji" and b.age_days >= 120 {
        return f"{b.alive} kienyeji chickens ready for market";
    }
    if b.bird_type == "layer" {
        recs = [r for r in daily_totals(b) if r.eggs > 0];
        if len(recs) > 0 {
            trays = recs[-1].eggs // 30;
            if trays > 0 { return f"about {trays} trays of eggs a day"; }
        }
    }
    return "";
}

"""Write a short WhatsApp message from the farm to a buyer, offering what is ready for sale.
Match the offer to what the buyer wants. Friendly Kenyan business tone,
written in the language given (English, Kiswahili or Sheng), following HOW TO WRITE EVERY REPLY in the language guide.
Invite them to reply with quantity and delivery day. Do not invent prices or numbers not given."""
def buyer_broadcast(farm_name: str, buyer_name: str, buyer_wants: str, offers: list[str], language: str, language_guide: str) -> str by writer();

# ---------- WALKER: feed delivered to the store ----------
walker receive_feed {
    has kg: float;
    has date: str;
    has cost_ksh: float = 0.0;

    can add with Root entry {
        f = [here -->[?:Farm]][0];
        fs = [f -->[?:FeedStore]][0];
        fs.stock_kg += self.kg;
        fs ++> FeedDelivery(date=self.date, kg=self.kg, cost_ksh=self.cost_ksh);
        print(f"Feed received: {self.kg} kg. Store now {fs.stock_kg:.0f} kg.");
    }
}

# ---------- WALKER: feed status, days left, over/under feeding ----------
walker feed_report {
    has alerts: list[str] = [];
    has days_left: float = 0.0;
    has stock_kg: float = 0.0;
    has lines: list[str] = [];
    has quiet: bool = False;
    has daily_need: float = 0.0;     # kg a day for all birds now
    has on_order_kg: float = 0.0;    # feed ordered from suppliers, not yet arrived
    has bags_to_order: int = 0;      # 50 kg bags still needed for the next 7 days

    can check with Root entry {
        f = [here -->[?:Farm]][0];
        fs = [f -->[?:FeedStore]][0];
        self.stock_kg = fs.stock_kg;
        if not self.quiet { print(f"\n--- FEED & INVENTORY ---\nFeed in store: {fs.stock_kg:.0f} kg"); }

        daily_need = 0.0;
        for b in farm_batches(f) {
            need = expected_feed_per_bird(b.bird_type, b.age_days) * b.alive;
            daily_need += need;
            recs = [r for r in daily_totals(b) if r.feed_kg > 0];
            line = f"  {b.batch_id}: needs about {need:.0f} kg/day";
            if len(recs) > 0 {
                used = recs[-1].feed_kg;
                then = feed_need_on(b, recs[-1].date);       # what it should have eaten THAT day (its age and birds then)
                line = line + f", used {used:.0f} kg on {recs[-1].date} (expected about {then:.0f} kg that day)";
                if then > 0 and used > 1.25 * then {
                    self.alerts.append(f"{b.batch_id}: used {used:.0f} kg on {recs[-1].date} vs about {then:.0f} kg expected - check for feed wastage, spills or rats.");
                } elif then > 0 and used < 0.75 * then {
                    self.alerts.append(f"{b.batch_id}: ate only {used:.0f} kg on {recs[-1].date} vs about {then:.0f} kg expected - birds may be sick or feeders empty.");
                }
            }
            self.lines.append(line.strip());
            if not self.quiet { print(line); }
        }

        self.daily_need = daily_need;
        self.on_order_kg = sum([s.qty for s in [f -->[?:SupplyOrder]] if s.kind == "Feed" and s.status == "ordered"]);
        if daily_need > 0 {
            self.days_left = fs.stock_kg / daily_need;
            self.lines.append(f"Whole farm needs about {daily_need:.0f} kg/day; feed lasts about {self.days_left:.1f} days.");
            if not self.quiet { print(f"Whole farm needs about {daily_need:.0f} kg/day -> feed lasts about {self.days_left:.1f} days."); }
            # whole 50 kg bags, rounded up, for 7 days - minus what is in store and what is already ordered
            self.bags_to_order = int(math.ceil(max(0.0, daily_need * 7 - fs.stock_kg - self.on_order_kg) / 50.0));
            coming = f" {self.on_order_kg:,.0f} kg is already ordered." if self.on_order_kg > 0 else "";
            if self.days_left < 3 {
                if self.bags_to_order > 0 {
                    self.alerts.append(f"URGENT: feed runs out in about {self.days_left:.1f} days. Order about {self.bags_to_order} bags of 50 kg now to last one week.{coming}");
                } else {
                    self.alerts.append(f"URGENT: feed runs out in about {self.days_left:.1f} days.{coming} Make sure it arrives in time.");
                }
            } elif self.days_left < 7 and self.bags_to_order > 0 {
                self.alerts.append(f"Feed runs out in about {self.days_left:.1f} days. Plan an order of about {self.bags_to_order} bags of 50 kg to last one week.{coming}");
            }
        }
        if not self.quiet { for a in self.alerts { print(f"  ALERT: {a}"); } }
    }
}

# ---------- WALKER: market-ready alerts + buyer broadcasts ----------
walker market_alerts {
    has offers: list[str] = [];
    has blocked: list[str] = [];
    has messages: list[str] = [];
    has quiet: bool = False;
    has broadcast: bool = True;      # False = just list what is ready, do not write buyer messages

    can check with Root entry {
        f = [here -->[?:Farm]][0];
        if not self.quiet { print("\n--- MARKET ---"); }
        for b in farm_batches(f) {
            offer = market_offer(b);
            if offer == "" { continue; }
            if latest_health(b) == "RED" {
                self.blocked.append(f"{b.batch_id}: {offer} - BLOCKED by RED health alert until a vet clears it");
                if not self.quiet { print(f"  {b.batch_id}: {offer} - BLOCKED: RED health alert. Do not sell until a vet clears the batch."); }
                continue;
            }
            self.offers.append(f"{b.batch_id}: {offer}");
            if not self.quiet { print(f"  {b.batch_id}: {offer}"); }
        }
        if len(self.offers) == 0 or not self.broadcast {
            if len(self.offers) == 0 and not self.quiet { print("  Nothing ready to sell right now."); }
            disengage;
        }
        for buyer in [f -->[?:Buyer]] {
            msg = plain_text(buyer_broadcast(f.name, buyer.name, buyer.wants, self.offers, "English", LANGUAGE_GUIDE));
            self.messages.append(msg);
            print(f"\n  To {buyer.name} ({buyer.phone}):\n  {msg}");
        }
    }
}

# ---------- WALKER: record a sale ----------
walker record_sale {
    has batch_id: str;
    has buyer: str;
    has item: str;
    has qty: int;
    has price_each: float;
    has date: str;
    has saved: bool = False;
    has note: str = "";          # what happened, in English (used to write the farmer's reply)

    can save with Root entry {
        found = [b for b in [here -->[?:Farm] -->[?:House] -->[?:Batch]] if b.batch_id == self.batch_id];
        if len(found) == 0 {
            self.note = f"No batch called {self.batch_id}. Sale NOT saved.";
            print(self.note);
            disengage;
        }
        b = found[0];
        if self.qty <= 0 or self.price_each <= 0 {
            self.note = "A sale needs a number above 0 and a price above 0. Sale NOT saved.";
            print(self.note);
            disengage;
        }
        if latest_health(b) == "RED" {
            self.note = f"SALE BLOCKED for {b.batch_id}: it has a RED health alert. Selling sick birds can spread disease. A vet must clear the batch first.";
            print(self.note);
            disengage;
        }
        # Eggs: once egg counts are recorded, you cannot sell more than collected minus already sold
        if self.item == "eggs" and egg_counts_recorded(b) and self.qty > eggs_in_store(b) {
            self.note = f"Only {eggs_in_store(b)} eggs from {b.batch_id} are in the records (collected minus sold), so {self.qty} eggs cannot be sold. Save today's egg count in a daily report first. Sale NOT saved.";
            print(self.note);
            disengage;
        }
        if self.item != "eggs" {
            if self.qty > b.alive {
                self.note = f"Only {b.alive} birds in {b.batch_id}, cannot sell {self.qty}. Sale NOT saved.";
                print(self.note);
                disengage;
            }
            b.alive -= self.qty;
        }
        total = r0(self.qty * self.price_each);       # money is kept in whole shillings
        f = [here -->[?:Farm]][0];
        self.buyer = find_or_add_buyer(f, self.buyer, self.item);
        b ++> Sale(date=self.date, buyer=self.buyer, item=self.item, qty=self.qty,
                   price_each=self.price_each, total=total);
        self.saved = True;
        each = f"KSh {self.price_each:,.0f}" if self.price_each == int(self.price_each) else f"KSh {self.price_each:,.2f}";
        if self.item == "eggs" {
            self.note = f"Sale saved: {sale_qty_text(self.qty, self.price_each)} from {b.batch_id} to {self.buyer} = KSh {total:,.0f}.";
        } else {
            self.note = f"Sale saved: {self.qty} {self.item} from {b.batch_id} to {self.buyer} at {each} each = KSh {total:,.0f}.";
        }
        if self.item != "eggs" { self.note = self.note + f" {b.alive} birds left in {b.batch_id}."; }
        m = batch_money(b, feed_price_per_kg(f));
        self.note = self.note + f" {b.batch_id} so far: sales KSh {m.income:,.0f}, costs KSh {m.feed_cost + m.other_cost:,.0f}, profit KSh {m.balance:,.0f}.";
        print(self.note);
    }
}

# ---------- WALKER: vet clears a batch after a RED alert ----------
walker vet_clear {
    has batch_id: str;
    has date: str;
    has vet_note: str = "Cleared by vet";

    can clear with Root entry {
        for b in [here -->[?:Farm] -->[?:House] -->[?:Batch]] {
            if b.batch_id == self.batch_id {
                b ++> HealthCheck(date=self.date, level="GREEN", summary=self.vet_note);
                print(f"{b.batch_id} cleared by vet. Sales allowed again.");
            }
        }
    }
}

# ---------- PROFIT PER BATCH (feed is the biggest cost on a poultry farm) ----------
glob DEFAULT_FEED_PRICE_PER_KG = 70.0;   # KSh per kg, used until real feed deliveries with prices are recorded

obj BatchMoney {
    has income: float;      # KSh from sales of this batch
    has feed_kg: float;     # feed this batch has eaten (from worker reports)
    has feed_cost: float;   # KSh
    has balance: float;     # profit = income - feed cost - other costs
    has other_cost: float = 0.0;   # chicks, vaccines, vet, labour... (recorded costs)
    has bird_income: float = 0.0;
    has egg_income: float = 0.0;
}

# Average price actually paid for feed, from deliveries that have a cost
def feed_price_per_kg(f: Farm) -> float {
    deliveries = [d for d in [f -->[?:FeedStore] -->[?:FeedDelivery]] if d.kg > 0 and d.cost_ksh > 0];
    if len(deliveries) == 0 { return DEFAULT_FEED_PRICE_PER_KG; }
    return r2(sum([d.cost_ksh for d in deliveries]) / sum([d.kg for d in deliveries]));     # to the cent
}

# Feed cost of each batch: the farm total is (all feed eaten x price), rounded once;
# each batch gets its rounded share and any shilling left over from rounding goes to the
# batch that ate the most, so the batch costs always add up to the farm total.
def feed_cost_shares(f: Farm, price: float) -> dict[str, float] {
    bs = [f -->[?:House] -->[?:Batch]];
    kgs = [sum([r.feed_kg for r in [b -->[?:Record]]]) for b in bs];
    shares: dict[str, float] = {};
    if len(bs) == 0 { return shares; }
    total = r0(sum(kgs) * price);
    parts = [r0(k * price) for k in kgs];
    big = 0;
    for i in range(len(bs)) {
        if kgs[i] > kgs[big] { big = i; }
    }
    parts[big] = parts[big] + (total - sum(parts));
    for i in range(len(bs)) { shares[bs[i].batch_id] = parts[i]; }
    return shares;
}

# Every amount is rounded to whole shillings FIRST, so profit = sales - feed - other costs adds up exactly
# on every page (batch rows and farm totals use the same rounded numbers).
def batch_money(b: Batch, price: float) -> BatchMoney {
    sales = [b -->[?:Sale]];
    eggs = r0(sum([s.total for s in sales if s.item == "eggs"]));
    birds = r0(sum([s.total for s in sales if s.item != "eggs"]));
    income = birds + eggs;
    kg = sum([r.feed_kg for r in [b -->[?:Record]]]);
    cost = r0(kg * price);
    farms = [b <--[?:House] <--[?:Farm]];
    if len(farms) > 0 { cost = float(feed_cost_shares(farms[0], price).get(b.batch_id, cost)); }
    other = r0(sum([e.amount for e in [b -->[?:Expense]]]));
    return BatchMoney(income=income, feed_kg=kg, feed_cost=cost, balance=income - cost - other,
                      other_cost=other, bird_income=birds, egg_income=eggs);
}

# Has anyone recorded egg counts for this batch yet? (until then the opening stock is unknown)
def egg_counts_recorded(b: Batch) -> bool {
    return len([r for r in [b -->[?:Record]] if r.eggs > 0]) > 0;
}

# KSh per kg as farmers write it: 70, 70.8
def per_kg_text(x: float) -> str {
    t = f"{x:,.1f}";
    return t[:-2] if t.endswith(".0") else t;
}

# Eggs from a batch still on the farm: collected (daily reports) minus sold
def eggs_in_store(b: Batch) -> int {
    return sum([r.eggs for r in [b -->[?:Record]]]) - sum([s.qty for s in [b -->[?:Sale]] if s.item == "eggs"]);
}

# "20 trays at KSh 400 a tray" / "45 eggs at KSh 13.50 each" - price shown so it multiplies to the total
def sale_qty_text(qty: int, price_each: float) -> str {
    tray = price_each * 30.0;
    if qty % 30 == 0 and qty > 0 {
        return f"{qty // 30} trays ({qty} eggs) at KSh {tray:,.0f} a tray";
    }
    if price_each == int(price_each) { return f"{qty} eggs at KSh {price_each:,.0f} each"; }
    return f"{qty} eggs at KSh {price_each:,.2f} each (KSh {tray:,.0f} a tray)";
}

# ---------- WALKER: sales and income summary ----------
walker sales_report {
    has total_income: float = 0.0;
    has feed_cost: float = 0.0;          # all feed bought (deliveries)
    has feed_eaten_cost: float = 0.0;    # feed eaten by the batches (reports x price)
    has lines: list[str] = [];
    has profit_lines: list[str] = [];
    has quiet: bool = False;

    can show with Root entry {
        f = [here -->[?:Farm]][0];
        if not self.quiet { print("\n--- SALES ---"); }
        for b in farm_batches(f) {
            sales = [b -->[?:Sale]];
            if len(sales) == 0 { continue; }
            income = batch_money(b, 0.0).income;
            self.total_income += income;
            self.lines.append(f"{b.batch_id}: {len(sales)} sale(s), KSh {income:,.0f}");
            if not self.quiet {
                print(f"  {b.batch_id}: {len(sales)} sale(s), KSh {income:,.0f}");
                for s in sales {
                    print(f"     {s.date} {s.buyer}: {s.qty} {s.item} x KSh {s.price_each} = KSh {s.total:,.0f}");
                }
            }
        }
        self.feed_cost = sum([d.cost_ksh for d in [f -->[?:FeedStore] -->[?:FeedDelivery]]]);
        if not self.quiet { print(f"  TOTAL sales: KSh {self.total_income:,.0f} | Feed bought: KSh {self.feed_cost:,.0f}"); }

        # Profit per batch: sales minus the feed the batch has eaten
        price = feed_price_per_kg(f);
        if not self.quiet { print(f"\n--- PROFIT PER BATCH (sales - feed eaten at KSh {price:.2f}/kg - recorded costs) ---"); }
        for b in farm_batches(f) {
            m = batch_money(b, price);
            self.feed_eaten_cost += m.feed_cost;
            line = f"{b.batch_id}: sales KSh {m.income:,.0f}, feed {m.feed_kg:.0f} kg = KSh {m.feed_cost:,.0f}, other costs KSh {m.other_cost:,.0f}, profit KSh {m.balance:,.0f}";
            self.profit_lines.append(line);
            if not self.quiet { print(f"  {line}"); }
        }
    }
}



# =====================================================================
# STEP 5: MANAGER (one front door for every message + morning briefing)
# =====================================================================

obj Route {
    has intent: str;      # exactly one of: report, new_batch, health, advice, hatchery, feed, sales, order, supply, vet_visit, expense, question, briefing
    has batch_id: str;    # one of batch_ids, or "" if no batch is mentioned
    has language: str;    # "English", "Kiswahili" or "Sheng"
}

"""Decide what a poultry farm message is about, so the right KukuMind agent handles it.
intent must be exactly one of:
- report: a worker giving today's numbers (deaths, feed used, eggs, weights). e.g. "B1 leo vifo 3, chakula gunia moja"
- new_batch: NEW birds arriving on the farm - bought chicks or birds, a new flock to register.
          e.g. "Tumeleta vifaranga 500 wa broiler leo, House B", "Received 1000 layer chicks today"
- health: sick birds, symptoms, strange droppings, coughing, sudden deaths, or a photo of birds.
          e.g. "kuku zinakohoa", "my chickens have green droppings"
- advice: how-to questions about brooding, heat, vaccines schedule, hatching, candling, housing, care.
          e.g. "Gumboro lini?", "joto kiasi gani?"
- hatchery: eggs in the incubator - setting eggs, candling results, hatching, hatch rate.
          e.g. "nimeweka mayai 300 ya kienyeji kwa incubator", "E1 candling: 264 fertile", "E2 imeangua vifaranga 410"
- feed: questions about feed stock, when to buy feed, how long feed will last.
- sales: a sale that happened with no booking before ("sold 50 B3 layers at 450 each", "tumeuza mayai trei 20"),
         or questions about selling, buyers, market, prices, income, profit or loss
         (faida, hasara, pesa, "is this batch making money?").
- order: a CUSTOMER booking / ordering birds or eggs for a later day, or a booked order being delivered,
         collected or cancelled, or questions about customer orders.
         e.g. "Mama Njeri ameagiza broilers 100 za Ijumaa kwa 600", "Hotel X wants 20 trays of eggs on Saturday",
         "Deliver O2", "Order ya Kamau imechukuliwa", "Which orders are due this week?"
- supply: ordering or receiving FEED, CHICKS, vaccines or medicine FROM A SUPPLIER, or a feed delivery arriving.
         e.g. "Nimeagiza gunia 40 za chakula kutoka Unga Farm Care, zitafika Jumatatu", "Feed delivery: 20 bags for 70,000",
         "P1 imefika", "Order 1000 layer chicks from Kenchic for Friday"
- vet_visit: booking the vet, the vet having visited, or the vet's fee.
         e.g. "Book the vet for Thursday to vaccinate B1", "Daktari amekuja, amesema B2 ni safi, tumemlipa 2000"
- expense: money PAID for the farm that is not feed or chicks: labour, transport, electricity, water, repairs.
         e.g. "Nimelipa vibarua 5000", "Paid 3,000 for electricity", "Transport ya kuku 1500 for B2"
- question: a QUESTION about the farm's own records or numbers that does not give new numbers to save:
         how many / how much / when / which batch / totals for a day, week or month / comparing batches or agents.
         e.g. "How many birds died this week?", "Tumepata faida ngapi mwezi huu?", "How many eggs did B3 lay yesterday?",
         "Which batch is doing best?", "Ni orders ngapi ziko wiki hii?", "How much have we spent on vaccines?",
         "How many birds do we have now?", "When did the vet last come?"
- briefing: asking for a summary of the farm or today's plan. e.g. "habari ya shamba leo?", "morning report"
If a message has numbers AND symptoms, choose health.
If a message gives NEW numbers to save (deaths, feed, eggs, a sale, an order, a cost), never choose question.
batch_id must be exactly one of batch_ids, or "" if none is mentioned.
Use the language guide to understand English, Kiswahili and Sheng and to set language."""
def route_message(text: str, batch_ids: list[str], language_guide: str) -> Route by llm();

obj ParsedSale {
    has is_record: bool;        # True only if the message says a sale HAPPENED (sold / tumeuza / nimeuza / imeuzwa)
    has batch_id: str;          # one of batch_ids, or ""
    has item: str;              # "birds" or "eggs"
    has birds: int;             # number of birds sold (0 if eggs)
    has egg_trays: int;         # trays of eggs sold (0 if none)
    has loose_eggs: int;        # single eggs sold, not in trays (0 if none)
    has price_per_bird: float;  # KSh, 0 if not said
    has price_per_tray: float;  # KSh, 0 if not said
    has price_per_egg: float;   # KSh, 0 if not said
    has total_ksh: float;       # total money if said, else 0
    has buyer: str;             # buyer name if said, else ""
    has language: str;
    has bird_type: str = "";    # "broiler", "layer" or "kienyeji" if the birds' type is said (kuku wa nyama = broiler), else ""
}

# A sale message that was missing details; the next short message completes it
node PendingSale {
    has text: str;
}

"""Read a farm message about selling. Copy numbers exactly as said; do NOT calculate.
is_record is True only if the message reports a sale that already happened.
Use the language guide for Kiswahili / Sheng number words. batch_id must be one of batch_ids or ""."""
def parse_sale(text: str, batch_ids: list[str], buyers: list[str], language_guide: str) -> ParsedSale by llm();

"""Ask the farmer, in the language given, for the missing details (listed in missing).
Follow HOW TO WRITE EVERY REPLY in the language guide. One or two short sentences."""
def ask_sale_details(missing: list[str], language: str, language_guide: str) -> str by writer();

"""Tell the farmer, in the language given, what KukuMind just did, using result exactly
(numbers unchanged). If something was blocked or not saved, explain why simply.
Follow HOW TO WRITE EVERY REPLY in the language guide."""
def confirm_action(result: str, language: str, language_guide: str) -> str by writer();

# ---------- NEW FLOCK: register bought chicks / birds as a new batch ----------
walker add_batch {
    has bird_type: str;          # broiler, layer or kienyeji
    has count: int;
    has house_name: str;
    has age_days: int = 1;       # day-old chicks = 1
    has date: str = "";
    has batch_id: str = "";      # filled in when created
    has note: str = "";

    can add with Root entry {
        f = [here -->[?:Farm]][0];
        houses = [h for h in [f -->[?:House]] if h.name == self.house_name];
        if len(houses) == 0 {
            self.note = f"No house called '{self.house_name}'. New batch NOT saved.";
            print(self.note);
            disengage;
        }
        self.batch_id = next_batch_id(f);
        houses[0] ++> Batch(batch_id=self.batch_id, bird_type=self.bird_type,
                            start_count=self.count, alive=self.count, age_days=self.age_days,
                            added=self.date or today());
        heat = brooding_temp(self.age_days);
        self.note = (f"New batch {self.batch_id} registered: {self.count} {self.bird_type} birds, "
                     + f"{self.age_days} day(s) old, in {self.house_name}. {heat}. "
                     + f"Workers can now report on {self.batch_id}, for example: '{self.batch_id} leo vifo 0, chakula kilo 20'.");
        print(self.note);
    }
}

obj ParsedNewBatch {
    has bird_type: str;   # "broiler", "layer" or "kienyeji", or "" if not said
    has count: int;       # number of birds/chicks that arrived, 0 if not said
    has house: str;       # house name if said, e.g. "House B", else ""
    has age_days: int;    # age in days if said; 1 for day-old chicks; 0 if not said
    has language: str;
}

"""Read a message about NEW birds arriving on the farm (bought chicks or birds).
Copy numbers exactly as said. "vifaranga" = chicks (day-old unless an age is said).
bird_type must be "broiler", "layer" or "kienyeji" (kuku wa nyama = broiler, kuku wa mayai = layer,
kuku wa kienyeji / improved kienyeji / kari = kienyeji), or "" if not said.
house must be one of houses (match loosely, e.g. "nyumba B" = "House B"), or "" if not said."""
def parse_new_batch(text: str, houses: list[str], language_guide: str) -> ParsedNewBatch by llm();

obj ParsedHatch {
    has action: str;      # "set" (eggs put in incubator), "candle" (candling result), "hatch" (chicks hatched), or "question"
    has set_id: str;      # egg set like "E1" if mentioned, else ""
    has bird_type: str;   # "broiler", "layer" or "kienyeji" (for "set"), else ""
    has eggs: int;        # eggs put in the incubator (for "set")
    has fertile: int;     # fertile eggs found at candling
    has hatched: int;     # chicks hatched
    has house: str;       # house name if mentioned, e.g. "House A", else ""
    has language: str;
}

"""Read a message about the incubator / hatchery. Copy numbers exactly as said.
action is "question" if the farmer is asking something rather than reporting.
Use the language guide for Kiswahili / Sheng number words."""
def parse_hatch(text: str, egg_sets: list[str], language_guide: str) -> ParsedHatch by llm();

"""Answer the farmer's question using ONLY the facts given (feed stock, needs, sales, buyers).
Follow HOW TO WRITE EVERY REPLY in the language guide and reply in the language given.
Do not invent numbers that are not in facts."""
def farm_answer(question: str, facts: str, language: str, language_guide: str) -> str by writer();

"""Write the farm's morning briefing for the owner, in the language given.
Order: urgent problems first (RED health alerts, urgent feed, very high deaths),
then today's tasks, then feed status, then what can be sold.
Use ONLY the facts given and keep every number exactly as given.
Plain text, no markdown. Short lines, at most 8 lines. Start by greeting the owner by name and naming the farm."""
def write_briefing(farm_name: str, owner: str, facts: str, language: str, language_guide: str) -> str by writer();

# ---------- WALKER: morning briefing ----------
walker morning_briefing {
    has language: str = "English";
    has reply: str = "";
    has facts: list[str] = [];

    can brief with Root entry {
        ensure_writer();
        f = [here -->[?:Farm]][0];
        for b in farm_batches(f) {
            if latest_health(b) == "RED" {
                self.facts.append(f"URGENT: {b.batch_id} has a RED health alert - vet needed, no selling or moving birds.");
            }
        }
        ew = here spawn early_warning_scan(quiet=True);
        for a in ew.alerts { self.facts.append(f"Warning {a}"); }
        tt = here spawn today_tasks(quiet=True);
        for t in tt.tasks { self.facts.append(f"Task {t}"); }
        fr = here spawn feed_report(quiet=True);
        self.facts.append(f"Feed in store: {fr.stock_kg:.0f} kg, lasts about {fr.days_left:.1f} days.");
        for a in fr.alerts { self.facts.append(f"Feed alert: {a}"); }
        ma = here spawn market_alerts(quiet=True, broadcast=False);
        for o in ma.offers { self.facts.append(f"Ready to sell: {o}"); }
        for x in ma.blocked { self.facts.append(f"Not for sale: {x}"); }
        for x in booking_tasks(f) { self.facts.append(f"Orders and bookings: {x}"); }

        self.reply = plain_text(write_briefing(f.name, f.owner, "\n".join(self.facts), self.language, LANGUAGE_GUIDE));
        print(f"\n=== MORNING BRIEFING ({self.language}) ===\n{self.reply}");
    }
}

# ---------- WALKER: KukuMind front door - send ANY message here ----------
walker kukumind {
    has text: str;
    has date: str;
    has photo_path: str = "";
    has intent: str = "";
    has reply: str = "";
    has level: str = "";          # RED / AMBER / GREEN for health checks
    has message: str = "";        # reply without the [RED - URGENT] badge (the web page shows its own badge)
    has vet_message: str = "";    # ready-to-send message for the vet, when a health check needs one
    has vet_link: str = "";
    has force: str = "";          # set when the farmer talks to one agent directly from its own page
    has language: str = "";       # reply language chosen on the web page ("" or "Auto" = same as the message)

    can route with Root entry {
        ensure_writer();
        batch_ids = [b.batch_id for b in [here -->[?:Farm] -->[?:House] -->[?:Batch]]];
        r = route_message(self.text, batch_ids, LANGUAGE_GUIDE);
        r.language = reply_lang(self.language, r.language);
        self.intent = r.intent;
        # a short answer to "which batch / what price?" finishes the sale that was waiting
        if len([here -->[?:Farm] -->[?:PendingSale]]) > 0 and len(self.text) <= 60 and self.force in ["", "sales"] {
            self.intent = "sales";
        }
        if self.force in ["report", "health", "advice", "hatchery", "feed", "sales", "briefing"] {
            # each agent's own chat also takes its own kind of booking:
            # Flock records -> new flocks, Sales -> customer orders and costs, Feed -> supply orders, Disease detector -> vet visits
            own = {"report": ["new_batch"], "sales": ["order", "expense"], "feed": ["supply"], "health": ["vet_visit"]};
            if r.intent not in own.get(self.force, []) { self.intent = self.force; }
        }
        if self.photo_path { self.intent = "health"; }     # a photo always means a health check

        print(f"\n>>> Message: {self.text}\n>>> Manager sends it to: {self.intent.upper()} agent");

        if self.intent == "new_batch" {
            f = [here -->[?:Farm]][0];
            houses = [h.name for h in [f -->[?:House]]];
            nb = parse_new_batch(self.text, houses, LANGUAGE_GUIDE);
            missing: list[str] = [];
            if nb.bird_type not in ["broiler", "layer", "kienyeji"] { missing.append("the type of birds (broiler, layer or kienyeji)"); }
            if nb.count <= 0 { missing.append("how many birds arrived"); }
            if nb.house not in houses { missing.append(f"which house ({', '.join(houses)})"); }
            if len(missing) > 0 {
                self.reply = plain_text(ask_sale_details(missing, reply_lang(self.language, nb.language or r.language), LANGUAGE_GUIDE));
            } else {
                wb = here spawn add_batch(bird_type=nb.bird_type, count=nb.count, house_name=nb.house,
                                          age_days=nb.age_days if nb.age_days > 0 else 1, date=self.date);
                note = wb.note;
                # chicks that were ordered earlier: the supply order is closed and its cost goes on the new batch
                waiting = [s for s in farm_supplies(f) if s.status == "ordered" and s.kind == "Chicks" and s.bird_type == nb.bird_type];
                if wb.batch_id != "" and len(waiting) == 1 {
                    s = waiting[0];
                    s.status = "received";
                    s.done_date = self.date;
                    s.qty = float(nb.count);
                    note = note + f" Supply order {s.supply_id} is now marked received.";
                    if s.cost > 0 { note = note + " Chick cost " + add_cost(f, wb.batch_id, "Chicks", s.cost, f"{nb.count} chicks ({s.supply_id})", self.date); }
                }
                self.reply = plain_text(confirm_action(note, reply_lang(self.language, nb.language or r.language), LANGUAGE_GUIDE));
            }
            self.intent = "report";      # the Flock records agent looks after new batches

        } elif self.intent == "report" {
            w = here spawn worker_message(text=self.text, date=self.date, language=self.language);
            self.reply = w.reply;

        } elif self.intent == "health" {
            if r.batch_id not in batch_ids {
                self.reply = plain_text(ask_which_batch(batch_ids, r.language, LANGUAGE_GUIDE));
            } else {
                hc = here spawn health_check(batch_id=r.batch_id, description=self.text,
                                            date=self.date, photo_path=self.photo_path, language=r.language if self.language in ["English", "Kiswahili", "Sheng"] else "");
                if hc.result {
                    badge = {"RED": "RED - URGENT", "AMBER": "AMBER - WATCH", "GREEN": "GREEN - OK"}.get(hc.result.level, hc.result.level);
                    self.level = hc.result.level;
                    self.message = hc.result.reply;
                    self.vet_message = hc.vet_message;
                    self.vet_link = hc.vet_link;
                    self.reply = f"[{badge}] {hc.result.reply}";
                }
            }

        } elif self.intent == "question" {
            # the Manager answers from every agent's saved records (numbers worked out by code)
            f = [here -->[?:Farm]][0];
            self.reply = plain_text(manager_answer(self.text, farm_facts(f), r.language, LANGUAGE_GUIDE));

        } elif self.intent == "feed" {
            fr = here spawn feed_report(quiet=True);
            facts = [f"Feed in store: {fr.stock_kg:.0f} kg"] + fr.lines + fr.alerts;
            self.reply = plain_text(manager_answer(self.text, "\n".join(facts) + "\n\nALL FARM RECORDS:\n" + farm_facts([here -->[?:Farm]][0]), r.language, LANGUAGE_GUIDE));

        } elif self.intent == "hatchery" {
            f = [here -->[?:Farm]][0];
            sets = [f"{s.set_id}: {s.eggs_set} {s.bird_type} eggs, day {s.day}, {'done' if s.done else 'in incubator'}" for s in [f -->[?:EggSet]]];
            ph = parse_hatch(self.text, sets, LANGUAGE_GUIDE);
            note = "";
            if ph.action == "set" and ph.eggs > 0 {
                kind = ph.bird_type if ph.bird_type in ["broiler", "layer", "kienyeji"] else "kienyeji";
                ws = here spawn set_eggs(bird_type=kind, eggs=ph.eggs, day=0);
                note = ws.note;
            } elif ph.action == "candle" and ph.set_id != "" {
                wc = here spawn record_candling(set_id=ph.set_id, fertile=ph.fertile);
                note = wc.note;
            } elif ph.action == "hatch" and ph.set_id != "" {
                houses = [h.name for h in [f -->[?:House]]];
                house = ph.house if ph.house in houses else houses[-1];
                wh = here spawn record_hatch(set_id=ph.set_id, hatched=ph.hatched, house_name=house);
                note = wh.note;
            }
            if note != "" {
                self.reply = plain_text(confirm_action(note, reply_lang(self.language, ph.language), LANGUAGE_GUIDE));
            } else {
                a = here spawn ask_advisor(question=self.text, language=r.language);
                self.reply = a.reply;
            }

        } elif self.intent == "sales" {
            # A reported sale is saved; anything else is a sales / profit question
            if not self.record_sale_from_text(r.language) {
                ma = here spawn market_alerts(quiet=True, broadcast=False);
                sr = here spawn sales_report(quiet=True);
                buyers = [f"{b.name} ({b.wants}, {b.phone})" for b in [here -->[?:Farm] -->[?:Buyer]]];
                facts = ([f"Ready to sell: {o}" for o in ma.offers] + [f"Not for sale: {x}" for x in ma.blocked]
                         + sr.lines + [f"Total sales so far: KSh {sr.total_income:,.0f}", f"Buyers: {buyers}"]
                         + ["Profit per batch (sales minus feed eaten minus recorded costs such as chicks, vaccines and labour):"] + sr.profit_lines);
                self.reply = plain_text(manager_answer(self.text, "\n".join(facts) + "\n\nALL FARM RECORDS:\n" + farm_facts([here -->[?:Farm]][0]), r.language, LANGUAGE_GUIDE));
            }

        } elif self.intent == "order" {
            self.handle_order(r.language);
            self.intent = "sales";        # the Sales agent looks after customer orders

        } elif self.intent == "supply" {
            self.handle_supply(r.language);
            self.intent = "feed";         # the Feed & inventory agent looks after supplies

        } elif self.intent == "vet_visit" {
            self.handle_vet_visit(r.language);
            self.intent = "health";       # the Disease detector looks after vet visits

        } elif self.intent == "expense" {
            self.handle_expense(r.language);
            self.intent = "sales";        # costs are part of the profit statement

        } elif self.intent == "briefing" {
            mb = here spawn morning_briefing(language=r.language);
            self.reply = mb.reply;

        } else {
            a = here spawn ask_advisor(question=self.text, language=r.language);
            self.reply = a.reply;
        }
        if self.message == "" { self.message = self.reply; }
        print(f"<<< KukuMind: {self.reply}");
    }

    # A message that reports a sale ("sold 50 B3 layers at 450") is saved as a sale.
    # Returns True if it handled the message (saved, blocked, or asked for missing details).
    def record_sale_from_text(language: str) -> bool {
        f = [root -->[?:Farm]][0];
        batch_ids = [b.batch_id for b in farm_batches(f)];
        buyers = [b.name for b in [f -->[?:Buyer]]];
        # A short answer ("B3", "kwa 420") completes a sale message that was missing details
        pending = [f -->[?:PendingSale]];
        text = self.text;
        if len(pending) > 0 and len(self.text) <= 60 {
            text = pending[0].text + ". " + self.text;
        }
        for p in pending { del p; }
        ps = parse_sale(text, batch_ids, buyers, LANGUAGE_GUIDE);
        if not ps.is_record { return False; }
        lang = reply_lang(self.language, ps.language or language);

        # No batch named: if only one batch can have sold this, use it
        if ps.batch_id not in batch_ids {
            kinds = ["layer"] if ps.item == "eggs" else ([ps.bird_type] if ps.bird_type in ["broiler", "layer", "kienyeji"] else []);
            fits = [b.batch_id for b in farm_batches(f) if b.bird_type in kinds and b.alive > 0];
            if len(fits) == 1 { ps.batch_id = fits[0]; }
        }

        # Code does the arithmetic
        if ps.item == "eggs" {
            qty = ps.egg_trays * 30 + ps.loose_eggs;
            price = ps.price_per_egg;
            if price == 0 and ps.price_per_tray > 0 { price = ps.price_per_tray / 30.0; }
        } else {
            qty = ps.birds;
            price = ps.price_per_bird;
        }
        if price == 0 and ps.total_ksh > 0 and qty > 0 { price = ps.total_ksh / qty; }

        missing: list[str] = [];
        if ps.batch_id not in batch_ids { missing.append(f"which batch ({', '.join(batch_ids)})"); }
        if qty <= 0 { missing.append("how many were sold"); }
        if price <= 0 { missing.append("the price (per bird, per tray, or the total)"); }
        if len(missing) > 0 {
            f ++> PendingSale(text=text);
            self.reply = plain_text(ask_sale_details(missing, lang, LANGUAGE_GUIDE));
            return True;
        }
        b = [x for x in farm_batches(f) if x.batch_id == ps.batch_id][0];
        item = "eggs" if ps.item == "eggs" else b.bird_type + "s";
        w = root spawn record_sale(batch_id=ps.batch_id, buyer=ps.buyer or "buyer not named",
                                   item=item, qty=qty, price_each=price, date=self.date);
        self.reply = plain_text(confirm_action(w.note, lang, LANGUAGE_GUIDE));
        return True;
    }

    # One open booking the message is about: by its reference, else by name, else the only open one
    def pick_open(refs: list[str], names: list[str], ref: str, name: str) -> str {
        r = ref.strip().upper();
        if r in refs { return r; }
        n = name.strip().lower();
        if n != "" {
            hits = [refs[i] for i in range(len(refs)) if n in names[i].lower() or names[i].lower() in n];
            if len(hits) == 1 { return hits[0]; }
        }
        if len(refs) == 1 { return refs[0]; }
        return "";
    }

    def say(note: str, lang: str) {
        self.reply = plain_text(confirm_action(note, lang, LANGUAGE_GUIDE));
    }

    # ---------- customer orders ----------
    def handle_order(language: str) {
        f = [root -->[?:Farm]][0];
        t = today();
        open_o = [o for o in farm_orders(f) if o.status == "booked"];
        listing = [f"{o.order_id}: {order_qty_text(o.item, o.bird_type, o.qty)} for {o.buyer}, delivery {nice_date(o.due, t)}, {order_price_text(o.item, o.price_each)}" for o in open_o];
        po = parse_order(self.text, day_and_date(t), listing,
                         [b.batch_id for b in farm_batches(f)], [b.name for b in [f -->[?:Buyer]]], LANGUAGE_GUIDE);
        lang = reply_lang(self.language, po.language or language);
        if po.action == "book" {
            qty = po.egg_trays * 30 + po.loose_eggs if po.item == "eggs" else po.birds;
            price = po.price_per_tray / 30.0 if po.item == "eggs" else po.price_per_bird;
            if price <= 0 and po.total_ksh > 0 and qty > 0 { price = po.total_ksh / qty; }
            missing: list[str] = [];
            if qty <= 0 { missing.append("how many birds or trays of eggs the buyer wants"); }
            if po.item != "eggs" and po.bird_type not in ["broiler", "layer", "kienyeji"] and po.batch_id == "" {
                missing.append("which birds (broilers, layers or kienyeji)");
            }
            if len(missing) > 0 {
                self.reply = plain_text(ask_sale_details(missing, lang, LANGUAGE_GUIDE));
                return;
            }
            w = root spawn take_order(buyer=po.buyer, item="eggs" if po.item == "eggs" else "birds", bird_type=po.bird_type,
                                      qty=qty, price_each=price, deposit=po.deposit_ksh,
                                      due=resolve_due(po.due_date, po.due_day, po.due_in_days, t),
                                      batch_id=po.batch_id, date=t);
            self.say(w.message, lang);
            return;
        }
        if po.action in ["deliver", "cancel"] {
            ref = self.pick_open([o.order_id for o in open_o], [o.buyer for o in open_o], po.order_id, po.buyer);
            if ref == "" {
                if len(open_o) == 0 { self.say("There are no open customer orders.", lang); return; }
                self.reply = plain_text(ask_sale_details([f"which order ({'; '.join(listing)})"], lang, LANGUAGE_GUIDE));
                return;
            }
            if po.action == "cancel" {
                c = root spawn cancel_ref(ref_id=ref);
                self.say(c.message, lang);
                return;
            }
            o = [x for x in open_o if x.order_id == ref][0];
            qty = (po.egg_trays * 30 + po.loose_eggs) if o.item == "eggs" else po.birds;
            price = po.price_per_tray / 30.0 if o.item == "eggs" else po.price_per_bird;
            if price <= 0 and po.total_ksh > 0 { price = po.total_ksh / (qty if qty > 0 else o.qty); }
            wd = root spawn deliver_order(order_id=ref, qty=qty, price_each=price, batch_id=po.batch_id, date=t);
            self.say(wd.message, lang);
            return;
        }
        done = [o for o in farm_orders(f) if o.status == "delivered"][-5:];
        facts = ["Open customer orders:"] + (listing if len(listing) > 0 else ["none"]);
        facts = facts + ["Recently delivered:"] + [f"{o.order_id}: {order_qty_text(o.item, o.bird_type, o.qty)} to {o.buyer} on {o.done_date}" for o in done];
        facts = facts + [f"Birds alive by type: " + ", ".join([f"{k}: {sum([b.alive for b in farm_batches(f) if b.bird_type == k])} ({booked_birds(f, k)} booked)" for k in ["broiler", "layer", "kienyeji"]])];
        facts = facts + [f"Eggs in store (from the records): {sum([max(0, eggs_in_store(b)) for b in farm_batches(f)])} ({booked_eggs(f)} booked)"];
        self.reply = plain_text(manager_answer(self.text, "\n".join(facts) + "\n\nALL FARM RECORDS:\n" + farm_facts(f), lang, LANGUAGE_GUIDE));
    }

    # ---------- supply orders: feed, chicks, vaccines, medicine ----------
    def handle_supply(language: str) {
        f = [root -->[?:Farm]][0];
        t = today();
        open_s = [s for s in farm_supplies(f) if s.status == "ordered"];
        listing = [f"{s.supply_id}: {supply_qty_text(s.kind, s.qty)}" + (f" from {s.supplier}" if s.supplier else "") + f", expected {nice_date(s.due, t)}" for s in open_s];
        houses = [h.name for h in [f -->[?:House]]];
        ps = parse_supply(self.text, day_and_date(t), listing, houses,
                          [b.batch_id for b in farm_batches(f)], LANGUAGE_GUIDE);
        lang = reply_lang(self.language, ps.language or language);
        kind = ps.kind if ps.kind in SUPPLY_KINDS else "Other";
        qty = ps.feed_bags * 50.0 + ps.feed_kg if kind == "Feed" else float(ps.count);
        if ps.action in ["received", "cancel"] {
            same = [s for s in open_s if s.kind == kind];
            ref = self.pick_open([s.supply_id for s in open_s], [s.supplier + " " + s.kind for s in open_s], ps.supply_id, ps.supplier);
            if ref == "" and len(same) == 1 { ref = same[0].supply_id; }
            if ps.action == "cancel" {
                if ref == "" { self.say("Which supply order should be cancelled? Open: " + ("; ".join(listing) or "none"), lang); return; }
                c = root spawn cancel_ref(ref_id=ref);
                self.say(c.message, lang);
                return;
            }
            if ref != "" {
                wr = root spawn receive_supply(supply_id=ref, qty=qty, cost=ps.cost_ksh if ps.cost_ksh > 0 else -1.0, date=t);
                self.say(wr.message, lang);
                return;
            }
        }
        if ps.action in ["order", "received"] {
            w = root spawn order_supply(kind=kind, qty=qty, cost=ps.cost_ksh, supplier=ps.supplier,
                                        due=resolve_due(ps.due_date, ps.due_day, ps.due_in_days, t),
                                        bird_type=ps.bird_type, house=ps.house, batch_id=ps.batch_id, date=t,
                                        received_now=ps.action == "received");
            self.say(w.message, lang);
            return;
        }
        fr = root spawn feed_report(quiet=True);
        facts = ["Open supply orders:"] + (listing if len(listing) > 0 else ["none"]) + [f"Feed in store: {fr.stock_kg:.0f} kg"] + fr.lines + fr.alerts;
        self.reply = plain_text(manager_answer(self.text, "\n".join(facts) + "\n\nALL FARM RECORDS:\n" + farm_facts(f), lang, LANGUAGE_GUIDE));
    }

    # ---------- vet visits ----------
    def handle_vet_visit(language: str) {
        f = [root -->[?:Farm]][0];
        t = today();
        open_v = [v for v in farm_visits(f) if v.status == "booked"];
        listing = [f"{v.visit_id}: " + (v.batch_id or "whole farm") + f", {nice_date(v.visit_date, t)}, {v.reason}" for v in open_v];
        pv = parse_vet_visit(self.text, day_and_date(t), listing,
                             [b.batch_id for b in farm_batches(f)], LANGUAGE_GUIDE);
        lang = reply_lang(self.language, pv.language or language);
        if pv.action == "book" {
            w = root spawn book_vet(batch_id=pv.batch_id, visit_date=resolve_due(pv.due_date, pv.due_day, pv.due_in_days, t),
                                    reason=clean_text(pv.reason), date=t);
            self.say(w.message, lang);
            self.vet_message = w.vet_message;
            self.vet_link = w.vet_link;
            return;
        }
        if pv.action in ["done", "cancel"] {
            ref = self.pick_open([v.visit_id for v in open_v], [v.batch_id for v in open_v], pv.visit_id, pv.batch_id);
            if ref == "" and pv.action == "done" {
                # the vet came without a booking: book it and close it at once
                nb = root spawn book_vet(batch_id=pv.batch_id, visit_date=t, reason=clean_text(pv.reason) or "farm visit", date=t);
                ref = nb.visit_id;
            }
            if ref == "" { self.say("Which vet visit? Open: " + ("; ".join(listing) or "none"), lang); return; }
            if pv.action == "cancel" {
                c = root spawn cancel_ref(ref_id=ref);
                self.say(c.message, lang);
                return;
            }
            wf = root spawn finish_vet(visit_id=ref, cost=pv.cost_ksh, cleared=pv.cleared, outcome=clean_text(pv.outcome), date=t);
            self.say(wf.message, lang);
            return;
        }
        facts = ["Booked vet visits:"] + (listing if len(listing) > 0 else ["none"]) + [f"Farm vet: {farm_vet(f).name} {farm_vet(f).phone}"];
        self.reply = plain_text(manager_answer(self.text, "\n".join(facts) + "\n\nALL FARM RECORDS:\n" + farm_facts(f), lang, LANGUAGE_GUIDE));
    }

    # ---------- costs paid ----------
    def handle_expense(language: str) {
        f = [root -->[?:Farm]][0];
        pe = parse_expense(self.text, EXPENSE_KINDS, [b.batch_id for b in farm_batches(f)], LANGUAGE_GUIDE);
        lang = reply_lang(self.language, pe.language or language);
        if pe.amount_ksh <= 0 {
            self.reply = plain_text(ask_sale_details(["how much was paid (KSh)"], lang, LANGUAGE_GUIDE));
            return;
        }
        kind = pe.kind if pe.kind in EXPENSE_KINDS else "Other";
        bid = pe.batch_id if pe.batch_id in [b.batch_id for b in farm_batches(f)] else "all";
        txt = add_cost(f, bid, kind, pe.amount_ksh, pe.note, today());
        if txt == "" { self.say("There is no batch on the farm yet, so the cost was NOT saved. Register a flock first.", lang); return; }
        self.say("Cost saved: " + (pe.note + " - " if pe.note else "") + txt + " The profit on the Sales page now includes it.", lang);
    }
}



# =====================================================================
# WEB API - walkers the KukuMind web page calls (walker:pub = open endpoint)
# =====================================================================
import base64;
import tempfile;
import from datetime { date }

obj ChatReply {
    has intent: str;      # which agent answered: report, health, advice, feed, sales, briefing
    has level: str;       # RED / AMBER / GREEN for health checks, "" otherwise
    has reply: str;
    has vet_message: str = "";   # ready-to-send message for the vet (RED cases)
    has vet_link: str = "";      # WhatsApp link that opens that message to the vet
}

obj RecordView {
    has date: str;
    has batch_id: str;
    has kind: str;        # "Report", "Sale", "Health", "New batch"
    has detail: str;
}

obj BatchView {
    has batch_id: str;
    has house: str;
    has bird_type: str;
    has age_days: int;
    has alive: int;
    has start_count: int;
    has health: str;
    has mortality: float;
    has label: str = "";
    has income: float = 0.0;
    has feed_cost: float = 0.0;
    has balance: float = 0.0;
    has days: list[str] = [];          # dates of the last reports (for charts)
    has deaths_series: list[int] = [];
    has eggs_series: list[int] = [];
    has feed_series: list[float] = [];
    has dead: int = 0;                 # all deaths reported
    has sold: int = 0;                 # birds sold (not eggs)
    has eggs_collected: int = 0;
    has eggs_sold: int = 0;
    has feed_eaten_kg: float = 0.0;
    has added: str = "";
    has other_cost: float = 0.0;       # chicks, vaccines, vet, labour... recorded for this batch
    has bird_income: float = 0.0;
    has egg_income: float = 0.0;
    has lay_rate: float = -1.0;        # % of hens that laid on the last egg count (-1 = no eggs recorded)
    has avg_weight: float = 0.0;       # last average weight reported (kg)
    has fcr: float = 0.0;              # feed conversion: kg feed per kg of bird (0 = no weight yet)
}

# Sales report numbers (all worked out on the server)
obj SalesSummary {
    has total: float = 0.0;
    has today: float = 0.0;
    has week: float = 0.0;            # last 7 days
    has month: float = 0.0;           # this calendar month
    has last_month: float = 0.0;
    has n_sales: int = 0;
    has birds_sold: int = 0;
    has bird_income: float = 0.0;
    has avg_bird_price: float = 0.0;  # KSh per bird
    has eggs_sold: int = 0;
    has egg_income: float = 0.0;
    has avg_tray_price: float = 0.0;  # KSh per tray of 30
    has bird_pct: float = 0.0;        # share of sales from birds (%)
    has egg_pct: float = 0.0;
    has day_labels: list[str] = [];   # last 14 days
    has day_values: list[float] = [];
    has month_labels: list[str] = []; # last 6 months
    has month_values: list[float] = [];
    has buyer_names: list[str] = [];  # top buyers, biggest first
    has buyer_values: list[float] = [];
    has batch_labels: list[str] = [];
    has batch_values: list[float] = [];
    has open_orders_value: float = 0.0;
    has open_orders: int = 0;
}

obj FarmView {
    has name: str;
    has owner: str;
    has batches: list[BatchView];
    has egg_sets: list[str];
    has feed_kg: float;
    has feed_days: float;
    has alerts: list[str];
    has income: float;
    has birds_alive: int = 0;
    has feed_need_per_day: float = 0.0;
    has bags_to_order: int = 0;          # 50 kg bags to order for the next 7 days (after stock and feed already ordered)
    has feed_on_order_kg: float = 0.0;
    has writer_model: str = "";
    has records: list[RecordView] = [];
    has phone: str = "";               # the owner's phone
    has start_total: int = 0;          # birds at the start of every batch
    has dead_total: int = 0;
    has sold_total: int = 0;
    has count_ok: bool = True;         # start - dead - sold == alive for every batch
    has eggs_collected: int = 0;
    has eggs_sold: int = 0;
    has feed_eaten_kg: float = 0.0;
    has feed_eaten_cost: float = 0.0;
    has balance: float = 0.0;          # all sales - all feed eaten
    has feed_price: float = 0.0;
    # ---- data for the agents' own pages ----
    has houses: list[str] = [];
    has tasks: list[str] = [];
    has health_rows: list[HealthRow] = [];
    has vet_name: str = "";
    has vet_phone: str = "";
    has egg_set_views: list[EggSetView] = [];
    has plans: list[BatchPlan] = [];
    has feed_rows: list[FeedRow] = [];
    has deliveries: list[DeliveryView] = [];
    has sales: list[SaleView] = [];
    has buyers: list[BuyerView] = [];
    has offers: list[str] = [];
    has blocked: list[str] = [];
    # ---- money ----
    has bird_income: float = 0.0;
    has egg_income: float = 0.0;
    has other_costs: float = 0.0;
    has cost_lines: list[CostLine] = [];      # costs by kind (feed eaten first)
    has expenses: list[ExpenseView] = [];
    has expense_kinds: list[str] = [];
    # ---- orders & bookings ----
    has orders: list[OrderView] = [];
    has supplies: list[SupplyView] = [];
    has vet_visits: list[VetVisitView] = [];
    has booking_tasks: list[str] = [];
    has supply_kinds: list[str] = [];
    has eggs_in_store: int = 0;
    has today: str = "";
    has sales_summary: SalesSummary = SalesSummary();
}

obj OrderView {
    has order_id: str;
    has date: str;
    has buyer: str;
    has item: str;
    has bird_type: str;
    has what: str;            # "100 broilers", "20 trays of eggs"
    has qty: int;
    has price_text: str;
    has total: float;         # 0 if no price yet
    has deposit: float;
    has due: str;
    has due_text: str;        # "today", "Fri 20 Nov"
    has due_status: str;      # overdue, today, soon, later, ""
    has batch_id: str;
    has status: str;          # booked, delivered, cancelled
    has done_date: str;
    has note: str;
    has can_supply: bool = True;
}

obj SupplyView {
    has supply_id: str;
    has date: str;
    has supplier: str;
    has kind: str;
    has what: str;
    has qty: float;
    has cost: float;
    has due: str;
    has due_text: str;
    has due_status: str;
    has status: str;          # ordered, received, cancelled
    has done_date: str;
    has house: str;
    has bird_type: str;
    has batch_id: str;
}

obj VetVisitView {
    has visit_id: str;
    has date: str;
    has visit_date: str;
    has when_text: str;
    has due_status: str;
    has batch_id: str;
    has reason: str;
    has status: str;          # booked, done, cancelled
    has cost: float;
    has outcome: str;
    has done_date: str;
    has vet_link: str = "";
}

obj CostLine {
    has kind: str;
    has amount: float;
}

obj ExpenseView {
    has date: str;
    has batch_id: str;
    has kind: str;
    has amount: float;
    has note: str;
}

obj HealthRow {
    has batch_id: str;
    has label: str;
    has level: str;
    has mortality: float;
    has warnings: list[str] = [];
    has last_check: str = "";       # "2026-10-16: GREEN - chicks near the heater"
    has checks: int = 0;
}

obj EggSetView {
    has set_id: str;
    has bird_type: str;
    has eggs_set: int;
    has day: int;
    has fertile: int;
    has hatched: int;
    has done: bool;
    has task: str;
    has hatch_rate: float = 0.0;
}

obj VaccineRow {
    has day: int;
    has task: str;
    has status: str;        # "done", "today", "soon", "later"
}

obj BatchPlan {
    has batch_id: str;
    has label: str;
    has age_days: int;
    has heat: str;
    has rows: list[VaccineRow] = [];
}

obj FeedRow {
    has batch_id: str;
    has label: str;
    has need_kg: float;          # expected kg per day for the birds alive
    has last_used: float;        # kg in the last report (-1 = no report yet)
    has eaten_kg: float;         # all feed eaten so far
    has status: str;             # "OK", "Too much", "Too little", "No report yet"
}

obj DeliveryView {
    has date: str;
    has kg: float;
    has cost: float;
}

obj SaleView {
    has date: str;
    has batch_id: str;
    has buyer: str;
    has item: str;
    has qty: int;
    has price_each: float;
    has total: float;
}

obj BuyerView {
    has name: str;
    has phone: str;
    has wants: str;
    has bought: float = 0.0;     # KSh bought from this farm
    has sales: int = 0;          # number of sales
    has last: str = "";          # date of the last sale
}

# Round to 1 decimal place (works for negative numbers too)
def r1(x: float) -> float {
    if x < 0 { return -r1(-x); }
    return float(int(x * 10.0 + 0.5)) / 10.0;
}

def r2(x: float) -> float {
    if x < 0 { return -r2(-x); }
    return float(int(x * 100.0 + 0.5)) / 100.0;
}

# Round to whole shillings
def r0(x: float) -> float {
    if x < 0 { return -r0(-x); }
    return float(int(x + 0.5));
}

def today() -> str {
    return date.today().isoformat();
}

# Save a photo sent by the browser (a "data:image/...;base64,..." string) to a temporary file
def save_photo(data_url: str) -> str {
    if not data_url { return ""; }
    try {
        raw = data_url.split(",", 1)[1] if "," in data_url else data_url;
        ext = ".png" if "image/png" in data_url[:40] else ".jpg";
        fd = tempfile.NamedTemporaryFile(delete=False, suffix=ext);
        fd.write(base64.b64decode(raw));
        fd.close();
        return fd.name;
    } except Exception as e {
        print(f"Could not read photo: {e}");
        return "";
    }
}

# Every saved record, newest first (for the "Farm records" table)
def farm_records(f: Farm, limit: int) -> list[RecordView] {
    rows: list[RecordView] = [];
    for b in farm_batches(f) {
        for r in [b -->[?:Record]] {
            parts: list[str] = [f"{r.deaths} deaths", f"{r.feed_kg:.0f} kg feed"];
            if r.eggs > 0 { parts.append(f"{r.eggs} eggs"); }
            if r.avg_weight_kg > 0 { parts.append(f"avg weight {r.avg_weight_kg} kg"); }
            if r.note { parts.append(r.note); }
            rows.append(RecordView(date=r.date, batch_id=b.batch_id, kind="Report", detail=", ".join(parts)));
        }
        for x in [b -->[?:Sale]] {
            what = sale_qty_text(x.qty, x.price_each) if x.item == "eggs" else f"{x.qty} {x.item} at KSh {x.price_each:,.0f} each";
            rows.append(RecordView(date=x.date, batch_id=b.batch_id, kind="Sale",
                                   detail=f"{what} to {x.buyer} = KSh {x.total:,.0f}"));
        }
        if b.added != "" {
            rows.append(RecordView(date=b.added, batch_id=b.batch_id, kind="New batch",
                                   detail=f"{b.start_count} {b.bird_type} birds arrived ({batch_label(b)})"));
        }
        for c in [b -->[?:HealthCheck]] {
            rows.append(RecordView(date=c.date, batch_id=b.batch_id, kind="Health",
                                   detail=f"{c.level}: {c.summary.split(' | ')[0]}"));
        }
    }
    for b in farm_batches(f) {
        for e in [b -->[?:Expense]] {
            rows.append(RecordView(date=e.date, batch_id=b.batch_id, kind="Cost",
                                   detail=f"{e.kind} KSh {e.amount:,.0f}" + (f" - {e.note}" if e.note else "")));
        }
    }
    for o in farm_orders(f) {
        rows.append(RecordView(date=o.date, batch_id=o.batch_id or "-", kind="Order",
                               detail=f"{o.order_id}: {order_qty_text(o.item, o.bird_type, o.qty)} for {o.buyer}, delivery {o.due or 'no date'} - {o.status}"));
    }
    for x in farm_supplies(f) {
        rows.append(RecordView(date=x.date, batch_id=x.batch_id or "-", kind="Supply",
                               detail=f"{x.supply_id}: {supply_qty_text(x.kind, x.qty)}" + (f" from {x.supplier}" if x.supplier else "") + f", KSh {x.cost:,.0f} - {x.status}"));
    }
    for v in farm_visits(f) {
        rows.append(RecordView(date=v.date, batch_id=v.batch_id or "-", kind="Vet visit",
                               detail=f"{v.visit_id}: {v.visit_date or 'date to confirm'}, {v.reason or 'farm visit'} - {v.status}" + (f", fee KSh {v.cost:,.0f}" if v.cost > 0 else "")));
    }
    pairs = sorted([(rows[i].date, i) for i in range(len(rows))], reverse=True);
    return [rows[p[1]] for p in pairs][:limit];
}

def farm_view(f: Farm) -> FarmView {
    views: list[BatchView] = [];
    price = feed_price_per_kg(f);
    for b in farm_batches(f) {
        for h in [b <--[?:House]] {
            recs = [b -->[?:Record]];
            sales = [b -->[?:Sale]];
            deaths = sum([r.deaths for r in recs]);
            sold = sum([x.qty for x in sales if x.item != "eggs"]);
            mort = 100.0 * deaths / b.start_count if b.start_count > 0 else 0.0;
            money = batch_money(b, price);
            recent = records_of(b)[-7:];
            views.append(BatchView(batch_id=b.batch_id, label=batch_label(b), house=h.name, bird_type=b.bird_type,
                                   age_days=b.age_days, alive=b.alive, start_count=b.start_count,
                                   health=latest_health(b), mortality=r1(mort),
                                   income=r0(money.income), feed_cost=r0(money.feed_cost), balance=r0(money.balance),
                                   days=[r.date[5:] for r in recent], deaths_series=[r.deaths for r in recent],
                                   eggs_series=[r.eggs for r in recent], feed_series=[r.feed_kg for r in recent],
                                   dead=deaths, sold=sold, added=b.added,
                                   eggs_collected=sum([r.eggs for r in recs]),
                                   eggs_sold=sum([x.qty for x in sales if x.item == "eggs"]),
                                   feed_eaten_kg=r2(money.feed_kg), other_cost=r0(money.other_cost),
                                   bird_income=r0(money.bird_income), egg_income=r0(money.egg_income),
                                   lay_rate=r1(batch_lay_rate(b)), avg_weight=last_weight(b), fcr=r2(batch_fcr(b))));
        }
    }
    sets = [f"{s.set_id}: {s.eggs_set} {s.bird_type} eggs, day {s.day} - {hatchery_task(s.day)}"
            for s in [f -->[?:EggSet]] if not s.done];
    fr = root spawn feed_report(quiet=True);
    ew = root spawn early_warning_scan(quiet=True);
    sr = root spawn sales_report(quiet=True);
    return FarmView(name=f.name, owner=f.owner, phone=farm_phone(f), batches=views, egg_sets=sets,
                    feed_kg=r1(fr.stock_kg), feed_days=r1(fr.days_left),
                    alerts=ew.alerts + fr.alerts, income=r0(sr.total_income),
                    birds_alive=sum([v.alive for v in views]),
                    feed_need_per_day=r0(fr.daily_need), bags_to_order=fr.bags_to_order, feed_on_order_kg=r0(fr.on_order_kg),
                    writer_model=str(WRITER_STATE["status"]),
                    records=farm_records(f, 200),
                    start_total=sum([v.start_count for v in views]),
                    dead_total=sum([v.dead for v in views]),
                    sold_total=sum([v.sold for v in views]),
                    count_ok=all([v.start_count - v.dead - v.sold == v.alive for v in views]),
                    eggs_collected=sum([v.eggs_collected for v in views]),
                    eggs_sold=sum([v.eggs_sold for v in views]),
                    feed_eaten_kg=r2(sum([sum([r.feed_kg for r in [b -->[?:Record]]]) for b in farm_batches(f)])),
                    feed_eaten_cost=r0(sr.feed_eaten_cost),
                    balance=r0(sum([v.balance for v in views])),
                    bird_income=r0(sum([v.bird_income for v in views])),
                    egg_income=r0(sum([v.egg_income for v in views])),
                    other_costs=r0(sum([v.other_cost for v in views])),
                    cost_lines=cost_lines(f, sr.feed_eaten_cost),
                    expenses=expense_views(f),
                    expense_kinds=EXPENSE_KINDS,
                    feed_price=r2(price),
                    houses=[h.name for h in [f -->[?:House]]],
                    tasks=booking_tasks(f) + (root spawn today_tasks(quiet=True)).tasks,
                    booking_tasks=booking_tasks(f),
                    orders=order_views(f), supplies=supply_views(f), vet_visits=visit_views(f),
                    supply_kinds=SUPPLY_KINDS, eggs_in_store=sum([max(0, eggs_in_store(b)) for b in farm_batches(f)]),
                    today=today(), sales_summary=sales_summary(f),
                    health_rows=[health_row(b) for b in farm_batches(f)],
                    vet_name=farm_vet(f).name, vet_phone=farm_vet(f).phone,
                    egg_set_views=[egg_set_view(e) for e in [f -->[?:EggSet]]],
                    plans=[batch_plan(b) for b in farm_batches(f)],
                    feed_rows=[feed_row(b) for b in farm_batches(f)],
                    deliveries=[DeliveryView(date=d.date, kg=d.kg, cost=d.cost_ksh) for d in [f -->[?:FeedStore] -->[?:FeedDelivery]]],
                    sales=sale_views(f),
                    buyers=buyer_views(f),
                    offers=(root spawn market_alerts(quiet=True, broadcast=False)).offers,
                    blocked=(root spawn market_alerts(quiet=True, broadcast=False)).blocked);
}

# ---------- Send any message (and optional photo) to KukuMind ----------
walker:pub chat {
    has text: str;
    has photo: str = "";
    has language: str = "";
    has reports: list[ChatReply] = [];

    can talk with Root entry {
        here spawn build_demo_farm();
        path = save_photo(self.photo);
        msg = self.text.strip() or "Angalia picha hii ya kuku wangu";
        k = here spawn kukumind(text=msg, date=today(), photo_path=path, language=self.language);
        report ChatReply(intent=k.intent, level=k.level, reply=k.message,
                         vet_message=k.vet_message, vet_link=k.vet_link);
    }
}

# ---------- Morning briefing button ----------
walker:pub briefing {
    has language: str = "English";
    has reports: list[ChatReply] = [];

    can brief with Root entry {
        here spawn build_demo_farm();
        mb = here spawn morning_briefing(language=self.language);
        report ChatReply(intent="briefing", level="", reply=mb.reply);
    }
}

# ---------- Farm dashboard data ----------
walker:pub farm_status {
    has reports: list[FarmView] = [];

    can show with Root entry {
        here spawn build_demo_farm();
        report farm_view([here -->[?:Farm]][0]);
    }
}

# ---------- Demo: move the farm forward one day ----------
walker:pub next_day {
    has reports: list[FarmView] = [];

    can tick with Root entry {
        here spawn build_demo_farm();
        here spawn new_day();
        report farm_view([here -->[?:Farm]][0]);
    }
}

# ---------- Vet has visited and cleared a RED batch ----------
walker:pub clear_batch {
    has batch_id: str;
    has reports: list[FarmView] = [];

    can clear with Root entry {
        here spawn vet_clear(batch_id=self.batch_id, date=today(), vet_note="Cleared by vet (from the web page)");
        report farm_view([here -->[?:Farm]][0]);
    }
}

# Delete the farm and everything under it (houses, batches, records, sales, feed store...)
def wipe_farm() {
    for old in [root -->[?:Farm]] {
        todo: list[any] = [old];
        found: list[any] = [];
        while len(todo) > 0 {
            n = todo.pop();
            if n in found { continue; }
            found.append(n);
            todo.extend([n -->]);
        }
        for n in reversed(found) { del n; }
    }
}

# ---------- Clear every record and start the farm again (same farm, houses, batches and buyers) ----------
walker:pub start_fresh {
    has reports: list[FarmView] = [];

    can reset with Root entry {
        wipe_farm();
        here spawn build_demo_farm();
        print("All records cleared. The farm starts again with no reports, sales or health checks.");
        report farm_view([here -->[?:Farm]][0]);
    }
}


# =====================================================================
# AGENT WORKSPACES - each agent's own page calls these directly
# =====================================================================

# ---------- helpers that build the data for each page ----------
def health_row(b: Batch) -> HealthRow {
    checks = [b -->[?:HealthCheck]];
    last = "";
    if len(checks) > 0 {
        c = checks[0];
        for x in checks {
            if x.date >= c.date { c = x; }
        }
        last = f"{c.date}: {c.level} - {c.summary.split(' | ')[0]}";
    }
    deaths = sum([r.deaths for r in [b -->[?:Record]]]);
    mort = 100.0 * deaths / b.start_count if b.start_count > 0 else 0.0;
    return HealthRow(batch_id=b.batch_id, label=batch_label(b), level=latest_health(b), mortality=r1(mort),
                     warnings=early_warnings(b), last_check=last, checks=len(checks));
}

def egg_set_view(e: EggSet) -> EggSetView {
    rate = 100.0 * e.hatched / e.eggs_set if e.hatched > 0 and e.eggs_set > 0 else 0.0;
    task = "Hatched" if e.done else hatchery_task(e.day);
    return EggSetView(set_id=e.set_id, bird_type=e.bird_type, eggs_set=e.eggs_set, day=e.day,
                      fertile=e.fertile, hatched=e.hatched, done=e.done, task=task, hatch_rate=r1(rate));
}

def batch_plan(b: Batch) -> BatchPlan {
    rows: list[VaccineRow] = [];
    for item in SCHEDULE.get(b.bird_type, []) {
        d = int(item[0]);
        status = "later";
        if d < b.age_days { status = "done"; }
        elif d == b.age_days { status = "today"; }
        elif d <= b.age_days + 7 { status = "soon"; }
        rows.append(VaccineRow(day=d, task=str(item[1]), status=status));
    }
    return BatchPlan(batch_id=b.batch_id, label=batch_label(b), age_days=b.age_days,
                     heat=brooding_temp(b.age_days), rows=rows);
}

def feed_row(b: Batch) -> FeedRow {
    need = expected_feed_per_bird(b.bird_type, b.age_days) * b.alive;
    recs = [r for r in daily_totals(b) if r.feed_kg > 0];
    last = -1.0;
    status = "No report yet";
    if len(recs) > 0 {
        last = recs[-1].feed_kg;
        then = feed_need_on(b, recs[-1].date);      # compared with what it should have eaten that day
        status = "OK";
        if then > 0 and last > 1.25 * then { status = "Too much"; }
        elif then > 0 and last < 0.75 * then { status = "Too little"; }
    }
    return FeedRow(batch_id=b.batch_id, label=batch_label(b), need_kg=r1(need), last_used=r1(last),
                   eaten_kg=r1(sum([r.feed_kg for r in [b -->[?:Record]]])), status=status);
}

def sale_views(f: Farm) -> list[SaleView] {
    out: list[SaleView] = [];
    for b in farm_batches(f) {
        for x in [b -->[?:Sale]] {
            out.append(SaleView(date=x.date, batch_id=b.batch_id, buyer=x.buyer, item=x.item,
                                qty=x.qty, price_each=x.price_each, total=x.total));
        }
    }
    pairs = sorted([(out[i].date, i) for i in range(len(out))], reverse=True);
    return [out[p[1]] for p in pairs];
}

# ---------- safety: medicine names never reach the farmer ----------
glob DRUG_WORDS = ["antibiotic", "oxytetracycline", "tetracycline", "amprolium", "tylosin", "enrofloxacin",
                   "sulfa", "doxycycline", "ivermectin", "piperazine", "levamisole", "albendazole",
                   "mg/kg", "ml per", "dose", "dozi", "dawa ya"];

def no_drug_text(t: str) -> bool {
    low = t.lower();
    return not any([w in low for w in DRUG_WORDS]);
}

def drop_drugs(items: list[str]) -> list[str] {
    return [x for x in items if no_drug_text(x)];
}

def clean_text(t: str) -> str {
    if no_drug_text(t) { return t; }
    parts = [p for p in t.replace("\n", " ").split(". ") if no_drug_text(p)];
    return ". ".join(parts) + " Ask your vet which treatment to use.";
}

# ---------- results sent back to an agent's page ----------
obj ActionResult {
    has ok: bool;
    has message: str;
    has farm: FarmView | None = None;
}

obj Diagnosis {
    has ok: bool;
    has batch_id: str;
    has level: str;
    has reply: str;
    has possible_problems: list[str] = [];
    has do_now: list[str] = [];
    has call_vet: bool = False;
    has warnings: list[str] = [];
    has vet_message: str = "";
    has vet_link: str = "";
    has had_photo: bool = False;
    has farm: FarmView | None = None;
}

obj DiseaseInfo {
    has topic: str;              # the disease or topic, e.g. "Newcastle disease"
    has summary: str;            # 2-3 simple sentences: what it is
    has signs: list[str];        # what the farmer will see
    has spread: str;             # how it spreads
    has prevention: list[str];   # prevention and biosecurity steps (vaccination by schedule is allowed)
    has notifiable: bool;        # must be reported to the county veterinary officer in Kenya
    has call_vet_when: str;      # when to call the vet
    has farm_note: str;          # what this means for THIS farm's batches ("" if nothing)
}

"""Explain a poultry disease or health topic to a Kenyan farmer. Write every field in the language given
(English, Kiswahili or Sheng; "Auto" = the language the question is written in; follow the language guide; plain text, no markdown).
Use farm_info so farm_note says what it means for THIS farm (which batches are at risk by age, vaccines due).
Follow the triage rules: NEVER name a medicine, antibiotic, dewormer brand or any dose.
Vaccination by the normal schedule may be mentioned as prevention, without doses.
notifiable is True for Newcastle disease and avian influenza (bird flu)."""
def research_disease(question: str, farm_info: str, language: str, triage_rules: str, language_guide: str) -> DiseaseInfo by writer();

obj BuyerMessage {
    has buyer: str;
    has phone: str;
    has message: str;
    has link: str;
}

obj BuyerMessages {
    has messages: list[BuyerMessage] = [];
    has note: str = "";
}

def farm_now() -> Farm {
    root spawn build_demo_farm();
    return [root -->[?:Farm]][0];
}

# ---------- talk to ONE agent directly (from that agent's page) ----------
walker:pub agent_chat {
    has agent: str;
    has text: str;
    has photo: str = "";
    has language: str = "";
    has reports: list[ChatReply] = [];

    can talk with Root entry {
        farm_now();
        path = save_photo(self.photo);
        msg = self.text.strip() or "Angalia picha hii ya kuku wangu";
        k = here spawn kukumind(text=msg, date=today(), photo_path=path, force=self.agent, language=self.language);
        report ChatReply(intent=k.intent, level=k.level, reply=clean_text(k.message),
                         vet_message=k.vet_message, vet_link=k.vet_link);
    }
}

# ---------- FLOCK RECORDS: daily report form ----------
walker:pub submit_report {
    has batch_id: str;
    has deaths: int = 0;
    has feed_kg: float = 0.0;
    has feed_bags: float = 0.0;
    has eggs: int = 0;
    has egg_trays: int = 0;
    has avg_weight_kg: float = 0.0;
    has note: str = "";
    has reports: list[ActionResult] = [];

    can save with Root entry {
        f = farm_now();
        if self.batch_id not in [b.batch_id for b in farm_batches(f)] {
            report ActionResult(ok=False, message=f"Choose a batch first.", farm=farm_view(f));
            disengage;
        }
        feed = self.feed_bags * 50.0 + self.feed_kg;
        eggs = self.egg_trays * 30 + self.eggs;
        w = here spawn save_report(batch_id=self.batch_id, date=today(), deaths=self.deaths, feed_kg=feed,
                                   eggs=eggs, avg_weight_kg=self.avg_weight_kg, note=self.note);
        if not w.saved {
            report ActionResult(ok=False, message=w.problem, farm=farm_view(f));
            disengage;
        }
        b = [x for x in farm_batches(f) if x.batch_id == self.batch_id][0];
        msg = f"Saved for {b.batch_id}: {self.deaths} deaths, {feed:.0f} kg feed";
        if eggs > 0 { msg = msg + f", {eggs} eggs"; }
        if self.avg_weight_kg > 0 { msg = msg + f", average weight {self.avg_weight_kg} kg"; }
        msg = msg + f". Birds alive now: {b.alive}. Feed left in store: {w.feed_left if w.feed_left >= 0 else [f -->[?:FeedStore]][0].stock_kg:.0f} kg.";
        if w.feed_short > 0 {
            msg = msg + f" Note: the store only had {feed - w.feed_short:.0f} kg, so {w.feed_short:.0f} kg came from feed that was never recorded. Record that feed delivery on the Feed page so the stock is right.";
        }
        warn = early_warnings(b);
        if len(warn) > 0 { msg = msg + " Warning: " + " ".join(warn) + " Open the Disease detector to check the birds."; }
        report ActionResult(ok=True, message=msg, farm=farm_view(f));
    }
}

# ---------- FLOCK RECORDS: register a new flock ----------
walker:pub register_flock {
    has bird_type: str;
    has count: int;
    has house: str;
    has age_days: int = 1;
    has price_each: float = 0.0;      # KSh paid per chick (0 = not entered)
    has reports: list[ActionResult] = [];

    can add with Root entry {
        f = farm_now();
        if self.bird_type not in ["broiler", "layer", "kienyeji"] or self.count <= 0 {
            report ActionResult(ok=False, message="Choose the type of birds and a number above 0.", farm=farm_view(f));
            disengage;
        }
        w = here spawn add_batch(bird_type=self.bird_type, count=self.count, house_name=self.house,
                                 age_days=self.age_days if self.age_days > 0 else 1, date=today());
        msg = w.note;
        if w.batch_id != "" and self.price_each > 0 {
            nb = [b for b in farm_batches(f) if b.batch_id == w.batch_id][0];
            cost = r0(self.price_each * self.count);
            nb ++> Expense(date=today(), kind="Chicks", amount=cost, note=f"{self.count} x KSh {per_kg_text(self.price_each)}");
            msg = msg + f" Chick cost KSh {cost:,.0f} saved as a cost of {w.batch_id}.";
        }
        report ActionResult(ok=w.batch_id != "", message=msg, farm=farm_view(f));
    }
}

# ---------- DISEASE DETECTOR: diagnose (camera photo and/or symptoms) ----------
walker:pub diagnose {
    has batch_id: str;
    has description: str = "";
    has photo: str = "";
    has language: str = "";
    has reports: list[Diagnosis] = [];

    can check with Root entry {
        ensure_writer();
        f = farm_now();
        if self.batch_id not in [b.batch_id for b in farm_batches(f)] {
            report Diagnosis(ok=False, batch_id=self.batch_id, level="", reply="Choose which batch the sick birds are in.");
            disengage;
        }
        path = save_photo(self.photo);
        desc = self.description.strip() or "Please look at this photo of my birds.";
        h = here spawn health_check(batch_id=self.batch_id, description=desc, date=today(), photo_path=path,
                                    language=self.language if self.language in ["English", "Kiswahili", "Sheng"] else "");
        if h.result is None {
            report Diagnosis(ok=False, batch_id=self.batch_id, level="", reply="The health check did not work. Please try again.");
            disengage;
        }
        t = h.result;
        b = [x for x in farm_batches(f) if x.batch_id == self.batch_id][0];
        report Diagnosis(ok=True, batch_id=self.batch_id, level=t.level, reply=clean_text(t.reply),
                         possible_problems=drop_drugs(t.possible_problems), do_now=drop_drugs(t.do_now),
                         call_vet=t.call_vet, warnings=early_warnings(b), vet_message=h.vet_message,
                         vet_link=h.vet_link, had_photo=path != "", farm=farm_view(f));
    }
}

# ---------- DISEASE DETECTOR: research a disease ----------
walker:pub research {
    has question: str;
    has language: str = "";
    has reports: list[DiseaseInfo] = [];

    can look with Root entry {
        ensure_writer();
        f = farm_now();
        info = "\n".join([batch_health_info(b) for b in farm_batches(f)]);
        d = research_disease(self.question, info, self.language if self.language in ["English", "Kiswahili", "Sheng"] else "Auto", TRIAGE_RULES, LANGUAGE_GUIDE);
        d.summary = clean_text(plain_text(d.summary));
        d.signs = drop_drugs(d.signs);
        d.prevention = drop_drugs(d.prevention);
        d.call_vet_when = clean_text(d.call_vet_when);
        d.farm_note = clean_text(plain_text(d.farm_note));
        report d;
    }
}

# ---------- HATCHERY: set eggs, candling, hatch ----------
walker:pub hatchery_action {
    has action: str;              # "set", "candle", "hatch"
    has bird_type: str = "kienyeji";
    has eggs: int = 0;
    has set_id: str = "";
    has fertile: int = 0;
    has hatched: int = 0;
    has house: str = "";
    has reports: list[ActionResult] = [];

    can act with Root entry {
        f = farm_now();
        sets = [e for e in [f -->[?:EggSet]] if e.set_id == self.set_id];
        if self.action == "set" {
            if self.eggs <= 0 {
                report ActionResult(ok=False, message="Enter how many eggs you put in the incubator.", farm=farm_view(f));
                disengage;
            }
            w = here spawn set_eggs(bird_type=self.bird_type, eggs=self.eggs, day=0);
            report ActionResult(ok=True, message=w.note, farm=farm_view(f));
        } elif self.action == "candle" {
            if len(sets) == 0 or self.fertile < 0 or self.fertile > sets[0].eggs_set {
                report ActionResult(ok=False, message="Choose an egg set and enter fertile eggs (not more than the eggs set).", farm=farm_view(f));
                disengage;
            }
            wc = here spawn record_candling(set_id=self.set_id, fertile=self.fertile);
            report ActionResult(ok=True, message=wc.note, farm=farm_view(f));
        } elif self.action == "hatch" {
            if len(sets) == 0 or self.hatched < 0 or self.hatched > sets[0].eggs_set {
                report ActionResult(ok=False, message="Choose an egg set and enter chicks hatched (not more than the eggs set).", farm=farm_view(f));
                disengage;
            }
            if sets[0].fertile >= 0 and self.hatched > sets[0].fertile {
                report ActionResult(ok=False, message=f"{self.hatched} chicks is more than the {sets[0].fertile} fertile eggs found at candling. Check the count.", farm=farm_view(f));
                disengage;
            }
            wh = here spawn record_hatch(set_id=self.set_id, hatched=self.hatched, house_name=self.house);
            report ActionResult(ok="NOT saved" not in wh.note, message=wh.note, farm=farm_view(f));
        } else {
            report ActionResult(ok=False, message="Unknown hatchery action.", farm=farm_view(f));
        }
    }
}

# ---------- FEED: a feed delivery arrived ----------
walker:pub add_feed {
    has kg: float = 0.0;
    has bags: float = 0.0;
    has cost_ksh: float = 0.0;
    has reports: list[ActionResult] = [];

    can add with Root entry {
        f = farm_now();
        kg = self.bags * 50.0 + self.kg;
        if kg <= 0 or self.cost_ksh < 0 {
            report ActionResult(ok=False, message="Enter the feed received (bags or kg).", farm=farm_view(f));
            disengage;
        }
        here spawn receive_feed(kg=kg, date=today(), cost_ksh=self.cost_ksh);
        fr = here spawn feed_report(quiet=True);
        msg = f"Feed received: {kg:.0f} kg";
        if self.cost_ksh > 0 { msg = msg + f" for KSh {self.cost_ksh:,.0f} (KSh {per_kg_text(self.cost_ksh / kg)} per kg)"; }
        msg = msg + f". Store now {fr.stock_kg:.0f} kg - lasts about {fr.days_left:.1f} days.";
        report ActionResult(ok=True, message=msg, farm=farm_view(f));
    }
}

# ---------- SALES: record a sale from the form ----------
walker:pub sell {
    has batch_id: str;
    has item: str;                # "birds" or "eggs"
    has qty: int = 0;
    has trays: int = 0;           # eggs only
    has price_each: float = 0.0;  # per bird or per egg
    has price_per_tray: float = 0.0;
    has buyer: str = "";
    has reports: list[ActionResult] = [];

    can save with Root entry {
        f = farm_now();
        found = [b for b in farm_batches(f) if b.batch_id == self.batch_id];
        if len(found) == 0 {
            report ActionResult(ok=False, message="Choose which batch you sold from.", farm=farm_view(f));
            disengage;
        }
        b = found[0];
        qty = self.qty;
        price = self.price_each;
        if self.item == "eggs" {
            qty = self.trays * 30 + self.qty;
            if price <= 0 and self.price_per_tray > 0 { price = self.price_per_tray / 30.0; }
        }
        item = "eggs" if self.item == "eggs" else b.bird_type + "s";
        w = here spawn record_sale(batch_id=b.batch_id, buyer=self.buyer or "buyer not named", item=item,
                                   qty=qty, price_each=price, date=today());
        report ActionResult(ok=w.saved, message=w.note, farm=farm_view(f));
    }
}

# ---------- SALES: write a WhatsApp message to every buyer ----------
walker:pub buyer_offers {
    has language: str = "";
    has reports: list[BuyerMessages] = [];

    can write with Root entry {
        ensure_writer();
        f = farm_now();
        ma = here spawn market_alerts(quiet=True, broadcast=False);
        out = BuyerMessages();
        if len(ma.offers) == 0 {
            out.note = "Nothing is ready to sell yet (broilers from day 35, kienyeji from day 120, eggs once layers are reported).";
            if len(ma.blocked) > 0 { out.note = out.note + " Blocked by health alerts: " + "; ".join(ma.blocked); }
            report out;
            disengage;
        }
        for buyer in [f -->[?:Buyer]] {
            m = plain_text(buyer_broadcast(f.name + (f" (call {f.owner} on {farm_phone(f)})" if farm_phone(f) else ""), buyer.name, buyer.wants, ma.offers, reply_lang(self.language, ""), LANGUAGE_GUIDE));
            out.messages.append(BuyerMessage(buyer=buyer.name, phone=buyer.phone, message=m,
                                             link=whatsapp_link(buyer.phone, m)));
        }
        report out;
    }
}

# ---------- money helpers for the Sales page ----------
def cost_lines(f: Farm, feed_eaten_cost: float) -> list[CostLine] {
    out: list[CostLine] = [CostLine(kind="Feed eaten", amount=r0(feed_eaten_cost))];
    for k in EXPENSE_KINDS {
        amt = sum([e.amount for e in [f -->[?:House] -->[?:Batch] -->[?:Expense]] if e.kind == k]);
        if amt > 0 { out.append(CostLine(kind=k, amount=r0(amt))); }
    }
    return out;
}

def expense_views(f: Farm) -> list[ExpenseView] {
    out: list[ExpenseView] = [];
    for b in farm_batches(f) {
        for e in [b -->[?:Expense]] {
            out.append(ExpenseView(date=e.date, batch_id=b.batch_id, kind=e.kind, amount=e.amount, note=e.note));
        }
    }
    pairs = sorted([(out[i].date, i) for i in range(len(out))], reverse=True);
    return [out[p[1]] for p in pairs];
}

def buyer_views(f: Farm) -> list[BuyerView] {
    all_sales = [x for b in farm_batches(f) for x in [b -->[?:Sale]]];
    out: list[BuyerView] = [];
    for x in [f -->[?:Buyer]] {
        mine = [s for s in all_sales if s.buyer == x.name];
        last = max([s.date for s in mine]) if len(mine) > 0 else "";
        out.append(BuyerView(name=x.name, phone=x.phone, wants=x.wants, bought=r0(sum([s.total for s in mine])),
                             sales=len(mine), last=last));
    }
    return out;
}

# ---------- SALES: record a cost (chicks, vaccines, labour...) ----------
walker:pub add_expense {
    has batch_id: str;
    has kind: str;
    has amount: float = 0.0;
    has note: str = "";
    has reports: list[ActionResult] = [];

    can add with Root entry {
        f = farm_now();
        found = [b for b in farm_batches(f) if b.batch_id == self.batch_id];
        if (len(found) == 0 and self.batch_id != "all") or r0(self.amount) <= 0 {
            report ActionResult(ok=False, message="Choose a batch (or all batches) and enter an amount above 0.", farm=farm_view(f));
            disengage;
        }
        kind = self.kind if self.kind in EXPENSE_KINDS else "Other";
        txt = add_cost(f, self.batch_id, kind, self.amount, self.note, today());
        if txt == "" {
            report ActionResult(ok=False, message="There is no batch to put the cost on yet.", farm=farm_view(f));
            disengage;
        }
        msg = "Cost saved: " + txt;
        if len(found) > 0 {
            b = found[0];
            m = batch_money(b, feed_price_per_kg(f));
            msg = msg + f" {b.batch_id} now: sales KSh {m.income:,.0f} - feed KSh {m.feed_cost:,.0f} - other costs KSh {m.other_cost:,.0f} = profit KSh {m.balance:,.0f}.";
        }
        report ActionResult(ok=True, farm=farm_view(f), message=msg);
    }
}

# ---------- Reset: the demo farm, or an EMPTY farm with the farmer's own details ----------
walker:pub setup_farm {
    has mode: str = "demo";           # "demo" or "own"
    has name: str = "";
    has owner: str = "";
    has phone: str = "";
    has houses: str = "House A";      # comma-separated, e.g. "House A, House B"
    has feed_kg: float = 0.0;         # feed in store now
    has vet_name: str = "";
    has vet_phone: str = "";
    has reports: list[FarmView] = [];

    can setup with Root entry {
        wipe_farm();
        if self.mode != "own" {
            here spawn build_demo_farm();
            report farm_view([here -->[?:Farm]][0]);
            disengage;
        }
        f = (here ++> Farm(name=self.name.strip() or "My Poultry Farm", owner=self.owner.strip() or "Farmer", last_tick=today(),
                          phone=self.phone.strip()))[0];
        names = [h.strip() for h in self.houses.split(",") if h.strip() != ""];
        if len(names) == 0 { names = ["House A"]; }
        for h in names { f ++> House(name=h, capacity=5000); }
        f ++> FeedStore(stock_kg=max(0.0, self.feed_kg));
        f ++> Vet(name=self.vet_name.strip() or "Farm vet", phone=self.vet_phone.strip());
        print(f"New empty farm set up: {f.name} with {len(names)} house(s).");
        report farm_view(f);
    }
}



# =====================================================================
# STEP 6: ORDERS & BOOKINGS - the Manager takes them from any message (or a form),
# and every agent's records update by themselves:
#   customer order delivered  -> Sales (sale saved, birds/eggs taken off, buyer's total)
#   feed order received       -> Feed (store up, price per kg) + profit (feed cost)
#   chick order received      -> Flock records (new batch) + Sales (chick cost)
#   vaccine/medicine received -> Sales (cost of the batch, or shared by all batches)
#   vet visit done            -> Disease detector (batch cleared) + Sales (vet fee)
#   any cost paid             -> Sales (one batch, or shared by birds alive)
# The AI only reads the message; Jac code does every date and number.
# =====================================================================
import from datetime { timedelta }

node Order {
    has order_id: str;            # O1, O2...
    has date: str;                # day the order was taken
    has buyer: str;
    has item: str;                # "birds" or "eggs"
    has qty: int;                 # birds, or eggs
    has bird_type: str = "";      # broiler, layer, kienyeji ("" for eggs)
    has price_each: float = 0.0;  # KSh per bird or per egg (0 = price agreed later)
    has deposit: float = 0.0;     # KSh paid in advance
    has due: str = "";            # YYYY-MM-DD ("" = no date yet)
    has batch_id: str = "";       # batch to deliver from ("" = chosen on delivery)
    has status: str = "booked";   # booked, delivered, cancelled
    has done_date: str = "";
    has note: str = "";
}

node SupplyOrder {
    has supply_id: str;           # P1, P2...
    has date: str;
    has kind: str;                # Feed, Chicks, Vaccines, Medicine, Other
    has supplier: str = "";
    has qty: float = 0.0;         # kg of feed, number of chicks, or units
    has cost: float = 0.0;        # KSh for the whole order
    has due: str = "";
    has bird_type: str = "";      # chicks only
    has house: str = "";          # chicks only
    has batch_id: str = "";       # vaccines / medicine: which batch ("" = shared by all batches)
    has status: str = "ordered";  # ordered, received, cancelled
    has done_date: str = "";
    has note: str = "";
}

node VetVisit {
    has visit_id: str;            # V1, V2...
    has date: str;                # day it was booked
    has visit_date: str = "";
    has batch_id: str = "";       # "" = the whole farm
    has reason: str = "";
    has status: str = "booked";   # booked, done, cancelled
    has cost: float = 0.0;
    has outcome: str = "";
    has done_date: str = "";
}

glob SUPPLY_KINDS = ["Feed", "Chicks", "Vaccines", "Medicine", "Other"];
glob WEEKDAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];

# Next free reference: next_ref("O", ["O1", "O2"]) -> "O3"
def next_ref(prefix: str, used: list[str]) -> str {
    top = 0;
    for u in used {
        n = u[len(prefix):];
        if u.startswith(prefix) and n.isdigit() and int(n) > top { top = int(n); }
    }
    return f"{prefix}{top + 1}";
}

def ref_number(ref: str) -> int {
    n = ref[1:];
    return int(n) if n.isdigit() else 0;
}

def farm_orders(f: Farm) -> list[Order] {
    found = [f -->[?:Order]];
    pairs = sorted([(ref_number(found[i].order_id), i) for i in range(len(found))]);
    return [found[p[1]] for p in pairs];
}

def farm_supplies(f: Farm) -> list[SupplyOrder] {
    found = [f -->[?:SupplyOrder]];
    pairs = sorted([(ref_number(found[i].supply_id), i) for i in range(len(found))]);
    return [found[p[1]] for p in pairs];
}

def farm_visits(f: Farm) -> list[VetVisit] {
    found = [f -->[?:VetVisit]];
    pairs = sorted([(ref_number(found[i].visit_id), i) for i in range(len(found))]);
    return [found[p[1]] for p in pairs];
}

# ---------- dates: the AI says "Friday" / "kesho" / "in 3 days"; code works out the date ----------
def resolve_due(exact: str, day_name: str, in_days: int, today_str: str) -> str {
    t = date.fromisoformat(today_str);
    e = exact.strip();
    if len(e) == 10 and e[4] == "-" and e[7] == "-" {
        try {
            return date.fromisoformat(e).isoformat();
        } except Exception as err {
            print(f"Not a date: {e}");
        }
    }
    dn = day_name.strip().lower();
    if dn in WEEKDAYS {
        ahead = (WEEKDAYS.index(dn) - t.weekday()) % 7;
        return (t + timedelta(days=ahead)).isoformat();
    }
    if in_days >= 0 { return (t + timedelta(days=in_days)).isoformat(); }
    return "";
}

def due_status(due: str, today_str: str) -> str {
    if due == "" { return ""; }
    if due < today_str { return "overdue"; }
    if due == today_str { return "today"; }
    days = (date.fromisoformat(due) - date.fromisoformat(today_str)).days;
    return "soon" if days <= 3 else "later";
}

# "2026-11-02 (Monday)" - given to the AI so it knows which day "Friday" or "kesho" means
def day_and_date(d: str) -> str {
    return d + " (" + date.fromisoformat(d).strftime("%A") + ")";
}

# "today", "tomorrow", "Fri 20 Nov"
def nice_date(d: str, today_str: str) -> str {
    if d == "" { return "no date yet"; }
    if d == today_str { return "today"; }
    try {
        x = date.fromisoformat(d);
        if (x - date.fromisoformat(today_str)).days == 1 { return "tomorrow"; }
        return x.strftime("%a %d %b");
    } except Exception as err {
        return d;
    }
}

# "100 broilers", "20 trays of eggs", "3 trays + 10 eggs"
def order_qty_text(item: str, bird_type: str, qty: int) -> str {
    if item == "eggs" {
        if qty % 30 == 0 { return f"{qty // 30} trays of eggs"; }
        if qty > 30 { return f"{qty // 30} trays + {qty % 30} eggs"; }
        return f"{qty} eggs";
    }
    return f"{qty} {bird_type or 'bird'}s";
}

def order_price_text(item: str, price_each: float) -> str {
    if price_each <= 0 { return "price not agreed yet"; }
    if item == "eggs" { return f"KSh {price_each * 30:,.0f} a tray"; }
    return f"KSh {price_each:,.0f} each";
}

def supply_qty_text(kind: str, qty: float) -> str {
    if kind == "Feed" {
        bags = qty / 50.0;
        if bags == int(bags) { return f"{qty:,.0f} kg of feed ({int(bags)} bags)"; }
        return f"{qty:,.0f} kg of feed";
    }
    if kind == "Chicks" { return f"{qty:,.0f} chicks"; }
    if qty > 0 { return f"{qty:,.0f} x {kind.lower()}"; }
    return kind.lower();
}

# Birds and eggs already promised to buyers in open orders
def booked_birds(f: Farm, bird_type: str) -> int {
    return sum([o.qty for o in farm_orders(f) if o.status == "booked" and o.item == "birds" and o.bird_type == bird_type]);
}

def booked_eggs(f: Farm) -> int {
    return sum([o.qty for o in farm_orders(f) if o.status == "booked" and o.item == "eggs"]);
}

# ---------- a cost on one batch, or shared by every batch in proportion to birds alive ----------
def add_cost(f: Farm, batch_id: str, kind: str, amount: float, note: str, d: str) -> str {
    amount = r0(amount);
    if amount <= 0 { return ""; }
    bs = farm_batches(f);
    if batch_id not in ["", "all"] {
        found = [b for b in bs if b.batch_id == batch_id];
        if len(found) == 0 { return ""; }
        found[0] ++> Expense(date=d, kind=kind, amount=amount, note=note);
        return f"KSh {amount:,.0f} saved as a {kind} cost of {batch_id}.";
    }
    live = [b for b in bs if b.alive > 0];
    if len(live) == 0 { live = bs; }
    if len(live) == 0 { return ""; }
    weights = [float(b.alive if b.alive > 0 else max(b.start_count, 1)) for b in live];
    total_w = sum(weights);
    given = 0.0;
    shares: list[str] = [];
    for i in range(len(live)) {
        part = amount - given if i == len(live) - 1 else r0(amount * weights[i] / total_w);
        given = given + part;
        if part > 0 {
            live[i] ++> Expense(date=d, kind=kind, amount=part, note=(note + " - " if note else "") + "shared cost");
        }
        shares.append(f"{live[i].batch_id} KSh {part:,.0f}");
    }
    if len(live) == 1 { return f"KSh {amount:,.0f} saved as a {kind} cost of {live[0].batch_id}."; }
    return f"KSh {amount:,.0f} {kind} shared by birds alive: " + ", ".join(shares) + ".";
}

# ---------- CUSTOMER ORDERS (Sales agent) ----------
walker take_order {
    has buyer: str;
    has item: str;                # "birds" or "eggs"
    has qty: int;
    has bird_type: str = "";
    has price_each: float = 0.0;  # per bird or per egg
    has deposit: float = 0.0;
    has due: str = "";
    has batch_id: str = "";
    has note: str = "";
    has date: str = "";
    has order_id: str = "";
    has saved: bool = False;
    has message: str = "";

    can take with Root entry {
        f = [here -->[?:Farm]][0];
        d = self.date or today();
        if self.item not in ["birds", "eggs"] or self.qty <= 0 {
            self.message = "An order needs birds or eggs and a number above 0. Order NOT saved.";
            disengage;
        }
        kind = "";
        if self.item == "birds" {
            kind = self.bird_type;
            if self.batch_id != "" {
                bs = [b for b in farm_batches(f) if b.batch_id == self.batch_id];
                if len(bs) == 0 {
                    self.message = f"No batch called {self.batch_id}. Order NOT saved.";
                    disengage;
                }
                kind = bs[0].bird_type;
            }
            if kind not in ["broiler", "layer", "kienyeji"] {
                self.message = "Which birds does the buyer want: broilers, layers or kienyeji? Order NOT saved.";
                disengage;
            }
        }
        buyer = find_or_add_buyer(f, self.buyer or "buyer not named", "eggs" if self.item == "eggs" else kind + "s");
        self.order_id = next_ref("O", [o.order_id for o in farm_orders(f)]);
        f ++> Order(order_id=self.order_id, date=d, buyer=buyer, item=self.item, bird_type=kind, qty=self.qty,
                    price_each=max(0.0, self.price_each), deposit=r0(max(0.0, self.deposit)), due=self.due,
                    batch_id=self.batch_id, note=self.note);
        self.saved = True;
        what = order_qty_text(self.item, kind, self.qty);
        msg = f"Order {self.order_id} booked: {what} for {buyer}, delivery {nice_date(self.due, d)}";
        if self.price_each > 0 {
            total = r0(self.qty * self.price_each);
            msg = msg + f", {order_price_text(self.item, self.price_each)} = KSh {total:,.0f}";
            if self.deposit > 0 { msg = msg + f" (deposit KSh {r0(self.deposit):,.0f} paid, KSh {total - r0(self.deposit):,.0f} to collect on delivery)"; }
            msg = msg + ".";
        } else {
            msg = msg + ". Price not agreed yet - it is asked for on delivery.";
            if self.deposit > 0 { msg = msg + f" Deposit KSh {r0(self.deposit):,.0f} paid."; }
        }
        # Can the farm supply it? (code checks birds alive and eggs in store against every open order)
        if self.item == "birds" {
            have = sum([b.alive for b in farm_batches(f) if b.bird_type == kind]);
            booked = booked_birds(f, kind);
            if booked > have {
                msg = msg + f" WARNING: only {have} {kind}s on the farm but {booked} are now booked - {booked - have} short.";
            } else {
                msg = msg + f" {have} {kind}s on the farm, {booked} booked in open orders.";
            }
        } else {
            store = sum([max(0, eggs_in_store(b)) for b in farm_batches(f)]);
            msg = msg + f" Eggs in store now (from the records): {store}; booked in open orders: {booked_eggs(f)}.";
        }
        self.message = msg;
        print(msg);
    }
}

walker deliver_order {
    has order_id: str;
    has qty: int = 0;             # 0 = as ordered
    has price_each: float = 0.0;  # 0 = as agreed in the order
    has batch_id: str = "";       # "" = as in the order, or the best batch
    has date: str = "";
    has saved: bool = False;
    has message: str = "";

    can deliver with Root entry {
        f = [here -->[?:Farm]][0];
        d = self.date or today();
        ref = self.order_id.strip().upper();
        found = [o for o in farm_orders(f) if o.order_id == ref];
        if len(found) == 0 {
            self.message = f"No order called {ref}. Nothing delivered.";
            disengage;
        }
        o = found[0];
        if o.status != "booked" {
            self.message = f"Order {ref} is already {o.status}.";
            disengage;
        }
        qty = self.qty if self.qty > 0 else o.qty;
        price = self.price_each if self.price_each > 0 else o.price_each;
        if price <= 0 {
            self.message = f"What is the price {'per tray' if o.item == 'eggs' else 'per bird'} for order {ref}? Delivery NOT saved yet.";
            disengage;
        }
        bid = self.batch_id or o.batch_id;
        if bid == "" {
            # choose a batch that can supply it: eggs from layers with enough eggs; birds of the right type, oldest first
            if o.item == "eggs" {
                fits = [b for b in farm_batches(f) if b.bird_type == "layer" and (eggs_in_store(b) >= qty or not egg_counts_recorded(b))];
            } else {
                fits = [b for b in farm_batches(f) if b.bird_type == o.bird_type and b.alive >= qty and latest_health(b) != "RED"];
            }
            if len(fits) == 0 {
                if o.item == "eggs" {
                    store = sum([max(0, eggs_in_store(b)) for b in farm_batches(f) if b.bird_type == "layer"]);
                    self.message = f"Order {ref} needs {qty} eggs but only {store} eggs are in store (collected minus sold). Delivery NOT saved - record today's eggs first.";
                } else {
                    have = max([0] + [b.alive for b in farm_batches(f) if b.bird_type == o.bird_type and latest_health(b) != "RED"]);
                    self.message = f"Order {ref} needs {qty} {o.bird_type}s but no healthy batch has that many (largest: {have}). Delivery NOT saved.";
                }
                disengage;
            }
            best = fits[0];
            for b in fits {
                if b.age_days > best.age_days { best = b; }
            }
            bid = best.batch_id;
        }
        item = "eggs" if o.item == "eggs" else o.bird_type + "s";
        w = root spawn record_sale(batch_id=bid, buyer=o.buyer, item=item, qty=qty, price_each=price, date=d);
        if not w.saved {
            self.message = f"Order {ref} NOT delivered: " + w.note;
            disengage;
        }
        if qty != o.qty { o.note = (o.note + " " if o.note else "") + f"(ordered {o.qty}, delivered {qty})"; }
        o.qty = qty;
        o.price_each = price;
        o.batch_id = bid;
        o.status = "delivered";
        o.done_date = d;
        self.saved = True;
        total = r0(qty * price);
        self.message = f"Order {ref} delivered to {o.buyer}. " + w.note;
        if o.deposit > 0 { self.message = self.message + f" Deposit KSh {o.deposit:,.0f} was paid before, so collect KSh {total - o.deposit:,.0f} now."; }
        print(self.message);
    }
}

# ---------- SUPPLY ORDERS (Feed agent: feed, chicks, vaccines, medicine) ----------
walker receive_supply {
    has supply_id: str;
    has qty: float = 0.0;          # 0 = as ordered
    has cost: float = -1.0;        # -1 = as ordered
    has date: str = "";
    has saved: bool = False;
    has message: str = "";
    has batch_made: str = "";

    can receive with Root entry {
        f = [here -->[?:Farm]][0];
        d = self.date or today();
        ref = self.supply_id.strip().upper();
        found = [s for s in farm_supplies(f) if s.supply_id == ref];
        if len(found) == 0 {
            self.message = f"No supply order called {ref}.";
            disengage;
        }
        s = found[0];
        if s.status != "ordered" {
            self.message = f"Supply order {ref} is already {s.status}.";
            disengage;
        }
        qty = self.qty if self.qty > 0 else s.qty;
        cost = r0(self.cost if self.cost >= 0 else s.cost);
        msg = "";
        if s.kind == "Feed" {
            if qty <= 0 {
                self.message = f"How many kg (or bags) of feed arrived for {ref}?";
                disengage;
            }
            root spawn receive_feed(kg=qty, date=d, cost_ksh=cost);
            fr = root spawn feed_report(quiet=True);
            msg = f"{ref} received: {supply_qty_text('Feed', qty)}";
            if cost > 0 { msg = msg + f" for KSh {cost:,.0f} (KSh {per_kg_text(cost / qty)} per kg)"; }
            msg = msg + f". Feed store now {fr.stock_kg:,.0f} kg";
            if fr.days_left > 0 { msg = msg + f", lasts about {fr.days_left:.1f} days"; }
            msg = msg + ".";
        } elif s.kind == "Chicks" {
            wb = root spawn add_batch(bird_type=s.bird_type, count=int(qty), house_name=s.house, age_days=1, date=d);
            if wb.batch_id == "" {
                self.message = f"{ref} NOT received: " + wb.note;
                disengage;
            }
            self.batch_made = wb.batch_id;
            msg = f"{ref} received. " + wb.note;
            if cost > 0 {
                msg = msg + " Chick cost " + add_cost(f, wb.batch_id, "Chicks", cost, f"{int(qty)} chicks" + (f" from {s.supplier}" if s.supplier else "") + f" ({ref})", d);
            }
        } else {
            kind = "Vaccines" if s.kind == "Vaccines" else ("Vet & medicine" if s.kind == "Medicine" else "Other");
            msg = f"{ref} received: {supply_qty_text(s.kind, qty)}" + (f" from {s.supplier}" if s.supplier else "") + ".";
            if cost > 0 {
                txt = add_cost(f, s.batch_id, kind, cost, f"{s.kind.lower()}" + (f" from {s.supplier}" if s.supplier else "") + f" ({ref})", d);
                if txt == "" {
                    self.message = f"{ref} NOT received: there is no batch to put the cost on.";
                    disengage;
                }
                msg = msg + " Cost " + txt;
            }
        }
        s.qty = qty;
        s.cost = cost;
        s.status = "received";
        s.done_date = d;
        self.saved = True;
        self.message = msg;
        print(msg);
    }
}

walker order_supply {
    has kind: str;                 # Feed, Chicks, Vaccines, Medicine, Other
    has qty: float = 0.0;
    has cost: float = 0.0;
    has supplier: str = "";
    has due: str = "";
    has bird_type: str = "";
    has house: str = "";
    has batch_id: str = "";
    has note: str = "";
    has date: str = "";
    has received_now: bool = False;   # it has already arrived: save it and receive it at once
    has supply_id: str = "";
    has saved: bool = False;
    has message: str = "";
    has batch_made: str = "";

    can place with Root entry {
        f = [here -->[?:Farm]][0];
        d = self.date or today();
        kind = self.kind if self.kind in SUPPLY_KINDS else "Other";
        houses = [h.name for h in [f -->[?:House]]];
        house = self.house;
        if kind == "Feed" and self.qty <= 0 {
            self.message = "How much feed (bags or kg)? Supply order NOT saved.";
            disengage;
        }
        if kind == "Chicks" {
            if self.bird_type not in ["broiler", "layer", "kienyeji"] or self.qty <= 0 {
                self.message = "How many chicks, and which type (broiler, layer or kienyeji)? Supply order NOT saved.";
                disengage;
            }
            if house not in houses {
                if len(houses) == 1 {
                    house = houses[0];
                } else {
                    self.message = f"Which house will the chicks go into ({', '.join(houses)})? Supply order NOT saved.";
                    disengage;
                }
            }
        }
        if self.batch_id not in ["", "all"] and self.batch_id not in [b.batch_id for b in farm_batches(f)] {
            self.message = f"No batch called {self.batch_id}. Supply order NOT saved.";
            disengage;
        }
        self.supply_id = next_ref("P", [s.supply_id for s in farm_supplies(f)]);
        f ++> SupplyOrder(supply_id=self.supply_id, date=d, supplier=self.supplier.strip(), kind=kind, qty=max(0.0, self.qty),
                          cost=r0(max(0.0, self.cost)), due=self.due, bird_type=self.bird_type if kind == "Chicks" else "",
                          house=house if kind == "Chicks" else "", batch_id="" if self.batch_id == "all" else self.batch_id,
                          note=self.note);
        if self.received_now {
            r = root spawn receive_supply(supply_id=self.supply_id, date=d);
            self.saved = r.saved;
            self.batch_made = r.batch_made;
            self.message = r.message;
            if not r.saved {
                for s in [x for x in farm_supplies(f) if x.supply_id == self.supply_id] { s.status = "cancelled"; }
            }
            disengage;
        }
        self.saved = True;
        msg = f"Supply order {self.supply_id} placed: {supply_qty_text(kind, self.qty)}";
        if self.supplier.strip() { msg = msg + f" from {self.supplier.strip()}"; }
        if self.cost > 0 { msg = msg + f" for KSh {r0(self.cost):,.0f}"; }
        msg = msg + f", expected {nice_date(self.due, d)}.";
        if kind == "Chicks" { msg = msg + f" They will go into {house}."; }
        msg = msg + f" When it arrives, tap Received (or write '{self.supply_id} imefika') and the stock, batches and costs update by themselves.";
        if kind == "Feed" {
            fr = root spawn feed_report(quiet=True);
            if fr.days_left > 0 { msg = msg + f" Feed in store now lasts about {fr.days_left:.1f} days."; }
        }
        self.message = msg;
        print(msg);
    }
}

# ---------- VET VISITS (Disease detector) ----------
def vet_visit_message(f: Farm, v: VetVisit) -> str {
    vet = farm_vet(f);
    what = "the farm";
    bs = [b for b in farm_batches(f) if b.batch_id == v.batch_id];
    if len(bs) > 0 { what = f"batch {batch_label(bs[0])} ({bs[0].alive} birds)"; }
    when = "as soon as you can" if v.visit_date == "" else "on " + date.fromisoformat(v.visit_date).strftime("%A %d %B");
    phone = f" ({farm_phone(f)})" if farm_phone(f) else "";
    return (f"Hello {vet.name}, this is {f.owner} of {f.name}{phone}. I would like to book a farm visit {when} "
            + f"for {what}. Reason: {v.reason or 'routine check'}. Please confirm. Thank you.");
}

walker book_vet {
    has batch_id: str = "";
    has visit_date: str = "";
    has reason: str = "";
    has date: str = "";
    has visit_id: str = "";
    has saved: bool = False;
    has message: str = "";
    has vet_message: str = "";
    has vet_link: str = "";

    can book with Root entry {
        f = [here -->[?:Farm]][0];
        d = self.date or today();
        if self.batch_id not in ["", "all"] and self.batch_id not in [b.batch_id for b in farm_batches(f)] {
            self.message = f"No batch called {self.batch_id}. Vet visit NOT booked.";
            disengage;
        }
        self.visit_id = next_ref("V", [v.visit_id for v in farm_visits(f)]);
        v = (f ++> VetVisit(visit_id=self.visit_id, date=d, visit_date=self.visit_date,
                            batch_id="" if self.batch_id == "all" else self.batch_id, reason=self.reason.strip()))[0];
        vet = farm_vet(f);
        self.vet_message = vet_visit_message(f, v);
        self.vet_link = whatsapp_link(vet.phone, self.vet_message) if vet.phone else "";
        self.saved = True;
        what = f"for {v.batch_id}" if v.batch_id else "for the whole farm";
        self.message = (f"Vet visit {self.visit_id} booked with {vet.name}, {nice_date(self.visit_date, d) if self.visit_date else 'date to confirm'}, "
                        + f"{what}: {v.reason or 'routine check'}. A WhatsApp message to the vet is ready to send.");
        print(self.message);
    }
}

walker finish_vet {
    has visit_id: str;
    has cost: float = 0.0;
    has cleared: bool = False;     # the vet cleared the batch (RED alert ends, sales allowed)
    has outcome: str = "";
    has date: str = "";
    has saved: bool = False;
    has message: str = "";

    can finish with Root entry {
        f = [here -->[?:Farm]][0];
        d = self.date or today();
        ref = self.visit_id.strip().upper();
        found = [v for v in farm_visits(f) if v.visit_id == ref];
        if len(found) == 0 {
            self.message = f"No vet visit called {ref}.";
            disengage;
        }
        v = found[0];
        if v.status != "booked" {
            self.message = f"Vet visit {ref} is already {v.status}.";
            disengage;
        }
        v.status = "done";
        v.done_date = d;
        v.cost = r0(max(0.0, self.cost));
        v.outcome = self.outcome.strip();
        msg: str = f"Vet visit {ref} done" + (f" ({v.batch_id})" if v.batch_id else "") + ".";
        if v.outcome { msg = msg + f" Vet's advice: {v.outcome}."; }
        if v.cost > 0 {
            txt = add_cost(f, v.batch_id, "Vet & medicine", v.cost, f"vet visit {ref}", d);
            if txt != "" { msg = msg + " Vet fee " + txt; }
        }
        if self.cleared {
            reds = [b for b in farm_batches(f) if latest_health(b) == "RED" and (v.batch_id == "" or b.batch_id == v.batch_id)];
            for b in reds {
                root spawn vet_clear(batch_id=b.batch_id, date=d, vet_note=f"Cleared by the vet at visit {ref}");
            }
            if len(reds) > 0 { msg = msg + " " + ", ".join([b.batch_id for b in reds]) + " cleared by the vet: sales allowed again."; }
        }
        self.saved = True;
        self.message = msg;
        print(msg);
    }
}

# ---------- cancel an order, a supply order or a vet visit by its reference ----------
walker cancel_ref {
    has ref_id: str;
    has saved: bool = False;
    has message: str = "";

    can cancel with Root entry {
        f = [here -->[?:Farm]][0];
        ref = self.ref_id.strip().upper();
        for o in [x for x in farm_orders(f) if x.order_id == ref] {
            if o.status != "booked" { self.message = f"Order {ref} is already {o.status}."; disengage; }
            o.status = "cancelled";
            o.done_date = today();
            self.saved = True;
            self.message = f"Order {ref} for {o.buyer} cancelled." + (f" A deposit of KSh {o.deposit:,.0f} was paid - refund it if agreed." if o.deposit > 0 else "");
            disengage;
        }
        for s in [x for x in farm_supplies(f) if x.supply_id == ref] {
            if s.status != "ordered" { self.message = f"Supply order {ref} is already {s.status}."; disengage; }
            s.status = "cancelled";
            s.done_date = today();
            self.saved = True;
            self.message = f"Supply order {ref} ({supply_qty_text(s.kind, s.qty)}) cancelled.";
            disengage;
        }
        for v in [x for x in farm_visits(f) if x.visit_id == ref] {
            if v.status != "booked" { self.message = f"Vet visit {ref} is already {v.status}."; disengage; }
            v.status = "cancelled";
            v.done_date = today();
            self.saved = True;
            self.message = f"Vet visit {ref} cancelled. Let the vet know.";
            disengage;
        }
        self.message = f"Nothing called {ref} was found (orders are O1, O2..., supply orders P1, P2..., vet visits V1, V2...).";
    }
}

# ---------- what the bookings add to today's plan and the morning briefing ----------
def booking_tasks(f: Farm) -> list[str] {
    t = today();
    out: list[str] = [];
    for o in farm_orders(f) {
        if o.status != "booked" { continue; }
        st = due_status(o.due, t);
        what = f"{order_qty_text(o.item, o.bird_type, o.qty)} to {o.buyer} ({o.order_id})";
        if st == "overdue" { out.append(f"OVERDUE: deliver {what} - was due {nice_date(o.due, t)}"); }
        elif st == "today" { out.append(f"Deliver {what} today"); }
        elif st == "soon" { out.append(f"Get ready: deliver {what} {nice_date(o.due, t)}"); }
    }
    for s in farm_supplies(f) {
        if s.status != "ordered" { continue; }
        st = due_status(s.due, t);
        what = supply_qty_text(s.kind, s.qty) + (f" from {s.supplier}" if s.supplier else "") + f" ({s.supply_id})";
        if st == "overdue" { out.append(f"LATE: {what} was expected {nice_date(s.due, t)} - call the supplier"); }
        elif st == "today" { out.append(f"Expect {what} today - tap Received when it comes"); }
        elif st == "soon" { out.append(f"Coming {nice_date(s.due, t)}: {what}"); }
    }
    for v in farm_visits(f) {
        if v.status != "booked" { continue; }
        st = due_status(v.visit_date, t);
        what = f"vet visit {v.visit_id}" + (f" for {v.batch_id}" if v.batch_id else "") + (f": {v.reason}" if v.reason else "");
        if st == "overdue" { out.append(f"Was the {what} done? It was booked for {nice_date(v.visit_date, t)}"); }
        elif st == "today" { out.append(f"Today: {what}"); }
        elif st == "soon" { out.append(f"{nice_date(v.visit_date, t)}: {what}"); }
    }
    return out;
}

# ---------- what the AI reads from a message (numbers copied, never calculated) ----------
obj ParsedOrder {
    has action: str;            # "book" (a buyer orders / books for later), "deliver" (an order was delivered or collected), "cancel", or "question"
    has order_id: str;          # like "O2" if written, else ""
    has buyer: str;             # buyer name, else ""
    has item: str;              # "birds" or "eggs"
    has bird_type: str;         # "broiler", "layer" or "kienyeji" if said (kuku wa nyama = broiler), else ""
    has birds: int;             # number of birds (0 if eggs or not said)
    has egg_trays: int;         # trays of eggs (0 if none)
    has loose_eggs: int;        # single eggs not in trays (0 if none)
    has price_per_bird: float;  # KSh, 0 if not said
    has price_per_tray: float;  # KSh, 0 if not said
    has total_ksh: float;       # total price if said, else 0
    has deposit_ksh: float;     # money paid in advance, else 0
    has due_date: str;          # YYYY-MM-DD ONLY if an exact date is written (e.g. 20/11 -> this year's date), else ""
    has due_day: str;           # weekday named for delivery ("friday", Ijumaa = friday, Jumamosi = saturday...), else ""
    has due_in_days: int;       # 0 = today/leo, 1 = tomorrow/kesho, 2 = keshokutwa, 7 = next week, -1 if not said
    has batch_id: str;          # one of batch_ids if said, else ""
    has language: str;
}

"""Read a farm message about a CUSTOMER ORDER: a buyer booking birds or eggs for a later day,
an order being delivered / collected, or cancelled. Copy numbers exactly as said; do NOT calculate.
Kiswahili days: Jumatatu=monday, Jumanne=tuesday, Jumatano=wednesday, Alhamisi=thursday, Ijumaa=friday,
Jumamosi=saturday, Jumapili=sunday. order_id must be one of the open orders if one is meant, else "".
Use the language guide for Kiswahili / Sheng number words."""
def parse_order(text: str, today_date: str, open_orders: list[str], batch_ids: list[str], buyers: list[str], language_guide: str) -> ParsedOrder by llm();

obj ParsedSupply {
    has action: str;            # "order" (ordered from a supplier, coming later), "received" (it arrived on the farm), "cancel", or "question"
    has supply_id: str;         # like "P1" if written or clearly meant, else ""
    has kind: str;              # "Feed", "Chicks", "Vaccines", "Medicine" or "Other"
    has feed_bags: float;       # bags of feed (gunia), 0 if none
    has feed_kg: float;         # kg of feed said in kg, 0 if none
    has count: int;             # number of chicks, or vaccine bottles / units, 0 if not said
    has bird_type: str;         # chicks: "broiler", "layer" or "kienyeji", else ""
    has house: str;             # chicks: one of houses if said, else ""
    has supplier: str;          # supplier name if said, else ""
    has cost_ksh: float;        # total cost if said, else 0
    has due_date: str;          # YYYY-MM-DD only if an exact date is written, else ""
    has due_day: str;           # weekday named ("friday"), else ""
    has due_in_days: int;       # 0 today, 1 tomorrow/kesho, -1 if not said
    has batch_id: str;          # vaccines/medicine: one of batch_ids if said, else ""
    has language: str;
}

"""Read a farm message about SUPPLIES bought from a supplier: feed, chicks, vaccines or medicine -
ordering them (coming later), or receiving them (arrived / imefika / zimefika / delivered), or cancelling.
Copy numbers exactly as said; do NOT calculate. gunia / bag = a 50 kg bag of feed.
supply_id must be one of the open supply orders if one is meant, else "". Use the language guide."""
def parse_supply(text: str, today_date: str, open_supplies: list[str], houses: list[str], batch_ids: list[str], language_guide: str) -> ParsedSupply by llm();

obj ParsedVetVisit {
    has action: str;            # "book" (arrange a vet visit), "done" (the vet came / visit finished), "cancel", or "question"
    has visit_id: str;          # like "V1" if written or clearly meant, else ""
    has batch_id: str;          # one of batch_ids if said, else ""
    has reason: str;            # why the vet is needed, short (e.g. "vaccinate against Gumboro", "check coughing birds")
    has due_date: str;          # YYYY-MM-DD only if an exact date is written, else ""
    has due_day: str;           # weekday named ("thursday", Alhamisi = thursday), else ""
    has due_in_days: int;       # 0 today/leo, 1 tomorrow/kesho, -1 if not said
    has cost_ksh: float;        # vet fee paid, 0 if not said
    has cleared: bool;          # True only if the message says the vet cleared / said the birds are fine to sell
    has outcome: str;           # what the vet said or did, short, else ""
    has language: str;
}

"""Read a farm message about a VET VISIT: booking the vet, the vet having come, the fee, or cancelling.
Copy numbers exactly as said. Never add medicine names or doses to reason or outcome.
visit_id must be one of the open visits if one is meant, else "". Use the language guide."""
def parse_vet_visit(text: str, today_date: str, open_visits: list[str], batch_ids: list[str], language_guide: str) -> ParsedVetVisit by llm();

obj ParsedExpense {
    has kind: str;              # exactly one of the cost kinds given
    has amount_ksh: float;      # money paid, copied exactly
    has batch_id: str;          # one of batch_ids if the cost is for one batch, "all" if for the whole farm, "" if not said
    has note: str;              # what was paid for, short (e.g. "electricity", "2 workers")
    has language: str;
}

"""Read a farm message about money PAID for the farm (a cost): labour, transport, electricity, water,
vaccines, vet, repairs and so on. Copy the amount exactly; do NOT calculate.
kind must be one of kinds (electricity, water, repairs, rent -> "Other"; vibarua / workers -> "Labour")."""
def parse_expense(text: str, kinds: list[str], batch_ids: list[str], language_guide: str) -> ParsedExpense by llm();

# ---------- views for the web pages ----------
def order_views(f: Farm) -> list[OrderView] {
    t = today();
    out: list[OrderView] = [];
    for o in reversed(farm_orders(f)) {
        ok = True;
        if o.status == "booked" {
            if o.item == "eggs" {
                unknown = len([b for b in farm_batches(f) if b.bird_type == "layer" and not egg_counts_recorded(b)]) > 0;
                ok = unknown or sum([max(0, eggs_in_store(b)) for b in farm_batches(f)]) >= booked_eggs(f);
            } else {
                ok = sum([b.alive for b in farm_batches(f) if b.bird_type == o.bird_type]) >= booked_birds(f, o.bird_type);
            }
        }
        out.append(OrderView(order_id=o.order_id, date=o.date, buyer=o.buyer, item=o.item, bird_type=o.bird_type,
                             what=order_qty_text(o.item, o.bird_type, o.qty), qty=o.qty,
                             price_text=order_price_text(o.item, o.price_each),
                             total=r0(o.qty * o.price_each), deposit=o.deposit, due=o.due,
                             due_text=nice_date(o.due, t), due_status=due_status(o.due, t) if o.status == "booked" else "",
                             batch_id=o.batch_id, status=o.status, done_date=o.done_date, note=o.note, can_supply=ok));
    }
    return out;
}

def supply_views(f: Farm) -> list[SupplyView] {
    t = today();
    return [SupplyView(supply_id=s.supply_id, date=s.date, supplier=s.supplier, kind=s.kind, what=supply_qty_text(s.kind, s.qty),
                       qty=s.qty, cost=s.cost, due=s.due, due_text=nice_date(s.due, t),
                       due_status=due_status(s.due, t) if s.status == "ordered" else "", status=s.status,
                       done_date=s.done_date, house=s.house, bird_type=s.bird_type, batch_id=s.batch_id)
            for s in reversed(farm_supplies(f))];
}

def visit_views(f: Farm) -> list[VetVisitView] {
    t = today();
    vet = farm_vet(f);
    out: list[VetVisitView] = [];
    for v in reversed(farm_visits(f)) {
        link = whatsapp_link(vet.phone, vet_visit_message(f, v)) if v.status == "booked" and vet.phone else "";
        out.append(VetVisitView(visit_id=v.visit_id, date=v.date, visit_date=v.visit_date,
                                when_text=nice_date(v.visit_date, t) if v.visit_date else "date to confirm",
                                due_status=due_status(v.visit_date, t) if v.status == "booked" else "",
                                batch_id=v.batch_id, reason=v.reason, status=v.status, cost=v.cost,
                                outcome=v.outcome, done_date=v.done_date, vet_link=link));
    }
    return out;
}

# =====================================================================
# WEB API for orders & bookings (forms and buttons on the agents' pages)
# =====================================================================
walker:pub order_add {
    has buyer: str = "";
    has item: str = "birds";        # "birds" or "eggs"
    has bird_type: str = "broiler";
    has qty: int = 0;               # birds, or loose eggs
    has trays: int = 0;             # eggs
    has price_each: float = 0.0;    # per bird
    has price_per_tray: float = 0.0;
    has deposit: float = 0.0;
    has due: str = "";              # YYYY-MM-DD
    has batch_id: str = "";
    has note: str = "";
    has reports: list[ActionResult] = [];

    can add with Root entry {
        f = farm_now();
        eggs = self.item == "eggs";
        w = here spawn take_order(buyer=self.buyer, item="eggs" if eggs else "birds", bird_type="" if eggs else self.bird_type,
                                  qty=self.trays * 30 + self.qty if eggs else self.qty,
                                  price_each=self.price_per_tray / 30.0 if eggs else self.price_each,
                                  deposit=self.deposit, due=self.due, batch_id=self.batch_id, note=self.note, date=today());
        report ActionResult(ok=w.saved, message=w.message, farm=farm_view(f));
    }
}

walker:pub order_deliver {
    has order_id: str;
    has qty: int = 0;
    has price_each: float = 0.0;     # per bird (0 = as agreed)
    has price_per_tray: float = 0.0; # eggs (0 = as agreed)
    has reports: list[ActionResult] = [];

    can go with Root entry {
        f = farm_now();
        price = self.price_per_tray / 30.0 if self.price_per_tray > 0 else self.price_each;
        w = here spawn deliver_order(order_id=self.order_id, qty=self.qty, price_each=price, date=today());
        report ActionResult(ok=w.saved, message=w.message, farm=farm_view(f));
    }
}

walker:pub supply_add {
    has kind: str = "Feed";
    has qty: float = 0.0;            # kg (feed), chicks, or units
    has bags: float = 0.0;           # feed bags of 50 kg
    has cost: float = 0.0;
    has supplier: str = "";
    has due: str = "";
    has bird_type: str = "broiler";
    has house: str = "";
    has batch_id: str = "";
    has received_now: bool = False;
    has reports: list[ActionResult] = [];

    can add with Root entry {
        f = farm_now();
        qty = self.bags * 50.0 + self.qty if self.kind == "Feed" else self.qty;
        w = here spawn order_supply(kind=self.kind, qty=qty, cost=self.cost, supplier=self.supplier, due=self.due,
                                    bird_type=self.bird_type, house=self.house, batch_id=self.batch_id,
                                    date=today(), received_now=self.received_now);
        report ActionResult(ok=w.saved, message=w.message, farm=farm_view(f));
    }
}

walker:pub supply_receive {
    has supply_id: str;
    has reports: list[ActionResult] = [];

    can go with Root entry {
        f = farm_now();
        w = here spawn receive_supply(supply_id=self.supply_id, date=today());
        report ActionResult(ok=w.saved, message=w.message, farm=farm_view(f));
    }
}

walker:pub vet_book {
    has batch_id: str = "";
    has visit_date: str = "";
    has reason: str = "";
    has reports: list[Diagnosis] = [];

    can go with Root entry {
        f = farm_now();
        w = here spawn book_vet(batch_id=self.batch_id, visit_date=self.visit_date, reason=clean_text(self.reason), date=today());
        report Diagnosis(ok=w.saved, batch_id=self.batch_id, level="", reply=w.message,
                         vet_message=w.vet_message, vet_link=w.vet_link, farm=farm_view(f));
    }
}

walker:pub vet_done {
    has visit_id: str;
    has cost: float = 0.0;
    has cleared: bool = False;
    has outcome: str = "";
    has reports: list[ActionResult] = [];

    can go with Root entry {
        f = farm_now();
        w = here spawn finish_vet(visit_id=self.visit_id, cost=self.cost, cleared=self.cleared, outcome=clean_text(self.outcome), date=today());
        report ActionResult(ok=w.saved, message=w.message, farm=farm_view(f));
    }
}

walker:pub booking_cancel {
    has ref_id: str;
    has reports: list[ActionResult] = [];

    can go with Root entry {
        f = farm_now();
        w = here spawn cancel_ref(ref_id=self.ref_id);
        report ActionResult(ok=w.saved, message=w.message, farm=farm_view(f));
    }
}

# =====================================================================
# STEP 7: THE MANAGER ANSWERS ANY QUESTION FROM THE SAVED RECORDS
# Every agent's records are turned into facts with numbers WORKED OUT BY CODE (totals for today,
# yesterday, the last 7 days, this month and all time; per batch and for the whole farm).
# The AI only picks the right facts and words the answer - it never adds or multiplies.
# =====================================================================

def batch_lay_rate(b: Batch) -> float {
    days = [r for r in daily_totals(b) if r.eggs > 0];
    if len(days) == 0 { return -1.0; }
    return laying_rate(b, days[-1].date, days[-1].eggs);
}

def last_weight(b: Batch) -> float {
    ws = [r for r in records_of(b) if r.avg_weight_kg > 0];
    return ws[-1].avg_weight_kg if len(ws) > 0 else 0.0;
}

# Feed conversion ratio: kg of feed eaten for each kg of live bird (birds alive + sold, at the last weight)
# Only for batches that arrived as chicks (7 days old or less) after KukuMind started,
# so ALL the feed they ate is in the records.
def batch_fcr(b: Batch) -> float {
    w = last_weight(b);
    if w <= 0 or b.bird_type == "layer" or b.added == "" or age_on(b, b.added) > 7 { return 0.0; }
    sold = sum([x.qty for x in [b -->[?:Sale]] if x.item != "eggs"]);
    kg_bird = (b.alive + sold) * w;
    feed = sum([r.feed_kg for r in [b -->[?:Record]]]);
    return feed / kg_bird if kg_bird > 0 else 0.0;
}

def in_period(d: str, start: str, end: str) -> bool {
    return d >= start and d <= end;
}

# Totals for one period, for one batch or the whole farm (code does every sum)
def period_line(f: Farm, bs: list[Batch], label: str, start: str, end: str) -> str {
    recs = [r for b in bs for r in [b -->[?:Record]] if in_period(r.date, start, end)];
    sales = [x for b in bs for x in [b -->[?:Sale]] if in_period(x.date, start, end)];
    costs = [e for b in bs for e in [b -->[?:Expense]] if in_period(e.date, start, end)];
    deaths = sum([r.deaths for r in recs]);
    feed = sum([r.feed_kg for r in recs]);
    eggs = sum([r.eggs for r in recs]);
    birds_sold = sum([x.qty for x in sales if x.item != "eggs"]);
    eggs_sold = sum([x.qty for x in sales if x.item == "eggs"]);
    income = r0(sum([x.total for x in sales]));
    other = r0(sum([e.amount for e in costs]));
    feed_cost = r0(feed * feed_price_per_kg(f));
    days = len(set([r.date for r in recs]));
    egg_days = len(set([r.date for r in recs if r.eggs > 0]));
    out = (f"{label}: {deaths} deaths, {feed:,.1f} kg feed eaten (KSh {feed_cost:,.0f}), {eggs:,} eggs collected ({eggs // 30} trays + {eggs % 30}), "
           + f"{birds_sold:,} birds sold, {eggs_sold:,} eggs sold, sales KSh {income:,.0f}, other costs KSh {other:,.0f}, "
           + f"sales minus feed minus other costs = KSh {income - feed_cost - other:,.0f}");
    if days > 0 {
        out = out + f"; {days} day(s) reported: on average {deaths / days:.1f} deaths and {feed / days:,.1f} kg feed a day";
        if egg_days > 0 { out = out + f"; {eggs / egg_days:,.0f} eggs a day on the {egg_days} day(s) eggs were counted"; }
    }
    return out;
}

def farm_facts(f: Farm) -> str {
    t = today();
    td = date.fromisoformat(t);
    y = (td - timedelta(days=1)).isoformat();
    w0 = (td - timedelta(days=6)).isoformat();
    m0 = t[:8] + "01";
    lm_end = (date.fromisoformat(m0) - timedelta(days=1)).isoformat();
    lm0 = lm_end[:8] + "01";
    periods = [["Today (" + t + ")", t, t], ["Yesterday (" + y + ")", y, y], [f"Last 7 days ({w0} to {t})", w0, t],
               [f"This month ({m0} to {t})", m0, t], [f"Last month ({lm0} to {lm_end})", lm0, lm_end], ["All time", "0000", "9999"]];
    price = feed_price_per_kg(f);
    bs = farm_batches(f);
    out: list[str] = [f"FARM: {f.name}, owner {f.owner}" + (f", phone {farm_phone(f)}" if farm_phone(f) else "") + f". Today is {day_and_date(t)}.",
                      "Houses: " + ", ".join([f"{h.name} (room for {h.capacity})" for h in [f -->[?:House]]])];

    # ---- every batch ----
    out.append("\nBATCHES (counts checked by code: started - dead - sold = alive):");
    for b in bs {
        recs = [b -->[?:Record]];
        dead = sum([r.deaths for r in recs]);
        sold = sum([x.qty for x in [b -->[?:Sale]] if x.item != "eggs"]);
        m = batch_money(b, price);
        h = [x.name for x in [b <--[?:House]]];
        line = (f"{batch_label(b)} in {h[0] if len(h) > 0 else '-'}: started {b.start_count:,}" + (f" (arrived {b.added})" if b.added else "")
                + f", dead {dead:,}, sold {sold:,}, alive {b.alive:,}; mortality {100.0 * dead / b.start_count if b.start_count > 0 else 0.0:.1f}%; "
                + f"health {latest_health(b)}; booked in open customer orders: "
                + f"{sum([o.qty for o in farm_orders(f) if o.status == 'booked' and o.item == 'birds' and (o.batch_id == b.batch_id or (o.batch_id == '' and o.bird_type == b.bird_type))])} birds.");
        if egg_counts_recorded(b) {
            lr = batch_lay_rate(b);
            line = line + f" Eggs: collected {sum([r.eggs for r in recs]):,}, sold {sum([x.qty for x in [b -->[?:Sale]] if x.item == 'eggs']):,}, in store {max(0, eggs_in_store(b)):,}; last laying rate {lr:.0f}%.";
        }
        if last_weight(b) > 0 {
            line = line + f" Last average weight {last_weight(b)} kg";
            if batch_fcr(b) > 0 { line = line + f", feed conversion {batch_fcr(b):.2f} kg feed per kg of bird"; }
            line = line + ".";
        }
        line = (line + f" Money: sales KSh {m.income:,.0f} (birds {m.bird_income:,.0f}, eggs {m.egg_income:,.0f}), feed eaten {m.feed_kg:,.1f} kg = KSh {m.feed_cost:,.0f}, "
                + f"other costs KSh {m.other_cost:,.0f}, profit KSh {m.balance:,.0f}.");
        kinds: dict[str, float] = {};
        for e in [b -->[?:Expense]] { kinds[e.kind] = kinds.get(e.kind, 0.0) + e.amount; }
        if len(kinds) > 0 { line = line + " Other costs by kind: " + ", ".join([f"{k} KSh {r0(v):,.0f}" for (k, v) in kinds.items()]) + "."; }
        line = line + f" Heat: {brooding_temp(b.age_days)}. Next care (7 days): {'; '.join(due_tasks(b.bird_type, b.age_days, 7)) or 'nothing due'}.";
        warn = early_warnings(b);
        if len(warn) > 0 { line = line + " Warnings: " + " ".join(warn); }
        out.append(line);
    }

    # ---- totals by period ----
    out.append("\nTOTALS FOR THE WHOLE FARM:");
    for p in periods { out.append(period_line(f, bs, p[0], p[1], p[2])); }
    for b in bs {
        out.append(f"\nTOTALS FOR {b.batch_id}:");
        for p in periods { out.append(period_line(f, [b], p[0], p[1], p[2])); }
    }

    # ---- daily reports (last 14 days) ----
    out.append("\nDAILY REPORTS (last 14 days, one line per batch per day):");
    for b in bs {
        for d in daily_totals(b)[-14:] {
            x = f"{d.date} {b.batch_id}: {d.deaths} deaths, {d.feed_kg:,.1f} kg feed";
            if d.eggs > 0 { x = x + f", {d.eggs:,} eggs (laying rate {laying_rate(b, d.date, d.eggs):.0f}%)"; }
            out.append(x);
        }
    }

    # ---- feed ----
    fr = root spawn feed_report(quiet=True);
    deliveries = [d for d in [f -->[?:FeedStore] -->[?:FeedDelivery]]];
    out.append(f"\nFEED: {fr.stock_kg:,.0f} kg in store ({fr.stock_kg / 50.0:,.1f} bags); the birds need about {fr.daily_need:,.0f} kg a day, so it lasts about {fr.days_left:.1f} days. "
               + f"Feed already ordered (not arrived): {fr.on_order_kg:,.0f} kg. Bags still to order for the next 7 days: {fr.bags_to_order}. "
               + f"Feed price used for costs: KSh {per_kg_text(price)} per kg (average of deliveries with a price"
               + ("" if len([d for d in deliveries if d.cost_ksh > 0]) > 0 else "; none recorded yet, so a standard price") + ").");
    out = out + fr.lines + fr.alerts;
    for d in deliveries[-10:] {
        out.append(f"Feed delivery {d.date}: {d.kg:,.0f} kg" + (f" for KSh {d.cost_ksh:,.0f} (KSh {per_kg_text(d.cost_ksh / d.kg)} per kg)" if d.cost_ksh > 0 and d.kg > 0 else ""));
    }
    out.append(f"Feed delivered all time: {sum([d.kg for d in deliveries]):,.0f} kg for KSh {r0(sum([d.cost_ksh for d in deliveries])):,.0f}.");

    # ---- money: whole-farm statement ----
    ms = [batch_money(b, price) for b in bs];
    inc = sum([m.income for m in ms]);
    fc = sum([m.feed_cost for m in ms]);
    oc = sum([m.other_cost for m in ms]);
    out.append(f"\nPROFIT STATEMENT (all time): sales KSh {inc:,.0f} (birds {sum([m.bird_income for m in ms]):,.0f}, eggs {sum([m.egg_income for m in ms]):,.0f}) "
               + f"- feed eaten KSh {fc:,.0f} - other costs KSh {oc:,.0f} = profit KSh {inc - fc - oc:,.0f}.");
    best = [b for b in bs];
    if len(best) > 0 {
        top = best[0];
        for b in best { if batch_money(b, price).balance > batch_money(top, price).balance { top = b; } }
        out.append(f"Batch with the highest profit so far: {top.batch_id} (KSh {batch_money(top, price).balance:,.0f}).");
    }
    allk: dict[str, float] = {};
    for b in bs { for e in [b -->[?:Expense]] { allk[e.kind] = allk.get(e.kind, 0.0) + e.amount; } }
    if len(allk) > 0 { out.append("Other costs by kind (all batches): " + ", ".join([f"{k} KSh {r0(v):,.0f}" for (k, v) in allk.items()]) + "."); }
    exps = sorted([(e.date, b.batch_id, e.kind, e.amount, e.note) for b in bs for e in [b -->[?:Expense]]], reverse=True)[:15];
    for e in exps { out.append(f"Cost {e[0]} {e[1]}: {e[2]} KSh {e[3]:,.0f}" + (f" ({e[4]})" if e[4] else "")); }

    # ---- sales and buyers ----
    sale_ids: list[str] = [b.batch_id for b in bs for x in [b -->[?:Sale]]];
    sale_list: list[Sale] = [x for b in bs for x in [b -->[?:Sale]]];
    newest: list[int] = [int(pair[1]) for pair in sorted([(sale_list[i].date, i) for i in range(len(sale_list))], reverse=True)][:20];
    out.append("\nSALES (latest 20):" if len(newest) > 0 else "\nSALES: none yet.");
    for si in newest {
        sl: Sale = sale_list[si];
        what = sale_qty_text(sl.qty, sl.price_each) if sl.item == "eggs" else f"{sl.qty} {sl.item} at KSh {sl.price_each:,.0f} each";
        out.append(f"{sl.date} {sale_ids[si]}: {what} to {sl.buyer} = KSh {sl.total:,.0f}");
    }
    for bv in buyer_views(f) {
        out.append(f"Buyer {bv.name}" + (f" ({bv.phone})" if bv.phone else "") + f": wants {bv.wants}; bought KSh {bv.bought:,.0f} so far.");
    }
    ma = root spawn market_alerts(quiet=True, broadcast=False);
    for o in ma.offers { out.append(f"Ready to sell: {o}"); }
    for x in ma.blocked { out.append(f"Not for sale: {x}"); }

    # ---- orders, supplies, vet visits ----
    out.append("\nCUSTOMER ORDERS:");
    for o in farm_orders(f) {
        out.append(f"{o.order_id} ({o.status}): {order_qty_text(o.item, o.bird_type, o.qty)} for {o.buyer}, delivery {nice_date(o.due, t)} ({o.due or 'no date'}), "
                   + f"{order_price_text(o.item, o.price_each)}" + (f", value KSh {r0(o.qty * o.price_each):,.0f}" if o.price_each > 0 else "")
                   + (f", deposit KSh {o.deposit:,.0f}" if o.deposit > 0 else "") + (f", delivered {o.done_date}" if o.status == "delivered" else ""));
    }
    out.append("SUPPLY ORDERS:");
    for x in farm_supplies(f) {
        out.append(f"{x.supply_id} ({x.status}): {supply_qty_text(x.kind, x.qty)}" + (f" from {x.supplier}" if x.supplier else "")
                   + (f", KSh {x.cost:,.0f}" if x.cost > 0 else "") + f", expected {nice_date(x.due, t)}" + (f", received {x.done_date}" if x.status == "received" else ""));
    }
    out.append(f"VET: {farm_vet(f).name} {farm_vet(f).phone}. Vet visits:");
    for v in farm_visits(f) {
        out.append(f"{v.visit_id} ({v.status}): " + (v.batch_id or "whole farm") + f", {v.visit_date or 'date to confirm'}, {v.reason}"
                   + (f", fee KSh {v.cost:,.0f}" if v.cost > 0 else "") + (f", vet said: {v.outcome}" if v.outcome else ""));
    }

    # ---- health checks ----
    checks = sorted([(c.date, b.batch_id, c.level, c.summary.split(" | ")[0]) for b in bs for c in [b -->[?:HealthCheck]]], reverse=True)[:10];
    out.append("\nHEALTH CHECKS (latest 10):" if len(checks) > 0 else "\nHEALTH CHECKS: none yet.");
    for c in checks { out.append(f"{c[0]} {c[1]}: {c[2]} - {c[3]}"); }

    # ---- hatchery ----
    sets = [e for e in [f -->[?:EggSet]]];
    out.append("\nINCUBATOR:" if len(sets) > 0 else "\nINCUBATOR: no eggs set yet.");
    for e in sets {
        x = f"{e.set_id}: {e.eggs_set:,} {e.bird_type} eggs, day {e.day}";
        if e.fertile >= 0 { x = x + f", {e.fertile:,} fertile at candling ({100.0 * e.fertile / e.eggs_set:.0f}%)"; }
        if e.done { x = x + f", hatched {max(0, e.hatched):,} chicks ({100.0 * max(0, e.hatched) / e.eggs_set:.0f}% of eggs set" + (f", {100.0 * max(0, e.hatched) / e.fertile:.0f}% of fertile eggs" if e.fertile > 0 else "") + ")"; }
        else { x = x + f". Next: {hatchery_task(e.day)}"; }
        out.append(x);
    }

    # ---- today ----
    out.append("\nTODAY'S PLAN:");
    out = out + booking_tasks(f) + (root spawn today_tasks(quiet=True)).tasks;
    return "\n".join(out);
}

"""Answer the farm owner's question as KukuMind's Manager, using ONLY the farm facts given.
The facts come from every agent's saved records, and every total, average and percentage in them was
worked out by code. Pick the fact that answers the question and copy its numbers exactly.
Never add, subtract, multiply or average numbers yourself: if the exact number asked for is not in the facts,
say it is not in the records yet (and which page or message would record it) instead of guessing.
Name the batch, period and dates you are using. Plain text, no markdown, short.
Reply in the language given and follow HOW TO WRITE EVERY REPLY in the language guide."""
def manager_answer(question: str, facts: str, language: str, language_guide: str) -> str by writer();


# ---------- SALES REPORT: totals, averages and chart data, worked out by code ----------
def sales_summary(f: Farm) -> SalesSummary {
    t = today();
    td = date.fromisoformat(t);
    w0 = (td - timedelta(days=6)).isoformat();
    m0 = t[:8] + "01";
    lm_end = (date.fromisoformat(m0) - timedelta(days=1)).isoformat();
    lm0 = lm_end[:8] + "01";
    sales = [x for b in farm_batches(f) for x in [b -->[?:Sale]]];
    total = r0(sum([x.total for x in sales]));
    birds = [x for x in sales if x.item != "eggs"];
    eggs = [x for x in sales if x.item == "eggs"];
    bird_income = r0(sum([x.total for x in birds]));
    egg_income = r0(sum([x.total for x in eggs]));
    birds_sold = sum([x.qty for x in birds]);
    eggs_sold = sum([x.qty for x in eggs]);
    day_labels: list[str] = [];
    day_values: list[float] = [];
    for i in range(13, -1, -1) {
        d = (td - timedelta(days=i)).isoformat();
        day_labels.append(d[8:]);
        day_values.append(r0(sum([x.total for x in sales if x.date == d])));
    }
    month_labels: list[str] = [];
    month_values: list[float] = [];
    y = td.year;
    m = td.month;
    months: list[str] = [];
    for i in range(6) {
        months.insert(0, f"{y:04d}-{m:02d}");
        m = m - 1;
        if m == 0 { m = 12; y = y - 1; }
    }
    for ym in months {
        month_labels.append(date.fromisoformat(ym + "-01").strftime("%b"));
        month_values.append(r0(sum([x.total for x in sales if x.date[:7] == ym])));
    }
    bv = sorted([(r0(sum([x.total for x in sales if x.buyer == b.name])), b.name) for b in [f -->[?:Buyer]]], reverse=True);
    bv = [z for z in bv if z[0] > 0][:6];
    open_o = [o for o in farm_orders(f) if o.status == "booked"];
    return SalesSummary(total=total,
                        today=r0(sum([x.total for x in sales if x.date == t])),
                        week=r0(sum([x.total for x in sales if x.date >= w0 and x.date <= t])),
                        month=r0(sum([x.total for x in sales if x.date >= m0 and x.date <= t])),
                        last_month=r0(sum([x.total for x in sales if x.date >= lm0 and x.date <= lm_end])),
                        n_sales=len(sales), birds_sold=birds_sold, bird_income=bird_income,
                        avg_bird_price=r0(bird_income / birds_sold) if birds_sold > 0 else 0.0,
                        eggs_sold=eggs_sold, egg_income=egg_income,
                        avg_tray_price=r0(egg_income / eggs_sold * 30.0) if eggs_sold > 0 else 0.0,
                        bird_pct=r1(100.0 * bird_income / total) if total > 0 else 0.0,
                        egg_pct=r1(100.0 * egg_income / total) if total > 0 else 0.0,
                        day_labels=day_labels, day_values=day_values,
                        month_labels=month_labels, month_values=month_values,
                        buyer_names=[str(z[1]) for z in bv], buyer_values=[float(z[0]) for z in bv],
                        batch_labels=[b.batch_id for b in farm_batches(f)],
                        batch_values=[batch_money(b, 0.0).income for b in farm_batches(f)],
                        open_orders_value=r0(sum([o.qty * o.price_each for o in open_o])), open_orders=len(open_o));
}
