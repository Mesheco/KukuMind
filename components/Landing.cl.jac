"""Home page: what KukuMind is, the problem it solves, the 7 agents, and the farm today."""

import from .AgentsPanel { all_agents }
import from .ui { Stat }
import from .Charts { money }
import from .FarmPanel { BirdCount }

sv import from ..farm { FarmView }

def:pub AgentCard(a: dict, onOpen: Callable[[str], None]) -> JsxElement {
    def open(e: MouseEvent) { onOpen(str(a["key"])); }
    does: list[str] = a["does"];  # jac:ignore[E1001]
    return
        <button className="km-agent" onClick={open}>
            <div style={{"display": "flex", "alignItems": "center", "gap": "0.55rem"}}>
                <span className="km-nav-icon" style={{"width": "2.4rem", "height": "2.4rem", "fontSize": "1.3rem"}}>{a["icon"]}</span>
                <strong style={{"fontSize": "0.98rem"}}>{a["name"]}</strong>
            </div>
            <div className="km-muted">{a["job"]}</div>
            <ul>
                {for d in does { <li key={d}>{d}</li> }}
            </ul>
            <span className="km-open">Open →</span>
        </button>;
}

def:pub Problem(icon: str, title: str, text: str, fix: str) -> JsxElement {
    return
        <div className="km-card km-problem" style={{"marginBottom": "0"}}>
            <div style={{"fontSize": "1.4rem"}}>{icon}</div>
            <strong>{title}</strong>
            <div className="km-muted" style={{"margin": "0.3rem 0"}}>{text}</div>
            <div style={{"fontSize": "0.82rem", "color": "#4ade80", "fontWeight": "600"}}>{"✓ " + fix}</div>
        </div>;
}

def:pub HowStep(num: str, title: str, text: str) -> JsxElement {
    return
        <div style={{"display": "flex", "gap": "0.6rem"}}>
            <span style={{"background": "#14b8a6", "color": "#0a1628", "borderRadius": "50%", "width": "1.8rem", "height": "1.8rem", "flexShrink": "0",
                          "display": "flex", "alignItems": "center", "justifyContent": "center", "fontWeight": "800"}}>{num}</span>
            <div><strong style={{"fontSize": "0.9rem"}}>{title}</strong><div className="km-muted">{text}</div></div>
        </div>;
}

def:pub Landing(farm: FarmView | None, onOpen: Callable[[str], None]) -> JsxElement {
    def go_manager(e: MouseEvent) { onOpen("manager"); }
    def go_health(e: MouseEvent) { onOpen("health"); }
    def go_records(e: MouseEvent) { onOpen("report"); }

    return
        <div>
            <section className="km-hero">
                <img src="/static/logo-mark.png" alt="KukuMind" />
                <div>
                    <span className="km-eyebrow">7 AI agents · built with Jac · English · Kiswahili · Sheng</span>
                    <h1>Your AI farm team, <span>from egg to market</span></h1>
                    <p>
                        KukuMind gives a poultry farm of 500 - 5,000 birds a team of seven AI agents. Workers send a message or a photo,
                        in English, Kiswahili or Sheng, and the right agent keeps the records, spots disease early, runs the incubator,
                        plans vaccines, watches the feed and finds buyers.
                    </p>
                    <div style={{"display": "flex", "gap": "0.5rem", "flexWrap": "wrap", "justifyContent": "inherit"}}>
                        <button className="km-btn primary" onClick={go_manager}>💬 Talk to the farm team</button>
                        <button className="km-btn ghost" onClick={go_health}>📷 Check a sick bird</button>
                        <button className="km-btn ghost" onClick={go_records}>📒 Record today's report</button>
                    </div>
                </div>
            </section>

            <h3 className="km-section-title">The problem on Kenyan poultry farms</h3>
            <div className="km-grid3" style={{"marginBottom": "1rem"}}>
                <Problem icon="🦠" title="Disease is noticed too late"
                         text="By the time many birds are dying, a whole batch can be lost."
                         fix="The Disease detector checks photos and the records every day." />
                <Problem icon="🌾" title="Feed runs out without warning"
                         text="Feed is the biggest cost, and wastage goes unseen."
                         fix="Feed & inventory counts days left and flags waste." />
                <Problem icon="📓" title="Records live in exercise books"
                         text="Nobody knows the real deaths, sales or profit per batch."
                         fix="Every message becomes a record; the maths is automatic." />
            </div>

            <div className="km-card">
                <h3>How it works</h3>
                <div className="km-grid3">
                    <HowStep num="1" title="Send a message or photo" text="Like WhatsApp: 'B1 leo vifo 2, chakula gunia moja'." />
                    <HowStep num="2" title="The Manager passes it on" text="It picks the right agent, or open any agent's page directly." />
                    <HowStep num="3" title="The agent does the work" text="Saves records, checks health, updates feed, sales and profit." />
                </div>
            </div>

            <h3 className="km-section-title">Meet your farm team</h3>
            <div className="km-grid3" style={{"marginBottom": "1rem"}}>
                {for a in all_agents() {
                    <AgentCard key={a["key"]} a={a} onOpen={onOpen} />
                }}
            </div>

            {if farm is not None {
                <div className="km-card">
                    <h3>{"Your farm today - " + (farm as FarmView).name}</h3>
                    <div className="km-small" style={{"marginTop": "-0.4rem", "marginBottom": "0.7rem"}}>
                        {"Owner: " + (farm as FarmView).owner + ((" · " + (farm as FarmView).phone) if (farm as FarmView).phone != "" else "") + " · Vet: " + (farm as FarmView).vet_name + " · " + (farm as FarmView).vet_phone}
                    </div>
                    <div className="km-grid4" style={{"marginBottom": "0.8rem"}}>
                        <Stat label="Birds alive" value={money(float((farm as FarmView).birds_alive))} note={str(len((farm as FarmView).batches)) + " batches"} />
                        <Stat label="Health alerts" value={str(len([b for b in (farm as FarmView).batches if b.health == "RED"])) + " RED"}
                              colour={"#f87171" if len([b for b in (farm as FarmView).batches if b.health == "RED"]) > 0 else "#4ade80"} />
                        <Stat label="Feed lasts" value={str((farm as FarmView).feed_days) + " days"} note={money((farm as FarmView).feed_kg) + " kg in store"}
                              colour={"#f87171" if (farm as FarmView).feed_days < 3 else "#e6edf7"} />
                        <Stat label="Profit" value={"KSh " + money((farm as FarmView).balance)} note={"sales KSh " + money((farm as FarmView).income) + " − costs"}
                              colour={"#4ade80" if (farm as FarmView).balance >= 0 else "#f87171"} />
                    </div>
                    <BirdCount start={(farm as FarmView).start_total} dead={(farm as FarmView).dead_total} sold={(farm as FarmView).sold_total}
                               alive={(farm as FarmView).birds_alive} ok={(farm as FarmView).count_ok} />
                    <strong style={{"fontSize": "0.88rem"}}>Today's plan</strong>
                    <ul className="km-list">
                        {for t in (farm as FarmView).tasks[:6] { <li key={t}>{t}</li> }}
                        {if len((farm as FarmView).tasks) == 0 { <li>No tasks due today.</li> }}
                    </ul>
                </div>
            }}
        </div>;
}
