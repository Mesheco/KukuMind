"""KukuMind farm agents - the 7-agent team and its farm graph (server side).

Used by main.jac (web app, `jac start main.jac`) and demo.jac (terminal demo, `jac run demo.jac`)."""

import os;
import from byllm.lib { Model, Image }
glob llm = Model(model_name="claude-haiku-4-5-20251001");      # reads messages and numbers (fast, cheap)

# Model that WRITES replies to farmers. For better Kiswahili, change it to "claude-sonnet-4-6",
# run the live test, and if you get an error change it back to "claude-haiku-4-5-20251001".
glob WRITER_MODEL = "claude-sonnet-4-6";
glob writer = Model(model_name=WRITER_MODEL);
glob writer_status: str = "";     # "" = not checked yet, then the model in use

"""Reply with the single word OK."""
def writer_ping() -> str by writer();

# Check once that the writing model works; if not, quietly use the reading model (Haiku) instead
def ensure_writer() {
    global writer, writer_status;
    if writer_status != "" or writer is llm { return; }
    try {
        writer_ping();
        writer_status = WRITER_MODEL;
    } except Exception as e {
        print(f"Writer model {WRITER_MODEL} not available ({e}); using claude-haiku-4-5 for replies.");
        writer = llm;
        writer_status = "claude-haiku-4-5-20251001 (fallback)";
    }
    print(f"KukuMind replies are written by: {writer_status}");
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
    recs = [b -->(?:Record)];
    pairs = sorted([(recs[i].date, i) for i in range(len(recs))]);
    return [recs[p[1]] for p in pairs];
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
        if [here -->(?:Farm)] {
            print("Farm already exists - skipping build.");
            disengage;
        }
        farm = here ++> Farm(name="Meshack Poultry Farm", owner="Meshack", phone="0722434939");
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

    can start with Root entry {
        visit [-->];
    }

    can walk_farm with Farm entry {
        visit [-->(?:House)];
    }

    can walk_house with House entry {
        visit [-->(?:Batch)];
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
            stores = [here <--(?:House) <--(?:Farm) -->(?:FeedStore)];
            if len(stores) > 0 and self.feed_kg > 0 {
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
        batch_ids = [b.batch_id for b in [here -->(?:Farm) -->(?:House) -->(?:Batch)]];
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
        for b in [here -->(?:Batch)] {
            recs = [b -->(?:Record)];
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
        f = [here -->(?:Farm)][0];
        if self.set_id == "" {
            self.set_id = f"E{len([f -->(?:EggSet)]) + 1}";
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
        for s in [here -->(?:Farm) -->(?:EggSet)] {
            if s.set_id == self.set_id and s.eggs_set > 0 {
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
        f = [here -->(?:Farm)][0];
        self.note = f"No egg set called {self.set_id}. Hatch NOT saved.";
        for s in [f -->(?:EggSet)] {
            if s.set_id == self.set_id and s.done {
                self.note = f"{s.set_id} was already hatched - nothing to do.";
                print(self.note);
            } elif s.set_id == self.set_id {
                houses = [h for h in [f -->(?:House)] if h.name == self.house_name];
                if len(houses) == 0 and self.hatched > 0 {
                    names = [h.name for h in [f -->(?:House)]];
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
                for h in [f -->(?:House)] {
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
        f = [here -->(?:Farm)][0];
        for b in [f -->(?:House) -->(?:Batch)] { b.age_days += 1; }
        for s in [f -->(?:EggSet)] {
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
        f = [here -->(?:Farm)][0];
        for s in [f -->(?:EggSet)] {
            if not s.done {
                self.tasks.append(f"[Hatchery {s.set_id}, day {s.day}] {hatchery_task(s.day)}");
            }
        }
        for b in [f -->(?:House) -->(?:Batch)] {
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
        f = [here -->(?:Farm)][0];
        lines: list[str] = [];
        for b in [f -->(?:House) -->(?:Batch)] {
            lines.append(f"{b.batch_id}: {b.bird_type}, day {b.age_days}, {b.alive} alive. {brooding_temp(b.age_days)}. Upcoming: {due_tasks(b.bird_type, b.age_days, 7)}");
        }
        for s in [f -->(?:EggSet)] {
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

# ---------- Early warnings from the records (no AI) ----------
def early_warnings(b: Batch) -> list[str] {
    out: list[str] = [];
    recs = records_of(b);
    if len(recs) == 0 { return out; }
    last = recs[-1];
    prev = recs[:-1];

    # 1. Deaths today vs flock size (normal is about 0.1% a day or less)
    flock = b.alive + last.deaths;
    if flock > 0 {
        pct = 100.0 * last.deaths / flock;
        if pct >= 1.0 {
            out.append(f"VERY HIGH deaths in the last report: {last.deaths} birds ({pct:.1f}% of the flock).");
        } elif pct >= 0.3 {
            out.append(f"Deaths above normal in the last report: {last.deaths} birds ({pct:.1f}%).");
        }
    }

    # 2. Deaths rising 3 reports in a row
    if len(recs) >= 3 {
        a = recs[-3].deaths;
        m = recs[-2].deaths;
        z = recs[-1].deaths;
        if z > m and m > a {
            out.append(f"Deaths rising 3 reports in a row: {a} -> {m} -> {z}.");
        }
    }

    # 3. Feed intake drop (sick birds eat less)
    prev_feed = [r.feed_kg for r in prev if r.feed_kg > 0];
    if len(prev_feed) > 0 and last.feed_kg > 0 {
        avg = sum(prev_feed) / len(prev_feed);
        if last.feed_kg < 0.85 * avg {
            drop = 100.0 * (avg - last.feed_kg) / avg;
            out.append(f"Feed intake dropped {drop:.0f}% ({last.feed_kg} kg vs average {avg:.0f} kg).");
        }
    }

    # 4. Egg drop (layers)
    prev_eggs = [r.eggs for r in prev if r.eggs > 0];
    if len(prev_eggs) > 0 and last.eggs > 0 {
        avg_e = sum(prev_eggs) / len(prev_eggs);
        if last.eggs < 0.9 * avg_e {
            drop_e = 100.0 * (avg_e - last.eggs) / avg_e;
            out.append(f"Egg production dropped {drop_e:.0f}% ({last.eggs} vs average {avg_e:.0f}).");
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
    vets = [f -->(?:Vet)];
    if len(vets) == 0 {
        f ++> Vet(name="Dr. Timothy Wambua (farm vet)", phone="0714297727");
        vets = [f -->(?:Vet)];
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
        found = [b for b in [here -->(?:Farm) -->(?:House) -->(?:Batch)] if b.batch_id == self.batch_id];
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
            f = [here -->(?:Farm)][0];
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
        for b in [here -->(?:Farm) -->(?:House) -->(?:Batch)] {
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
    for b in [f -->(?:Buyer)] {
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
    found = [f -->(?:House) -->(?:Batch)];
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
    checks = [b -->(?:HealthCheck)];
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
        recs = [r for r in records_of(b) if r.eggs > 0];
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
        f = [here -->(?:Farm)][0];
        fs = [f -->(?:FeedStore)][0];
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

    can check with Root entry {
        f = [here -->(?:Farm)][0];
        fs = [f -->(?:FeedStore)][0];
        self.stock_kg = fs.stock_kg;
        if not self.quiet { print(f"\n--- FEED & INVENTORY ---\nFeed in store: {fs.stock_kg:.0f} kg"); }

        daily_need = 0.0;
        for b in farm_batches(f) {
            need = expected_feed_per_bird(b.bird_type, b.age_days) * b.alive;
            daily_need += need;
            recs = [r for r in records_of(b) if r.feed_kg > 0];
            line = f"  {b.batch_id}: needs about {need:.0f} kg/day";
            if len(recs) > 0 {
                used = recs[-1].feed_kg;
                line = line + f", last report used {used:.0f} kg";
                if used > 1.25 * need {
                    self.alerts.append(f"{b.batch_id}: using {used:.0f} kg vs about {need:.0f} kg expected - check for feed wastage, spills or rats.");
                } elif used < 0.75 * need {
                    self.alerts.append(f"{b.batch_id}: eating only {used:.0f} kg vs about {need:.0f} kg expected - birds may be sick or feeders empty.");
                }
            }
            self.lines.append(line.strip());
            if not self.quiet { print(line); }
        }

        if daily_need > 0 {
            self.days_left = fs.stock_kg / daily_need;
            self.lines.append(f"Whole farm needs about {daily_need:.0f} kg/day; feed lasts about {self.days_left:.1f} days.");
            if not self.quiet { print(f"Whole farm needs about {daily_need:.0f} kg/day -> feed lasts about {self.days_left:.1f} days."); }
            bags = (daily_need * 7 - fs.stock_kg) / 50;
            if self.days_left < 3 {
                self.alerts.append(f"URGENT: feed runs out in about {self.days_left:.1f} days. Order now (about {max(bags, 1):.0f} bags of 50 kg for one week).");
            } elif self.days_left < 7 {
                self.alerts.append(f"Feed runs out in about {self.days_left:.1f} days. Plan an order (about {max(bags, 1):.0f} bags of 50 kg for one week).");
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
        f = [here -->(?:Farm)][0];
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
        for buyer in [f -->(?:Buyer)] {
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
        found = [b for b in [here -->(?:Farm) -->(?:House) -->(?:Batch)] if b.batch_id == self.batch_id];
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
        if self.item != "eggs" {
            if self.qty > b.alive {
                self.note = f"Only {b.alive} birds in {b.batch_id}, cannot sell {self.qty}. Sale NOT saved.";
                print(self.note);
                disengage;
            }
            b.alive -= self.qty;
        }
        total = self.qty * self.price_each;
        f = [here -->(?:Farm)][0];
        self.buyer = find_or_add_buyer(f, self.buyer, self.item);
        b ++> Sale(date=self.date, buyer=self.buyer, item=self.item, qty=self.qty,
                   price_each=self.price_each, total=total);
        self.saved = True;
        each = f"KSh {self.price_each:,.0f}" if self.price_each >= 1 else f"KSh {self.price_each:.2f}";
        if self.item == "eggs" and self.qty % 30 == 0 {
            each = f"{self.qty // 30} trays at KSh {self.price_each * 30:,.0f} a tray";
            self.note = f"Sale saved: {self.qty} eggs ({each}) from {b.batch_id} to {self.buyer} = KSh {total:,.0f}.";
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
        for b in [here -->(?:Farm) -->(?:House) -->(?:Batch)] {
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
    deliveries = [d for d in [f -->(?:FeedStore) -->(?:FeedDelivery)] if d.kg > 0 and d.cost_ksh > 0];
    if len(deliveries) == 0 { return DEFAULT_FEED_PRICE_PER_KG; }
    return sum([d.cost_ksh for d in deliveries]) / sum([d.kg for d in deliveries]);
}

def batch_money(b: Batch, price: float) -> BatchMoney {
    sales = [b -->(?:Sale)];
    income = sum([s.total for s in sales]);
    eggs = sum([s.total for s in sales if s.item == "eggs"]);
    kg = sum([r.feed_kg for r in [b -->(?:Record)]]);
    cost = kg * price;
    other = sum([e.amount for e in [b -->(?:Expense)]]);
    return BatchMoney(income=income, feed_kg=kg, feed_cost=cost, balance=income - cost - other,
                      other_cost=other, bird_income=income - eggs, egg_income=eggs);
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
        f = [here -->(?:Farm)][0];
        if not self.quiet { print("\n--- SALES ---"); }
        for b in farm_batches(f) {
            sales = [b -->(?:Sale)];
            if len(sales) == 0 { continue; }
            income = sum([s.total for s in sales]);
            self.total_income += income;
            self.lines.append(f"{b.batch_id}: {len(sales)} sale(s), KSh {income:,.0f}");
            if not self.quiet {
                print(f"  {b.batch_id}: {len(sales)} sale(s), KSh {income:,.0f}");
                for s in sales {
                    print(f"     {s.date} {s.buyer}: {s.qty} {s.item} x KSh {s.price_each} = KSh {s.total:,.0f}");
                }
            }
        }
        self.feed_cost = sum([d.cost_ksh for d in [f -->(?:FeedStore) -->(?:FeedDelivery)]]);
        if not self.quiet { print(f"  TOTAL sales: KSh {self.total_income:,.0f} | Feed bought: KSh {self.feed_cost:,.0f}"); }

        # Profit per batch: sales minus the feed the batch has eaten
        price = feed_price_per_kg(f);
        if not self.quiet { print(f"\n--- PROFIT PER BATCH (sales - feed eaten at KSh {price:.0f}/kg - recorded costs) ---"); }
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
    has intent: str;      # exactly one of: report, new_batch, health, advice, hatchery, feed, sales, briefing
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
- sales: a sale that happened ("sold 50 B3 layers at 450 each", "tumeuza mayai trei 20"),
         or questions about selling, buyers, market, orders, prices, income, profit or loss
         (faida, hasara, pesa, "is this batch making money?").
- briefing: asking for a summary of the farm or today's plan. e.g. "habari ya shamba leo?", "morning report"
If a message has numbers AND symptoms, choose health.
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
        f = [here -->(?:Farm)][0];
        houses = [h for h in [f -->(?:House)] if h.name == self.house_name];
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
        f = [here -->(?:Farm)][0];
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
        batch_ids = [b.batch_id for b in [here -->(?:Farm) -->(?:House) -->(?:Batch)]];
        r = route_message(self.text, batch_ids, LANGUAGE_GUIDE);
        r.language = reply_lang(self.language, r.language);
        self.intent = r.intent;
        # a short answer to "which batch / what price?" finishes the sale that was waiting
        if len([here -->(?:Farm) -->(?:PendingSale)]) > 0 and len(self.text) <= 60 and self.force in ["", "sales"] {
            self.intent = "sales";
        }
        if self.force in ["report", "health", "advice", "hatchery", "feed", "sales", "briefing"] {
            # the Flock records agent also registers new flocks
            if not (self.force == "report" and r.intent == "new_batch") { self.intent = self.force; }
        }
        if self.photo_path { self.intent = "health"; }     # a photo always means a health check

        print(f"\n>>> Message: {self.text}\n>>> Manager sends it to: {self.intent.upper()} agent");

        if self.intent == "new_batch" {
            f = [here -->(?:Farm)][0];
            houses = [h.name for h in [f -->(?:House)]];
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
                self.reply = plain_text(confirm_action(wb.note, reply_lang(self.language, nb.language or r.language), LANGUAGE_GUIDE));
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

        } elif self.intent == "feed" {
            fr = here spawn feed_report(quiet=True);
            facts = [f"Feed in store: {fr.stock_kg:.0f} kg"] + fr.lines + fr.alerts;
            self.reply = plain_text(farm_answer(self.text, "\n".join(facts), r.language, LANGUAGE_GUIDE));

        } elif self.intent == "hatchery" {
            f = [here -->(?:Farm)][0];
            sets = [f"{s.set_id}: {s.eggs_set} {s.bird_type} eggs, day {s.day}, {'done' if s.done else 'in incubator'}" for s in [f -->(?:EggSet)]];
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
                houses = [h.name for h in [f -->(?:House)]];
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
                buyers = [f"{b.name} ({b.wants}, {b.phone})" for b in [here -->(?:Farm) -->(?:Buyer)]];
                facts = ([f"Ready to sell: {o}" for o in ma.offers] + [f"Not for sale: {x}" for x in ma.blocked]
                         + sr.lines + [f"Total sales so far: KSh {sr.total_income:,.0f}", f"Buyers: {buyers}"]
                         + ["Profit per batch (sales minus feed eaten minus recorded costs such as chicks, vaccines and labour):"] + sr.profit_lines);
                self.reply = plain_text(farm_answer(self.text, "\n".join(facts), r.language, LANGUAGE_GUIDE));
            }

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
        f = [root -->(?:Farm)][0];
        batch_ids = [b.batch_id for b in farm_batches(f)];
        buyers = [b.name for b in [f -->(?:Buyer)]];
        # A short answer ("B3", "kwa 420") completes a sale message that was missing details
        pending = [f -->(?:PendingSale)];
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
        for r in [b -->(?:Record)] {
            parts: list[str] = [f"{r.deaths} deaths", f"{r.feed_kg:.0f} kg feed"];
            if r.eggs > 0 { parts.append(f"{r.eggs} eggs"); }
            if r.avg_weight_kg > 0 { parts.append(f"avg weight {r.avg_weight_kg} kg"); }
            if r.note { parts.append(r.note); }
            rows.append(RecordView(date=r.date, batch_id=b.batch_id, kind="Report", detail=", ".join(parts)));
        }
        for x in [b -->(?:Sale)] {
            rows.append(RecordView(date=x.date, batch_id=b.batch_id, kind="Sale",
                                   detail=f"{x.qty} {x.item} to {x.buyer} at KSh {x.price_each:,.0f} = KSh {x.total:,.0f}"));
        }
        if b.added != "" {
            rows.append(RecordView(date=b.added, batch_id=b.batch_id, kind="New batch",
                                   detail=f"{b.start_count} {b.bird_type} birds arrived ({batch_label(b)})"));
        }
        for c in [b -->(?:HealthCheck)] {
            rows.append(RecordView(date=c.date, batch_id=b.batch_id, kind="Health",
                                   detail=f"{c.level}: {c.summary.split(' | ')[0]}"));
        }
    }
    pairs = sorted([(rows[i].date, i) for i in range(len(rows))], reverse=True);
    return [rows[p[1]] for p in pairs][:limit];
}

def farm_view(f: Farm) -> FarmView {
    views: list[BatchView] = [];
    price = feed_price_per_kg(f);
    for b in farm_batches(f) {
        for h in [b <--(?:House)] {
            recs = [b -->(?:Record)];
            sales = [b -->(?:Sale)];
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
                                   feed_eaten_kg=r1(money.feed_kg), other_cost=r0(money.other_cost),
                                   bird_income=r0(money.bird_income), egg_income=r0(money.egg_income)));
        }
    }
    sets = [f"{s.set_id}: {s.eggs_set} {s.bird_type} eggs, day {s.day} - {hatchery_task(s.day)}"
            for s in [f -->(?:EggSet)] if not s.done];
    fr = root spawn feed_report(quiet=True);
    ew = root spawn early_warning_scan(quiet=True);
    sr = root spawn sales_report(quiet=True);
    return FarmView(name=f.name, owner=f.owner, phone=farm_phone(f), batches=views, egg_sets=sets,
                    feed_kg=r1(fr.stock_kg), feed_days=r1(fr.days_left),
                    alerts=ew.alerts + fr.alerts, income=r0(sr.total_income),
                    birds_alive=sum([v.alive for v in views]),
                    feed_need_per_day=r0(fr.stock_kg / fr.days_left if fr.days_left > 0 else 0.0),
                    writer_model=writer_status,
                    records=farm_records(f, 200),
                    start_total=sum([v.start_count for v in views]),
                    dead_total=sum([v.dead for v in views]),
                    sold_total=sum([v.sold for v in views]),
                    count_ok=all([v.start_count - v.dead - v.sold == v.alive for v in views]),
                    eggs_collected=sum([v.eggs_collected for v in views]),
                    eggs_sold=sum([v.eggs_sold for v in views]),
                    feed_eaten_kg=r1(sum([v.feed_eaten_kg for v in views])),
                    feed_eaten_cost=r0(sr.feed_eaten_cost),
                    balance=r0(sum([v.balance for v in views])),
                    bird_income=r0(sum([v.bird_income for v in views])),
                    egg_income=r0(sum([v.egg_income for v in views])),
                    other_costs=r0(sum([v.other_cost for v in views])),
                    cost_lines=cost_lines(f, sr.feed_eaten_cost),
                    expenses=expense_views(f),
                    expense_kinds=EXPENSE_KINDS,
                    feed_price=r1(price),
                    houses=[h.name for h in [f -->(?:House)]],
                    tasks=(root spawn today_tasks(quiet=True)).tasks,
                    health_rows=[health_row(b) for b in farm_batches(f)],
                    vet_name=farm_vet(f).name, vet_phone=farm_vet(f).phone,
                    egg_set_views=[egg_set_view(e) for e in [f -->(?:EggSet)]],
                    plans=[batch_plan(b) for b in farm_batches(f)],
                    feed_rows=[feed_row(b) for b in farm_batches(f)],
                    deliveries=[DeliveryView(date=d.date, kg=d.kg, cost=d.cost_ksh) for d in [f -->(?:FeedStore) -->(?:FeedDelivery)]],
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
        report farm_view([here -->(?:Farm)][0]);
    }
}

# ---------- Demo: move the farm forward one day ----------
walker:pub next_day {
    has reports: list[FarmView] = [];

    can tick with Root entry {
        here spawn build_demo_farm();
        here spawn new_day();
        report farm_view([here -->(?:Farm)][0]);
    }
}

# ---------- Vet has visited and cleared a RED batch ----------
walker:pub clear_batch {
    has batch_id: str;
    has reports: list[FarmView] = [];

    can clear with Root entry {
        here spawn vet_clear(batch_id=self.batch_id, date=today(), vet_note="Cleared by vet (from the web page)");
        report farm_view([here -->(?:Farm)][0]);
    }
}

# ---------- Clear every record and start the farm again (same farm, houses, batches and buyers) ----------
walker:pub start_fresh {
    has reports: list[FarmView] = [];

    can reset with Root entry {
        # delete the farm and everything under it (houses, batches, records, sales, feed store...)
        for old in [here -->(?:Farm)] {
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
        here spawn build_demo_farm();
        print("All records cleared. The farm starts again with no reports, sales or health checks.");
        report farm_view([here -->(?:Farm)][0]);
    }
}


# =====================================================================
# AGENT WORKSPACES - each agent's own page calls these directly
# =====================================================================

# ---------- helpers that build the data for each page ----------
def health_row(b: Batch) -> HealthRow {
    checks = [b -->(?:HealthCheck)];
    last = "";
    if len(checks) > 0 {
        c = checks[0];
        for x in checks {
            if x.date >= c.date { c = x; }
        }
        last = f"{c.date}: {c.level} - {c.summary.split(' | ')[0]}";
    }
    deaths = sum([r.deaths for r in [b -->(?:Record)]]);
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
    recs = [r for r in records_of(b) if r.feed_kg > 0];
    last = -1.0;
    status = "No report yet";
    if len(recs) > 0 {
        last = recs[-1].feed_kg;
        status = "OK";
        if last > 1.25 * need { status = "Too much"; }
        elif last < 0.75 * need { status = "Too little"; }
    }
    return FeedRow(batch_id=b.batch_id, label=batch_label(b), need_kg=r1(need), last_used=r1(last),
                   eaten_kg=r1(sum([r.feed_kg for r in [b -->(?:Record)]])), status=status);
}

def sale_views(f: Farm) -> list[SaleView] {
    out: list[SaleView] = [];
    for b in farm_batches(f) {
        for x in [b -->(?:Sale)] {
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
    return [root -->(?:Farm)][0];
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
        msg = msg + f". Birds alive now: {b.alive}. Feed left in store: {w.feed_left if w.feed_left >= 0 else [f -->(?:FeedStore)][0].stock_kg:.0f} kg.";
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
            cost = self.price_each * self.count;
            nb ++> Expense(date=today(), kind="Chicks", amount=cost, note=f"{self.count} x KSh {self.price_each:,.0f}");
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
        sets = [e for e in [f -->(?:EggSet)] if e.set_id == self.set_id];
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
        if self.cost_ksh > 0 { msg = msg + f" for KSh {self.cost_ksh:,.0f} (KSh {self.cost_ksh / kg:.0f} per kg)"; }
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
        for buyer in [f -->(?:Buyer)] {
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
        amt = sum([e.amount for e in [f -->(?:House) -->(?:Batch) -->(?:Expense)] if e.kind == k]);
        if amt > 0 { out.append(CostLine(kind=k, amount=r0(amt))); }
    }
    return out;
}

def expense_views(f: Farm) -> list[ExpenseView] {
    out: list[ExpenseView] = [];
    for b in farm_batches(f) {
        for e in [b -->(?:Expense)] {
            out.append(ExpenseView(date=e.date, batch_id=b.batch_id, kind=e.kind, amount=e.amount, note=e.note));
        }
    }
    pairs = sorted([(out[i].date, i) for i in range(len(out))], reverse=True);
    return [out[p[1]] for p in pairs];
}

def buyer_views(f: Farm) -> list[BuyerView] {
    all_sales = [x for b in farm_batches(f) for x in [b -->(?:Sale)]];
    out: list[BuyerView] = [];
    for x in [f -->(?:Buyer)] {
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
        if len(found) == 0 or self.amount <= 0 {
            report ActionResult(ok=False, message="Choose a batch and enter an amount above 0.", farm=farm_view(f));
            disengage;
        }
        kind = self.kind if self.kind in EXPENSE_KINDS else "Other";
        b = found[0];
        b ++> Expense(date=today(), kind=kind, amount=self.amount, note=self.note);
        m = batch_money(b, feed_price_per_kg(f));
        report ActionResult(ok=True, farm=farm_view(f),
            message=f"Cost saved: {kind} KSh {self.amount:,.0f} for {b.batch_id}. {b.batch_id} now: sales KSh {m.income:,.0f} - feed KSh {m.feed_cost:,.0f} - other costs KSh {m.other_cost:,.0f} = profit KSh {m.balance:,.0f}.");
    }
}

