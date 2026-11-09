"""Orders & bookings: customer orders (Sales), supply orders (Feed), vet visits (Disease detector).
The Manager page shows all of them together; each agent's page shows its own part.
Every button calls a walker on the server, and the server updates every agent's records."""

import from .ui { Field, Choice, Pill, Notice, Stat }
import from .Charts { money }

sv import from ..farm { FarmView, OrderView, SupplyView, VetVisitView, Diagnosis, ActionResult,
                        order_add, order_deliver, supply_add, supply_receive, vet_book, vet_done, booking_cancel }

glob STATUS_COLOUR = {"booked": "#fbbf24", "ordered": "#fbbf24", "delivered": "#4ade80", "received": "#4ade80",
                      "done": "#4ade80", "cancelled": "#94a8c4"};
glob DUE_COLOUR = {"overdue": "#f87171", "today": "#f2b84b", "soon": "#2dd4bf", "later": "#94a8c4"};

def:pub StatusChip(status: str) -> JsxElement {
    c = STATUS_COLOUR.get(status, "#94a8c4");
    return <span style={{"border": "1px solid " + c, "color": c, "borderRadius": "999px", "padding": "0.05rem 0.5rem",
                         "fontSize": "0.72rem", "fontWeight": "700", "whiteSpace": "nowrap"}}>{status}</span>;
}

def:pub DueText(text: str, status: str) -> JsxElement {
    c = DUE_COLOUR.get(status, "#94a8c4");
    label = ("⚠ " + text + " - late") if status == "overdue" else text;
    return <span style={{"color": c, "fontWeight": "700" if status == "overdue" or status == "today" else "400", "whiteSpace": "nowrap"}}>{label}</span>;
}

def:pub ShowPicker(show: str, onPick: Callable[[str], None], open_label: str) -> JsxElement {
    return
        <div style={{"marginBottom": "0.4rem"}}>
            <Pill label={open_label} value="open" on={show == "open"} onPick={onPick} />
            <Pill label="All" value="all" on={show == "all"} onPick={onPick} />
        </div>;
}

# ---------------- CUSTOMER ORDERS ----------------
def:pub OrdersCard(farm: FarmView, onFarm: Callable[[FarmView], None]) -> JsxElement {
    has buyer: str = "";
    has item: str = "birds";
    has bird_type: str = "broiler";
    has qty: str = "";
    has trays: str = "";
    has price: str = "";
    has tray_price: str = "";
    has deposit: str = "";
    has due: str = "";
    has batch: str = "";
    has msg: str = "";
    has ok: bool = True;
    has saving: bool = False;
    has show: str = "open";

    rows = [o for o in farm.orders if show == "all" or o.status == "booked"];
    n_eggs = int(parseFloat(trays or "0")) * 30 + int(parseFloat(qty or "0"));
    total = parseFloat(tray_price or "0") * n_eggs / 30.0 if item == "eggs" else parseFloat(price or "0") * int(parseFloat(qty or "0"));

    def done(r: ActionResult) {
        msg = r.message;
        ok = r.ok;
        if r.farm { onFarm(r.farm); }
    }
    async def save() {
        saving = True;
        res = root spawn order_add(buyer=buyer, item=item, bird_type=bird_type, qty=int(parseFloat(qty or "0")),
                                   trays=int(parseFloat(trays or "0")), price_each=parseFloat(price or "0"),
                                   price_per_tray=parseFloat(tray_price or "0"), deposit=parseFloat(deposit or "0"),
                                   due=due, batch_id=batch);
        r = res.reports[0];
        done(r);
        if r.ok { qty = ""; trays = ""; deposit = ""; }
        saving = False;
    }
    def submit(e: FormEvent) { e.preventDefault(); save(); }
    async def deliver(o: OrderView) {
        win: any = window;
        p = 0.0;
        pt = 0.0;
        if o.total <= 0 {
            raw: any = win.prompt("Price " + ("per tray" if o.item == "eggs" else "per bird") + " for " + o.order_id + " (KSh)?", "");
            if not raw { return; }
            ans: str = str(raw);
            if o.item == "eggs" { pt = parseFloat(ans); } else { p = parseFloat(ans); }
        }
        if not win.confirm("Deliver " + o.what + " to " + o.buyer + " now? It is saved as a sale and taken off the batch.") { return; }
        res = root spawn order_deliver(order_id=o.order_id, price_each=p, price_per_tray=pt);
        done(res.reports[0]);
    }
    async def cancel(ref: str) {
        win: any = window;
        if not win.confirm("Cancel " + ref + "?") { return; }
        res = root spawn booking_cancel(ref_id=ref);
        done(res.reports[0]);
    }

    return
        <div>
            <form className="km-card" onSubmit={submit}>
                <h3>Book a customer order</h3>
                <div className="km-muted" style={{"marginBottom": "0.5rem"}}>
                    A buyer wants birds or eggs on a later day. When you deliver, tap Delivered: the sale, the birds or eggs left, the buyer's total and the profit all update.
                </div>
                <div style={{"marginBottom": "0.5rem"}}>
                    <Pill label="🐔 Birds" value="birds" on={item == "birds"} onPick={lambda(v: str) { item = v; }} />
                    <Pill label="🥚 Eggs" value="eggs" on={item == "eggs"} onPick={lambda(v: str) { item = v; }} />
                </div>
                <div className="km-grid3">
                    <Field label="Buyer" value={buyer} onValue={lambda(v: str) { buyer = v; }} hint="e.g. Mama Njeri Hotel" />
                    {if item == "birds" {
                        <Choice label="Birds" value={bird_type} onValue={lambda(v: str) { bird_type = v; }}
                                options={[["broiler", "Broilers"], ["layer", "Layers"], ["kienyeji", "Kienyeji"]]} />
                    } else {
                        <Field label="Trays (30 eggs)" value={trays} onValue={lambda(v: str) { trays = v; }} kind="number" />
                    }}
                    <Field label={"Number of birds" if item == "birds" else "Loose eggs"} value={qty} onValue={lambda(v: str) { qty = v; }} kind="number" />
                    {if item == "birds" {
                        <Field label="Price per bird (KSh)" value={price} onValue={lambda(v: str) { price = v; }} kind="number" hint="blank = agree later" />
                    } else {
                        <Field label="Price per tray (KSh)" value={tray_price} onValue={lambda(v: str) { tray_price = v; }} kind="number" hint="blank = agree later" />
                    }}
                    <Field label="Deposit paid (KSh)" value={deposit} onValue={lambda(v: str) { deposit = v; }} kind="number" hint="0" />
                    <Field label="Delivery date" value={due} onValue={lambda(v: str) { due = v; }} kind="date" />
                    <Choice label="From batch" value={batch} onValue={lambda(v: str) { batch = v; }}
                            options={[["", "Choose when delivering"]] + [[b.batch_id, b.label] for b in farm.batches]} />
                </div>
                {if total > 0 {
                    <div className="km-small" style={{"marginTop": "0.5rem"}}>
                        {"Order value: KSh " + money(total) + (" · to collect on delivery: KSh " + money(total - parseFloat(deposit or "0")) if parseFloat(deposit or "0") > 0 else "")}
                    </div>
                }}
                <div style={{"marginTop": "0.7rem"}}>
                    <button type="submit" className="km-btn primary" disabled={saving}>{"Saving..." if saving else "Book order"}</button>
                </div>
                <Notice text={msg} ok={ok} />
            </form>
            <div className="km-card">
                <h3>Customer orders</h3>
                <ShowPicker show={show} onPick={lambda(v: str) { show = v; }} open_label="Open orders" />
                <div style={{"overflowX": "auto"}}>
                    <table className="km-table">
                        <thead><tr><th>Order</th><th>Buyer</th><th>What</th><th>Delivery</th><th>Value</th><th>Status</th><th></th></tr></thead>
                        <tbody>
                            {for o in rows {
                                <tr key={o.order_id}>
                                    <td><strong>{o.order_id}</strong></td>
                                    <td>{o.buyer}</td>
                                    <td>{o.what}{if not o.can_supply { <div style={{"color": "#f87171", "fontSize": "0.72rem"}}>not enough on the farm</div> }}</td>
                                    <td>{if o.status == "booked" { <DueText text={o.due_text} status={o.due_status} /> } else { <span className="km-small">{o.done_date}</span> }}</td>
                                    <td>{("KSh " + money(o.total)) if o.total > 0 else o.price_text}
                                        {if o.deposit > 0 { <div className="km-small">{"deposit " + money(o.deposit)}</div> }}</td>
                                    <td><StatusChip status={o.status} />{if o.batch_id != "" { <div className="km-small">{o.batch_id}</div> }}</td>
                                    <td style={{"whiteSpace": "nowrap"}}>
                                        {if o.status == "booked" {
                                            <span>
                                                <button type="button" className="km-btn small primary" onClick={lambda(e: MouseEvent) { deliver(o); }}>Delivered</button>
                                                <button type="button" className="km-btn small" style={{"marginLeft": "0.3rem"}} onClick={lambda(e: MouseEvent) { cancel(o.order_id); }}>Cancel</button>
                                            </span>
                                        }}
                                    </td>
                                </tr>
                            }}
                        </tbody>
                    </table>
                </div>
                {if len(rows) == 0 { <div className="km-small" style={{"padding": "0.5rem"}}>No orders here yet. Book one above, or tell the Manager: "Mama Njeri wants 100 broilers on Friday at 600".</div> }}
            </div>
        </div>;
}

# ---------------- SUPPLY ORDERS: feed, chicks, vaccines, medicine ----------------
def:pub SuppliesCard(farm: FarmView, onFarm: Callable[[FarmView], None]) -> JsxElement {
    has kind: str = "Feed";
    has bags: str = "";
    has kg: str = "";
    has count: str = "";
    has bird_type: str = "broiler";
    has house: str = "";
    has batch: str = "";
    has cost: str = "";
    has supplier: str = "";
    has due: str = "";
    has arrived: bool = False;
    has msg: str = "";
    has ok: bool = True;
    has saving: bool = False;
    has show: str = "open";

    rows = [s for s in farm.supplies if show == "all" or s.status == "ordered"];
    the_house = house if house != "" else (farm.houses[0] if len(farm.houses) > 0 else "");

    def done(r: ActionResult) {
        msg = r.message;
        ok = r.ok;
        if r.farm { onFarm(r.farm); }
    }
    async def save() {
        saving = True;
        res = root spawn supply_add(kind=kind, qty=parseFloat((kg if kind == "Feed" else count) or "0"), bags=parseFloat(bags or "0"),
                                    cost=parseFloat(cost or "0"), supplier=supplier, due=due, bird_type=bird_type,
                                    house=the_house, batch_id=batch, received_now=arrived);
        r = res.reports[0];
        done(r);
        if r.ok { bags = ""; kg = ""; count = ""; cost = ""; arrived = False; }
        saving = False;
    }
    def submit(e: FormEvent) { e.preventDefault(); save(); }
    async def receive(s: SupplyView) {
        win: any = window;
        if not win.confirm(s.supply_id + ": has " + s.what + " arrived?") { return; }
        res = root spawn supply_receive(supply_id=s.supply_id);
        done(res.reports[0]);
    }
    async def cancel(ref: str) {
        win: any = window;
        if not win.confirm("Cancel " + ref + "?") { return; }
        res = root spawn booking_cancel(ref_id=ref);
        done(res.reports[0]);
    }

    return
        <div>
            <form className="km-card" onSubmit={submit}>
                <h3>Order supplies</h3>
                <div className="km-muted" style={{"marginBottom": "0.5rem"}}>
                    When it arrives, tap Received: feed goes into the store (with its price per kg), chicks become a new batch, and every cost goes into the profit.
                </div>
                <div style={{"marginBottom": "0.5rem"}}>
                    {for k in farm.supply_kinds {
                        <Pill key={k} label={k} value={k} on={kind == k} onPick={lambda(v: str) { kind = v; }} />
                    }}
                </div>
                <div className="km-grid3">
                    {if kind == "Feed" {
                        <Field label="Bags (50 kg)" value={bags} onValue={lambda(v: str) { bags = v; }} kind="number" />
                    }}
                    {if kind == "Feed" {
                        <Field label="Extra kg" value={kg} onValue={lambda(v: str) { kg = v; }} kind="number" />
                    }}
                    {if kind != "Feed" {
                        <Field label={"Number of chicks" if kind == "Chicks" else "Units / bottles"} value={count} onValue={lambda(v: str) { count = v; }} kind="number" />
                    }}
                    {if kind == "Chicks" {
                        <Choice label="Type of chicks" value={bird_type} onValue={lambda(v: str) { bird_type = v; }}
                                options={[["broiler", "Broiler"], ["layer", "Layer"], ["kienyeji", "Kienyeji"]]} />
                    }}
                    {if kind == "Chicks" {
                        <Choice label="Into house" value={the_house} onValue={lambda(v: str) { house = v; }}
                                options={[[h, h] for h in farm.houses]} />
                    }}
                    {if kind != "Feed" and kind != "Chicks" {
                        <Choice label="For batch" value={batch} onValue={lambda(v: str) { batch = v; }}
                                options={[["", "All batches (shared)"]] + [[b.batch_id, b.label] for b in farm.batches]} />
                    }}
                    <Field label="Total cost (KSh)" value={cost} onValue={lambda(v: str) { cost = v; }} kind="number" />
                    <Field label="Supplier" value={supplier} onValue={lambda(v: str) { supplier = v; }} hint="e.g. Unga Farm Care" />
                    <Field label="Expected on" value={due} onValue={lambda(v: str) { due = v; }} kind="date" />
                </div>
                <label className="km-small" style={{"display": "flex", "gap": "0.4rem", "alignItems": "center", "marginTop": "0.6rem", "cursor": "pointer"}}>
                    <input type="checkbox" checked={arrived} onChange={lambda(e: ChangeEvent) { arrived = not arrived; }} />
                    It has already arrived (save it as received now)
                </label>
                <div style={{"marginTop": "0.7rem"}}>
                    <button type="submit" className="km-btn primary" disabled={saving}>{"Saving..." if saving else ("Save delivery" if arrived else "Place order")}</button>
                </div>
                <Notice text={msg} ok={ok} />
            </form>
            <div className="km-card">
                <h3>Supply orders</h3>
                <ShowPicker show={show} onPick={lambda(v: str) { show = v; }} open_label="Waiting to arrive" />
                <div style={{"overflowX": "auto"}}>
                    <table className="km-table">
                        <thead><tr><th>Order</th><th>What</th><th>Supplier</th><th>Expected</th><th>Cost</th><th>Status</th><th></th></tr></thead>
                        <tbody>
                            {for s in rows {
                                <tr key={s.supply_id}>
                                    <td><strong>{s.supply_id}</strong></td>
                                    <td>{s.what}{if s.kind == "Chicks" { <div className="km-small">{s.bird_type + " → " + s.house}</div> }}
                                        {if s.batch_id != "" { <div className="km-small">{"for " + s.batch_id}</div> }}</td>
                                    <td>{s.supplier if s.supplier != "" else "-"}</td>
                                    <td>{if s.status == "ordered" { <DueText text={s.due_text} status={s.due_status} /> } else { <span className="km-small">{s.done_date}</span> }}</td>
                                    <td>{("KSh " + money(s.cost)) if s.cost > 0 else "-"}</td>
                                    <td><StatusChip status={s.status} /></td>
                                    <td style={{"whiteSpace": "nowrap"}}>
                                        {if s.status == "ordered" {
                                            <span>
                                                <button type="button" className="km-btn small primary" onClick={lambda(e: MouseEvent) { receive(s); }}>Received</button>
                                                <button type="button" className="km-btn small" style={{"marginLeft": "0.3rem"}} onClick={lambda(e: MouseEvent) { cancel(s.supply_id); }}>Cancel</button>
                                            </span>
                                        }}
                                    </td>
                                </tr>
                            }}
                        </tbody>
                    </table>
                </div>
                {if len(rows) == 0 { <div className="km-small" style={{"padding": "0.5rem"}}>Nothing waiting. Order above, or tell the Manager: "Nimeagiza gunia 40 za chakula, zitafika Jumatatu".</div> }}
            </div>
        </div>;
}

# ---------------- VET VISITS ----------------
def:pub VetVisitsCard(farm: FarmView, onFarm: Callable[[FarmView], None]) -> JsxElement {
    has batch: str = "";
    has when: str = "";
    has reason: str = "";
    has msg: str = "";
    has ok: bool = True;
    has link: str = "";
    has saving: bool = False;
    has show: str = "open";

    rows = [v for v in farm.vet_visits if show == "all" or v.status == "booked"];
    reds = [b.batch_id for b in farm.batches if b.health == "RED"];

    def done(r: ActionResult) {
        msg = r.message;
        ok = r.ok;
        link = "";
        if r.farm { onFarm(r.farm); }
    }
    async def save() {
        saving = True;
        res = root spawn vet_book(batch_id=batch, visit_date=when, reason=reason);
        r = res.reports[0];
        msg = r.reply;
        ok = r.ok;
        if r.farm { onFarm(r.farm); }
        link = r.vet_link if r.ok else "";
        if r.ok { reason = ""; }
        saving = False;
    }
    def submit(e: FormEvent) { e.preventDefault(); save(); }
    async def finish(v: VetVisitView) {
        win: any = window;
        fee_raw: any = win.prompt(v.visit_id + " done. Vet fee paid (KSh)? Leave 0 if none.", "0");
        if fee_raw is None { return; }
        fee: str = str(fee_raw);
        said_raw: any = win.prompt("What did the vet say or do? (optional)", "");
        said: str = str(said_raw) if said_raw else "";
        cleared = False;
        if len([b for b in reds if v.batch_id == "" or b == v.batch_id]) > 0 {
            cleared = True if win.confirm("Did the vet clear the sick batch? (OK = yes, sales allowed again)") else False;
        }
        res = root spawn vet_done(visit_id=v.visit_id, cost=parseFloat(fee or "0"), cleared=cleared, outcome=said or "");
        done(res.reports[0]);
    }
    async def cancel(ref: str) {
        win: any = window;
        if not win.confirm("Cancel " + ref + "?") { return; }
        res = root spawn booking_cancel(ref_id=ref);
        done(res.reports[0]);
    }

    return
        <div>
            <form className="km-card" onSubmit={submit}>
                <h3>Book the vet</h3>
                <div className="km-muted" style={{"marginBottom": "0.5rem"}}>
                    {"Farm vet: " + farm.vet_name + (" · " + farm.vet_phone if farm.vet_phone != "" else "") + ". After the visit, tap Done: the fee goes into the costs and a cleared batch can be sold again."}
                </div>
                <div className="km-grid3">
                    <Choice label="For" value={batch} onValue={lambda(v: str) { batch = v; }}
                            options={[["", "The whole farm"]] + [[b.batch_id, b.label] for b in farm.batches]} />
                    <Field label="Visit date" value={when} onValue={lambda(v: str) { when = v; }} kind="date" />
                    <Field label="Reason" value={reason} onValue={lambda(v: str) { reason = v; }} hint="e.g. Gumboro vaccination" />
                </div>
                <div style={{"marginTop": "0.7rem"}}>
                    <button type="submit" className="km-btn primary" disabled={saving}>{"Booking..." if saving else "Book vet visit"}</button>
                </div>
                <Notice text={msg} ok={ok} />
                {if link != "" {
                    <a href={link} target="_blank" rel="noopener noreferrer" className="km-btn primary"
                       style={{"background": "#25d366", "borderColor": "#25d366", "textDecoration": "none", "display": "inline-block", "marginTop": "0.5rem"}}>Send to the vet on WhatsApp</a>
                }}
            </form>
            <div className="km-card">
                <h3>Vet visits</h3>
                <ShowPicker show={show} onPick={lambda(v: str) { show = v; }} open_label="Booked" />
                <div style={{"overflowX": "auto"}}>
                    <table className="km-table">
                        <thead><tr><th>Visit</th><th>For</th><th>When</th><th>Reason</th><th>Status</th><th></th></tr></thead>
                        <tbody>
                            {for v in rows {
                                <tr key={v.visit_id}>
                                    <td><strong>{v.visit_id}</strong></td>
                                    <td>{v.batch_id if v.batch_id != "" else "Whole farm"}</td>
                                    <td>{if v.status == "booked" { <DueText text={v.when_text} status={v.due_status} /> } else { <span className="km-small">{v.done_date}</span> }}</td>
                                    <td>{v.reason}{if v.outcome != "" { <div className="km-small">{"Vet: " + v.outcome}</div> }}
                                        {if v.cost > 0 { <div className="km-small">{"Fee KSh " + money(v.cost)}</div> }}</td>
                                    <td><StatusChip status={v.status} /></td>
                                    <td style={{"whiteSpace": "nowrap"}}>
                                        {if v.status == "booked" {
                                            <span>
                                                {if v.vet_link != "" {
                                                    <a href={v.vet_link} target="_blank" rel="noopener noreferrer" className="km-btn small"
                                                       style={{"textDecoration": "none", "marginRight": "0.3rem"}}>WhatsApp</a>
                                                }}
                                                <button type="button" className="km-btn small primary" onClick={lambda(e: MouseEvent) { finish(v); }}>Done</button>
                                                <button type="button" className="km-btn small" style={{"marginLeft": "0.3rem"}} onClick={lambda(e: MouseEvent) { cancel(v.visit_id); }}>Cancel</button>
                                            </span>
                                        }}
                                    </td>
                                </tr>
                            }}
                        </tbody>
                    </table>
                </div>
                {if len(rows) == 0 { <div className="km-small" style={{"padding": "0.5rem"}}>No vet visits booked. Book above, or tell the Manager: "Book the vet for Thursday to vaccinate B1".</div> }}
            </div>
        </div>;
}

# ---------------- MANAGER: everything in one place ----------------
def:pub BookingsBoard(farm: FarmView, onFarm: Callable[[FarmView], None]) -> JsxElement {
    has part: str = "Customer orders";

    open_orders = [o for o in farm.orders if o.status == "booked"];
    waiting = [s for s in farm.supplies if s.status == "ordered"];
    visits = [v for v in farm.vet_visits if v.status == "booked"];
    to_collect = sum([o.total - o.deposit for o in open_orders if o.total > 0]);

    return
        <div>
            <div className="km-grid4" style={{"marginBottom": "0.8rem"}}>
                <Stat label="Open orders" value={str(len(open_orders))} note={"KSh " + money(to_collect) + " to collect"} />
                <Stat label="Supplies coming" value={str(len(waiting))} note={"KSh " + money(sum([s.cost for s in waiting])) + " to pay"} />
                <Stat label="Vet visits booked" value={str(len(visits))} note={farm.vet_name} />
                <Stat label="Due soon" value={str(len(farm.booking_tasks))} note="see the list below"
                      colour={"#f2b84b" if len(farm.booking_tasks) > 0 else "#ffffff"} />
            </div>
            <div className="km-card">
                <h3>Coming up</h3>
                {if len(farm.booking_tasks) == 0 { <div className="km-muted">Nothing due in the next 3 days.</div> }}
                <ul className="km-list">
                    {for t in farm.booking_tasks {
                        <li key={t} style={{"color": "#fca5a5" if "OVERDUE" in t or "LATE:" in t else "#e6edf7"}}>{t}</li>
                    }}
                </ul>
                <div className="km-small" style={{"marginTop": "0.4rem"}}>
                    Tip: just tell the Manager in the chat - "Mama Njeri ameagiza broilers 100 za Ijumaa", "P1 imefika", "Daktari amekuja, tumemlipa 2000", "Nimelipa vibarua 5000". It saves it with the right agent.
                </div>
            </div>
            <div style={{"marginBottom": "0.5rem"}}>
                {for p in ["Customer orders", "Supplies", "Vet visits"] {
                    <Pill key={p} label={p} value={p} on={part == p} onPick={lambda(v: str) { part = v; }} />
                }}
            </div>
            {if part == "Customer orders" { <OrdersCard farm={farm} onFarm={onFarm} /> }}
            {if part == "Supplies" { <SuppliesCard farm={farm} onFarm={onFarm} /> }}
            {if part == "Vet visits" { <VetVisitsCard farm={farm} onFarm={onFarm} /> }}
        </div>;
}
