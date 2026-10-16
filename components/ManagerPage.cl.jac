"""Manager page: team chat (routes every message), morning briefing, today's plan and alerts, dashboard, records."""

import from .ui { AgentHead, Tab, Notice, join_words }
import from .AgentChat { AgentChat }
import from .AgentsPanel { agent_info, all_agents }
import from .FarmPanel { FarmPanel }
import from .RecordsTable { RecordsTable }

sv import from ..farm { FarmView, briefing, next_day, clear_batch, start_fresh }

def:pub ManagerPage(lang: str, farm: FarmView, onFarm: Callable[[FarmView], None], lines: list[dict], busy: bool,
                    onSend: Callable[[str, str, str], None], onOpen: Callable[[str], None]) -> JsxElement {
    has tab: str = "Morning briefing";
    has brief: str = "";
    has brief_lang: str = "";
    has writing: bool = False;
    has msg: str = "";

    a = agent_info("manager");
    red = [b for b in farm.batches if b.health == "RED"];

    async def get_brief(lang: str) {
        writing = True;
        brief_lang = lang;
        res = root spawn briefing(language=lang);
        if res.reports and len(res.reports) > 0 { brief = res.reports[0].reply; }
        writing = False;
    }
    async def go_next_day() {
        res = root spawn next_day();
        if res.reports and len(res.reports) > 0 { onFarm(res.reports[0]); }
        msg = "A new day has started: every batch and egg set is one day older.";
    }
    async def vet_cleared(bid: str) {
        res = root spawn clear_batch(batch_id=bid);
        if res.reports and len(res.reports) > 0 { onFarm(res.reports[0]); }
        msg = bid + " cleared by the vet. Sales are allowed again.";
    }
    async def go_fresh() {
        win: any = window;
        if not win.confirm("Clear ALL records (reports, sales, health checks, egg sets) and start the farm again?") { return; }
        res = root spawn start_fresh();
        if res.reports and len(res.reports) > 0 { onFarm(res.reports[0]); }
        msg = "All records cleared. The farm starts again with no reports, sales or health checks.";
        brief = "";
    }
    def pick_tab(t: str) { tab = t; }

    return
        <div>
            <AgentHead icon={a["icon"]} name={a["name"]} job={a["job"]} />
            <div className="km-work">
                <div>
                    <div className="km-tabs">
                        <Tab label="Morning briefing" current={tab} onPick={pick_tab} />
                        <Tab label="Today's plan" current={tab} onPick={pick_tab} />
                        <Tab label="Dashboard" current={tab} onPick={pick_tab} />
                        <Tab label="Records" current={tab} onPick={pick_tab} />
                    </div>
                    <Notice text={msg} ok={True} />
                    <div style={{"height": "0.6rem"}}></div>

                    {if tab == "Morning briefing" {
                        <div className="km-card">
                            <h3>{"Good morning, " + farm.owner}</h3>
                            <div className="km-small" style={{"marginTop": "-0.4rem", "marginBottom": "0.5rem"}}>{farm.name + (" · " + farm.phone if farm.phone != "" else "")}</div>
                            <div className="km-muted" style={{"marginBottom": "0.7rem"}}>
                                The Manager asks every agent for its news (health, tasks, feed, market) and writes one short briefing.
                            </div>
                            <div style={{"display": "flex", "gap": "0.5rem", "flexWrap": "wrap", "alignItems": "center"}}>
                                <button className="km-btn primary" disabled={writing}
                                        onClick={lambda(e: MouseEvent) { get_brief(lang if lang != "Auto" else "English"); }}>
                                    {"☀ Write today's briefing (" + (lang if lang != "Auto" else "English") + ")"}
                                </button>
                                <span className="km-small">Other language:</span>
                                {for l in ["English", "Kiswahili", "Sheng"] {
                                    <button key={l} className="km-btn small" disabled={writing} onClick={lambda(e: MouseEvent) { get_brief(l); }}>{l}</button>
                                }}
                            </div>
                            {if writing { <div className="km-muted" style={{"marginTop": "0.7rem"}}>The team is reporting to the Manager...</div> }}
                            {if brief != "" and not writing {
                                <div className="km-notice ok" style={{"fontSize": "0.95rem"}}>{"🧭 (" + brief_lang + ")\n" + brief}</div>
                            }}
                        </div>
                    }}

                    {if tab == "Today's plan" {
                        <div>
                            {if len(red) > 0 {
                                <div className="km-notice bad" style={{"marginTop": "0", "marginBottom": "0.8rem"}}>
                                    {"🚨 " + join_words([b.batch_id for b in red]) + " on RED alert - open the Disease detector."}
                                </div>
                            }}
                            <div className="km-card">
                                <h3>Today's tasks</h3>
                                {if len(farm.tasks) == 0 { <div className="km-muted">Nothing due today.</div> }}
                                <ul className="km-list">{for t in farm.tasks { <li key={t}>{t}</li> }}</ul>
                            </div>
                            <div className="km-card">
                                <h3>Alerts from the agents</h3>
                                {if len(farm.alerts) == 0 { <div className="km-muted">✓ No alerts. The records look normal.</div> }}
                                <ul className="km-list" style={{"color": "#fca5a5"}}>{for x in farm.alerts { <li key={x}>{x}</li> }}</ul>
                            </div>
                            <div className="km-card">
                                <h3>Go to an agent</h3>
                                <div className="km-grid3">
                                    {for g in all_agents()[1:] {
                                        <button key={g["key"]} className="km-btn" onClick={lambda(e: MouseEvent) { onOpen(str(g["key"])); }}>{g["icon"] + " " + g["name"]}</button>
                                    }}
                                </div>
                            </div>
                        </div>
                    }}

                    {if tab == "Dashboard" {
                        <div className="km-card">
                            <FarmPanel farm={farm} onNextDay={lambda { go_next_day(); }} onClear={lambda(b: str) { vet_cleared(b); }} onFresh={lambda { go_fresh(); }} />
                        </div>
                    }}

                    {if tab == "Records" {
                        <RecordsTable records={farm.records} />
                    }}
                </div>
                <AgentChat agentKey="manager" title="Team chat - the Manager passes it on" lines={lines} busy={busy}
                           examples={a["examples"]} onSend={onSend} allowPhoto={True} />
            </div>
        </div>;
}
