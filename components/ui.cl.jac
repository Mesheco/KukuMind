"""Shared look for every KukuMind page: styles, cards, tabs, form fields, notices."""

# One stylesheet for the whole app (class names start with km-)
glob CSS = """
:root {
  --navy-900: #071224; --navy-800: #0a1628; --navy-700: #10213a; --navy-600: #16294a; --navy-500: #1c3152;
  --line: #22385c; --line-2: #2a4468;
  --text: #e6edf7; --muted: #94a8c4; --subtle: #6f84a3;
  --teal: #14b8a6; --teal-2: #2dd4bf; --teal-soft: rgba(20,184,166,0.14);
  --gold: #f2b84b; --gold-soft: rgba(242,184,75,0.14);
  --ok: #4ade80; --warn: #fbbf24; --bad: #f87171;
}
* { box-sizing: border-box; }
html, body { margin: 0; background: var(--navy-800); color: var(--text); }
::selection { background: rgba(45,212,191,0.35); }
.km-app { font-family: 'Inter', system-ui, -apple-system, 'Segoe UI', sans-serif; color: var(--text); min-height: 100vh;
  background: radial-gradient(1200px 600px at 85% -10%, rgba(20,184,166,0.10), transparent 60%),
              radial-gradient(900px 500px at -10% 10%, rgba(242,184,75,0.05), transparent 55%), var(--navy-800); }
.km-header { background: rgba(7,18,36,0.82); backdrop-filter: blur(10px); border-bottom: 1px solid var(--line); padding: 0.6rem 1.4rem; display: flex; align-items: center; gap: 0.8rem; position: sticky; top: 0; z-index: 10; }
.km-brand { display: flex; align-items: center; gap: 0.7rem; cursor: pointer; flex: 1; }
.km-brand img { height: 46px; background: #fff; border-radius: 50%; padding: 2px; box-shadow: 0 0 0 2px var(--line-2); }
.km-name { font-size: 1.4rem; font-weight: 800; line-height: 1; letter-spacing: -0.01em; color: #fff; }
.km-tag { font-size: 0.78rem; color: var(--muted); }
.km-lang { display: flex; align-items: center; gap: 0.3rem; font-size: 0.85rem; background: var(--navy-600); border: 1px solid var(--line-2); border-radius: 999px; padding: 0.25rem 0.6rem; }
.km-lang select { border: none; background: transparent; font: inherit; font-size: 0.82rem; color: var(--teal-2); font-weight: 700; cursor: pointer; }
.km-lang select option { background: var(--navy-700); color: var(--text); }
.km-chip { font-size: 0.75rem; background: var(--gold-soft); color: var(--gold); border: 1px solid rgba(242,184,75,0.3); border-radius: 999px; padding: 0.3rem 0.7rem; white-space: nowrap; }
.km-shell { display: flex; gap: 1.1rem; padding: 1.1rem; max-width: 1400px; margin: 0 auto; align-items: flex-start; }
.km-side { width: 252px; flex-shrink: 0; position: sticky; top: 84px; }
.km-main { flex: 1; min-width: 0; }
.km-nav { background: var(--navy-700); border: 1px solid var(--line); border-radius: 16px; padding: 0.6rem; box-shadow: 0 10px 30px rgba(0,0,0,0.25); }
.km-nav-title { font-size: 0.66rem; font-weight: 700; letter-spacing: 0.12em; color: var(--gold); margin: 0.7rem 0.6rem 0.35rem; }
.km-nav-item { display: flex; align-items: center; gap: 0.6rem; width: 100%; border: 1px solid transparent; background: none; text-align: left; padding: 0.5rem 0.55rem; border-radius: 11px; cursor: pointer; font-size: 0.88rem; color: var(--text); transition: background 0.15s, border-color 0.15s; }
.km-nav-item:hover { background: var(--navy-600); }
.km-nav-item.on { background: var(--teal-soft); border-color: rgba(45,212,191,0.45); color: #fff; box-shadow: inset 3px 0 0 var(--teal-2); }
.km-nav-icon { width: 1.95rem; height: 1.95rem; border-radius: 10px; display: flex; align-items: center; justify-content: center; background: var(--navy-600); border: 1px solid var(--line); font-size: 1.02rem; flex-shrink: 0; }
.km-nav-item.on .km-nav-icon { background: var(--teal); border-color: var(--teal); }
.km-nav-sub { font-size: 0.7rem; color: var(--subtle); }
.km-nav-item.on .km-nav-sub { color: var(--muted); }
.km-badge { white-space: nowrap; margin-left: auto; font-size: 0.65rem; font-weight: 800; border-radius: 999px; padding: 0.12rem 0.45rem; background: var(--bad); color: var(--navy-900); }
.km-card { background: var(--navy-700); border: 1px solid var(--line); border-radius: 16px; padding: 1.05rem 1.15rem; box-shadow: 0 8px 24px rgba(0,0,0,0.22); margin-bottom: 1rem; }
.km-card h3 { margin: 0 0 0.65rem; font-size: 1rem; color: #fff; letter-spacing: -0.005em; }
.km-muted { color: var(--muted); font-size: 0.84rem; }
.km-small { font-size: 0.75rem; color: var(--subtle); }
.km-grid2 { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0.8rem; }
.km-grid3 { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 0.8rem; }
.km-grid4 { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 0.7rem; }
.km-work { display: grid; grid-template-columns: minmax(0, 1fr) 350px; gap: 1rem; align-items: start; }
.km-head { display: flex; align-items: center; gap: 0.95rem; margin-bottom: 1rem; }
.km-head-icon { width: 3.3rem; height: 3.3rem; border-radius: 16px; background: linear-gradient(135deg, var(--teal), #0f766e); color: #fff; display: flex; align-items: center; justify-content: center; font-size: 1.6rem; flex-shrink: 0; box-shadow: 0 8px 22px rgba(20,184,166,0.3); }
.km-head h2 { margin: 0; font-size: 1.45rem; color: #fff; letter-spacing: -0.01em; }
.km-tabs { display: flex; gap: 0.3rem; flex-wrap: wrap; border-bottom: 1px solid var(--line); margin-bottom: 1rem; }
.km-tab { border: none; background: none; padding: 0.6rem 0.95rem; font-size: 0.88rem; cursor: pointer; color: var(--muted); border-bottom: 2px solid transparent; margin-bottom: -1px; font-weight: 600; }
.km-tab:hover { color: var(--text); }
.km-tab.on { color: var(--teal-2); border-bottom-color: var(--teal-2); }
.km-field { display: flex; flex-direction: column; gap: 0.3rem; font-size: 0.8rem; color: var(--muted); font-weight: 600; }
.km-field input, .km-field select, .km-field textarea, .km-input { font: inherit; font-weight: 400; font-size: 0.92rem; padding: 0.6rem 0.7rem; border: 1px solid var(--line-2); border-radius: 10px; background: var(--navy-800); color: var(--text); width: 100%; transition: border-color 0.15s, box-shadow 0.15s; }
.km-field input::placeholder, .km-field textarea::placeholder, .km-input::placeholder { color: #5b6f8e; }
.km-field input:focus, .km-field select:focus, .km-field textarea:focus, .km-input:focus { outline: none; border-color: var(--teal-2); box-shadow: 0 0 0 3px rgba(45,212,191,0.18); }
.km-field select option { background: var(--navy-700); }
.km-field textarea { min-height: 80px; resize: vertical; }
.km-btn { font: inherit; font-weight: 700; font-size: 0.88rem; padding: 0.6rem 1.05rem; border-radius: 10px; border: 1px solid var(--teal); background: transparent; color: var(--teal-2); cursor: pointer; transition: all 0.15s; }
.km-btn:hover { background: var(--teal-soft); }
.km-btn.primary { background: var(--teal); border-color: var(--teal); color: var(--navy-900); box-shadow: 0 6px 18px rgba(20,184,166,0.25); }
.km-btn.primary:hover { background: var(--teal-2); border-color: var(--teal-2); }
.km-btn.danger { border-color: var(--bad); color: var(--bad); }
.km-btn.danger:hover { background: rgba(248,113,113,0.12); }
.km-btn.small { padding: 0.32rem 0.7rem; font-size: 0.78rem; font-weight: 600; }
.km-btn:disabled { opacity: 0.55; cursor: wait; }
.km-pill { display: inline-block; border: 1px solid var(--line-2); background: var(--navy-600); color: var(--text); border-radius: 999px; padding: 0.28rem 0.7rem; font-size: 0.78rem; cursor: pointer; margin: 0 0.3rem 0.35rem 0; transition: all 0.15s; font-family: inherit; }
.km-pill:hover { border-color: var(--teal); color: var(--teal-2); }
.km-pill.on { background: var(--teal); border-color: var(--teal); color: var(--navy-900); font-weight: 700; }
.km-notice { border-radius: 12px; padding: 0.7rem 0.85rem; font-size: 0.86rem; margin-top: 0.7rem; line-height: 1.5; white-space: pre-wrap; color: var(--text); }
.km-notice.ok { background: rgba(74,222,128,0.10); border: 1px solid rgba(74,222,128,0.35); }
.km-notice.bad { background: rgba(248,113,113,0.10); border: 1px solid rgba(248,113,113,0.4); }
.km-stat { background: var(--navy-600); border: 1px solid var(--line); border-radius: 14px; padding: 0.7rem 0.8rem; min-width: 0; position: relative; overflow: hidden; }
.km-stat::before { content: ""; position: absolute; left: 0; top: 0; bottom: 0; width: 3px; background: var(--gold); opacity: 0.85; }
.km-stat-label { font-size: 0.7rem; color: var(--muted); text-transform: uppercase; letter-spacing: 0.06em; font-weight: 600; }
.km-stat-value { font-size: 1.3rem; font-weight: 800; white-space: nowrap; color: #fff; letter-spacing: -0.01em; }
.km-table { width: 100%; border-collapse: collapse; font-size: 0.83rem; }
.km-table th { text-align: left; background: var(--navy-600); padding: 0.5rem 0.6rem; font-size: 0.72rem; color: var(--muted); text-transform: uppercase; letter-spacing: 0.05em; }
.km-table td { padding: 0.5rem 0.6rem; border-top: 1px solid var(--line); vertical-align: top; color: var(--text); }
.km-table tr:hover td { background: rgba(45,212,191,0.04); }
.km-level { display: inline-block; font-weight: 800; font-size: 0.72rem; border-radius: 999px; padding: 0.15rem 0.6rem; color: var(--navy-900); }
.km-list { margin: 0.3rem 0 0; padding-left: 1.1rem; font-size: 0.87rem; line-height: 1.6; }
.km-chat { display: flex; flex-direction: column; height: 72vh; min-height: 380px; position: sticky; top: 84px; }
.km-chat-body { flex: 1; overflow-y: auto; background: var(--navy-800); border: 1px solid var(--line); border-radius: 12px; padding: 0.35rem 0.55rem; }
.km-hero { background: linear-gradient(135deg, #0c1f3b 0%, #0f2a4a 45%, #0b3b47 100%); border: 1px solid var(--line-2); color: #fff; border-radius: 22px; padding: 2rem 2.1rem; display: flex; gap: 1.8rem; align-items: center; margin-bottom: 1.2rem; position: relative; overflow: hidden; box-shadow: 0 20px 50px rgba(0,0,0,0.35); }
.km-hero::after { content: ""; position: absolute; right: -120px; top: -120px; width: 360px; height: 360px; border-radius: 50%; background: radial-gradient(circle, rgba(45,212,191,0.22), transparent 70%); }
.km-hero img { width: 150px; height: 150px; background: #fff; border-radius: 50%; padding: 8px; flex-shrink: 0; box-shadow: 0 0 0 6px rgba(45,212,191,0.18), 0 0 0 1px rgba(242,184,75,0.6); position: relative; z-index: 1; }
.km-hero > div { position: relative; z-index: 1; }
.km-eyebrow { display: inline-block; font-size: 0.72rem; font-weight: 700; letter-spacing: 0.12em; color: var(--gold); text-transform: uppercase; margin-bottom: 0.5rem; }
.km-hero h1 { margin: 0 0 0.5rem; font-size: 2.1rem; line-height: 1.12; letter-spacing: -0.02em; }
.km-hero h1 span { color: var(--teal-2); }
.km-hero p { margin: 0 0 1.1rem; font-size: 1rem; color: #c8d4e6; line-height: 1.6; max-width: 720px; }
.km-hero .km-btn.ghost { background: transparent; color: #fff; border-color: rgba(255,255,255,0.35); }
.km-hero .km-btn.ghost:hover { border-color: var(--teal-2); color: var(--teal-2); }
.km-agent { background: var(--navy-700); border: 1px solid var(--line); border-radius: 16px; padding: 1rem; cursor: pointer; display: flex; flex-direction: column; gap: 0.4rem; transition: all 0.18s; text-align: left; font: inherit; color: inherit; }
.km-agent:hover { border-color: var(--teal); box-shadow: 0 12px 30px rgba(20,184,166,0.18); transform: translateY(-3px); }
.km-agent ul { margin: 0.2rem 0 0; padding-left: 1rem; font-size: 0.78rem; color: var(--muted); line-height: 1.5; }
.km-open { margin-top: auto; font-size: 0.8rem; font-weight: 700; color: var(--teal-2); }
.km-problem { border-left: 3px solid var(--gold); }
.km-section-title { margin: 0.6rem 0 0.7rem; font-size: 1.05rem; color: #fff; }
.km-progress { height: 10px; background: var(--navy-500); border-radius: 999px; overflow: hidden; position: relative; }
.km-progress > div { height: 100%; background: linear-gradient(90deg, var(--teal), var(--gold)); border-radius: 999px; }
.km-video { width: 100%; max-height: 300px; background: #000; border-radius: 12px; object-fit: cover; }
.km-photo { width: 100%; max-height: 300px; object-fit: contain; border-radius: 12px; background: var(--navy-800); }
.km-modal-back { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(4,10,20,0.72); backdrop-filter: blur(4px); z-index: 50; display: flex; align-items: flex-start; justify-content: center; padding: 5vh 16px; overflow-y: auto; }
.km-modal { max-width: 680px; width: 100%; margin: 0; box-shadow: 0 30px 80px rgba(0,0,0,0.5); }
.km-picked { border-color: var(--teal-2); box-shadow: 0 0 0 2px rgba(45,212,191,0.35); background: var(--teal-soft); }
.km-reset { font: inherit; font-size: 0.8rem; font-weight: 600; border: 1px solid var(--line-2); background: var(--navy-600); color: var(--text); border-radius: 999px; padding: 0.35rem 0.75rem; cursor: pointer; white-space: nowrap; }
.km-reset:hover { border-color: var(--teal-2); color: var(--teal-2); }
.km-footer { text-align: center; font-size: 0.75rem; color: var(--subtle); padding: 0 1rem 1.4rem; }
.km-footer b { color: var(--gold); font-weight: 600; }
::-webkit-scrollbar { width: 10px; height: 10px; }
::-webkit-scrollbar-thumb { background: var(--line-2); border-radius: 999px; border: 2px solid var(--navy-800); }
::-webkit-scrollbar-track { background: transparent; }
@media (max-width: 1100px) { .km-work { grid-template-columns: minmax(0, 1fr); } .km-chat { position: static; height: 60vh; } }
@media (max-width: 860px) {
  .km-shell { flex-direction: column; padding: 0.6rem; align-items: stretch; }
  .km-main { width: 100%; }
  .km-stat-value { font-size: 1.05rem; white-space: normal; }
  .km-header { padding: 0.45rem 0.7rem; }
  .km-chip { display: none; }
  .km-lang { padding: 0.2rem 0.4rem; flex-shrink: 0; }
  .km-lang select { max-width: 92px; font-size: 0.78rem; }
  .km-brand { min-width: 0; }
  .km-brand > div { min-width: 0; }
  .km-tag { display: none; }
  .km-reset { padding: 0.3rem 0.55rem; font-size: 0.75rem; }
  .km-brand img { height: 38px; }
  .km-work { gap: 0.6rem; }
  .km-side { width: 100%; position: static; }
  .km-nav { display: flex; overflow-x: auto; gap: 0.3rem; }
  .km-nav-title, .km-nav-sub { display: none; }
  .km-nav-item { width: auto; white-space: nowrap; }
  .km-grid3, .km-grid4 { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .km-hero { flex-direction: column; text-align: center; padding: 1.3rem; }
  .km-hero img { width: 110px; height: 110px; }
  .km-hero h1 { font-size: 1.6rem; }
}
""";


glob LEVEL_COLOUR = {"RED": "#f87171", "AMBER": "#fbbf24", "GREEN": "#4ade80"};

# Text from a form box -> number (empty or wrong text = 0)
def:pub num(s: str) -> float {
    v = parseFloat(s);
    if v != v { return 0.0; }
    return v;
}

# "a, b, c" (str.join is not available in the browser)
def:pub join_words(items: list[str], sep: str = ", ") -> str {
    out = "";
    for (i, x) in enumerate(items) {
        out = out + (sep if i > 0 else "") + x;
    }
    return out;
}

def:pub Styles() -> JsxElement {
    return <style>{CSS}</style>;
}

def:pub Stat(label: str, value: str, note: str = "", colour: str = "#ffffff") -> JsxElement {
    return
        <div className="km-stat">
            <div className="km-stat-label">{label}</div>
            <div className="km-stat-value" style={{"color": colour}}>{value}</div>
            {if note != "" { <div className="km-small">{note}</div> }}
        </div>;
}

def:pub Level(level: str) -> JsxElement {
    return <span className="km-level" style={{"background": LEVEL_COLOUR.get(level, "#7a8a72")}}>{level if level != "" else "-"}</span>;
}

def:pub Notice(text: str, ok: bool) -> JsxElement {
    if text == "" { return <span></span>; }
    return <div className={"km-notice " + ("ok" if ok else "bad")}>{("✅ " if ok else "⚠ ") + text}</div>;
}

def:pub AgentHead(icon: str, name: str, job: str) -> JsxElement {
    return
        <div className="km-head">
            <div className="km-head-icon">{icon}</div>
            <div>
                <h2>{name}</h2>
                <div className="km-muted">{job}</div>
            </div>
        </div>;
}

def:pub Tab(label: str, current: str, onPick: Callable[[str], None]) -> JsxElement {
    def pick(e: MouseEvent) { onPick(label); }
    return <button className={"km-tab" + (" on" if label == current else "")} onClick={pick}>{label}</button>;
}

def:pub Pill(label: str, onPick: Callable[[str], None], on: bool = False, value: str = "") -> JsxElement {
    def pick(e: MouseEvent) { onPick(value if value != "" else label); }
    return <button type="button" className={"km-pill" + (" on" if on else "")} onClick={pick}>{label}</button>;
}

# A text / number box with a label
def:pub Field(label: str, value: str, onValue: Callable[[str], None], kind: str = "text", hint: str = "") -> JsxElement {
    def change(e: ChangeEvent) { onValue(str(e.target.value)); }
    return
        <label className="km-field">
            {label}
            <input type={kind} value={value} onChange={change} placeholder={hint} min="0" />
        </label>;
}

def:pub BigText(label: str, value: str, onValue: Callable[[str], None], hint: str = "") -> JsxElement {
    def change(e: ChangeEvent) { onValue(str(e.target.value)); }
    return
        <label className="km-field">
            {label}
            <textarea value={value} onChange={change} placeholder={hint}></textarea>
        </label>;
}

# A drop-down; options are [value, text] pairs
def:pub Choice(label: str, value: str, options: list[list[str]], onValue: Callable[[str], None]) -> JsxElement {
    def change(e: ChangeEvent) { onValue(str(e.target.value)); }
    return
        <label className="km-field">
            {label}
            <select value={value} onChange={change}>
                {for o in options {
                    <option key={o[0]} value={o[0]}>{o[1]}</option>
                }}
            </select>
        </label>;
}
