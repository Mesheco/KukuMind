"""Hatchery agent page: every egg set day by day, candling and hatch results, and the hatch history."""

import from .ui { AgentHead, Tab, Field, Choice, Notice, Stat }
import from .AgentChat { AgentChat }
import from .AgentsPanel { agent_info }

sv import from ..farm { FarmView, EggSetView, hatchery_action, next_day }

def:pub Milestone(day: int, label: str, now: int) -> JsxElement {
    passed = now >= day;
    return
        <div style={{"position": "absolute", "left": str(int(day * 100 / 21)) + "%", "top": "14px", "transform": "translateX(-50%)",
                     "fontSize": "0.65rem", "color": "#f2b84b" if passed else "#6f84a3", "whiteSpace": "nowrap", "textAlign": "center"}}>
            {"|"}<br/>{label}
        </div>;
}

def:pub EggSetCard(e: EggSetView, houses: list[str], onAction: Callable[[str, str, int, str], None]) -> JsxElement {
    has fertile: str = "";
    has hatched: str = "";
    has house: str = "";
    pct = int(e.day * 100 / 21) if e.day < 21 else 100;
    house_now = house if house != "" else (houses[-1] if len(houses) > 0 else "");
    return
        <div className="km-card">
            <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center"}}>
                <strong>{"🥚 " + e.set_id + " · " + str(e.eggs_set) + " " + e.bird_type + " eggs"}</strong>
                <span className="km-chip">{"Day " + str(e.day) + " of 21"}</span>
            </div>
            <div style={{"position": "relative", "margin": "0.7rem 0 2.2rem"}}>
                <div className="km-progress"><div style={{"width": str(pct) + "%"}}></div></div>
                <Milestone day={7} label="Candle 1" now={e.day} />
                <Milestone day={14} label="Candle 2" now={e.day} />
                <Milestone day={18} label="Lockdown" now={e.day} />
                <Milestone day={21} label="Hatch" now={e.day} />
            </div>
            <div className="km-notice ok" style={{"marginTop": "0"}}>{"Today: " + e.task}</div>
            <div className="km-small" style={{"marginTop": "0.4rem"}}>
                {"Fertile at candling: " + (str(e.fertile) + " of " + str(e.eggs_set) if e.fertile >= 0 else "not candled yet")}
            </div>
            <div className="km-grid3" style={{"marginTop": "0.6rem", "alignItems": "end"}}>
                <Field label="Fertile eggs (candling)" value={fertile} onValue={lambda(v: str) { fertile = v; }} kind="number" />
                <button className="km-btn small" onClick={lambda(ev: MouseEvent) { onAction("candle", e.set_id, int(parseFloat(fertile or "0")), ""); fertile = ""; }}>Save candling</button>
                <span></span>
                <Field label="Chicks hatched" value={hatched} onValue={lambda(v: str) { hatched = v; }} kind="number" />
                <Choice label="Move chicks to" value={house_now} onValue={lambda(v: str) { house = v; }} options={[[h, h] for h in houses]} />
                <button className="km-btn small primary" onClick={lambda(ev: MouseEvent) { onAction("hatch", e.set_id, int(parseFloat(hatched or "0")), house_now); hatched = ""; }}>Save hatch</button>
            </div>
        </div>;
}

def:pub HatcheryPage(farm: FarmView, onFarm: Callable[[FarmView], None], lines: list[dict], busy: bool,
                     onSend: Callable[[str, str, str], None]) -> JsxElement {
    has tab: str = "Incubator";
    has bird_type: str = "kienyeji";
    has eggs: str = "";
    has msg: str = "";
    has ok: bool = True;

    a = agent_info("hatchery");
    running = [e for e in farm.egg_set_views if not e.done];
    finished = [e for e in farm.egg_set_views if e.done];
    total_set = sum([e.eggs_set for e in finished]);
    total_hatched = sum([e.hatched for e in finished if e.hatched > 0]);

    async def act(action: str, set_id: str, n: int, house: str) {
        res = root spawn hatchery_action(action=action, set_id=set_id, fertile=n if action == "candle" else 0,
                                         hatched=n if action == "hatch" else 0, house=house);
        r = res.reports[0];
        msg = r.message;
        ok = r.ok;
        if r.farm { onFarm(r.farm); }
    }
    def on_action(action: str, set_id: str, n: int, house: str) { act(action, set_id, n, house); }

    async def set_now() {
        res = root spawn hatchery_action(action="set", bird_type=bird_type, eggs=int(parseFloat(eggs or "0")));
        r = res.reports[0];
        msg = r.message;
        ok = r.ok;
        if r.farm { onFarm(r.farm); }
        if r.ok { eggs = ""; tab = "Incubator"; }
    }
    def submit_set(e: FormEvent) { e.preventDefault(); set_now(); }

    async def tomorrow(e: MouseEvent) {
        res = root spawn next_day();
        if res.reports and len(res.reports) > 0 { onFarm(res.reports[0]); }
        msg = "A new day: every egg set and batch is one day older.";
        ok = True;
    }
    def pick_tab(t: str) { tab = t; }

    return
        <div>
            <AgentHead icon={a["icon"]} name={a["name"] + " agent"} job={a["job"]} />
            <div className="km-work">
                <div>
                    <div className="km-tabs">
                        <Tab label="Incubator" current={tab} onPick={pick_tab} />
                        <Tab label="Set eggs" current={tab} onPick={pick_tab} />
                        <Tab label="Hatch history" current={tab} onPick={pick_tab} />
                    </div>
                    <Notice text={msg} ok={ok} />
                    <div style={{"height": "0.6rem"}}></div>

                    {if tab == "Incubator" {
                        <div>
                            {if len(running) == 0 {
                                <div className="km-card">
                                    <h3>The incubator is empty</h3>
                                    <div className="km-muted">Open "Set eggs" to start, or send "Nimeweka mayai 200 ya kienyeji kwa incubator".</div>
                                </div>
                            }}
                            {for e in running {
                                <EggSetCard key={e.set_id} e={e} houses={farm.houses} onAction={on_action} />
                            }}
                            <div className="km-card">
                                <h3>The 21-day plan</h3>
                                <ul className="km-list">
                                    <li><strong>Day 0-17:</strong> 37.5 - 37.8 C, humidity 50-55%, turn eggs at least 3 times a day.</li>
                                    <li><strong>Day 7 and 14:</strong> candle - remove clear and dead eggs.</li>
                                    <li><strong>Day 18:</strong> lockdown - stop turning, humidity 65-70%, keep the incubator closed.</li>
                                    <li><strong>Day 21:</strong> hatch - let chicks dry, then move them to a brooder at 32-35 C.</li>
                                </ul>
                                <button className="km-btn small" style={{"marginTop": "0.6rem"}} onClick={tomorrow}>Demo: move to the next day</button>
                            </div>
                        </div>
                    }}

                    {if tab == "Set eggs" {
                        <form className="km-card" onSubmit={submit_set}>
                            <h3>Put eggs in the incubator</h3>
                            <div className="km-grid2">
                                <Choice label="Type of eggs" value={bird_type} onValue={lambda(v: str) { bird_type = v; }}
                                        options={[["kienyeji", "Kienyeji"], ["broiler", "Broiler"], ["layer", "Layer"]]} />
                                <Field label="Number of eggs" value={eggs} onValue={lambda(v: str) { eggs = v; }} kind="number" hint="e.g. 300" />
                            </div>
                            <div className="km-small" style={{"margin": "0.5rem 0"}}>Use clean eggs not older than 7 days, stored pointed end down.</div>
                            <button type="submit" className="km-btn primary">Save egg set</button>
                        </form>
                    }}

                    {if tab == "Hatch history" {
                        <div>
                            <div className="km-grid3" style={{"marginBottom": "1rem"}}>
                                <Stat label="Sets hatched" value={str(len(finished))} />
                                <Stat label="Chicks hatched" value={str(total_hatched)} />
                                <Stat label="Hatch rate" value={(str(int(total_hatched * 100.0 / total_set + 0.5)) if total_set > 0 else "-") + "%"} note="chicks / eggs set · good is 80% or more" />
                            </div>
                            <div className="km-card">
                                <table className="km-table">
                                    <thead><tr><th>Set</th><th>Eggs</th><th>Fertile</th><th>Hatched</th><th>Hatch rate</th></tr></thead>
                                    <tbody>
                                        {for e in finished {
                                            <tr key={e.set_id}><td>{e.set_id + " " + e.bird_type}</td><td>{str(e.eggs_set)}</td>
                                                <td>{str(e.fertile) if e.fertile >= 0 else "-"}</td><td>{str(e.hatched)}</td><td>{str(e.hatch_rate) + "%"}</td></tr>
                                        }}
                                    </tbody>
                                </table>
                                {if len(finished) == 0 { <div className="km-small" style={{"padding": "0.5rem"}}>No hatches recorded yet.</div> }}
                            </div>
                        </div>
                    }}
                </div>
                <AgentChat agentKey="hatchery" title="Ask the Hatchery agent" lines={lines} busy={busy}
                           examples={a["examples"]} onSend={onSend} />
            </div>
        </div>;
}
