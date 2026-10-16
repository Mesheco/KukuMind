"""Farm records table: every report, sale and health check the agents have saved, newest first."""

sv import from ..farm { RecordView }

glob KIND_COLOUR = {"Report": "#4ade80", "Sale": "#fbbf24", "Health": "#f87171", "New batch": "#60a5fa"};

def:pub FilterButton(label: str, current: str, onPick: Callable[[str], None]) -> JsxElement {
    def handle(e: MouseEvent) {
        onPick(label);
    }
    on = label == current;
    return
        <button onClick={handle}
            style={{"fontSize": "0.75rem", "padding": "0.2rem 0.6rem", "borderRadius": "999px", "cursor": "pointer",
                    "border": "1px solid " + ("#4ade80" if on else "#2a4468"),
                    "background": "#14b8a6" if on else "#10213a", "color": "#0a1628" if on else "#e6edf7"}}>
            {label}
        </button>;
}

def:pub RecordsTable(records: list[RecordView]) -> JsxElement {
    has show: str = "All";

    def pick(label: str) {
        show = label;
    }

    rows = [r for r in records if show == "All" or r.kind + "s" == show or (show == "Health" and r.kind == "Health") or (show == "Reports" and r.kind == "New batch")];

    return
        <section style={{"background": "#10213a", "borderRadius": "14px", "padding": "0.9rem", "marginTop": "0.8rem", "boxShadow": "0 1px 3px rgba(0,0,0,0.35)"}}>
            <div style={{"display": "flex", "alignItems": "center", "gap": "0.4rem", "flexWrap": "wrap", "marginBottom": "0.4rem"}}>
                <strong style={{"flex": "1", "fontSize": "0.95rem"}}>Farm records</strong>
                <FilterButton label="All" current={show} onPick={pick} />
                <FilterButton label="Reports" current={show} onPick={pick} />
                <FilterButton label="Sales" current={show} onPick={pick} />
                <FilterButton label="Health" current={show} onPick={pick} />
            </div>
            <div style={{"fontSize": "0.75rem", "color": "#94a8c4", "marginBottom": "0.5rem"}}>
                Every message the agents understand is saved here automatically - no forms to fill in.
            </div>
            <div style={{"maxHeight": "320px", "overflowY": "auto", "border": "1px solid #1c3152", "borderRadius": "10px"}}>
                <table style={{"width": "100%", "borderCollapse": "collapse", "fontSize": "0.8rem"}}>
                    <thead>
                        <tr style={{"background": "#16294a", "textAlign": "left", "position": "sticky", "top": "0"}}>
                            <th style={{"padding": "0.4rem 0.5rem"}}>Date</th>
                            <th style={{"padding": "0.4rem 0.5rem"}}>Batch</th>
                            <th style={{"padding": "0.4rem 0.5rem"}}>Type</th>
                            <th style={{"padding": "0.4rem 0.5rem"}}>Details</th>
                        </tr>
                    </thead>
                    <tbody>
                        {for (i, r) in enumerate(rows) {
                            <tr key={str(i)} style={{"borderTop": "1px solid #1c3152"}}>
                                <td style={{"padding": "0.35rem 0.5rem", "whiteSpace": "nowrap"}}>{r.date}</td>
                                <td style={{"padding": "0.35rem 0.5rem", "fontWeight": "700"}}>{r.batch_id}</td>
                                <td style={{"padding": "0.35rem 0.5rem", "color": KIND_COLOUR.get(r.kind, "#c8d4e6"), "fontWeight": "600"}}>{r.kind}</td>
                                <td style={{"padding": "0.35rem 0.5rem"}}>{r.detail}</td>
                            </tr>
                        }}
                    </tbody>
                </table>
                {if len(rows) == 0 {
                    <div style={{"padding": "0.8rem", "fontSize": "0.8rem", "color": "#6f84a3"}}>No records yet. Send a report, a sale or a new flock in the chat and it appears here.</div>
                }}
            </div>
        </section>;
}
