"""Feed & inventory page: feed store and days left, feed per batch (expected vs used), deliveries."""

import from .ui { AgentHead, Tab, Field, Notice, Stat }
import from .AgentChat { AgentChat }
import from .AgentsPanel { agent_info }
import from .Charts { FeedGauge, BarChart, money }

sv import from ..farm { FarmView, add_feed }

glob FEED_STATUS = {"OK": "#4ade80", "Too much": "#f87171", "Too little": "#fbbf24", "No report yet": "#6f84a3"};

def:pub FeedPage(farm: FarmView, onFarm: Callable[[FarmView], None], lines: list[dict], busy: bool,
                 onSend: Callable[[str, str, str], None]) -> JsxElement {
    has tab: str = "Feed store";
    has bags: str = "";
    has kg: str = "";
    has cost: str = "";
    has msg: str = "";
    has ok: bool = True;
    has saving: bool = False;

    a = agent_info("feed");
    week_need = farm.feed_need_per_day * 7.0;
    order_bags = int((week_need - farm.feed_kg) / 50.0 + 0.99) if week_need > farm.feed_kg else 0;
    feed_alerts = [x for x in farm.alerts if "feed" in x.lower() or "eating" in x.lower() or "using" in x.lower()];

    async def save() {
        saving = True;
        res = root spawn add_feed(bags=parseFloat(bags or "0"), kg=parseFloat(kg or "0"), cost_ksh=parseFloat(cost or "0"));
        r = res.reports[0];
        msg = r.message;
        ok = r.ok;
        if r.farm { onFarm(r.farm); }
        if r.ok { bags = ""; kg = ""; cost = ""; }
        saving = False;
    }
    def submit(e: FormEvent) { e.preventDefault(); save(); }
    def pick_tab(t: str) { tab = t; }

    return
        <div>
            <AgentHead icon={a["icon"]} name={a["name"] + " agent"} job={a["job"]} />
            <div className="km-work">
                <div>
                    <div className="km-tabs">
                        <Tab label="Feed store" current={tab} onPick={pick_tab} />
                        <Tab label="Per batch" current={tab} onPick={pick_tab} />
                        <Tab label="Deliveries" current={tab} onPick={pick_tab} />
                    </div>

                    {if tab == "Feed store" {
                        <div>
                            <div className="km-grid4" style={{"marginBottom": "0.8rem"}}>
                                <Stat label="In store" value={money(farm.feed_kg) + " kg"} note={str(int(farm.feed_kg / 50.0)) + " bags"} />
                                <Stat label="Needed per day" value={money(farm.feed_need_per_day) + " kg"} note="whole farm" />
                                <Stat label="Lasts" value={str(farm.feed_days) + " days"} colour={"#f87171" if farm.feed_days < 3 else ("#fbbf24" if farm.feed_days < 7 else "#4ade80")} />
                                <Stat label="Order for 1 week" value={str(order_bags) + " bags"} note="of 50 kg" />
                            </div>
                            <FeedGauge days={farm.feed_days} kg={farm.feed_kg} />
                            {if len(feed_alerts) > 0 {
                                <div className="km-card">
                                    <h3>⚠ Feed alerts</h3>
                                    <ul className="km-list">{for x in feed_alerts { <li key={x}>{x}</li> }}</ul>
                                </div>
                            }}
                            <form className="km-card" onSubmit={submit}>
                                <h3>Feed delivered today</h3>
                                <div className="km-grid3">
                                    <Field label="Bags (50 kg)" value={bags} onValue={lambda(v: str) { bags = v; }} kind="number" hint="0" />
                                    <Field label="Extra kg" value={kg} onValue={lambda(v: str) { kg = v; }} kind="number" hint="0" />
                                    <Field label="Total cost (KSh)" value={cost} onValue={lambda(v: str) { cost = v; }} kind="number" hint="e.g. 35000" />
                                </div>
                                <div style={{"marginTop": "0.7rem"}}>
                                    <button type="submit" className="km-btn primary" disabled={saving}>{"Saving..." if saving else "Add to store"}</button>
                                </div>
                                <Notice text={msg} ok={ok} />
                            </form>
                        </div>
                    }}

                    {if tab == "Per batch" {
                        <div>
                            <div className="km-card">
                                <h3>Expected vs used (last report)</h3>
                                <table className="km-table">
                                    <thead><tr><th>Batch</th><th>Should eat / day</th><th>Last report</th><th>Status</th><th>Eaten so far</th></tr></thead>
                                    <tbody>
                                        {for r in farm.feed_rows {
                                            <tr key={r.batch_id}>
                                                <td><strong>{r.label}</strong></td>
                                                <td>{str(r.need_kg) + " kg"}</td>
                                                <td>{str(r.last_used) + " kg" if r.last_used >= 0 else "-"}</td>
                                                <td style={{"color": FEED_STATUS.get(r.status, "#c8d4e6"), "fontWeight": "700"}}>{r.status}</td>
                                                <td>{money(r.eaten_kg) + " kg"}</td>
                                            </tr>
                                        }}
                                    </tbody>
                                </table>
                                <div className="km-small" style={{"marginTop": "0.5rem"}}>"Too much" (over 125%) can mean spills, wastage or rats. "Too little" (under 75%) can mean sick birds or empty feeders.</div>
                            </div>
                            <BarChart title="Feed each batch should eat per day (kg)" labels={[r.batch_id for r in farm.feed_rows]}
                                      values={[r.need_kg for r in farm.feed_rows]} color="#2dd4bf" />
                            <div className="km-grid2">
                                {for b in farm.batches {
                                    <BarChart key={b.batch_id} title={"Feed used per day - " + b.label} labels={b.days}
                                              values={b.feed_series} color="#5eead4" empty_note="No reports yet" />
                                }}
                            </div>
                        </div>
                    }}

                    {if tab == "Deliveries" {
                        <div className="km-card">
                            <h3>Feed deliveries</h3>
                            <table className="km-table">
                                <thead><tr><th>Date</th><th>Feed</th><th>Cost</th><th>Price per kg</th></tr></thead>
                                <tbody>
                                    {for (i, d) in enumerate(farm.deliveries) {
                                        <tr key={str(i)}><td>{d.date}</td><td>{money(d.kg) + " kg"}</td>
                                            <td>{"KSh " + money(d.cost) if d.cost > 0 else "-"}</td>
                                            <td>{"KSh " + str(int(d.cost / d.kg)) if d.cost > 0 and d.kg > 0 else "-"}</td></tr>
                                    }}
                                </tbody>
                            </table>
                            {if len(farm.deliveries) == 0 { <div className="km-small" style={{"padding": "0.5rem"}}>No deliveries recorded yet. The farm started with 2,500 kg in store.</div> }}
                            <div className="km-muted" style={{"marginTop": "0.6rem"}}>
                                {"Feed price used for profit: KSh " + str(farm.feed_price) + " per kg" + (" (average of deliveries)" if len(farm.deliveries) > 0 else " (default until a delivery with a price is added)")}
                            </div>
                        </div>
                    }}
                </div>
                <AgentChat agentKey="feed" title="Ask the Feed agent" lines={lines} busy={busy}
                           examples={a["examples"]} onSend={onSend} />
            </div>
        </div>;
}
