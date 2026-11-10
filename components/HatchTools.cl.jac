"""Hatchery tools: the incubation calendar, egg selection check, incubator check, hatch analysis
and the AI hatchery teacher. Every number and date comes from the server (Jac code);
the AI only explains the results and answers questions."""

import from .ui { Field, Choice, Pill, Notice, Stat }

sv import from ..farm { FarmView, EggSetView, CalEvent, CalMonth, CheckItem, HatchCheck,
                        egg_selection_check, incubator_check, hatch_analysis, hatchery_ask }

glob KIND_COLOUR = {"set": "#2dd4bf", "candle": "#f2b84b", "prep": "#94a8c4", "lockdown": "#fbbf24",
                    "hatch": "#4ade80", "after": "#a78bfa"};
glob STATUS_ICON = {"good": "✅", "warn": "⚠️", "bad": "⛔"};
glob STATUS_COL = {"good": "#4ade80", "warn": "#fbbf24", "bad": "#f87171"};

# ---------------- results of a check, with the teacher's advice ----------------
def:pub CheckResult(r: HatchCheck) -> JsxElement {
    return
        <div className="km-card" style={{"marginTop": "0.8rem"}}>
            <h3>{r.verdict}</h3>
            {if len(r.numbers) > 0 {
                <ul className="km-list" style={{"marginBottom": "0.6rem"}}>
                    {for (i, n) in enumerate(r.numbers) { <li key={str(i)}>{n}</li> }}
                </ul>
            }}
            {for (i, it) in enumerate(r.items) {
                <div key={str(i)} style={{"display": "flex", "gap": "0.5rem", "padding": "0.45rem 0", "borderTop": "1px solid #22385c",
                                          "fontSize": "0.86rem", "lineHeight": "1.45"}}>
                    <span>{STATUS_ICON.get(it.status, "•")}</span>
                    <span style={{"color": STATUS_COL.get(it.status, "#e6edf7") if it.status != "good" else "#e6edf7"}}>{it.text}</span>
                </div>
            }}
            {if r.advice != "" {
                <div className="km-notice ok">
                    <strong>🎓 Hatchery teacher: </strong>{r.advice}
                </div>
            }}
        </div>;
}

# ---------------- the calendar ----------------
def:pub MonthGrid(m: CalMonth) -> JsxElement {
    return
        <div className="km-card">
            <h3>{m.label}</h3>
            <div style={{"display": "grid", "gridTemplateColumns": "repeat(7, minmax(0, 1fr))", "gap": "3px", "fontSize": "0.7rem"}}>
                {for d in ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"] {
                    <div key={d} style={{"textAlign": "center", "color": "#94a8c4", "fontWeight": "700", "padding": "0.2rem 0"}}>{d}</div>
                }}
                {for (i, c) in enumerate(m.cells) {
                    <div key={str(i)} style={{"minHeight": "3.6rem", "borderRadius": "8px", "padding": "0.2rem",
                                              "background": "transparent" if c.day_num == 0 else ("#14b8a633" if c.today else "#10213a"),
                                              "border": "none" if c.day_num == 0 else ("2px solid #2dd4bf" if c.today else "1px solid #22385c"), "overflow": "hidden"}}>
                        {if c.day_num > 0 { <div style={{"fontWeight": "700", "color": "#e6edf7"}}>{str(c.day_num)}</div> }}
                        {for (j, mk) in enumerate(c.marks) {
                            <div key={str(j)} style={{"background": KIND_COLOUR.get(c.kinds[j], "#2dd4bf"), "color": "#0a1628", "borderRadius": "4px",
                                                      "padding": "0 0.2rem", "marginTop": "2px", "fontWeight": "700", "lineHeight": "1.25",
                                                      "whiteSpace": "nowrap", "overflow": "hidden", "textOverflow": "ellipsis"}} title={mk}>{mk}</div>
                        }}
                    </div>
                }}
            </div>
        </div>;
}

def:pub HatchCalendar(farm: FarmView) -> JsxElement {
    running = [e for e in farm.egg_set_views if not e.done];
    upcoming_sorted = farm.hatch_upcoming;
    return
        <div>
            {if len(running) == 0 {
                <div className="km-card"><h3>No eggs in the incubator</h3><div className="km-muted">Set eggs and KukuMind fills in every date: candling, lockdown and the expected hatch day.</div></div>
            }}
            {if len(running) > 0 {
                <div className="km-grid3" style={{"marginBottom": "0.8rem"}}>
                    {for e in running {
                        <Stat key={e.set_id} label={e.set_id + " expected hatch"} value={e.hatch_short}
                              note={("in " + str(e.days_to_hatch) + " days" if e.days_to_hatch > 0 else ("TODAY" if e.days_to_hatch == 0 else str(-e.days_to_hatch) + " days ago")) + " · set " + e.set_text}
                              colour="#4ade80" />
                    }}
                </div>
            }}
            <div style={{"display": "flex", "flexWrap": "wrap", "gap": "0.4rem", "marginBottom": "0.6rem", "fontSize": "0.75rem"}}>
                {for k in [["set", "Eggs set"], ["candle", "Candling"], ["prep", "Get ready"], ["lockdown", "Lockdown / pipping"], ["hatch", "Hatch"], ["after", "Pull chicks"]] {
                    <span key={k[0]} style={{"background": KIND_COLOUR.get(k[0], "#2dd4bf"), "color": "#0a1628", "borderRadius": "999px", "padding": "0.1rem 0.55rem", "fontWeight": "700"}}>{k[1]}</span>
                }}
            </div>
            {for m in farm.hatch_months { <MonthGrid key={m.label} m={m} /> }}
            {if len(upcoming_sorted) > 0 {
                <div className="km-card">
                    <h3>Coming up</h3>
                    {for (i, ev) in enumerate(upcoming_sorted) {
                        <div key={str(i)} style={{"display": "flex", "gap": "0.7rem", "padding": "0.5rem 0", "borderTop": "1px solid #22385c"}}>
                            <div style={{"minWidth": "5.5rem", "fontWeight": "700", "color": "#f2b84b" if ev.status == "today" else "#e6edf7"}}>
                                {("TODAY" if ev.status == "today" else ev.date[8:] + "/" + ev.date[5:7])}
                                <div className="km-small">{"day " + str(ev.day)}</div>
                            </div>
                            <div>
                                <strong style={{"color": KIND_COLOUR.get(ev.kind, "#2dd4bf")}}>{ev.set_id + " · " + ev.title}</strong>
                                <div className="km-small" style={{"color": "#c8d4e6"}}>{ev.detail}</div>
                            </div>
                        </div>
                    }}
                </div>
            }}
        </div>;
}

# ---------------- egg selection check ----------------
def:pub EggSelectionCard(farm: FarmView, language: str) -> JsxElement {
    has bird_type: str = "kienyeji";
    has weight: str = "";
    has days: str = "";
    has temp: str = "";
    has down: bool = True;
    has cracked: str = "";
    has dirty: str = "";
    has washed: bool = False;
    has hens: str = "";
    has age: str = "";
    has busy: bool = False;
    has result: HatchCheck | None = None;

    async def run() {
        busy = True;
        res = root spawn egg_selection_check(bird_type=bird_type, weight_g=parseFloat(weight or "0"), storage_days=int(parseFloat(days or "0")),
                                             storage_temp=parseFloat(temp or "0"), pointed_down=down, cracked=int(parseFloat(cracked or "0")),
                                             dirty=int(parseFloat(dirty or "0")), washed=washed, hens_per_cock=parseFloat(hens or "0"),
                                             hen_age_weeks=int(parseFloat(age or "0")), language=language);
        result = res.reports[0];
        busy = False;
    }
    def submit(e: FormEvent) { e.preventDefault(); run(); }

    return
        <div>
            <form className="km-card" onSubmit={submit}>
                <h3>Are my eggs good for hatching?</h3>
                <div className="km-muted" style={{"marginBottom": "0.6rem"}}>Fill in what you know about the eggs you plan to set. KukuMind checks each point and the teacher explains what to change.</div>
                <div className="km-grid3">
                    <Choice label="Type of eggs" value={bird_type} onValue={lambda(v: str) { bird_type = v; }}
                            options={[["kienyeji", "Kienyeji"], ["layer", "Layer"], ["broiler", "Broiler"]]} />
                    <Field label="Average egg weight (g)" value={weight} onValue={lambda(v: str) { weight = v; }} kind="number" hint="e.g. 52" />
                    <Field label="Days stored" value={days} onValue={lambda(v: str) { days = v; }} kind="number" hint="e.g. 5" />
                    <Field label="Storage temperature (C)" value={temp} onValue={lambda(v: str) { temp = v; }} kind="number" hint="e.g. 18" />
                    <Field label="Cracked eggs" value={cracked} onValue={lambda(v: str) { cracked = v; }} kind="number" hint="0" />
                    <Field label="Dirty eggs" value={dirty} onValue={lambda(v: str) { dirty = v; }} kind="number" hint="0" />
                    <Field label="Hens per cock" value={hens} onValue={lambda(v: str) { hens = v; }} kind="number" hint="e.g. 10" />
                    <Field label="Hens' age (weeks)" value={age} onValue={lambda(v: str) { age = v; }} kind="number" hint="e.g. 40" />
                </div>
                <div style={{"display": "flex", "gap": "1rem", "flexWrap": "wrap", "marginTop": "0.6rem"}}>
                    <label className="km-small" style={{"display": "flex", "gap": "0.4rem", "alignItems": "center", "cursor": "pointer"}}>
                        <input type="checkbox" checked={down} onChange={lambda(e: ChangeEvent) { down = not down; }} /> Stored pointed end down
                    </label>
                    <label className="km-small" style={{"display": "flex", "gap": "0.4rem", "alignItems": "center", "cursor": "pointer"}}>
                        <input type="checkbox" checked={washed} onChange={lambda(e: ChangeEvent) { washed = not washed; }} /> Eggs were washed
                    </label>
                </div>
                <button type="submit" className="km-btn primary" style={{"marginTop": "0.7rem"}} disabled={busy}>{"Checking..." if busy else "Check my eggs"}</button>
            </form>
            {if result { <CheckResult r={result} /> }}
        </div>;
}

# ---------------- incubator settings check ----------------
def:pub IncubatorCheckCard(farm: FarmView, language: str) -> JsxElement {
    has set_id: str = "";
    has day: str = "";
    has temp: str = "";
    has hum: str = "";
    has turns: str = "";
    has fan: str = "fan";
    has busy: bool = False;
    has result: HatchCheck | None = None;

    running = [e for e in farm.egg_set_views if not e.done];
    chosen = set_id if set_id != "" else (running[0].set_id if len(running) > 0 else "");

    async def run() {
        busy = True;
        res = root spawn incubator_check(set_id=chosen, day=int(parseFloat(day or "0")), temp=parseFloat(temp or "0"),
                                         humidity=parseFloat(hum or "0"), turns=int(parseFloat(turns or "0")), fan=fan == "fan", language=language);
        result = res.reports[0];
        busy = False;
    }
    def submit(e: FormEvent) { e.preventDefault(); run(); }

    return
        <div>
            <form className="km-card" onSubmit={submit}>
                <h3>Check my incubator settings</h3>
                <div className="km-muted" style={{"marginBottom": "0.6rem"}}>Read the thermometer and hygrometer, then enter them. The right settings change at lockdown (day 18).</div>
                <div className="km-grid3">
                    {if len(running) > 0 {
                        <Choice label="Egg set (gives the day)" value={chosen} onValue={lambda(v: str) { set_id = v; }}
                                options={[[e.set_id, e.set_id + " · day " + str(e.day)] for e in running] + [["", "Other - type the day"]]} />
                    }}
                    {if chosen == "" {
                        <Field label="Incubation day" value={day} onValue={lambda(v: str) { day = v; }} kind="number" hint="0-21" />
                    }}
                    <Choice label="Incubator type" value={fan} onValue={lambda(v: str) { fan = v; }}
                            options={[["fan", "With a fan (forced air)"], ["still", "No fan (still air)"]]} />
                    <Field label="Temperature (C)" value={temp} onValue={lambda(v: str) { temp = v; }} kind="number" hint="e.g. 37.5" />
                    <Field label="Humidity (%)" value={hum} onValue={lambda(v: str) { hum = v; }} kind="number" hint="e.g. 52" />
                    <Field label="Turns per day" value={turns} onValue={lambda(v: str) { turns = v; }} kind="number" hint="e.g. 5" />
                </div>
                <button type="submit" className="km-btn primary" style={{"marginTop": "0.7rem"}} disabled={busy}>{"Checking..." if busy else "Check settings"}</button>
            </form>
            {if result { <CheckResult r={result} /> }}
            <div className="km-card">
                <h3>The right settings (chicken eggs)</h3>
                <table className="km-table">
                    <thead><tr><th>Stage</th><th>Fan incubator</th><th>Still-air</th><th>Humidity</th><th>Turning</th></tr></thead>
                    <tbody>
                        <tr><td>Day 0-17</td><td>37.5 C (37.2-37.8)</td><td>38.3-38.9 C at egg top</td><td>50-55%</td><td>3-5 times a day</td></tr>
                        <tr><td>Day 18-21 (lockdown)</td><td>37.0-37.5 C</td><td>37.8-38.6 C</td><td>65-75%</td><td>Stop</td></tr>
                    </tbody>
                </table>
            </div>
        </div>;
}

# ---------------- hatch analysis ----------------
def:pub HatchAnalysisCard(farm: FarmView, onFarm: Callable[[FarmView], None], language: str) -> JsxElement {
    has set_id: str = "";
    has eggs: str = "";
    has clear: str = "";
    has early: str = "";
    has mid: str = "";
    has late: str = "";
    has pipped: str = "";
    has hatched: str = "";
    has culls: str = "";
    has busy: bool = False;
    has result: HatchCheck | None = None;

    sets = farm.egg_set_views;
    chosen = [e for e in sets if e.set_id == set_id];

    def pick(v: str) {
        set_id = v;
        for e in sets {
            if e.set_id == v {
                if e.fertile >= 0 { clear = str(e.eggs_set - e.fertile); }
                if e.hatched >= 0 { hatched = str(e.hatched); }
            }
        }
    }
    async def run() {
        busy = True;
        res = root spawn hatch_analysis(set_id=set_id, eggs_set=int(parseFloat(eggs or "0")), clear=int(parseFloat(clear or "0")),
                                        early_dead=int(parseFloat(early or "0")), mid_dead=int(parseFloat(mid or "0")),
                                        late_dead=int(parseFloat(late or "0")), pipped_dead=int(parseFloat(pipped or "0")),
                                        hatched=int(parseFloat(hatched or "0")), culls=int(parseFloat(culls or "0")), language=language);
        r = res.reports[0];
        result = r;
        if r.farm { onFarm(r.farm); }
        busy = False;
    }
    def submit(e: FormEvent) { e.preventDefault(); run(); }

    return
        <div>
            <form className="km-card" onSubmit={submit}>
                <h3>Why did (or didn't) my eggs hatch?</h3>
                <div className="km-muted" style={{"marginBottom": "0.6rem"}}>
                    After the hatch, open the eggs that did not hatch and count what you see. KukuMind works out fertility and hatch rates, finds the stage where most were lost, and the teacher explains the likely causes.
                </div>
                <div className="km-grid3">
                    <Choice label="Egg set" value={set_id} onValue={pick}
                            options={[["", "Not in KukuMind - type the eggs"]] + [[e.set_id, e.set_id + " · " + str(e.eggs_set) + " eggs"] for e in sets]} />
                    {if len(chosen) == 0 {
                        <Field label="Eggs set" value={eggs} onValue={lambda(v: str) { eggs = v; }} kind="number" />
                    }}
                    <Field label="Clear (infertile)" value={clear} onValue={lambda(v: str) { clear = v; }} kind="number" hint="no development" />
                    <Field label="Early dead (day 1-7)" value={early} onValue={lambda(v: str) { early = v; }} kind="number" hint="blood ring" />
                    <Field label="Mid dead (day 8-17)" value={mid} onValue={lambda(v: str) { mid = v; }} kind="number" />
                    <Field label="Late dead (day 18-21)" value={late} onValue={lambda(v: str) { late = v; }} kind="number" hint="formed, not pipped" />
                    <Field label="Pipped but dead" value={pipped} onValue={lambda(v: str) { pipped = v; }} kind="number" />
                    <Field label="Chicks hatched" value={hatched} onValue={lambda(v: str) { hatched = v; }} kind="number" />
                    <Field label="Weak / deformed chicks" value={culls} onValue={lambda(v: str) { culls = v; }} kind="number" hint="0" />
                </div>
                <button type="submit" className="km-btn primary" style={{"marginTop": "0.7rem"}} disabled={busy}>{"Working it out..." if busy else "Analyse the hatch"}</button>
            </form>
            {if result { <CheckResult r={result} /> }}
        </div>;
}

# ---------------- the AI teacher + the guide ----------------
def:pub LearnCard(farm: FarmView, language: str) -> JsxElement {
    has q: str = "";
    has answer: str = "";
    has asked: str = "";
    has busy: bool = False;
    has open: str = "";

    async def ask(text: str) {
        if text.strip() == "" { return; }
        busy = True;
        asked = text;
        res = root spawn hatchery_ask(question=text, language=language);
        answer = res.reports[0].advice;
        busy = False;
    }
    def submit(e: FormEvent) { e.preventDefault(); ask(q); q = ""; }

    return
        <div>
            <form className="km-card" onSubmit={submit}>
                <h3>🎓 Ask the hatchery teacher</h3>
                <div className="km-muted" style={{"marginBottom": "0.5rem"}}>Anything from choosing eggs to the day the chicks hatch - in English, Kiswahili or Sheng. It also knows your own egg sets and dates.</div>
                <div style={{"marginBottom": "0.5rem"}}>
                    {for ex in ["Which eggs qualify for hatching?", "How do I store eggs before setting?", "What temperature and humidity?",
                                "How do I candle eggs?", "What do I do at lockdown?", "Why do chicks die in the shell?",
                                "Mayai yangu yataanguliwa lini?", "How do I get a better hatch rate?"] {
                        <Pill key={ex} label={ex} value={ex} on={False} onPick={lambda(v: str) { ask(v); }} />
                    }}
                </div>
                <div style={{"display": "flex", "gap": "0.5rem"}}>
                    <input className="km-input" style={{"flex": "1"}} value={q} placeholder="Type your question..." onChange={lambda(e: ChangeEvent) { q = e.target.value; }} />
                    <button type="submit" className="km-btn primary" disabled={busy}>{"..." if busy else "Ask"}</button>
                </div>
                {if busy { <div className="km-small" style={{"marginTop": "0.6rem"}}>The teacher is thinking...</div> }}
                {if answer != "" and not busy {
                    <div className="km-notice ok"><strong>{"Q: " + asked}</strong>{"\n" + answer}</div>
                }}
            </form>
            <div className="km-card">
                <h3>Hatchery guide: from egg to chick</h3>
                {for t in farm.hatch_topics {
                    <div key={t.title} style={{"borderTop": "1px solid #22385c"}}>
                        <button type="button" onClick={lambda(e: MouseEvent) { open = "" if open == t.title else t.title; }}
                                style={{"width": "100%", "textAlign": "left", "background": "none", "border": "none", "color": "#e6edf7",
                                        "fontWeight": "700", "padding": "0.6rem 0", "cursor": "pointer", "fontSize": "0.9rem"}}>
                            {("▾ " if open == t.title else "▸ ") + t.title}
                        </button>
                        {if open == t.title {
                            <ul className="km-list" style={{"marginBottom": "0.6rem"}}>
                                {for (i, p) in enumerate(t.points) { <li key={str(i)}>{p}</li> }}
                            </ul>
                        }}
                    </div>
                }}
            </div>
        </div>;
}
