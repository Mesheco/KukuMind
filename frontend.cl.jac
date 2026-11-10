"""KukuMind web page: a menu of the 7 agents on the left; the home page or one agent's own workspace on the right."""

import from .components.ui { Styles }
import from .components.AgentsPanel { NavPanel }
import from .components.Landing { Landing }
import from .components.ManagerPage { ManagerPage }
import from .components.FlockPage { FlockPage }
import from .components.HealthPage { HealthPage }
import from .components.HatcheryPage { HatcheryPage }
import from .components.AdvisorPage { AdvisorPage }
import from .components.FeedPage { FeedPage }
import from .components.SalesPage { SalesPage }
import from .components.ResetFarm { ResetFarm }

sv import from farm {
    ChatReply, FarmView, chat, agent_chat, farm_status
}

def line(who: str, text: str, intent: str = "", level: str = "", vet: str = "", vet_link: str = "") -> dict {
    return {"who": who, "text": text, "intent": intent, "level": level, "vet": vet, "vet_link": vet_link};
}

# A copy of the chat lists with one agent's list replaced (React needs a new object to redraw)
def with_lines(d: dict[str, list[dict]], key: str, value: list[dict]) -> dict[str, list[dict]] {
    out: any = Object.assign({}, d);
    out[key] = value;
    return out;  # jac:ignore[E1002]
}

def:pub app -> JsxElement {
    has page: str = "home";
    has farm: FarmView | None = None;
    has chats: dict[str, list[dict]] = {};
    has busy_agent: str = "";
    has lang: str = "English";
    has resetting: bool = False;     # the Reset farm window is open      # language for every reply (Auto = same as the message)

    async can with entry {
        document.title = "KukuMind - your AI farm team";
        icon: any = document.querySelector("link[rel='icon']");
        if not icon {
            icon = document.createElement("link");
            icon.rel = "icon";
            head: any = document.head;
            head.appendChild(icon);
        }
        icon.href = "/static/favicon.png";
        await load_farm();
    }

    async def load_farm() {
        res = root spawn farm_status();
        if res.reports and len(res.reports) > 0 { farm = res.reports[0]; }
    }

    def set_farm(f: FarmView) { farm = f; }

    def lines_of(agent: str) -> list[dict] {
        return chats[agent] if agent in chats else [];
    }

    # Send a message to one agent (the Manager passes it on to the right agent)
    async def send(agent: str, text: str, photo: str) {
        if busy_agent != "" { return; }
        shown = text if text.strip() != "" else "(photo)";
        if photo != "" { shown = shown + "  📷"; }
        cur = lines_of(agent) + [line("farmer", shown)];
        chats = with_lines(chats, agent, cur);
        busy_agent = agent;
        try {
            reps: list[ChatReply] = [];
            if agent == "manager" {
                rm = root spawn chat(text=text, photo=photo, language=lang);
                reps = rm.reports;
            } else {
                ra = root spawn agent_chat(agent=agent, text=text, photo=photo, language=lang);
                reps = ra.reports;
            }
            if len(reps) > 0 {
                r = reps[0];
                cur = cur + [line("kukumind", r.reply, r.intent, r.level, r.vet_message, r.vet_link)];
            }
        } except Exception as e {
            cur = cur + [line("kukumind", "Samahani - something went wrong. Please try again.", "system")];
        }
        chats = with_lines(chats, agent, cur);
        busy_agent = "";
        await load_farm();
    }

    def open_page(p: str) {
        page = p;
        win: any = window;
        win.scrollTo(0, 0);
    }
    def go_home(e: MouseEvent) { open_page("home"); }
    def after_reset(f: FarmView) {
        farm = f;
        chats = {};
        resetting = False;
        open_page("home");
    }

    red = len([b for b in (farm as FarmView).batches if b.health == "RED"]) if farm is not None else 0;

    return
        <div className="km-app">
            <Styles />
            <header className="km-header">
                <div className="km-brand" onClick={go_home}>
                    <img src="/static/logo-mark.png" alt="KukuMind logo" />
                    <div>
                        <div className="km-name"><span style={{"color": "#2dd4bf"}}>Kuku</span><span>Mind</span></div>
                        <div className="km-tag">Your AI farm team, from egg to market</div>
                    </div>
                </div>
                {if farm is not None {
                    <span className="km-chip">{"🏡 " + (farm as FarmView).name}</span>
                }}
                <button className="km-reset" onClick={lambda(e: MouseEvent) { resetting = True; }} title="Start again: demo farm or your own empty farm">⟳ Reset farm</button>
                <label className="km-lang" title="Language KukuMind replies in">
                    🌐
                    <select value={lang} onChange={lambda(e: ChangeEvent) { lang = str(e.target.value); }}>
                        <option value="English">English</option>
                        <option value="Kiswahili">Kiswahili</option>
                        <option value="Sheng">Sheng</option>
                        <option value="Auto">Same as my message</option>
                    </select>
                </label>
            </header>

            <div className="km-shell">
                <aside className="km-side">
                    <NavPanel page={page} onOpen={open_page} red={red} />
                </aside>
                <main className="km-main">
                    {if farm is None {
                        <div className="km-card">Loading the farm...</div>
                    } elif page == "home" {
                        <Landing farm={farm} onOpen={open_page} />
                    } elif page == "manager" {
                        <ManagerPage lang={lang} farm={farm as FarmView} onFarm={set_farm} lines={lines_of("manager")} busy={busy_agent == "manager"} onSend={send} onOpen={open_page} />
                    } elif page == "report" {
                        <FlockPage farm={farm as FarmView} onFarm={set_farm} lines={lines_of("report")} busy={busy_agent == "report"} onSend={send} />
                    } elif page == "health" {
                        <HealthPage lang={lang} farm={farm as FarmView} onFarm={set_farm} lines={lines_of("health")} busy={busy_agent == "health"} onSend={send} />
                    } elif page == "hatchery" {
                        <HatcheryPage farm={farm as FarmView} onFarm={set_farm} lines={lines_of("hatchery")} busy={busy_agent == "hatchery"} onSend={send} language={lang} />
                    } elif page == "advice" {
                        <AdvisorPage farm={farm as FarmView} lines={lines_of("advice")} busy={busy_agent == "advice"} onSend={send} />
                    } elif page == "feed" {
                        <FeedPage farm={farm as FarmView} onFarm={set_farm} lines={lines_of("feed")} busy={busy_agent == "feed"} onSend={send} />
                    } else {
                        <SalesPage lang={lang} farm={farm as FarmView} onFarm={set_farm} lines={lines_of("sales")} busy={busy_agent == "sales"} onSend={send} />
                    }}
                </main>
            </div>

            {if resetting {
                <ResetFarm onDone={after_reset} onClose={lambda { resetting = False; }} />
            }}
            <footer className="km-footer">
                KukuMind never prescribes medicine. For RED alerts, call a vet or the county veterinary officer. · Built with <b>Jac</b> + Claude
            </footer>
        </div>;
}
