"""Reset the farm: back to the demo farm, or start an EMPTY farm with the farmer's own details."""

import from .ui { Field, Notice }

sv import from ..farm { FarmView, setup_farm }

def:pub ResetFarm(onDone: Callable[[FarmView], None], onClose: Callable[[], None]) -> JsxElement {
    has mode: str = "own";
    has name: str = "";
    has owner: str = "";
    has phone: str = "";
    has houses: str = "House A, House B";
    has feed: str = "";
    has vet_name: str = "";
    has vet_phone: str = "";
    has working: bool = False;
    has msg: str = "";

    async def go() {
        if mode == "own" and name.strip() == "" {
            msg = "Please enter the farm name.";
            return;
        }
        win: any = window;
        if not win.confirm("This deletes ALL records, batches, sales and costs on this farm. Continue?") { return; }
        working = True;
        res = root spawn setup_farm(mode=mode, name=name, owner=owner, phone=phone, houses=houses,
                                    feed_kg=parseFloat(feed or "0"), vet_name=vet_name, vet_phone=vet_phone);
        working = False;
        if res.reports and len(res.reports) > 0 { onDone(res.reports[0]); }
    }
    def submit(e: FormEvent) { e.preventDefault(); go(); }
    def close(e: MouseEvent) { onClose(); }

    return
        <div className="km-modal-back">
            <form className="km-card km-modal" onSubmit={submit}>
                <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center"}}>
                    <h3 style={{"margin": "0"}}>⟳ Reset farm</h3>
                    <button type="button" className="km-btn small" onClick={close}>✕ Close</button>
                </div>
                <div className="km-muted" style={{"margin": "0.4rem 0 0.9rem"}}>
                    Choose how to start. Everything on the current farm (batches, reports, sales, costs, health checks, egg sets) will be deleted.
                </div>
                <div className="km-grid2" style={{"marginBottom": "0.9rem"}}>
                    <button type="button" className={"km-agent" + (" km-picked" if mode == "own" else "")} onClick={lambda(e: MouseEvent) { mode = "own"; }}>
                        <strong>🏡 My own farm (empty)</strong>
                        <span className="km-muted">No batches, no records. Enter your farm’s details, then register your own flocks and reports.</span>
                    </button>
                    <button type="button" className={"km-agent" + (" km-picked" if mode == "demo" else "")} onClick={lambda(e: MouseEvent) { mode = "demo"; }}>
                        <strong>🎬 Demo farm</strong>
                        <span className="km-muted">Meshack Poultry Farm: B1, B2, B3 and 2,500 kg feed, no records. Good for presentations.</span>
                    </button>
                </div>
                {if mode == "own" {
                    <div className="km-grid2">
                        <Field label="Farm name *" value={name} onValue={lambda(v: str) { name = v; }} hint="e.g. Kamau Poultry Farm" />
                        <Field label="Owner" value={owner} onValue={lambda(v: str) { owner = v; }} hint="e.g. Kamau" />
                        <Field label="Owner phone" value={phone} onValue={lambda(v: str) { phone = v; }} hint="e.g. 0722..." />
                        <Field label="Houses (separate with commas)" value={houses} onValue={lambda(v: str) { houses = v; }} />
                        <Field label="Feed in store now (kg)" value={feed} onValue={lambda(v: str) { feed = v; }} kind="number" hint="e.g. 1000" />
                        <span></span>
                        <Field label="Vet name" value={vet_name} onValue={lambda(v: str) { vet_name = v; }} hint="e.g. Dr. ..." />
                        <Field label="Vet phone" value={vet_phone} onValue={lambda(v: str) { vet_phone = v; }} hint="e.g. 0714..." />
                    </div>
                }}
                <div style={{"marginTop": "1rem", "display": "flex", "gap": "0.5rem", "flexWrap": "wrap"}}>
                    <button type="submit" className="km-btn primary" disabled={working}>
                        {"Resetting..." if working else ("Start my own farm" if mode == "own" else "Reset to the demo farm")}
                    </button>
                    <button type="button" className="km-btn" onClick={close}>Cancel</button>
                </div>
                <Notice text={msg} ok={False} />
                {if mode == "own" {
                    <div className="km-small" style={{"marginTop": "0.6rem"}}>
                        Next: Flock records → New flock to add your birds, then save daily reports, sales and costs.
                    </div>
                }}
            </form>
        </div>;
}
