"""Small charts for the farm dashboard, drawn as SVG (no chart library needed)."""

def absf(v: float) -> float { return 0.0 - v if v < 0 else v; }
def lower(a: float, b: float) -> float { return a if a < b else b; }
def higher(a: float, b: float) -> float { return a if a > b else b; }

# 22500 -> "22,500" (rounded to the nearest whole number, not cut off: 1288.6 -> "1,289")
def:pub money(x: float) -> str {
    neg = x < 0;
    n = int((0.0 - x if neg else x) + 0.5);
    if n == 0 { neg = False; }
    digits = str(n);
    out = "";
    while len(digits) > 3 {
        out = "," + digits[len(digits) - 3:] + out;
        digits = digits[:len(digits) - 3];
    }
    return ("-" if neg else "") + digits + out;
}

# 64.45 -> "64.45", 70.8 -> "70.8", 1288 -> "1,288" (up to `places` decimals, no trailing zeros)
def:pub dec(x: float, places: int) -> str {
    neg = x < 0;
    scale = 1;
    for i in range(places) { scale = scale * 10; }
    v = int((0.0 - x if neg else x) * scale + 0.5);
    whole = int(v / scale);
    frac = v - whole * scale;
    out = money(float(whole));
    if frac > 0 {
        fs = str(frac);
        while len(fs) < places { fs = "0" + fs; }
        while len(fs) > 0 and fs[len(fs) - 1] == "0" { fs = fs[:len(fs) - 1]; }
        out = out + "." + fs;
    }
    return ("-" if neg and v > 0 else "") + out;
}

def fmt(v: float) -> str {
    if v >= 10000 or v <= -10000 { return dec(v / 1000.0, 1) + "k"; }
    return money(v);
}

# Vertical bar chart. signed=True draws negative values below a middle line (in red).
def:pub BarChart(title: str, labels: list[str], values: list[float], color: str = "#2dd4bf",
                 empty_note: str = "No data yet", signed: bool = False) -> JsxElement {
    W: float = 300.0;
    H: float = 110.0;
    top: float = 18.0;
    bottom: float = 22.0;
    n: int = len(values);
    biggest: float = 1.0;
    for v in values {
        if absf(v) > biggest { biggest = absf(v); }
    }
    plot_h: float = H - top - bottom;
    half: float = plot_h / 2.0 if signed else plot_h;
    base: float = top + half;
    scale: float = half / biggest;
    slot: float = (W - 10.0) / (float(n) if n > 0 else 1.0);
    bar_w: float = lower(38.0, slot * 0.6);
    xs: list[float] = [5.0 + float(i) * slot + (slot - bar_w) / 2.0 for i in range(n)];
    hs: list[float] = [higher(absf(v) * scale, 1.0) for v in values];

    return
        <div style={{"background": "#10213a", "border": "1px solid #22385c", "borderRadius": "12px", "padding": "0.55rem 0.6rem 0.3rem", "marginBottom": "0.6rem"}}>
            <div style={{"fontSize": "0.8rem", "fontWeight": "700", "color": "#e6edf7"}}>{title}</div>
            {if n == 0 {
                <div style={{"fontSize": "0.75rem", "color": "#6f84a3", "padding": "1rem 0"}}>{empty_note}</div>
            } else {
                <svg viewBox={"0 0 " + str(W) + " " + str(H)} style={{"width": "100%", "height": "auto"}}>
                    <line x1="5" x2={str(W - 5)} y1={str(base)} y2={str(base)} stroke="#2a4468" strokeWidth="1" />
                    {for (i, v) in enumerate(values) {
                        <g key={str(i)}>
                            <rect x={str(xs[i])} y={str(base - hs[i] if v >= 0 else base)} width={str(bar_w)} height={str(hs[i])} rx="3"
                                  fill={color if v >= 0 else "#f87171"} />
                            <text x={str(xs[i] + bar_w / 2.0)} y={str(base - hs[i] - 3.0 if v >= 0 else base - 3.0)}
                                  textAnchor="middle" fontSize="9" fill="#c8d4e6">{fmt(v)}</text>
                            <text x={str(xs[i] + bar_w / 2.0)} y={str(H - 6.0)} textAnchor="middle" fontSize="9" fill="#94a8c4">{labels[i] if i < len(labels) else ""}</text>
                        </g>
                    }}
                </svg>
            }}
        </div>;
}

# Feed gauge: how many days the feed in store will last (out of 14).
def:pub FeedGauge(days: float, kg: float) -> JsxElement {
    pct: float = lower(100.0, higher(3.0, days / 14.0 * 100.0));
    no_birds = days <= 0 and kg > 0;     # feed in store but no birds eating it yet
    colour = "#2dd4bf" if no_birds else ("#f87171" if days < 3 else ("#fbbf24" if days < 7 else "#4ade80"));
    note = "No birds to feed yet" if no_birds else ("Order feed now!" if days < 3 else ("Plan a feed order this week" if days < 7 else "Feed stock is fine"));
    if no_birds { pct = 100.0; }
    return
        <div style={{"background": "#10213a", "border": "1px solid #22385c", "borderRadius": "12px", "padding": "0.55rem 0.6rem", "marginBottom": "0.6rem"}}>
            <div style={{"display": "flex", "justifyContent": "space-between", "fontSize": "0.8rem"}}>
                <strong style={{"color": "#e6edf7"}}>Feed stock</strong>
                <span style={{"color": colour, "fontWeight": "700"}}>{"-" if no_birds else str(days) + " days"}</span>
            </div>
            <div style={{"height": "12px", "background": "#1c3152", "borderRadius": "999px", "margin": "0.4rem 0", "overflow": "hidden"}}>
                <div style={{"width": str(pct) + "%", "height": "100%", "background": colour, "borderRadius": "999px"}}></div>
            </div>
            <div style={{"fontSize": "0.72rem", "color": "#94a8c4"}}>{money(kg) + " kg in store · " + note}</div>
        </div>;
}

# Horizontal bars with the value and share of the total: good for "who bought the most" or "birds vs eggs".
def:pub HBars(title: str, labels: list[str], values: list[float], color: str = "#2dd4bf",
              empty_note: str = "No data yet", unit: str = "KSh ") -> JsxElement {
    biggest: float = 1.0;
    total: float = 0.0;
    for v in values {
        total = total + v;
        if v > biggest { biggest = v; }
    }
    return
        <div style={{"background": "#10213a", "border": "1px solid #22385c", "borderRadius": "12px", "padding": "0.6rem 0.7rem", "marginBottom": "0.6rem"}}>
            <div style={{"fontSize": "0.8rem", "fontWeight": "700", "color": "#e6edf7", "marginBottom": "0.4rem"}}>{title}</div>
            {if len(values) == 0 or total <= 0 {
                <div style={{"fontSize": "0.75rem", "color": "#6f84a3", "padding": "0.6rem 0"}}>{empty_note}</div>
            }}
            {for (i, v) in enumerate(values) {
                <div key={str(i)} style={{"marginBottom": "0.45rem"}}>
                    <div style={{"display": "flex", "justifyContent": "space-between", "fontSize": "0.78rem", "color": "#c8d4e6", "gap": "0.5rem"}}>
                        <span style={{"overflow": "hidden", "textOverflow": "ellipsis", "whiteSpace": "nowrap"}}>{labels[i] if i < len(labels) else ""}</span>
                        <span style={{"whiteSpace": "nowrap", "fontWeight": "700"}}>{unit + money(v) + (" · " + str(int(v * 100.0 / total + 0.5)) + "%" if total > 0 else "")}</span>
                    </div>
                    <div style={{"height": "9px", "background": "#1c3152", "borderRadius": "999px", "marginTop": "0.2rem", "overflow": "hidden"}}>
                        <div style={{"width": str(higher(2.0, v * 100.0 / biggest)) + "%", "height": "100%", "background": color, "borderRadius": "999px"}}></div>
                    </div>
                </div>
            }}
        </div>;
}
