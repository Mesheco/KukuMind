"""Camera for the Disease detector: take a photo with the phone or laptop camera, or upload one."""

import from react { useRef, useEffect }

def:pub Camera(photo: str, onPhoto: Callable[[str], None]) -> JsxElement {
    has live: bool = False;
    has problem: str = "";
    video: any = useRef(None);
    stream: any = useRef(None);

    def stop_camera() {
        if stream.current {
            stream.current.getTracks().forEach(lambda(t: any) { t.stop(); });
            stream.current = None;
        }
        live = False;
    }

    # switch the camera off when the farmer leaves the page
    useEffect(lambda { return lambda { if stream.current { stream.current.getTracks().forEach(lambda(t: any) { t.stop(); }); } }; }, []);

    async def start_camera(e: MouseEvent) {
        problem = "";
        try {
            nav: any = navigator;
            s: any = await nav.mediaDevices.getUserMedia({"video": {"facingMode": "environment"}, "audio": False});
            stream.current = s;
            live = True;
            video.current.srcObject = s;
            await video.current.play();
        } except Exception as ex {
            problem = "Camera not available here (allow camera access, or use Upload photo).";
            live = False;
        }
    }

    def take_photo(e: MouseEvent) {
        v: any = video.current;
        if not v { return; }
        w: float = float(v.videoWidth);  # jac:ignore[E1053]
        h: float = float(v.videoHeight);  # jac:ignore[E1053]
        scale: float = 1.0;
        if w > 1024 { scale = 1024.0 / w; }
        canvas: any = document.createElement("canvas");
        canvas.width = int(w * scale);
        canvas.height = int(h * scale);
        ctx: any = canvas.getContext("2d");
        ctx.drawImage(v, 0, 0, canvas.width, canvas.height);
        onPhoto(str(canvas.toDataURL("image/jpeg", 0.85)));
        stop_camera();
    }

    def upload(e: ChangeEvent) {
        files: any = e.target.files;
        if not files or files.length == 0 { return; }
        reader: any = new(FileReader);  # jac:ignore[E1053]
        reader.onload = lambda(ev: any) { onPhoto(str(ev.target.result)); };
        reader.readAsDataURL(files[0]);
    }

    def retake(e: MouseEvent) { onPhoto(""); }
    def stop_click(e: MouseEvent) { stop_camera(); }

    return
        <div style={{"border": "1px dashed #2a4468", "borderRadius": "12px", "padding": "0.7rem", "background": "#0d1c33"}}>
            <video ref={video} className="km-video" playsInline={True} muted={True}
                   style={{"display": "block" if live else "none"}}></video>
            {if photo != "" and not live {
                <img src={photo} alt="Photo of the birds" className="km-photo" />
            }}
            {if photo == "" and not live {
                <div className="km-muted" style={{"textAlign": "center", "padding": "1.2rem 0.5rem"}}>
                    📷 Take a clear photo of the sick birds, their droppings, or a dead bird.
                </div>
            }}
            <div style={{"display": "flex", "gap": "0.4rem", "flexWrap": "wrap", "marginTop": "0.5rem", "justifyContent": "center"}}>
                {if live {
                    <button type="button" className="km-btn primary" onClick={take_photo}>📸 Take photo</button>
                }}
                {if live {
                    <button type="button" className="km-btn small" onClick={stop_click}>Cancel</button>
                }}
                {if not live {
                    <button type="button" className="km-btn primary" onClick={start_camera}>{"📷 Open camera" if photo == "" else "📷 Retake with camera"}</button>
                }}
                {if not live {
                    <label className="km-btn" style={{"display": "inline-block"}}>
                        ⬆ Upload photo
                        <input type="file" accept="image/*" capture="environment" onChange={upload} style={{"display": "none"}} />
                    </label>
                }}
                {if photo != "" and not live {
                    <button type="button" className="km-btn small danger" onClick={retake}>Remove photo</button>
                }}
            </div>
            {if problem != "" { <div className="km-small" style={{"color": "#f87171", "textAlign": "center", "marginTop": "0.3rem"}}>{problem}</div> }}
        </div>;
}
