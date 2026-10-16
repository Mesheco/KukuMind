# KukuMind 🐔 — your AI farm team, from egg to market

![KukuMind logo](assets/logo.png)

**The problem:** on poultry farms of 500–5,000 birds, disease is noticed too late, feed runs out without warning, and records live in exercise books, so birds and money are lost.

**KukuMind** is a team of seven AI agents, written in **Jac**, that helps medium-scale Kenyan poultry farmers (about 500–5,000 birds) hatch, raise, protect and sell their birds. Farmers and workers talk to it in **English, Kiswahili or Sheng**.

## The seven agents

| Agent | What it does |
|---|---|
| **Manager** | One front door: reads any message and sends it to the right agent; writes the morning briefing |
| **Flock records** | Turns a one-line worker report ("B1 leo vifo 3, chakula gunia moja") into saved records |
| **Hatchery** | Egg sets, candling (day 7 and 14), lockdown (day 18), hatch (day 21), all by chat message ("Nimeweka mayai 200 ya kienyeji"); hatched chicks become a new batch |
| **Advisor** | Brooding temperatures and the vaccination schedule for each batch's age |
| **Disease detector** | RED / AMBER / GREEN triage from symptoms or a photo, plus early warnings from the records. For RED cases it writes a ready-to-send **message for the vet** (WhatsApp or copy) built from the farm records |
| **Feed & inventory** | Feed used per batch, days of feed left, order and wastage alerts |
| **Sales & marketing** | Records sales from a chat message ("Sold 50 B3 layers at 450 each"), market-ready alerts, buyer messages, income and **profit per batch** (sales minus feed eaten) |

## How Jac is used

- **Graph (OSP):** Farm → Houses → Batches → Records / Health checks / Sales, plus Feed store, Buyers and Egg sets. Each agent is a **walker** that moves through this graph.
- **byLLM:** `by llm()` functions read messages in three languages, triage health, and write replies. The AI only copies numbers; Jac code does the arithmetic (32 trays × 30 = 960 eggs).
- **Full stack in Jac:** the server (`farm.jac`) and the web page (`frontend.cl.jac`, `components/*.cl.jac`) are both Jac.

## The web page

- **Home:** what KukuMind solves, how it works, the 7 agents, and the farm today (birds, health, feed, balance, today's plan).
- **Left menu:** Home plus one page for each agent. Every agent works on its own page, with its own tools and its own chat (messages there go straight to that agent). The Manager's team chat passes any message to the right agent.

| Agent page | Tabs and tools |
|---|---|
| **Manager** | Morning briefing (Kiswahili, English, Sheng) · Today's plan and alerts · Dashboard · Farm records · team chat |
| **Flock records** | Daily report form (deaths, feed in bags/kg, eggs in trays, weight) · Register a new flock · Flock list (start − dead − sold = alive) · Records |
| **Disease detector** | **Diagnose** with the camera or a photo plus symptom buttons → RED/AMBER/GREEN, safe actions, possible causes for the vet, WhatsApp message to the vet · **Monitor** every batch (deaths, feed and egg drops, last check, vet clearance) · **Research** a disease (signs, spread, prevention, notifiable, what it means for this farm) |
| **Hatchery** | Incubator with a 21-day progress bar per egg set · candling and hatch forms (hatched chicks become a new batch) · hatch history and hatch rate |
| **Advisor** | Vaccination plan per batch (done / today / this week / later) · brooder heat by age |
| **Feed & inventory** | Stock, days left, bags to order · feed delivery form · expected vs used per batch (wastage / sick-bird flags) · deliveries and price per kg |
| **Sales & marketing** | Sale form (birds, or eggs in trays) · ready for market and buyers · WhatsApp offers to buyers · profit per batch · sales history |

- The farm starts **clean**: 3 batches (B1 1,000 broiler chicks, B2 800 broilers, B3 1,200 layers), 2,500 kg of feed and **no records**.
- **The maths runs everywhere:** deaths and birds sold come off birds alive, feed eaten comes off the store, sales minus feed eaten gives the balance.
- **Clear all records and start fresh** (Manager → Dashboard) wipes every record and starts again.
- Works on a phone: the menu becomes a row at the top.

## Safety rules built into the code

- KukuMind **never names medicines or doses** (and code removes any line that does before it reaches the farmer). It only gives safe actions (isolate sick birds, remove dead birds, stop moving birds) and tells the farmer when to call a vet.
- Very high deaths in the records **always** produce a RED alert, whatever the AI says.
- A batch with a RED alert **cannot be sold** until a vet clears it.
- Newcastle disease and bird flu are flagged as notifiable to the county veterinary officer.
- The vet message is written by code from the records, not by the AI, so its numbers are always exact.

## Run it

```
jac start main.jac
```
Then open http://localhost:8000. It needs `ANTHROPIC_API_KEY` set in the environment.
Replies are written by `claude-sonnet-4-6`; if that model is not available, KukuMind switches to `claude-haiku-4-5` automatically.

- Terminal demo: `jac run demo.jac` (not while the web app is running)
- Live AI test: `cd livetest` then `jac run live_test.jac`

## Files

| File | Purpose |
|---|---|
| `main.jac` | Entry point: joins the server and the web page |
| `farm.jac` | The seven agents, the farm graph and the web API walkers |
| `frontend.cl.jac` | The chat web page |
| `components/` | Home page, menu, one page per agent, camera, chat, charts, records table, shared styles (all Jac) |
| `assets/` | KukuMind logo and browser icon |
| `demo.jac` | Terminal demo |
| `livetest/live_test.jac` | Live test with the real AI (18 checks) |
| `jac.toml` | Project settings |
