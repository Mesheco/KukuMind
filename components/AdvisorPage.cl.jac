"""Advisor page: vaccination plan for every batch, brooder heat by age, and answers to care questions."""

import from .ui { AgentHead, Tab, Pill }
import from .AgentChat { AgentChat }
import from .AgentsPanel { agent_info }

sv import from ..farm { FarmView, BatchPlan }

glob STATUS_STYLE = {
    "done": ["rgba(74,222,128,0.12)", "#4ade80", "✓ should be done"],
    "today": ["rgba(248,113,113,0.12)", "#f87171", "● TODAY"],
    "soon": ["rgba(251,191,36,0.12)", "#fbbf24", "◔ this week"],
    "later": ["#13243f", "#6f84a3", "later"]
};

glob HEAT = [
    ["Week 1 (day 1-7)", "32 - 35 C", "Chicks spread evenly under the heater"],
    ["Week 2 (day 8-14)", "29 - 32 C", "Raise the heater a little"],
    ["Week 3 (day 15-21)", "26 - 29 C", "More ventilation"],
    ["Week 4 (day 22-28)", "24 - 26 C", "Start weaning off heat"],
    ["After day 28", "No heat for most farms", "Heat only on cold nights"]
];

def:pub PlanCard(p: BatchPlan) -> JsxElement {
    return
        <div className="km-card">
            <div style={{"display": "flex", "justifyContent": "space-between", "flexWrap": "wrap", "gap": "0.4rem"}}>
                <strong>{p.label}</strong>
                <span className="km-chip">{"🌡 " + p.heat}</span>
            </div>
            <table className="km-table" style={{"marginTop": "0.5rem"}}>
                <thead><tr><th>Day</th><th>Task</th><th>Status</th></tr></thead>
                <tbody>
                    {for r in p.rows {
                        <tr key={str(r.day)} style={{"background": STATUS_STYLE.get(r.status, STATUS_STYLE["later"])[0]}}>
                            <td>{"Day " + str(r.day)}</td>
                            <td>{r.task}</td>
                            <td style={{"color": STATUS_STYLE.get(r.status, STATUS_STYLE["later"])[1], "fontWeight": "700", "whiteSpace": "nowrap"}}>
                                {STATUS_STYLE.get(r.status, STATUS_STYLE["later"])[2]}
                            </td>
                        </tr>
                    }}
                </tbody>
            </table>
        </div>;
}

def:pub AdvisorPage(farm: FarmView, lines: list[dict], busy: bool, onSend: Callable[[str, str, str], None]) -> JsxElement {
    has tab: str = "Vaccination plan";
    has only: str = "";

    a = agent_info("advice");
    plans = [p for p in farm.plans if only == "" or p.batch_id == only];
    due_now: list[str] = [];
    for p in farm.plans {
        for r in p.rows {
            if r.status == "today" or r.status == "soon" { due_now.append(p.batch_id + " (day " + str(r.day) + "): " + r.task); }
        }
    }
    def pick_tab(t: str) { tab = t; }
    def pick(v: str) { only = "" if v == only else v; }

    return
        <div>
            <AgentHead icon={a["icon"]} name={a["name"]} job={a["job"]} />
            <div className="km-work">
                <div>
                    <div className="km-tabs">
                        <Tab label="Vaccination plan" current={tab} onPick={pick_tab} />
                        <Tab label="Brooding heat" current={tab} onPick={pick_tab} />
                    </div>

                    {if tab == "Vaccination plan" {
                        <div>
                            <div className="km-card">
                                <h3>Due this week</h3>
                                {if len(due_now) == 0 { <div className="km-muted">Nothing due in the next 7 days.</div> }}
                                <ul className="km-list">{for d in due_now { <li key={d}>{d}</li> }}</ul>
                                <div className="km-small" style={{"marginTop": "0.5rem"}}>Typical Kenyan schedule - confirm vaccines and doses with your vet or hatchery.</div>
                            </div>
                            <div style={{"marginBottom": "0.6rem"}}>
                                <Pill label="All batches" on={only == ""} onPick={lambda(v: str) { only = ""; }} />
                                {for p in farm.plans { <Pill key={p.batch_id} label={p.batch_id} value={p.batch_id} on={only == p.batch_id} onPick={pick} /> }}
                            </div>
                            {for p in plans { <PlanCard key={p.batch_id} p={p} /> }}
                        </div>
                    }}

                    {if tab == "Brooding heat" {
                        <div>
                            <div className="km-card">
                                <h3>Your batches now</h3>
                                <table className="km-table">
                                    <thead><tr><th>Batch</th><th>Age</th><th>Heat needed</th></tr></thead>
                                    <tbody>
                                        {for p in farm.plans {
                                            <tr key={p.batch_id}><td><strong>{p.label}</strong></td><td>{str(p.age_days) + " days"}</td><td>{p.heat}</td></tr>
                                        }}
                                    </tbody>
                                </table>
                            </div>
                            <div className="km-card">
                                <h3>Brooder temperature guide</h3>
                                <table className="km-table">
                                    <thead><tr><th>Age</th><th>Temperature</th><th>Tip</th></tr></thead>
                                    <tbody>
                                        {for h in HEAT { <tr key={h[0]}><td>{h[0]}</td><td><strong>{h[1]}</strong></td><td>{h[2]}</td></tr> }}
                                    </tbody>
                                </table>
                                <div className="km-muted" style={{"marginTop": "0.6rem"}}>
                                    Watch the chicks: crowding under the heater = too cold; far from the heater and panting = too hot; spread evenly = just right.
                                </div>
                            </div>
                        </div>
                    }}
                </div>
                <AgentChat agentKey="advice" title="Ask the Advisor" lines={lines} busy={busy}
                           examples={a["examples"]} onSend={onSend} />
            </div>
        </div>;
}
