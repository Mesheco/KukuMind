"""The KukuMind team: who the 7 agents are, and the left-hand menu that opens each agent's page."""

glob AGENTS: list[dict] = [
    {"key": "manager", "icon": "🧭", "name": "Manager", "short": "Team chat & briefing",
     "job": "The front door. Reads every message, passes it to the right agent, and writes the morning briefing.",
     "does": ["Routes any message in English, Kiswahili or Sheng", "Morning briefing for the owner", "Today's plan and farm-wide alerts"],
     "examples": ["Habari ya shamba leo?", "B1 leo vifo mbili, chakula gunia moja", "Sold 50 B3 layers at 450 each to Mama Njeri"]},
    {"key": "report", "icon": "📒", "name": "Flock records", "short": "Reports & new flocks",
     "job": "Saves daily reports (deaths, feed, eggs, weight), registers new flocks and keeps every bird counted.",
     "does": ["Daily report form or one-line message", "Register bought chicks as a new batch", "Start − dead − sold = alive for every batch"],
     "examples": ["B1 leo vifo mbili, chakula gunia moja", "Tumeleta vifaranga 500 wa broiler leo, House B", "B3 mayai trei 35, kuku moja imekufa"]},
    {"key": "health", "icon": "🩺", "name": "Disease detector", "short": "Diagnose · monitor · research",
     "job": "Checks sick birds from the camera or symptoms, watches the records for early warnings, and explains diseases.",
     "does": ["Camera / photo check with RED · AMBER · GREEN", "Monitors deaths, feed and egg drops", "Disease library and a ready message for the vet"],
     "examples": ["Kuku za B2 zinakohoa na zingine zimepinda shingo", "Chicks in B1 have white watery droppings", "What is Newcastle disease?"]},
    {"key": "hatchery", "icon": "🥚", "name": "Hatchery", "short": "Incubator to chicks",
     "job": "Runs the incubator: eggs set, candling on day 7 and 14, lockdown day 18, hatch day 21.",
     "does": ["Track every egg set day by day", "Record candling and hatch results", "Hatched chicks become a new batch"],
     "examples": ["Nimeweka mayai 200 ya kienyeji kwa incubator", "E1 candling: 270 fertile", "When do I stop turning the eggs?"]},
    {"key": "advice", "icon": "🌡️", "name": "Advisor", "short": "Vaccines & brooding",
     "job": "Vaccination plan and brooder heat for each batch's age, and answers to how-to questions.",
     "does": ["Vaccination plan per batch (done, today, soon)", "Correct brooder temperature by age", "Answers care questions"],
     "examples": ["When is the Gumboro vaccine for B1?", "Vifaranga wa B1 wanahitaji joto kiasi gani?", "How much space do layers need?"]},
    {"key": "feed", "icon": "🌾", "name": "Feed & inventory", "short": "Stock, use & orders",
     "job": "Tracks the feed store, how much each batch should eat, wastage, and when to order.",
     "does": ["Days of feed left and order alerts", "Feed per batch: expected vs used", "Feed deliveries and price per kg"],
     "examples": ["Msosi itatosha siku ngapi?", "Is B2 eating too much?", "How many bags should I order this week?"]},
    {"key": "sales", "icon": "💰", "name": "Sales & marketing", "short": "Sales, buyers & profit",
     "job": "Records sales, finds what is ready for market, writes messages to buyers, and shows profit per batch.",
     "does": ["Record bird and egg sales", "WhatsApp offers to buyers", "Profit per batch (sales − feed)"],
     "examples": ["Sold 50 B3 layers at 450 each to Mama Njeri", "Tumeuza mayai trei 20 kwa 420", "Is B2 making money?"]}
];

# Globals are not shared between client files, so other pages ask for the list
def:pub all_agents() -> list[dict] {
    return AGENTS;
}

def:pub agent_info(key: str) -> dict {
    for a in AGENTS {
        if a["key"] == key { return a; }
    }
    return AGENTS[0];
}

def:pub NavItem(icon: str, name: str, sub: str, on: bool, badge: str, onPick: Callable[[], None]) -> JsxElement {
    def pick(e: MouseEvent) { onPick(); }
    return
        <button className={"km-nav-item" + (" on" if on else "")} onClick={pick}>
            <span className="km-nav-icon">{icon}</span>
            <span>
                <div style={{"fontWeight": "700"}}>{name}</div>
                <div className="km-nav-sub">{sub}</div>
            </span>
            {if badge != "" { <span className="km-badge">{badge}</span> }}
        </button>;
}

def:pub NavPanel(page: str, onOpen: Callable[[str], None], red: int) -> JsxElement {
    return
        <nav className="km-nav">
            <NavItem icon="🏠" name="Home" sub="What KukuMind does" on={page == "home"} badge="" onPick={lambda { onOpen("home"); }} />
            <div className="km-nav-title">YOUR AI FARM TEAM</div>
            {for a in AGENTS {
                <NavItem key={a["key"]} icon={a["icon"]} name={a["name"]} sub={a["short"]} on={page == a["key"]}
                         badge={str(red) + " RED" if a["key"] == "health" and red > 0 else ""}
                         onPick={lambda { onOpen(str(a["key"])); }} />
            }}
        </nav>;
}
