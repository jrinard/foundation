# LifeSpring website webhooks

Reference for **`lifespringdesign.com` → Foundation** lead intake. Two forms share one handler; **`sms_opt_in_source`** is the discriminator.

**Related:** [`SUBREACH-SMS.md`](SUBREACH-SMS.md) (Outreach/SMS ops), service `app/services/lifespring/contact_form_opt_in.rb`.

---

## Overview

When someone submits a LifeSpring website form with SMS consent, the site backend POSTs JSON to Foundation. Foundation:

1. Authenticates the request
2. Creates or updates a **Prospects** customer (LifeSpring org)
3. Records SMS opt-in audit fields (`sms_opt_in`, `sms_opt_in_at`, `sms_opt_in_source`, `sms_opt_in_label`)
4. Adds the phone to the org SMS whitelist (when outreach is configured)
5. Optionally texts the LifeSpring admin (`LIFESPRING_OPT_IN_ADMIN_PHONE`, default `2083168338`) when **Text Admin when new opt-ins happen** is enabled in Settings → Outreach → Text Messages

Prospects list shows a source badge on the card:

| Source | Badge | Color |
|--------|-------|-------|
| Contact form | **CF** | Green |
| Website review | **WR** | Amber |

Default Prospects sort is **newest opt-in first**. Filters: *Website contact form*, *Website review*, *Opted in today*, *Opted in this week*.

---

## Endpoints

Both URLs hit the **same handler**. Pick one URL per form; the payload **`sms_opt_in_source`** must match the form type.

| Form | POST URL (production) |
|------|------------------------|
| **Contact form** | `https://foundation.lifespringdesign.com/webhooks/lifespring/contact_form_opt_in` |
| **Website review** | `https://foundation.lifespringdesign.com/webhooks/lifespring/website_review` |

Local dev: replace host with `http://localhost:3000`.

---

## Authentication

Set on Foundation server (`.env`):

```bash
LIFESPRING_CONTACT_FORM_WEBHOOK_TOKEN=your-long-random-secret
LIFESPRING_CONTACT_FORM_ORG_SLUG=lifespring   # optional; defaults to lifespring
```

Website backend sends **one** of:

```http
Authorization: Bearer YOUR_TOKEN_HERE
```

```http
X-LifeSpring-Webhook-Token: YOUR_TOKEN_HERE
```

- Missing/wrong token → `401` `{ "ok": false, "error": "Unauthorized" }`
- Share the token out-of-band (not in front-end JS)

---

## When to call

**Only when the user checks the SMS opt-in checkbox.**  
If they do not opt in, do not call the webhook.

Both forms require `sms_opt_in: true`.

---

## Source identifiers (critical)

The website **must** send the exact `sms_opt_in_source` string for the form. Foundation rejects unknown values.

| Form | `sms_opt_in_source` (exact) |
|------|-----------------------------|
| Contact form | `lifespringdesign.com/contact-form` |
| Website review | `lifespringdesign.com/website-review` |

Defined in code: `Lifespring::WebsiteSources` (`app/services/lifespring/website_sources.rb`).

Wrong source → `422`:

```json
{
  "ok": false,
  "error": "sms_opt_in_source must be one of: lifespringdesign.com/contact-form, lifespringdesign.com/website-review."
}
```

---

## Payload (JSON, snake_case)

`Content-Type: application/json`

### Required (when SMS opt-in checked)

| Field | Type | Notes |
|-------|------|--------|
| `phone` | string | 10-digit US ok: `"3605551234"`, `"360-555-1234"`, `"+13605551234"` |
| `sms_opt_in` | boolean | Must be `true` |
| `sms_opt_in_source` | string | See table above — **exact match** |

### Strongly recommended

| Field | Type | Notes |
|-------|------|--------|
| `name` | string | Person name |
| `business_name` | string | Company; used as CRM customer name when present |
| `email` | string | Match/update existing customer |
| `message` | string | Form body / notes |
| `sms_opt_in_at` | string | ISO 8601 UTC, e.g. `"2026-07-24T20:15:00.000Z"` |
| `sms_opt_in_label` | string | **Exact checkbox label** (compliance audit) |

Use **snake_case** keys (`business_name`, not `businessName`).

---

## Examples

### Contact form

```bash
curl -X POST "https://foundation.lifespringdesign.com/webhooks/lifespring/contact_form_opt_in" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "name": "Jordan Test",
    "business_name": "Sunrise Bakery",
    "email": "hello@sunrisebakery.com",
    "phone": "3605550199",
    "message": "Interested in a new website and local SEO.",
    "sms_opt_in": true,
    "sms_opt_in_source": "lifespringdesign.com/contact-form",
    "sms_opt_in_at": "2026-07-24T20:15:00.000Z",
    "sms_opt_in_label": "Yes, text me about my project"
  }'
```

### Website review

```bash
curl -X POST "https://foundation.lifespringdesign.com/webhooks/lifespring/website_review" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "name": "Alex Rivera",
    "business_name": "Rivera Plumbing",
    "email": "alex@riveraplumbing.com",
    "phone": "3605554422",
    "message": "Please review our site and suggest improvements.",
    "sms_opt_in": true,
    "sms_opt_in_source": "lifespringdesign.com/website-review",
    "sms_opt_in_at": "2026-07-24T21:00:00.000Z",
    "sms_opt_in_label": "Yes, text me about my free website review"
  }'
```

---

## Success response (`200`)

```json
{
  "ok": true,
  "customer_id": 13,
  "created": true,
  "board": "prospects",
  "sms_opt_in": true,
  "sms_opt_in_at": "2026-07-24T20:15:00.000Z",
  "sms_opt_in_source": "lifespringdesign.com/contact-form"
}
```

- `created: true` — new prospect
- `created: false` — matched existing customer (phone, then email) and updated
- Customer appears on **Prospects** with **CF** or **WR** badge

---

## Error responses

| Status | Example |
|--------|---------|
| `401` | `{ "ok": false, "error": "Unauthorized" }` |
| `422` | `{ "ok": false, "error": "phone is required." }` |
| `422` | `{ "ok": false, "error": "sms_opt_in must be true." }` |
| `422` | `{ "ok": false, "error": "sms_opt_in_source must be one of: ..." }` |
| `500` | `{ "ok": false, "error": "Internal error." }` |

---

## CRM behavior

### Customer matching

1. Normalize phone → find customer in LifeSpring org  
2. Else lowercase email → find customer  
3. Else create new

Existing customers are moved to **Prospects** (`onBoard: "The List"`, not archived).

### Notes prefix

| Source | `extra_notes` starts with |
|--------|---------------------------|
| Contact form | `LifeSpring contact form` |
| Website review | `LifeSpring website review` |

Message and contact name are appended when provided.

### Default customer name

If no `business_name` or `name`:

| Source | Default name |
|--------|----------------|
| Contact form | `Website contact` |
| Website review | `Website review` |

---

## Website integration checklist

1. **Server-side only** — never expose webhook token in browser code.  
2. On submit **with SMS checked**, POST JSON from your server/API route.  
3. Use the correct **URL** and matching **`sms_opt_in_source`**.  
4. Send `sms_opt_in_at` as submit time (UTC).  
5. Send `sms_opt_in_label` as the exact checkbox text shown to the user.  
6. Log `customer_id` from the response for support traceability.  
7. Do not block the user on Foundation errors — log and alert internally.

---

## Code map (Foundation)

| Piece | Path |
|-------|------|
| Allowed sources + badges | `app/services/lifespring/website_sources.rb` |
| Intake service | `app/services/lifespring/contact_form_opt_in.rb` |
| Controller | `app/controllers/lifespring_webhooks_controller.rb` |
| Routes | `config/routes.rb` |
| Prospects filters/sort | `app/controllers/potentials_controller.rb` |
| Specs | `spec/requests/lifespring_contact_form_opt_in_spec.rb`, `spec/services/lifespring/contact_form_opt_in_spec.rb` |

---

## Tell the other codebase

**Contact form**

- URL: `.../webhooks/lifespring/contact_form_opt_in`
- Source: `lifespringdesign.com/contact-form`

**Website review**

- URL: `.../webhooks/lifespring/website_review`
- Source: `lifespringdesign.com/website-review`

Same auth token, same JSON shape, same required fields. Only URL + `sms_opt_in_source` change.
