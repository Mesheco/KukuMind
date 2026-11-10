"""Sales & marketing page: record a sale, market and buyers (with what each bought), profit statement and costs, sales history."""

import from .ui { AgentHead, Tab, Field, Choice, Notice, Stat, Pill }
import from .AgentChat { AgentChat }
import from .AgentsPanel { agent_info }
import from .Charts { BarChart, HBars, money, dec }
import from .FarmPanel { Row }
import from .Bookings { OrdersCard }

sv import from ..farm { FarmView, BuyerMessages, SaleView, sell, buyer_offers, add_expense }

# KSh 450, KSh 13.67 - prices shown to the cent so quantity x price = total
def price_text(p: float) -> str {
    return "KSh " + dec(p, 2);
}

def:pub SalesTable(sales: list[SaleView], limit: int) -> JsxElement {
    rows = sales[:limit] if limit > 0 else sales;
    return
        <div style={{"overflowX": "auto"}}>
            <table className="km-table">
                <thead><tr><th>Date</th><th>Batch</th><th>Buyer</th><th>Sold</th><th>Price</th><th>Total</th></tr></thead>
                <tbody>
                    {for (i, x) in enumerate(rows) {
                        <tr key={str(i)}>
                            <td>{x.date}</td><td>{x.batch_id}</td><td>{x.buyer}</td>
                            <td>{(str(int(x.qty / 30)) + " trays (" + str(x.qty) + " eggs)") if x.item == "eggs" and x.qty % 30 == 0 else str(x.qty) + " " + x.item}</td>
                            <td>{(price_text(x.price_each * 30) + " / tray") if x.item == "eggs" and x.qty % 30 == 0 else price_text(x.price_each)}</td>
                            <td><strong>{"KSh " + money(x.total)}</strong></td>
                        </tr>
                    }}
                </tbody>
            </table>
            {if len(rows) == 0 { <div className="km-small" style={{"padding": "0.5rem"}}>No sales yet.</div> }}
        </div>;
}

def:pub SalesPage(lang: str, farm: FarmView, onFarm: Callable[[FarmView], None], lines: list[dict], busy: bool,
                  onSend: Callable[[str, str, str], None]) -> JsxElement {
    has tab: str = "Sales report";
    has batch_id: str = "";
    has item: str = "birds";
    has qty: str = "";
    has trays: str = "";
    has price: str = "";
    has tray_price: str = "";
    has buyer: str = "";
    has msg: str = "";
    has ok: bool = True;
    has saving: bool = False;
    has offers: BuyerMessages | None = None;
    has writing: bool = False;
    has cost_batch: str = "";
    has cost_kind: str = "Vaccines";
    has cost_amount: str = "";
    has cost_note: str = "";
    has cost_msg: str = "";
    has cost_ok: bool = True;

    a = agent_info("sales");
    ss = farm.sales_summary;
    chosen = batch_id if batch_id != "" else (farm.batches[0].batch_id if len(farm.batches) > 0 else "");
    cost_chosen = cost_batch if cost_batch != "" else chosen;
    picked = [b for b in farm.batches if b.batch_id == chosen];
    n_eggs = int(parseFloat(trays or "0")) * 30 + int(parseFloat(qty or "0"));
    each = parseFloat(price or "0");
    if item == "eggs" { each = parseFloat(tray_price or "0") / 30.0; }
    total = (n_eggs if item == "eggs" else int(parseFloat(qty or "0"))) * each;
    total_costs = sum([c.amount for c in farm.cost_lines]);
    margin = int(farm.balance * 100 / farm.income) if farm.income > 0 else 0;

    async def save() {
        saving = True;
        res = root spawn sell(batch_id=chosen, item=item, qty=int(parseFloat(qty or "0")), trays=int(parseFloat(trays or "0")),
                              price_each=parseFloat(price or "0") if item == "birds" else 0.0,
                              price_per_tray=parseFloat(tray_price or "0"), buyer=buyer);
        r = res.reports[0];
        msg = r.message;
        ok = r.ok;
        if r.farm { onFarm(r.farm); }
        if r.ok { qty = ""; trays = ""; }
        saving = False;
    }
    def submit(e: FormEvent) { e.preventDefault(); save(); }

    async def save_cost() {
        res = root spawn add_expense(batch_id=cost_chosen, kind=cost_kind, amount=parseFloat(cost_amount or "0"), note=cost_note);
        r = res.reports[0];
        cost_msg = r.message;
        cost_ok = r.ok;
        if r.farm { onFarm(r.farm); }
        if r.ok { cost_amount = ""; cost_note = ""; }
    }
    def submit_cost(e: FormEvent) { e.preventDefault(); save_cost(); }

    async def write_offers(e: MouseEvent) {
        writing = True;
        res = root spawn buyer_offers(language=lang);
        offers = res.reports[0];
        writing = False;
    }
    def pick_tab(t: str) { tab = t; }
    def pick_batch(v: str) { batch_id = v; }

    return
        <div>
            <AgentHead icon={a["icon"]} name={a["name"] + " agent"} job={a["job"]} />
            <div className="km-grid4" style={{"marginBottom": "1rem"}}>
                <Stat label="Sales (money in)" value={"KSh " + money(farm.income)} note={"birds " + money(farm.bird_income) + " · eggs " + money(farm.egg_income)} />
                <Stat label="Costs (money out)" value={"KSh " + money(total_costs)} note={"feed " + money(farm.feed_eaten_cost) + " · other " + money(farm.other_costs)} />
                <Stat label="Profit" value={"KSh " + money(farm.balance)} note={str(margin) + "% of sales" if farm.income > 0 else "no sales yet"}
                      colour={"#4ade80" if farm.balance >= 0 else "#f87171"} />
                <Stat label="Sold" value={money(float(farm.sold_total)) + " birds"} note={money(float(farm.eggs_sold)) + " eggs"} />
            </div>
            <div className="km-work">
                <div>
                    <div className="km-tabs">
                        <Tab label="Sales report" current={tab} onPick={pick_tab} />
                        <Tab label="Record a sale" current={tab} onPick={pick_tab} />
                        <Tab label="Orders" current={tab} onPick={pick_tab} />
                        <Tab label="Market & buyers" current={tab} onPick={pick_tab} />
                        <Tab label="Profit & costs" current={tab} onPick={pick_tab} />
                        <Tab label="Sales history" current={tab} onPick={pick_tab} />
                    </div>

                    {if tab == "Sales report" {
                        <div>
                            <div className="km-grid4" style={{"marginBottom": "0.8rem"}}>
                                <Stat label="Total sales" value={"KSh " + money(ss.total)} note={str(ss.n_sales) + (" sale" if ss.n_sales == 1 else " sales") + " so far"} />
                                <Stat label="This month" value={"KSh " + money(ss.month)}
                                      note={"last month KSh " + money(ss.last_month)}
                                      colour={"#4ade80" if ss.month >= ss.last_month and ss.month > 0 else "#ffffff"} />
                                <Stat label="Last 7 days" value={"KSh " + money(ss.week)} note={"today KSh " + money(ss.today)} />
                                <Stat label="Profit (all time)" value={"KSh " + money(farm.balance)} note="sales − feed − other costs"
                                      colour={"#4ade80" if farm.balance >= 0 else "#f87171"} />
                            </div>
                            <div className="km-grid4" style={{"marginBottom": "0.8rem"}}>
                                <Stat label="Birds sold" value={money(float(ss.birds_sold))}
                                      note={("average KSh " + money(ss.avg_bird_price) + " a bird") if ss.birds_sold > 0 else "none yet"} />
                                <Stat label="Eggs sold" value={money(float(ss.eggs_sold // 30)) + " trays" + (" + " + str(ss.eggs_sold % 30) if ss.eggs_sold % 30 > 0 else "")}
                                      note={("average KSh " + money(ss.avg_tray_price) + " a tray") if ss.eggs_sold > 0 else "none yet"} />
                                <Stat label="Eggs in store" value={money(float(farm.eggs_in_store))} note="collected − sold" />
                                <Stat label="Open orders" value={str(ss.open_orders)} note={"worth KSh " + money(ss.open_orders_value)} colour="#f2b84b" />
                            </div>
                            <div style={{"display": "grid", "gridTemplateColumns": "repeat(auto-fit, minmax(min(280px, 100%), 1fr))", "gap": "0 0.8rem"}}>
                                <BarChart title="Sales per day - last 14 days (KSh, by day of the month)" labels={ss.day_labels} values={ss.day_values}
                                          empty_note="No sales yet." />
                                <BarChart title="Sales per month - last 6 months (KSh)" labels={ss.month_labels} values={ss.month_values}
                                          color="#f2b84b" empty_note="No sales yet." />
                                <HBars title="Where the money comes from" labels={["Birds", "Eggs"]} values={[ss.bird_income, ss.egg_income]}
                                       empty_note="No sales yet - record one in 'Record a sale'." />
                                <HBars title="Top buyers" labels={ss.buyer_names} values={ss.buyer_values} color="#f2b84b"
                                       empty_note="No buyers have bought yet." />
                                <BarChart title="Sales per batch (KSh)" labels={ss.batch_labels} values={ss.batch_values} empty_note="No batches yet." />
                                <BarChart title="Profit per batch (KSh)" labels={[b.batch_id for b in farm.batches]}
                                          values={[b.balance for b in farm.batches]} color="#4ade80" signed={True} />
                            </div>
                            <div className="km-small">All numbers are worked out by KukuMind from the saved sales, reports and costs. See "Profit & costs" for the full statement and "Sales history" for every sale.</div>
                        </div>
                    }}

                    {if tab == "Record a sale" {
                        <div>
                            <form className="km-card" onSubmit={submit}>
                                <h3>What did you sell?</h3>
                                <div style={{"marginBottom": "0.5rem"}}>
                                    {for b in farm.batches {
                                        <Pill key={b.batch_id} label={b.label} value={b.batch_id} on={b.batch_id == chosen} onPick={pick_batch} />
                                    }}
                                </div>
                                <div style={{"marginBottom": "0.6rem"}}>
                                    <Pill label="🐔 Birds" value="birds" on={item == "birds"} onPick={lambda(v: str) { item = v; }} />
                                    <Pill label="🥚 Eggs" value="eggs" on={item == "eggs"} onPick={lambda(v: str) { item = v; }} />
                                </div>
                                {if item == "birds" {
                                    <div className="km-grid3">
                                        <Field label="Number of birds" value={qty} onValue={lambda(v: str) { qty = v; }} kind="number" />
                                        <Field label="Price per bird (KSh)" value={price} onValue={lambda(v: str) { price = v; }} kind="number" />
                                        <Field label="Buyer" value={buyer} onValue={lambda(v: str) { buyer = v; }} hint="e.g. Mama Njeri Hotel" />
                                    </div>
                                } else {
                                    <div className="km-grid3">
                                        <Field label="Trays (30 eggs)" value={trays} onValue={lambda(v: str) { trays = v; }} kind="number" />
                                        <Field label="Loose eggs" value={qty} onValue={lambda(v: str) { qty = v; }} kind="number" />
                                        <Field label="Price per tray (KSh)" value={tray_price} onValue={lambda(v: str) { tray_price = v; }} kind="number" />
                                        <Field label="Buyer" value={buyer} onValue={lambda(v: str) { buyer = v; }} hint="e.g. Kamau Eggs Supply" />
                                    </div>
                                }}
                                <div className="km-notice ok" style={{"background": "#16294a", "border": "1px solid #22385c"}}>
                                    {("Total: " + str(int(parseFloat(qty or "0"))) + " birds x KSh " + money(each) + " = KSh " + money(total)
                                      + (" · birds left in " + chosen + ": " + str(picked[0].alive - int(parseFloat(qty or "0"))) if len(picked) > 0 else ""))
                                     if item == "birds" else
                                     ("Total: " + str(n_eggs) + " eggs (" + trays + " trays) x KSh " + money(parseFloat(tray_price or "0")) + " a tray = KSh " + money(total))}
                                </div>
                                {if len(picked) > 0 and picked[0].health == "RED" {
                                    <div className="km-notice bad">{chosen + " has a RED health alert - sales are blocked until the vet clears it."}</div>
                                }}
                                <div style={{"marginTop": "0.7rem"}}>
                                    <button type="submit" className="km-btn primary" disabled={saving}>{"Saving..." if saving else "Save sale"}</button>
                                </div>
                                <Notice text={msg} ok={ok} />
                            </form>
                            <div className="km-card">
                                <h3>Latest sales</h3>
                                <SalesTable sales={farm.sales} limit={5} />
                            </div>
                        </div>
                    }}

                    {if tab == "Orders" {
                        <OrdersCard farm={farm} onFarm={onFarm} />
                    }}

                    {if tab == "Market & buyers" {
                        <div>
                            <div className="km-card">
                                <h3>Ready for market now</h3>
                                {if len(farm.offers) == 0 and len(farm.blocked) == 0 {
                                    <div className="km-muted">Nothing ready yet: broilers from day 35, kienyeji from day 120, eggs once layer reports come in.</div>
                                }}
                                <ul className="km-list">{for o in farm.offers { <li key={o}>{"✅ " + o}</li> }}</ul>
                                <ul className="km-list" style={{"color": "#fca5a5"}}>{for o in farm.blocked { <li key={o}>{"⛔ " + o}</li> }}</ul>
                            </div>
                            <div className="km-card">
                                <h3>Buyers</h3>
                                <div style={{"overflowX": "auto"}}>
                                    <table className="km-table">
                                        <thead><tr><th>Buyer</th><th>Wants</th><th>Phone</th><th>Sales</th><th>Bought (KSh)</th><th>Last sale</th></tr></thead>
                                        <tbody>
                                            {for b in farm.buyers {
                                                <tr key={b.name}><td><strong>{b.name}</strong></td><td>{b.wants}</td><td>{b.phone if b.phone != "" else "-"}</td>
                                                    <td>{str(b.sales)}</td><td><strong>{money(b.bought)}</strong></td><td>{b.last if b.last != "" else "-"}</td></tr>
                                            }}
                                        </tbody>
                                    </table>
                                </div>
                                <div className="km-small" style={{"marginTop": "0.4rem"}}>A new buyer named in a sale is added here automatically.</div>
                                <button className="km-btn primary" style={{"marginTop": "0.7rem"}} onClick={write_offers} disabled={writing}>
                                    {"Writing messages..." if writing else "✍ Write WhatsApp offers to buyers (" + (lang if lang != "Auto" else "English") + ")"}
                                </button>
                            </div>
                            {if offers is not None {
                                <div>
                                    {if (offers as BuyerMessages).note != "" { <Notice text={(offers as BuyerMessages).note} ok={False} /> }}
                                    {for m in (offers as BuyerMessages).messages {
                                        <div key={m.buyer} className="km-card">
                                            <strong>{"To " + m.buyer + (" (" + m.phone + ")" if m.phone != "" else "")}</strong>
                                            <p style={{"whiteSpace": "pre-wrap", "lineHeight": "1.45", "fontSize": "0.9rem"}}>{m.message}</p>
                                            {if m.phone != "" {
                                                <a href={m.link} target="_blank" rel="noopener noreferrer" className="km-btn primary"
                                                   style={{"background": "#25d366", "borderColor": "#25d366", "textDecoration": "none", "display": "inline-block"}}>Send on WhatsApp</a>
                                            }}
                                        </div>
                                    }}
                                </div>
                            }}
                            <div className="km-card">
                                <h3>Sales made</h3>
                                <SalesTable sales={farm.sales} limit={10} />
                            </div>
                        </div>
                    }}

                    {if tab == "Profit & costs" {
                        <div>
                            <div className="km-card">
                                <h3>Profit statement - whole farm</h3>
                                <div style={{"fontWeight": "700", "fontSize": "0.85rem", "marginTop": "0.3rem", "color": "#4ade80"}}>MONEY IN</div>
                                <Row label="Bird sales" value={"KSh " + money(farm.bird_income)} />
                                <Row label="Egg sales" value={"KSh " + money(farm.egg_income)} />
                                <Row label="Total sales" value={"KSh " + money(farm.income)} bold={True} />
                                <div style={{"fontWeight": "700", "fontSize": "0.85rem", "marginTop": "0.7rem", "color": "#f87171"}}>MONEY OUT</div>
                                {for c in farm.cost_lines {
                                    <Row key={c.kind} label={c.kind + (" (" + dec(farm.feed_eaten_kg, 2) + " kg x KSh " + dec(farm.feed_price, 2) + " per kg)" if c.kind == "Feed eaten" else "")}
                                         value={"- KSh " + money(c.amount)} />
                                }}
                                <Row label="Total costs" value={"- KSh " + money(total_costs)} bold={True} />
                                <div style={{"borderTop": "2px solid #e6edf7", "marginTop": "0.5rem", "paddingTop": "0.3rem"}}>
                                    <Row label={"PROFIT" + (" (" + str(margin) + "% of sales)" if farm.income > 0 else "")} value={"KSh " + money(farm.balance)}
                                         bold={True} colour={"#4ade80" if farm.balance >= 0 else "#f87171"} />
                                </div>
                                <div className="km-small" style={{"marginTop": "0.5rem"}}>
                                    Feed is counted when the birds eat it (from the daily reports), not when it is bought. Add chick, vaccine and labour costs below so the profit is complete.
                                </div>
                            </div>

                            <BarChart title="Profit per batch (KSh)" labels={[b.batch_id for b in farm.batches]}
                                      values={[b.balance for b in farm.batches]} color="#4ade80" signed={True} />

                            <div className="km-card">
                                <h3>Profit per batch</h3>
                                <div style={{"overflowX": "auto"}}>
                                    <table className="km-table">
                                        <thead><tr><th>Batch</th><th>Sales</th><th>Feed eaten</th><th>Other costs</th><th>Profit</th></tr></thead>
                                        <tbody>
                                            {for b in farm.batches {
                                                <tr key={b.batch_id}><td><strong>{b.label}</strong></td><td>{money(b.income)}</td>
                                                    <td>{"- " + money(b.feed_cost)}</td><td>{"- " + money(b.other_cost)}</td>
                                                    <td style={{"color": "#4ade80" if b.balance >= 0 else "#f87171", "fontWeight": "800"}}>{money(b.balance)}</td></tr>
                                            }}
                                            <tr style={{"background": "#16294a", "fontWeight": "800"}}>
                                                <td>Total</td><td>{money(farm.income)}</td><td>{"- " + money(farm.feed_eaten_cost)}</td><td>{"- " + money(farm.other_costs)}</td>
                                                <td style={{"color": "#4ade80" if farm.balance >= 0 else "#f87171"}}>{money(farm.balance)}</td>
                                            </tr>
                                        </tbody>
                                    </table>
                                </div>
                            </div>

                            <form className="km-card" onSubmit={submit_cost}>
                                <h3>Add a cost</h3>
                                <div className="km-grid2">
                                    <Choice label="Batch" value={cost_chosen} onValue={lambda(v: str) { cost_batch = v; }}
                                            options={[[b.batch_id, b.label] for b in farm.batches] + [["all", "All batches (shared by birds alive)"]]} />
                                    <Choice label="Type of cost" value={cost_kind} onValue={lambda(v: str) { cost_kind = v; }}
                                            options={[[k, k] for k in farm.expense_kinds]} />
                                    <Field label="Amount (KSh)" value={cost_amount} onValue={lambda(v: str) { cost_amount = v; }} kind="number" hint="e.g. 4000" />
                                    <Field label="Note" value={cost_note} onValue={lambda(v: str) { cost_note = v; }} hint="e.g. Gumboro vaccine" />
                                </div>
                                <div style={{"marginTop": "0.7rem"}}>
                                    <button type="submit" className="km-btn primary">Save cost</button>
                                </div>
                                <Notice text={cost_msg} ok={cost_ok} />
                                {if len(farm.expenses) > 0 {
                                    <table className="km-table" style={{"marginTop": "0.8rem"}}>
                                        <thead><tr><th>Date</th><th>Batch</th><th>Cost</th><th>Amount</th><th>Note</th></tr></thead>
                                        <tbody>
                                            {for (i, x) in enumerate(farm.expenses) {
                                                <tr key={str(i)}><td>{x.date}</td><td>{x.batch_id}</td><td>{x.kind}</td><td>{"KSh " + money(x.amount)}</td><td>{x.note}</td></tr>
                                            }}
                                        </tbody>
                                    </table>
                                }}
                            </form>
                        </div>
                    }}

                    {if tab == "Sales history" {
                        <div className="km-card">
                            <h3>All sales</h3>
                            <SalesTable sales={farm.sales} limit={0} />
                            {if len(farm.sales) > 0 {
                                <div style={{"marginTop": "0.6rem"}}>
                                    <Row label={str(len(farm.sales)) + " sales"} value={"KSh " + money(farm.income)} bold={True} />
                                </div>
                            }}
                        </div>
                    }}
                </div>
                <AgentChat agentKey="sales" title="Ask the Sales agent" lines={lines} busy={busy}
                           examples={a["examples"]} onSend={onSend} />
            </div>
        </div>;
}
