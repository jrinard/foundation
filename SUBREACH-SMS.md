# Subreach SMS — Plan

**Product:** Foundation Outreach — SMS channel  
**Primary use case:** LifeSpring Design — first conversational touch on local SMB prospects  
**Depends on:** Outreach V1 manual loop ([`OUTREACH_PLAN.md`](OUTREACH_PLAN.md)) · `Customer.phone` · optional `DiscoveryBusiness` link  
**Parent checklist:** [`OUTREACH_PLAN.md`](OUTREACH_PLAN.md) — channel step UIs · templates · Twilio → **Settings → Outreach → Text Messages**

**Last updated:** 2026-08-10  
**Status:** ✅ **V1 complete (100%)** — live Twilio outbound/inbound, compliance, website opt-in webhooks, enrollment polling. Production QA passed on Heroku (LifeSpring org).

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

## What we built

### Core SMS step (2026-07)

- **`OutreachTextMessage`** rows = source of truth for the conversation thread
- **Stay on the SMS plan step** while texting — Send and Log outcome do **not** advance plan position
- **Dev simulate buttons** — superadmin + non-production + Dev Mode (no Twilio)
- **Intent-based response templates** in `TextTemplates` (code-defined; no DB template admin)
- **Compliance** — per-customer opt fields + org opt lists + STOP/YES auto-replies
- **Twilio** — ENV credentials + per-org from number in Settings; inbound `POST /twilio/incoming_sms`
- **Potentials dock** — single **Continue Outreach** button → enrollment show

### Production complete (2026-08)

- **Live outbound + inbound** on Heroku — LifeSpring from number in Settings (not ENV)
- **Enrollment thread polling** — auto-refresh conversation + activity on new inbound; draft preserved; Dev Mode off; superadmin can pause via Settings
- **LifeSpring website webhooks** — contact form + website review → Prospects ([`LIFESPRING-WEBSITE-WEBHOOKS.md`](LIFESPRING-WEBSITE-WEBHOOKS.md))
- **Webhook intake** — WebForm contact, activity note, CF/WR badges, opt-in source select, clean SMS status line
- **Admin opt-in alerts** — optional SMS to admin on website opt-in (Settings, superadmin)

---

## Phase status

| Phase | Scope | Status |
|-------|--------|--------|
| 2 | Merge field renderer | 🟡 Partial — inline in `TextTemplates` (acceptable for V1) |
| 3 | SMS step panel UI | ✅ Done |
| 4 | Send actions | ✅ Done |
| 5 | Outcomes + activity | ✅ Done |
| 6 | Compliance (opt-in, opt-out) | ✅ Done |
| 7 | Twilio outbound + inbound webhook | ✅ Done — live QA passed |

**Dropped from V1:** SMS-only plan seed · DB template admin · dock compact SMS · token encryption in DB · Twilio webhook signature validation.

---

## Twilio / Settings config

| Setting | Where |
|---------|--------|
| `TWILIO_ACCOUNT_SID` | Server ENV (Heroku) |
| `TWILIO_AUTH_TOKEN` | Server ENV (Heroku) |
| **`TWILIO_FROM_NUMBER`** | **Not used** — removed; from number is Settings only |
| **From number (per org)** | Settings → Outreach → Text Messages |
| **Text Message Sending Active** | Same — enables live send for that org |
| **Inbound webhook (production)** | `POST` `https://foundation.lifespringdesign.com/twilio/incoming_sms` |
| **Contact form / review webhooks** | [`LIFESPRING-WEBSITE-WEBHOOKS.md`](LIFESPRING-WEBSITE-WEBHOOKS.md) |
| STOP/YES reply copy | Settings (superadmin edit) |
| Opt lists | Settings (superadmin view) |
| Admin opt-in alerts | Settings (superadmin) |
| Auto-refresh enrollment threads | Settings (superadmin; default on) |

---

## V1 checklist

- [x] Complete plan step · phone guard · compliance · Twilio services · inbound actor
- [x] Potentials dock — Continue Outreach (single button)
- [x] Settings — Text Messages panels (Twilio · opt lists · auto-reply · admin alerts · polling toggle)
- [x] Live Twilio QA — ENV creds + org from number + webhook URL in Twilio console
- [x] Live inbound QA — STOP/YES + conversation reply on enrollment thread
- [x] LifeSpring website contact form + review webhooks → Prospects
- [x] Enrollment inbound polling (draft-safe partial refresh)

---

## QA (manual) — passed 2026-08

- [x] Send / simulate / multi-turn / opt-out / Continue Outreach dock button
- [x] Live outbound via Twilio
- [x] Live inbound webhook (production)
- [x] STOP opts out + sends configured confirmation reply
- [x] Website contact form opt-in webhook (200, prospect + contact + activity note)
- [x] Polling updates thread without clearing compose draft

---

## Future (not V1)

- Multi-org website webhook settings UI (URL + token per org in Settings)
- Per-org admin alert phone in Settings (today: `LIFESPRING_OPT_IN_ADMIN_PHONE` ENV)
- Twilio webhook request signature validation
- DB-backed SMS template admin
- Full merge-field renderer UI

---

## Links

- Parent: [`OUTREACH_PLAN.md`](OUTREACH_PLAN.md)
- Website webhooks: [`LIFESPRING-WEBSITE-WEBHOOKS.md`](LIFESPRING-WEBSITE-WEBHOOKS.md)
- Agent context: [`AGENTS.md`](AGENTS.md)
