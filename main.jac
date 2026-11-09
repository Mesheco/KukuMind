"""KukuMind - Entry Point.

Start the web app with:   jac start main.jac   then open http://localhost:8000

Server side: the 7-agent farm team in farm.jac.
Client side: the chat page in frontend.cl.jac (also written in Jac).
"""

import from farm {
    ChatReply, BatchView, FarmView,
    chat, briefing, farm_status, next_day, clear_batch, start_fresh,
    agent_chat, submit_report, register_flock, diagnose, research, hatchery_action, add_feed, sell, buyer_offers, add_expense, setup_farm,
    order_add, order_deliver, supply_add, supply_receive, vet_book, vet_done, booking_cancel
}

cl {
    import from .frontend { app as KukuApp }

    def:pub app -> JsxElement {
        return <KukuApp/>;
    }
}
