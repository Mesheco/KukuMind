"""One chat message: the farmer's message, or KukuMind's reply with the agent that answered."""

glob AGENT_NAMES = {
    "report": "Flock records agent",
    "health": "Disease detector",
    "advice": "Advisor",
    "hatchery": "Hatchery agent",
    "feed": "Feed & inventory agent",
    "sales": "Sales & marketing agent",
    "briefing": "Manager - morning briefing",
    "question": "Manager - from all the farm records",
    "system": "KukuMind"
};

glob LEVEL_STYLE = {
    "RED": {"bg": "rgba(248,113,113,0.12)", "border": "#f87171", "label": "RED - URGENT: call the vet"},
    "AMBER": {"bg": "rgba(251,191,36,0.12)", "border": "#fbbf24", "label": "AMBER - watch closely"},
    "GREEN": {"bg": "rgba(74,222,128,0.12)", "border": "#4ade80", "label": "GREEN - looks OK"}
};

def:pub ChatBubble(who: str, text: str, intent: str, level: str, vet_message: str = "", vet_link: str = "") -> JsxElement {
    has copied: bool = False;
    is_farmer = who == "farmer";

    def copy_vet(e: MouseEvent) {
        board: any = navigator.clipboard;
        board.writeText(vet_message);
        copied = True;
    }
    style: dict[str, str] = LEVEL_STYLE.get(level, {"bg": "#16294a", "border": "#2a4468", "label": ""});
    accent: str = style["border"];
    agent = AGENT_NAMES.get(intent, "KukuMind");

    return
        <div style={{"display": "flex", "justifyContent": "flex-end" if is_farmer else "flex-start", "margin": "0.5rem 0"}}>
            <div
                style={{
                    "maxWidth": "82%",
                    "padding": "0.7rem 0.9rem",
                    "borderRadius": "14px",
                    "backgroundColor": "rgba(20,184,166,0.18)" if is_farmer else style["bg"],
                    "border": "1px solid " + ("#14b8a6" if is_farmer else accent),
                    "borderLeft": ("1px solid #14b8a6" if is_farmer else "5px solid " + accent),
                    "whiteSpace": "pre-wrap",
                    "lineHeight": "1.45"
                }}
            >
                {if not is_farmer {
                    <div style={{"fontSize": "0.75rem", "fontWeight": "600", "color": "#94a8c4", "marginBottom": "0.25rem"}}>
                        {"🐔 " + agent}
                    </div>
                }}
                {if level != "" {
                    <div style={{"fontSize": "0.8rem", "fontWeight": "700", "color": accent, "marginBottom": "0.3rem"}}>
                        {style["label"]}
                    </div>
                }}
                <div>{text}</div>
                {if vet_message != "" {
                    <div style={{"marginTop": "0.6rem", "padding": "0.6rem", "background": "#10213a", "border": "1px dashed #f87171", "borderRadius": "10px"}}>
                        <div style={{"fontSize": "0.8rem", "fontWeight": "700", "color": "#fca5a5", "marginBottom": "0.3rem"}}>📋 Message for the vet (ready to send)</div>
                        <div style={{"fontSize": "0.8rem", "color": "#c8d4e6", "whiteSpace": "pre-wrap", "lineHeight": "1.4"}}>{vet_message}</div>
                        <div style={{"display": "flex", "gap": "0.4rem", "marginTop": "0.5rem", "flexWrap": "wrap"}}>
                            <a href={vet_link} target="_blank" rel="noopener noreferrer"
                               style={{"padding": "0.35rem 0.7rem", "borderRadius": "8px", "background": "#25d366", "color": "#ffffff", "textDecoration": "none", "fontSize": "0.8rem", "fontWeight": "700"}}>
                                Send to vet on WhatsApp
                            </a>
                            <button onClick={copy_vet}
                               style={{"padding": "0.35rem 0.7rem", "borderRadius": "8px", "border": "1px solid #2a4468", "background": "#10213a", "fontSize": "0.8rem", "cursor": "pointer"}}>
                                {"Copied ✔" if copied else "Copy message"}
                            </button>
                        </div>
                    </div>
                }}
            </div>
        </div>;
}
