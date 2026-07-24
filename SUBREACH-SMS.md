# Subreach SMS — Plan

**Product:** Foundation Outreach — SMS channel  
**Primary use case:** LifeSpring Design — first conversational touch on local SMB prospects  
**Depends on:** Outreach V1 manual loop ([`OUTREACH_PLAN.md`](OUTREACH_PLAN.md)) · `Customer.phone` · optional `DiscoveryBusiness` link  
**Parent checklist:** [`OUTREACH_PLAN.md`](OUTREACH_PLAN.md) — channel step UIs · templates · Twilio → **Settings → Outreach → Text Messages**

**Last updated:** 2026-07-24  
**Status:** ✅ **V1 complete (~95%)** — manual conversation UI, compliance, Twilio service layer + inbound webhook wired. **Remaining:** live Twilio QA with ENV creds + org from number.

---

## North star

When a rep hits an SMS step, they should be able to:

1. See **who** they’re texting and the **conversation so far**
2. Pick or edit **personalized copy** (Discovery-aware where linked)
3. **Send** — records in CRM; live Twilio when channel active + ENV creds present
4. **Continue the thread** (multiple outbound + inbound turns on the same step)
5. **Log outcome** when the SMS phase is done (replied, no response, opt-out)
6. **Advance to the next plan step** only when explicitly ready (not mid-conversation)

> SMS is the conversation starter. Email and phone steps stay in the **Emerald Plan** — this doc owns **`send_sms`** steps only.

---

## What we built (2026-07)

- **`OutreachTextMessage`** rows = source of truth for the conversation thread
- **Stay on the SMS plan step** while texting — Send and Log outcome do **not** advance plan position
- **Dev simulate buttons** — superadmin + non-production + Dev Mode
- **Intent-based response templates** in `TextTemplates` (code-defined; no DB template admin)
- **Compliance** — per-customer opt fields + org opt lists + STOP/YES auto-replies
- **Twilio** — ENV credentials + per-org from number in Settings; inbound `POST /twilio/incoming_sms`
- **Potentials dock** — single **Continue Outreach** button → enrollment show

---

## Phase status

| Phase | Scope | Status |
|-------|--------|--------|
| 2 | Merge field renderer | 🟡 Partial — inline in `TextTemplates` |
| 3 | SMS step panel UI | ✅ Done |
| 4 | Send actions | ✅ Done |
| 5 | Outcomes + activity | ✅ Done |
| 6 | Compliance (opt-in, opt-out) | ✅ Done |
| 7 | Twilio outbound + inbound webhook | ✅ Built — live QA pending |

**Dropped from scope:** SMS-only plan seed · DB template admin · dock compact SMS · token encryption in DB · webhook signature validation (MVP).

---

## Twilio MVP config

| Setting | Where |
|---------|--------|
| `TWILIO_ACCOUNT_SID` | Server ENV |
| `TWILIO_AUTH_TOKEN` | Server ENV |
| `TWILIO_FROM_NUMBER` | ENV optional dev fallback |
| **From number (per org)** | Settings → Outreach → Text Messages |
| **Active flag** | Same — enables live send for that org |
| **Inbound webhook (production)** | `POST` `https://foundation.lifespringdesign.com/twilio/incoming_sms` — set on Twilio number (Webhook, not TwiML App) |
| **Contact form opt-in webhook** | See [`LIFESPRING-WEBSITE-WEBHOOKS.md`](LIFESPRING-WEBSITE-WEBHOOKS.md) — Contact form + Website review → Prospects |
| STOP/YES reply copy | Settings (superadmin edit) |
| Opt lists | Settings (superadmin view) |

---

## Open items

- [x] Complete plan step · phone guard · compliance · Twilio services · inbound actor
- [x] Potentials dock — Continue Outreach (single button)
- [x] Settings — Text Messages panels (Twilio · opt lists · auto-reply)
- [ ] **Live Twilio QA** — ENV creds + org from number + webhook URL in Twilio console
- [ ] **Live inbound QA** — test STOP/YES + conversation reply

---

## QA (manual)

- [x] Send / simulate / multi-turn / opt-out / Continue Outreach dock button
- [ ] Live outbound via Twilio
- [ ] Live inbound webhook (ngrok or deployed host)
- [ ] STOP opts out + sends configured confirmation reply

---

## Links

- Parent: [`OUTREACH_PLAN.md`](OUTREACH_PLAN.md)
- Agent context: [`AGENTS.md`](AGENTS.md)
