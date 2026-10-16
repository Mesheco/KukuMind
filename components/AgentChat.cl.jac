"""A chat box for one agent: the farmer types (or attaches a photo) and that agent answers."""

import from react { useRef }
import from .ChatBubble { ChatBubble }
import from .ui { Pill }

def:pub AgentChat(agentKey: str, title: str, lines: list[dict], busy: bool, examples: list[str],
                  onSend: Callable[[str, str, str], None], allowPhoto: bool = False) -> JsxElement {
    has draft: str = "";
    has photo: str = "";
    has photo_name: str = "";
    box: any = useRef(None);

    can with (lines, busy) entry {
        if box.current { box.current.scrollTop = box.current.scrollHeight; }
    }

    def send_now(text: str) {
        if busy or (text.strip() == "" and photo == "") { return; }
        onSend(agentKey, text, photo);
        draft = "";
        photo = "";
        photo_name = "";
    }
    def submit(e: FormEvent) {
        e.preventDefault();
        send_now(draft);
    }
    def typing(e: ChangeEvent) { draft = str(e.target.value); }
    def try_example(x: str) { send_now(x); }
    def pick_photo(e: ChangeEvent) {
        files: any = e.target.files;
        if not files or files.length == 0 { return; }
        f: any = files[0];
        photo_name = str(f.name);
        reader: any = new(FileReader);  # jac:ignore[E1053]
        reader.onload = lambda(ev: any) { photo = str(ev.target.result); };
        reader.readAsDataURL(f);
    }

    return
        <div className="km-card km-chat">
            <h3>{title}</h3>
            <div className="km-small" style={{"marginBottom": "0.4rem"}}>Type in English, Kiswahili or Sheng. Try:</div>
            <div>
                {for x in examples {
                    <Pill key={x} label={x} onPick={try_example} />
                }}
            </div>
            <div className="km-chat-body" ref={box}>
                {if len(lines) == 0 {
                    <div className="km-small" style={{"padding": "0.6rem"}}>No messages yet.</div>
                }}
                {for (i, m) in enumerate(lines) {
                    <ChatBubble key={str(i)} who={m["who"]} text={m["text"]} intent={m["intent"]} level={m["level"]}
                                vet_message={m["vet"]} vet_link={m["vet_link"]} />
                }}
                {if busy {
                    <div className="km-small" style={{"fontStyle": "italic", "padding": "0.4rem"}}>Working on it...</div>
                }}
            </div>
            <form onSubmit={submit} style={{"display": "flex", "gap": "0.4rem", "marginTop": "0.5rem"}}>
                <input className="km-input" value={draft} onChange={typing} placeholder="Andika ujumbe... / Type a message..." />
                {if allowPhoto {
                    <label className="km-btn small" style={{"display": "flex", "alignItems": "center"}} title="Attach a photo">
                        {"📷" if photo == "" else "✅"}
                        <input type="file" accept="image/*" onChange={pick_photo} style={{"display": "none"}} />
                    </label>
                }}
                <button type="submit" className="km-btn primary" disabled={busy}>Tuma</button>
            </form>
            {if photo_name != "" { <div className="km-small">{"Photo ready: " + photo_name}</div> }}
        </div>;
}
