"""Flock records agent page: daily report form, register a new flock, flock list with every bird counted, records."""

import from .ui { AgentHead, Tab, Field, Choice, Notice, Stat, Pill }
import from .AgentChat { AgentChat }
import from .AgentsPanel { agent_info }
import from .FarmPanel { BirdCount }
import from .Charts { BarChart, money }
import from .RecordsTable { RecordsTable }

sv import from ..farm { FarmView, BatchView, submit_report, register_flock }

def:pub FlockPage(farm: FarmView, onFarm: Callable[[FarmView], None], lines: list[dict], busy: bool,
                  onSend: Callable[[str, str, str], None]) -> JsxElement {
    has tab: str = "Daily report";
    has batch_id: str = "";
    has deaths: str = "";
    has bags: str = "";
    has kg: str = "";
    has trays: str = "";
    has eggs: str = "";
    has weight: str = "";
    has note: str = "";
    has bird_type: str = "broiler";
    has count: str = "";
    has house: str = "";
    has age: str = "1";
    has chick_price: str = "";
    has msg: str = "";
    has ok: bool = True;
    has saving: bool = False;

    a = agent_info("report");
    chosen = batch_id if batch_id != "" else (farm.batches[0].batch_id if len(farm.batches) > 0 else "");
    house_now = house if house != "" else (farm.houses[0] if len(farm.houses) > 0 else "");
    picked = [b for b in farm.batches if b.batch_id == chosen];
    is_layer = len(picked) > 0 and picked[0].bird_type == "layer";
    feed_total = num_or0(bags) * 50.0 + num_or0(kg);
    egg_total = int(num_or0(trays)) * 30 + int(num_or0(eggs));

    async def save_report() {
        saving = True;
        res = root spawn submit_report(batch_id=chosen, deaths=int(num_or0(deaths)), feed_bags=num_or0(bags), feed_kg=num_or0(kg),
                                       egg_trays=int(num_or0(trays)), eggs=int(num_or0(eggs)), avg_weight_kg=num_or0(weight), note=note);
        r = res.reports[0];
        msg = r.message;
        ok = r.ok;
        if r.farm { onFarm(r.farm); }
        if r.ok { deaths = ""; bags = ""; kg = ""; trays = ""; eggs = ""; weight = ""; note = ""; }
        saving = False;
    }
    async def save_flock() {
        saving = True;
        res = root spawn register_flock(bird_type=bird_type, count=int(num_or0(count)), house=house_now, age_days=int(num_or0(age)),
                                        price_each=num_or0(chick_price));
        r = res.reports[0];
        msg = r.message;
        ok = r.ok;
        if r.farm { onFarm(r.farm); }
        if r.ok { count = ""; }
        saving = False;
    }
    def submit_report_form(e: FormEvent) { e.preventDefault(); save_report(); }
    def submit_flock_form(e: FormEvent) { e.preventDefault(); save_flock(); }
    def pick_tab(t: str) { tab = t; msg = ""; }
    def pick_batch(v: str) { batch_id = v; }

    return
        <div>
            <AgentHead icon={a["icon"]} name={a["name"] + " agent"} job={a["job"]} />
            <div className="km-work">
                <div>
                    <div className="km-tabs">
                        <Tab label="Daily report" current={tab} onPick={pick_tab} />
                        <Tab label="New flock" current={tab} onPick={pick_tab} />
                        <Tab label="Flock list" current={tab} onPick={pick_tab} />
                        <Tab label="Records" current={tab} onPick={pick_tab} />
                    </div>

                    {if tab == "Daily report" {
                        <form className="km-card" onSubmit={submit_report_form}>
                            <h3>Today's report</h3>
                            <div className="km-small" style={{"marginBottom": "0.4rem"}}>Which batch?</div>
                            <div style={{"marginBottom": "0.6rem"}}>
                                {for b in farm.batches {
                                    <Pill key={b.batch_id} label={b.label} value={b.batch_id} on={b.batch_id == chosen} onPick={pick_batch} />
                                }}
                            </div>
                            <div className="km-grid3">
                                <Field label="Deaths today" value={deaths} onValue={lambda(v: str) { deaths = v; }} kind="number" hint="0" />
                                <Field label="Feed used - bags (50 kg)" value={bags} onValue={lambda(v: str) { bags = v; }} kind="number" hint="0" />
                                <Field label="Feed used - extra kg" value={kg} onValue={lambda(v: str) { kg = v; }} kind="number" hint="0" />
                                {if is_layer {
                                    <Field label="Eggs - trays (30)" value={trays} onValue={lambda(v: str) { trays = v; }} kind="number" hint="0" />
                                }}
                                {if is_layer {
                                    <Field label="Eggs - loose" value={eggs} onValue={lambda(v: str) { eggs = v; }} kind="number" hint="0" />
                                }}
                                <Field label="Average weight (kg)" value={weight} onValue={lambda(v: str) { weight = v; }} kind="number" hint="optional" />
                            </div>
                            <div style={{"marginTop": "0.6rem"}}>
                                <Field label="Note (anything unusual?)" value={note} onValue={lambda(v: str) { note = v; }} hint="e.g. 2 chicks look weak" />
                            </div>
                            <div className="km-muted" style={{"margin": "0.6rem 0"}}>
                                {"Will save: " + str(int(num_or0(deaths))) + " deaths, " + str(int(feed_total)) + " kg feed" + (", " + str(egg_total) + " eggs" if is_layer else "")
                                 + (" · alive after: " + str(picked[0].alive - int(num_or0(deaths))) if len(picked) > 0 else "")}
                            </div>
                            <button type="submit" className="km-btn primary" disabled={saving}>{"Saving..." if saving else "Save report"}</button>
                            <Notice text={msg} ok={ok} />
                        </form>
                    }}

                    {if tab == "New flock" {
                        <form className="km-card" onSubmit={submit_flock_form}>
                            <h3>Register new birds</h3>
                            <div className="km-muted" style={{"marginBottom": "0.7rem"}}>Bought chicks or birds become a new batch with the next free name.</div>
                            <div className="km-grid2">
                                <Choice label="Type of birds" value={bird_type} onValue={lambda(v: str) { bird_type = v; }}
                                        options={[["broiler", "Broiler (kuku wa nyama)"], ["layer", "Layer (kuku wa mayai)"], ["kienyeji", "Kienyeji / improved kienyeji"]]} />
                                <Field label="How many?" value={count} onValue={lambda(v: str) { count = v; }} kind="number" hint="e.g. 500" />
                                <Choice label="House" value={house_now} onValue={lambda(v: str) { house = v; }} options={[[h, h] for h in farm.houses]} />
                                <Field label="Age in days (day-old = 1)" value={age} onValue={lambda(v: str) { age = v; }} kind="number" />
                                <Field label="Price per chick (KSh) - for profit" value={chick_price} onValue={lambda(v: str) { chick_price = v; }} kind="number" hint="e.g. 110" />
                            </div>
                            {if num_or0(count) > 0 and num_or0(chick_price) > 0 {
                                <div className="km-muted" style={{"marginTop": "0.5rem"}}>
                                    {"Chick cost: " + str(int(num_or0(count))) + " x KSh " + str(int(num_or0(chick_price))) + " = KSh " + money(num_or0(count) * num_or0(chick_price)) + " (saved as a cost of the new batch)"}
                                </div>
                            }}
                            <div style={{"marginTop": "0.8rem"}}>
                                <button type="submit" className="km-btn primary" disabled={saving}>{"Saving..." if saving else "Register flock"}</button>
                            </div>
                            <Notice text={msg} ok={ok} />
                        </form>
                    }}

                    {if tab == "Flock list" {
                        <div>
                            <div className="km-card">
                                <h3>Every bird counted</h3>
                                <BirdCount start={farm.start_total} dead={farm.dead_total} sold={farm.sold_total} alive={farm.birds_alive} ok={farm.count_ok} />
                                <div style={{"overflowX": "auto"}}>
                                    <table className="km-table">
                                        <thead><tr><th>Batch</th><th>House</th><th>Started</th><th>Dead</th><th>Sold</th><th>Alive</th><th>Deaths %</th><th>Eggs</th></tr></thead>
                                        <tbody>
                                            {for b in farm.batches {
                                                <tr key={b.batch_id}>
                                                    <td><strong>{b.label}</strong></td><td>{b.house}</td><td>{money(float(b.start_count))}</td>
                                                    <td style={{"color": "#f87171"}}>{str(b.dead)}</td><td style={{"color": "#fbbf24"}}>{str(b.sold)}</td>
                                                    <td style={{"color": "#4ade80", "fontWeight": "700"}}>{money(float(b.alive))}</td>
                                                    <td>{str(b.mortality) + "%"}</td><td>{money(float(b.eggs_collected)) if b.eggs_collected > 0 else "-"}</td>
                                                </tr>
                                            }}
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                            <div className="km-grid2">
                                {for b in farm.batches {
                                    <BarChart key={b.batch_id} title={"Deaths per day - " + b.label} labels={b.days}
                                              values={[float(x) for x in b.deaths_series]} color="#f87171" empty_note="No reports yet" />
                                }}
                            </div>
                        </div>
                    }}

                    {if tab == "Records" {
                        <RecordsTable records={farm.records} />
                    }}
                </div>
                <AgentChat agentKey="report" title="Or send the report as a message" lines={lines} busy={busy}
                           examples={a["examples"]} onSend={onSend} />
            </div>
        </div>;
}

def num_or0(s: str) -> float {
    v = parseFloat(s);
    if v != v { return 0.0; }
    return v;
}
