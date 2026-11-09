"""Disease detector page: Diagnose (camera + symptoms), Monitor (every batch, every day), Research (disease library)."""

import from .ui { AgentHead, Tab, Pill, BigText, Notice, Level, Stat, join_words }
import from .AgentChat { AgentChat }
import from .AgentsPanel { agent_info }
import from .Camera { Camera }
import from .Charts { BarChart }
import from .Bookings { VetVisitsCard }

sv import from ..farm { FarmView, Diagnosis, DiseaseInfo, diagnose, research, clear_batch }

glob SYMPTOMS: list[str] = ["Coughing / sneezing", "Twisted neck / paralysis", "Green droppings", "White watery droppings",
                            "Bloody droppings", "Swollen head or comb", "Not eating", "Many sudden deaths",
                            "Drop in eggs", "Weak, sleepy chicks", "Gasping / noisy breathing", "Wounds or scabs"];

glob DISEASES: list[str] = ["Newcastle disease", "Gumboro", "Coccidiosis", "Fowl pox", "Fowl typhoid",
                            "Bird flu (avian influenza)", "CRD / breathing disease", "Worms"];

glob LEVEL_TEXT = {"RED": "RED - URGENT: call the vet today. Do not sell or move birds.",
                   "AMBER": "AMBER - watch closely. Recheck in 24 hours; call the vet if it gets worse.",
                   "GREEN": "GREEN - looks OK. Keep watching and keep the house clean."};
glob LEVEL_BG = {"RED": "rgba(248,113,113,0.12)", "AMBER": "rgba(251,191,36,0.12)", "GREEN": "rgba(74,222,128,0.12)"};
glob LEVEL_FG = {"RED": "#f87171", "AMBER": "#fbbf24", "GREEN": "#4ade80"};

def:pub HealthPage(lang: str, farm: FarmView, onFarm: Callable[[FarmView], None], lines: list[dict], busy: bool,
                   onSend: Callable[[str, str, str], None]) -> JsxElement {
    has tab: str = "Diagnose";
    has batch_id: str = "";
    has picked: list[str] = [];
    has description: str = "";
    has photo: str = "";
    has checking: bool = False;
    has result: Diagnosis | None = None;
    has question: str = "";
    has info: DiseaseInfo | None = None;
    has looking: bool = False;
    has copied: bool = False;
    has problem: str = "";

    a = agent_info("health");
    chosen = batch_id if batch_id != "" else (farm.batches[0].batch_id if len(farm.batches) > 0 else "");
    red = [h for h in farm.health_rows if h.level == "RED"];
    with_warnings = [h for h in farm.health_rows if len(h.warnings) > 0];
    health_records = [r for r in farm.records if r.kind == "Health"];

    def toggle(s: str) {
        if s in picked { picked = [x for x in picked if x != s]; }
        else { picked = picked + [s]; }
    }

    async def run_check() {
        text = join_words(picked);
        if description.strip() != "" { text = (text + ". " if text != "" else "") + description.strip(); }
        if text == "" and photo == "" {
            problem = "Take a photo or describe what you see first.";
            return;
        }
        problem = "";
        checking = True;
        result = None;
        copied = False;
        res = root spawn diagnose(batch_id=chosen, description=text, photo=photo, language=lang);
        d = res.reports[0];
        result = d;
        if d.farm { onFarm(d.farm); }
        checking = False;
    }
    def check_click(e: MouseEvent) { run_check(); }

    async def ask(q: str) {
        if q.strip() == "" { return; }
        question = q;
        looking = True;
        info = None;
        res = root spawn research(question=q, language=lang);
        info = res.reports[0];
        looking = False;
    }
    def ask_click(e: MouseEvent) { ask(question); }
    def ask_disease(name: str) { ask("Tell me about " + name + " in chickens"); }

    async def vet_clear(bid: str) {
        res = root spawn clear_batch(batch_id=bid);
        if res.reports and len(res.reports) > 0 { onFarm(res.reports[0]); }
        result = None;
    }

    def copy_vet(e: MouseEvent) {
        board: any = navigator.clipboard;
        board.writeText((result as Diagnosis).vet_message);
        copied = True;
    }
    def pick_tab(t: str) { tab = t; }
    def pick_batch(v: str) { batch_id = v; result = None; }

    return
        <div>
            <AgentHead icon={a["icon"]} name={a["name"]} job={a["job"]} />
            {if len(red) > 0 {
                <div className="km-notice bad" style={{"marginTop": "0", "marginBottom": "0.8rem"}}>
                    {"🚨 RED alert on " + join_words([h.batch_id for h in red]) + ": the vet must clear these batches before any sale."}
                </div>
            }}
            <div className="km-work">
                <div>
                    <div className="km-tabs">
                        <Tab label="Diagnose" current={tab} onPick={pick_tab} />
                        <Tab label="Monitor" current={tab} onPick={pick_tab} />
                        <Tab label="Research" current={tab} onPick={pick_tab} />
                        <Tab label="Vet visits" current={tab} onPick={pick_tab} />
                    </div>

                    {if tab == "Diagnose" {
                        <div>
                            <div className="km-card">
                                <h3>1. Which batch?</h3>
                                {for b in farm.batches {
                                    <Pill key={b.batch_id} label={b.label} value={b.batch_id} on={b.batch_id == chosen} onPick={pick_batch} />
                                }}
                                <h3 style={{"marginTop": "0.8rem"}}>2. Photo</h3>
                                <Camera photo={photo} onPhoto={lambda(p: str) { photo = p; }} />
                                <h3 style={{"marginTop": "0.8rem"}}>3. What do you see? (tap all that apply)</h3>
                                {for s in SYMPTOMS {
                                    <Pill key={s} label={s} on={s in picked} onPick={toggle} />
                                }}
                                <div style={{"marginTop": "0.5rem"}}>
                                    <BigText label="Describe in your own words (any language)" value={description}
                                             onValue={lambda(v: str) { description = v; }} hint="e.g. Kuku 5 zimekufa leo, zingine zinakohoa" />
                                </div>
                                <div style={{"marginTop": "0.7rem", "display": "flex", "gap": "0.6rem", "alignItems": "center", "flexWrap": "wrap"}}>
                                    <button className="km-btn primary" onClick={check_click} disabled={checking}>
                                        {"Checking the birds..." if checking else "🩺 Check now"}
                                    </button>
                                    <span className="km-small">KukuMind also reads this batch's records (deaths, feed, eggs, age, vaccines due).</span>
                                </div>
                                <Notice text={problem} ok={False} />
                            </div>

                            {if result is not None and not (result as Diagnosis).ok {
                                <Notice text={(result as Diagnosis).reply} ok={False} />
                            }}
                            {if result is not None and (result as Diagnosis).ok {
                                <div className="km-card" style={{"border": "2px solid " + LEVEL_FG.get((result as Diagnosis).level, "#4ade80")}}>
                                    <div style={{"background": LEVEL_BG.get((result as Diagnosis).level, "#16294a"), "color": LEVEL_FG.get((result as Diagnosis).level, "#4ade80"),
                                                 "borderRadius": "10px", "padding": "0.7rem 0.9rem", "fontWeight": "800", "fontSize": "1.05rem"}}>
                                        {(result as Diagnosis).batch_id + ": " + LEVEL_TEXT.get((result as Diagnosis).level, (result as Diagnosis).level)}
                                    </div>
                                    <p style={{"lineHeight": "1.5", "whiteSpace": "pre-wrap"}}>{(result as Diagnosis).reply}</p>
                                    <div className="km-grid2">
                                        <div>
                                            <strong style={{"fontSize": "0.88rem"}}>✅ Do now</strong>
                                            <ul className="km-list">{for x in (result as Diagnosis).do_now { <li key={x}>{x}</li> }}</ul>
                                        </div>
                                        <div>
                                            <strong style={{"fontSize": "0.88rem"}}>🔎 Could be (for the vet - not a diagnosis)</strong>
                                            <ul className="km-list">{for x in (result as Diagnosis).possible_problems { <li key={x}>{x}</li> }}</ul>
                                        </div>
                                    </div>
                                    {if len((result as Diagnosis).warnings) > 0 {
                                        <div style={{"marginTop": "0.6rem"}}>
                                            <strong style={{"fontSize": "0.88rem"}}>📈 What the records show</strong>
                                            <ul className="km-list">{for x in (result as Diagnosis).warnings { <li key={x}>{x}</li> }}</ul>
                                        </div>
                                    }}
                                    {if (result as Diagnosis).had_photo {
                                        <div className="km-small" style={{"marginTop": "0.4rem"}}>📷 The photo was checked together with the description.</div>
                                    }}
                                    {if (result as Diagnosis).vet_message != "" {
                                        <div style={{"marginTop": "0.8rem", "padding": "0.7rem", "border": "1px dashed #f87171", "borderRadius": "10px", "background": "rgba(248,113,113,0.06)"}}>
                                            <strong style={{"color": "#fca5a5"}}>{"📋 Message for " + farm.vet_name + " (" + farm.vet_phone + ")"}</strong>
                                            <div style={{"fontSize": "0.82rem", "whiteSpace": "pre-wrap", "margin": "0.4rem 0", "lineHeight": "1.4"}}>{(result as Diagnosis).vet_message}</div>
                                            <div style={{"display": "flex", "gap": "0.4rem", "flexWrap": "wrap"}}>
                                                <a href={(result as Diagnosis).vet_link} target="_blank" rel="noopener noreferrer" className="km-btn primary"
                                                   style={{"background": "#25d366", "borderColor": "#25d366", "textDecoration": "none"}}>Send to vet on WhatsApp</a>
                                                <button className="km-btn" onClick={copy_vet}>{"Copied ✔" if copied else "Copy message"}</button>
                                            </div>
                                        </div>
                                    }}
                                    <div className="km-small" style={{"marginTop": "0.6rem"}}>KukuMind never names medicines or doses. Only a vet can diagnose and treat.</div>
                                </div>
                            }}
                        </div>
                    }}

                    {if tab == "Vet visits" {
                        <VetVisitsCard farm={farm} onFarm={onFarm} />
                    }}

                    {if tab == "Monitor" {
                        <div>
                            <div className="km-grid3" style={{"marginBottom": "1rem"}}>
                                <Stat label="Batches watched" value={str(len(farm.health_rows))} note="checked after every report" />
                                <Stat label="RED alerts" value={str(len(red))} colour={"#f87171" if len(red) > 0 else "#4ade80"} />
                                <Stat label="Batches with warnings" value={str(len(with_warnings))} colour={"#fbbf24" if len(with_warnings) > 0 else "#4ade80"} />
                            </div>
                            <div className="km-grid2">
                                {for h in farm.health_rows {
                                    <div key={h.batch_id} className="km-card" style={{"borderLeft": "6px solid " + LEVEL_FG.get(h.level, "#4ade80")}}>
                                        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center"}}>
                                            <strong>{h.label}</strong>
                                            <Level level={h.level} />
                                        </div>
                                        <div className="km-muted">{"Deaths so far: " + str(h.mortality) + "% · health checks: " + str(h.checks)}</div>
                                        {if h.last_check != "" { <div className="km-small" style={{"marginTop": "0.2rem"}}>{"Last check " + h.last_check}</div> }}
                                        {if len(h.warnings) == 0 {
                                            <div style={{"fontSize": "0.82rem", "color": "#4ade80", "marginTop": "0.4rem"}}>✓ No warning signs in the records</div>
                                        } else {
                                            <ul className="km-list" style={{"color": "#fca5a5"}}>{for w in h.warnings { <li key={w}>{w}</li> }}</ul>
                                        }}
                                        {if h.level == "RED" {
                                            <button className="km-btn small danger" style={{"marginTop": "0.5rem"}} onClick={lambda(e: MouseEvent) { vet_clear(h.batch_id); }}>
                                                Vet has visited - clear batch
                                            </button>
                                        }}
                                    </div>
                                }}
                            </div>
                            <div className="km-grid2">
                                {for b in farm.batches {
                                    <BarChart key={b.batch_id} title={"Deaths per day - " + b.label} labels={b.days}
                                              values={[float(x) for x in b.deaths_series]} color="#f87171" empty_note="No reports yet" />
                                }}
                            </div>
                            <div className="km-card">
                                <h3>How KukuMind watches the flock</h3>
                                <ul className="km-list">
                                    <li>Deaths of 0.3% of a batch in one day = warning; 1% or more = RED, even if the photo looks fine.</li>
                                    <li>Deaths rising 3 reports in a row.</li>
                                    <li>Feed eaten falls by 15% or more (sick birds eat less).</li>
                                    <li>Eggs fall by 10% or more in layers.</li>
                                    <li>A RED batch cannot be sold until the vet clears it.</li>
                                </ul>
                            </div>
                            <div className="km-card">
                                <h3>Health check history</h3>
                                {if len(health_records) == 0 { <div className="km-small">No health checks yet.</div> }}
                                <table className="km-table">
                                    <tbody>
                                        {for (i, r) in enumerate(health_records) {
                                            <tr key={str(i)}><td>{r.date}</td><td><strong>{r.batch_id}</strong></td><td>{r.detail}</td></tr>
                                        }}
                                    </tbody>
                                </table>
                                <div className="km-small" style={{"marginTop": "0.5rem"}}>{"Farm vet: " + farm.vet_name + " · " + farm.vet_phone}</div>
                            </div>
                        </div>
                    }}

                    {if tab == "Research" {
                        <div>
                            <div className="km-card">
                                <h3>Learn about a disease</h3>
                                <div style={{"marginBottom": "0.5rem"}}>
                                    {for d in DISEASES { <Pill key={d} label={d} onPick={ask_disease} /> }}
                                </div>
                                <div style={{"display": "flex", "gap": "0.4rem"}}>
                                    <input className="km-input" value={question} onChange={lambda(e: ChangeEvent) { question = str(e.target.value); }}
                                           placeholder="Ask anything, e.g. Is my B1 at risk of Gumboro?" />
                                    <button className="km-btn primary" onClick={ask_click} disabled={looking}>{"..." if looking else "Ask"}</button>
                                </div>
                            </div>
                            {if looking { <div className="km-card km-muted">Looking it up...</div> }}
                            {if info is not None {
                                <div className="km-card">
                                    <div style={{"display": "flex", "alignItems": "center", "gap": "0.5rem", "flexWrap": "wrap"}}>
                                        <h3 style={{"margin": "0"}}>{(info as DiseaseInfo).topic}</h3>
                                        {if (info as DiseaseInfo).notifiable {
                                            <span className="km-level" style={{"background": "#f87171"}}>Notifiable - report to the county veterinary officer</span>
                                        }}
                                    </div>
                                    <p style={{"lineHeight": "1.5"}}>{(info as DiseaseInfo).summary}</p>
                                    <div className="km-grid2">
                                        <div><strong style={{"fontSize": "0.88rem"}}>👀 Signs</strong>
                                            <ul className="km-list">{for x in (info as DiseaseInfo).signs { <li key={x}>{x}</li> }}</ul></div>
                                        <div><strong style={{"fontSize": "0.88rem"}}>🛡 Prevention</strong>
                                            <ul className="km-list">{for x in (info as DiseaseInfo).prevention { <li key={x}>{x}</li> }}</ul></div>
                                    </div>
                                    <p className="km-muted"><strong>How it spreads: </strong>{(info as DiseaseInfo).spread}</p>
                                    <p className="km-muted"><strong>Call the vet when: </strong>{(info as DiseaseInfo).call_vet_when}</p>
                                    {if (info as DiseaseInfo).farm_note != "" {
                                        <div className="km-notice ok">{"🏡 On your farm: " + (info as DiseaseInfo).farm_note}</div>
                                    }}
                                    <div className="km-small" style={{"marginTop": "0.6rem"}}>General information only - KukuMind never names medicines or doses. Ask your vet about treatment.</div>
                                </div>
                            }}
                        </div>
                    }}
                </div>
                <AgentChat agentKey="health" title="Describe the problem" lines={lines} busy={busy}
                           examples={a["examples"]} onSend={onSend} allowPhoto={True} />
            </div>
        </div>;
}
