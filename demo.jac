"""KukuMind terminal demo - run with:  jac run demo.jac

Uses the same agents and the same saved farm as the web app (farm.jac).
Do not run this while `jac start main.jac` is running.
"""

import from farm {
    build_demo_farm, kukumind, morning_briefing, flock_summary, new_day,
    feed_report, market_alerts, sales_report, vet_clear, today
}

with entry {
    root spawn build_demo_farm();

    # ONE front door - the manager sends every message to the right agent
    root spawn kukumind(text="B1 leo vifo mbili, chakula gunia moja", date=today());
    root spawn kukumind(text="Kuku za B2 zinakohoa, tatu zimekufa leo", date=today());
    root spawn kukumind(text="When is the Gumboro booster for B1?", date=today());
    root spawn kukumind(text="Manze, msosi itatosha siku ngapi?", date=today());
    root spawn kukumind(text="Nani anataka mayai? Tumeuza pesa ngapi?", date=today());
    root spawn kukumind(text="Batch B2 inaleta faida?", date=today());
    root spawn kukumind(text="Sold 50 B3 layers at 450 each to Mama Njeri", date=today());
    root spawn kukumind(text="Nimeweka mayai 200 ya kienyeji kwa incubator", date=today());
    root spawn kukumind(text="Habari ya shamba leo?", date=today());

    # Photo check: put sick_bird.jpg in this folder, then remove the # below
    # root spawn kukumind(text="Kuku hii ya B3 ina kinyesi cha kijani", date=today(), photo_path="sick_bird.jpg");

    # More demo actions (remove the # to use):
    # root spawn new_day();
    # root spawn feed_report();
    # root spawn market_alerts();
    # root spawn sales_report();
    # root spawn vet_clear(batch_id="B2", date=today(), vet_note="Vet visited, cleared");

    root spawn flock_summary();
}
