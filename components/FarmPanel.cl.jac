"""The farm at a glance: key numbers, charts, batches with health colour, incubator and alerts."""

import from .Charts { BarChart, FeedGauge, money }

sv import from ..farm { FarmView, BatchView }

glob HEALTH_COLOUR = {"RED": "#f87171", "AMBER": "#fbbf24", "GREEN": "#4ade80"};

def:pub Tile(label: str, value: str, note: str = "", colour: str = "#e6edf7", size: str = "1.1rem") -> JsxElement {
    return
        <div style={{"background": "#16294a", "borderRadius": "10px", "padding": "0.45rem 0.55rem", "minWidth": "0"}}>
            <div style={{"fontSize": "0.7rem", "color": "#94a8c4"}}>{label}</div>
            <div style={{"fontWeight": "800", "fontSize": size, "color": colour, "whiteSpace": "nowrap"}}>{value}</div>
            {if note != "" { <div style={{"fontSize": "0.68rem", "color": "#94a8c4"}}>{note}</div> }}
        </div>;
}

def:pub Row(label: str, value: str, bold: bool = False, colour: str = "#e6edf7") -> JsxElement {
    return
        <div style={{"display": "flex", "justifyContent": "space-between", "gap": "0.5rem", "marginTop": "0.25rem",
                     "fontWeight": "700" if bold else "400", "color": colour}}>
            <span>{label}</span>
            <span style={{"whiteSpace": "nowrap"}}>{value}</span>
        </div>;
}

# Where every bird went: start - dead - sold = alive
def:pub BirdCount(start: int, dead: int, sold: int, alive: int, ok: bool) -> JsxElement {
    return
        <div style={{"background": "#10213a", "border": "1px solid #22385c", "borderRadius": "12px", "padding": "0.55rem 0.6rem", "marginBottom": "0.6rem"}}>
            <strong style={{"fontSize": "0.8rem", "color": "#e6edf7"}}>Bird count (all batches)</strong>
            <div style={{"display": "grid", "gridTemplateColumns": "repeat(4, 1fr)", "gap": "0.25rem", "marginTop": "0.35rem", "textAlign": "center"}}>
                <Tile label="Started" value={money(float(start))} size="0.88rem" />
                <Tile label="Dead" value={"− " + money(float(dead))} size="0.88rem" colour="#f87171" />
                <Tile label="Sold" value={"− " + money(float(sold))} size="0.88rem" colour="#fbbf24" />
                <Tile label="Alive" value={"= " + money(float(alive))} size="0.88rem" colour="#4ade80" />
            </div>
            <div style={{"fontSize": "0.68rem", "color": "#4ade80" if ok else "#f87171", "marginTop": "0.3rem"}}>
                {"✓ Every bird is counted: started − dead − sold = alive" if ok else "⚠ Counts do not add up - check the records"}
            </div>
        </div>;
}

def:pub ClearButton(batchId: str, onClear: Callable[[str], None]) -> JsxElement {
    def handle(e: MouseEvent) {
        onClear(batchId);
    }
    return
        <button
            onClick={handle}
            style={{
                "marginTop": "0.35rem", "padding": "0.25rem 0.6rem", "fontSize": "0.72rem",
                "border": "1px solid #f87171", "background": "#10213a", "color": "#f87171",
                "borderRadius": "6px", "cursor": "pointer"
            }}
        >
            Vet has visited - clear batch
        </button>;
}

def:pub FarmPanel(
    farm: FarmView | None,
    onNextDay: Callable[[], None],
    onClear: Callable[[str], None],
    onFresh: Callable[[], None]
) -> JsxElement {
    def handle_next(e: MouseEvent) {
        onNextDay();
    }
    def handle_fresh(e: MouseEvent) {
        onFresh();
    }

    if farm is None {
        return <div style={{"padding": "1rem", "color": "#94a8c4"}}>Loading farm...</div>;
    }

    fv = farm as FarmView;
    red_count = len([b for b in fv.batches if b.health == "RED"]);
    with_records = [b for b in fv.batches if len(b.deaths_series) > 0];
    layers = [b for b in fv.batches if sum(b.eggs_series) > 0];

    return
        <div>
            <div style={{"fontSize": "0.75rem", "fontWeight": "700", "letterSpacing": "0.06em", "color": "#94a8c4", "marginBottom": "0.2rem"}}>FARM DASHBOARD</div>
            <h2 style={{"margin": "0 0 0.1rem", "fontSize": "1.05rem"}}>{fv.name}</h2>
            <div style={{"color": "#94a8c4", "fontSize": "0.78rem", "marginBottom": "0.6rem"}}>{"Owner: " + fv.owner}</div>

            <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "0.4rem", "marginBottom": "0.6rem"}}>
                <Tile label="Birds alive" value={str(fv.birds_alive)} note={str(len(fv.batches)) + " batches"} />
                <Tile label="Health alerts" value={str(red_count) + " RED"} note={"needs a vet" if red_count > 0 else "all clear"}
                      colour={"#f87171" if red_count > 0 else "#4ade80"} />
                <Tile label="Sales so far" value={"KSh " + money(fv.income)} />
                <Tile label="Feed needed per day" value={str(int(fv.feed_need_per_day)) + " kg"} note="whole farm" />
            </div>

            <BirdCount start={fv.start_total} dead={fv.dead_total} sold={fv.sold_total} alive={fv.birds_alive} ok={fv.count_ok} />

            <div style={{"background": "#10213a", "border": "1px solid #22385c", "borderRadius": "12px", "padding": "0.55rem 0.6rem", "marginBottom": "0.6rem", "fontSize": "0.75rem", "color": "#e6edf7"}}>
                <strong style={{"fontSize": "0.8rem"}}>Money and feed so far</strong>
                <Row label="Sales (birds + eggs)" value={"KSh " + money(fv.income)} />
                <Row label={"Feed eaten: " + money(fv.feed_eaten_kg) + " kg x KSh " + str(fv.feed_price)} value={"- KSh " + money(fv.feed_eaten_cost)} />
                <Row label="Other costs (chicks, vaccines, labour...)" value={"- KSh " + money(fv.other_costs)} />
                <Row label="Profit" value={"KSh " + money(fv.balance)} bold={True} colour={"#4ade80" if fv.balance >= 0 else "#f87171"} />
                <Row label="Eggs collected / sold" value={money(float(fv.eggs_collected)) + " / " + money(float(fv.eggs_sold))} />
            </div>

            <FeedGauge days={fv.feed_days} kg={fv.feed_kg} />

            {for b in with_records {
                <BarChart key={"d" + b.batch_id} title={"Deaths per day - " + b.label}
                          labels={b.days} values={[float(x) for x in b.deaths_series]} color="#f87171" />
            }}
            {if len(with_records) == 0 {
                <BarChart title="Deaths per day" labels={[]} values={[]} empty_note="No worker reports yet - send one in the chat." />
            }}

            {for b in layers {
                <BarChart key={"e" + b.batch_id} title={"Eggs per day - " + b.label}
                          labels={b.days} values={[float(x) for x in b.eggs_series]} color="#fbbf24" />
            }}

            <BarChart title="Profit per batch (sales minus costs, KSh)"
                      labels={[b.batch_id for b in fv.batches]} values={[b.balance for b in fv.batches]}
                      color="#4ade80" signed={True} />

            <div style={{"fontSize": "0.8rem", "fontWeight": "700", "margin": "0.4rem 0 0.1rem", "color": "#e6edf7"}}>Batches</div>
            <div style={{"fontSize": "0.7rem", "color": "#94a8c4", "marginBottom": "0.35rem"}}>
                A batch (B1, B2...) is a group of birds of the same age, raised together. Workers report by batch.
            </div>
            {for b in fv.batches {
                <div
                    key={b.batch_id}
                    style={{
                        "border": "1px solid #22385c",
                        "borderLeft": "6px solid " + HEALTH_COLOUR.get(b.health, "#4ade80"),
                        "borderRadius": "10px",
                        "padding": "0.45rem 0.6rem",
                        "marginBottom": "0.4rem",
                        "background": "#10213a"
                    }}
                >
                    <div style={{"display": "flex", "justifyContent": "space-between"}}>
                        <strong style={{"fontSize": "0.86rem"}}>{b.label}</strong>
                        <span style={{"color": HEALTH_COLOUR.get(b.health, "#4ade80"), "fontWeight": "700", "fontSize": "0.75rem"}}>{b.health}</span>
                    </div>
                    <div style={{"fontSize": "0.75rem", "color": "#b6c4d8"}}>
                        {b.house + " | " + str(b.alive) + " of " + str(b.start_count) + " alive | deaths " + str(b.mortality) + "%"}
                    </div>
                    <div style={{"fontSize": "0.72rem", "color": "#94a8c4"}}>
                        {"Start " + str(b.start_count) + " − dead " + str(b.dead) + " − sold " + str(b.sold) + " = " + str(b.alive) + " alive"
                         + (" · eggs " + money(float(b.eggs_collected)) + " collected, " + money(float(b.eggs_sold)) + " sold" if b.eggs_collected > 0 or b.eggs_sold > 0 else "")}
                    </div>
                    <div style={{"fontSize": "0.73rem", "marginTop": "0.15rem"}}>
                        <span style={{"color": "#b6c4d8"}}>{"Sales KSh " + money(b.income) + " · Feed KSh " + money(b.feed_cost) + (" · Other KSh " + money(b.other_cost) if b.other_cost > 0 else "") + " · "}</span>
                        <strong style={{"color": "#4ade80" if b.balance >= 0 else "#f87171"}}>{"Profit KSh " + money(b.balance)}</strong>
                    </div>
                    {if b.health == "RED" {
                        <ClearButton batchId={b.batch_id} onClear={onClear} />
                    }}
                </div>
            }}
            <div style={{"fontSize": "0.68rem", "color": "#6f84a3", "marginBottom": "0.4rem"}}>
                Profit = sales minus feed eaten minus recorded costs (add chick, vaccine and labour costs on the Sales page).
            </div>

            {if len(fv.egg_sets) > 0 {
                <div style={{"fontSize": "0.8rem", "fontWeight": "700", "margin": "0.5rem 0 0.3rem", "color": "#e6edf7"}}>Incubator</div>
                for s in fv.egg_sets {
                    <div key={s} style={{"fontSize": "0.75rem", "marginBottom": "0.25rem"}}>{"🥚 " + s}</div>
                }
            }}

            {if len(fv.alerts) > 0 {
                <div style={{"fontSize": "0.8rem", "fontWeight": "700", "margin": "0.5rem 0 0.3rem", "color": "#f87171"}}>Alerts</div>
                for a in fv.alerts {
                    <div key={a} style={{"fontSize": "0.75rem", "color": "#fca5a5", "marginBottom": "0.25rem"}}>{"⚠ " + a}</div>
                }
            }}

            <button
                onClick={handle_next}
                style={{
                    "marginTop": "0.6rem", "width": "100%", "padding": "0.5rem",
                    "border": "1px dashed #14b8a6", "background": "transparent", "color": "#2dd4bf",
                    "borderRadius": "8px", "cursor": "pointer", "fontWeight": "600", "fontSize": "0.8rem"
                }}
            >
                Demo: move farm to the next day
            </button>
            <button
                onClick={handle_fresh}
                style={{
                    "marginTop": "0.4rem", "width": "100%", "padding": "0.45rem",
                    "border": "1px solid #f87171", "background": "#10213a", "color": "#f87171",
                    "borderRadius": "8px", "cursor": "pointer", "fontWeight": "600", "fontSize": "0.78rem"
                }}
            >
                Clear all records and start fresh
            </button>
        </div>;
}
