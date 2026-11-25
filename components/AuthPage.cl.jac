"""Sign up / sign in. Every farmer gets a private farm, so testers never mix up each other's records."""

import from "@jac/runtime" { jacSignup, jacLogin }
import from .ui { Styles, Field }

def:pub AuthPage(onDone: Callable[[str], None]) -> JsxElement {
    has mode: str = "signup";     # "signup" or "signin"
    has username: str = "";
    has password: str = "";
    has busy: bool = False;
    has error: str = "";

    async def submit() {
        user = username.strip();
        if user == "" or len(password) < 8 {
            error = "Type your username (your phone number is best) and a password of at least 8 characters.";
            return;
        }
        error = "";
        busy = True;
        ok: bool = False;
        try {
            if mode == "signup" {
                try {
                    await jacSignup(user, password);
                } except Exception as e1 {
                    print("signup did not complete");
                }
            }
            ok = await jacLogin(user, password);
        } except Exception as e {
            ok = False;
        }
        busy = False;
        if ok {
            onDone(user);
        } elif mode == "signup" {
            error = "Could not create your account. The username may already be taken (try Sign in if it is yours), or the password is too weak. Use at least 8 characters.";
        } else {
            error = "Wrong username or password. New here? Choose Create account.";
        }
    }
    def submit_form(e: FormEvent) { e.preventDefault(); submit(); }
    def pick_signup(e: MouseEvent) { mode = "signup"; error = ""; }
    def pick_signin(e: MouseEvent) { mode = "signin"; error = ""; }

    return
        <div className="km-app">
            <Styles />
            <div style={{"maxWidth": "26rem", "margin": "2.5rem auto", "padding": "0 1rem"}}>
                <div style={{"textAlign": "center", "marginBottom": "1.2rem"}}>
                    <img src="/static/logo-mark.png" alt="KukuMind logo" style={{"width": "72px", "height": "72px", "borderRadius": "50%"}} />
                    <div style={{"fontSize": "1.8rem", "fontWeight": "800"}}><span style={{"color": "#2dd4bf"}}>Kuku</span><span>Mind</span></div>
                    <div style={{"opacity": "0.75"}}>Your AI farm team, from egg to market</div>
                </div>
                <form className="km-card" onSubmit={submit_form}>
                    <div style={{"display": "flex", "gap": "0.5rem", "marginBottom": "0.8rem"}}>
                        <button type="button" className={"km-btn primary" if mode == "signup" else "km-btn"} onClick={pick_signup}>Create account</button>
                        <button type="button" className={"km-btn primary" if mode == "signin" else "km-btn"} onClick={pick_signin}>Sign in</button>
                    </div>
                    <Field label="Username (your phone number is best)" value={username} onValue={lambda(v: str) { username = v; }} hint="e.g. 0712345678" />
                    <Field label="Password (8 or more characters)" value={password} onValue={lambda(v: str) { password = v; }} kind="password" />
                    {if error != "" { <div className="km-notice" style={{"marginTop": "0.6rem"}}>{error}</div> }}
                    <button type="submit" className="km-btn primary" style={{"marginTop": "0.8rem", "width": "100%"}} disabled={busy}>
                        {"Please wait..." if busy else ("Create my farm" if mode == "signup" else "Sign in")}
                    </button>
                    <div className="km-small" style={{"marginTop": "0.7rem"}}>
                        Your farm is private to you. Nobody else can see or change your records. Remember your password: it cannot be reset yet.
                    </div>
                </form>
            </div>
        </div>;
}
